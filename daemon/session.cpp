/*
    Copyright (c) 2026 Alex Fabri
    https://fromhelloworld.com
    https://github.com/hotbit9

    This file is part of CRT Plus.

    CRT Plus is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    CRT Plus is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with CRT Plus.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "session.h"
#include "log.h"
#include "protocol.h"

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <util.h>       // openpty
#else
#include <dirent.h>     // opendir/readdir for close_fds_from
#include <pty.h>        // openpty on Linux
#endif

// Set FD_CLOEXEC on a file descriptor
static bool set_cloexec(int fd) {
    int flags = fcntl(fd, F_GETFD);
    if (flags < 0) return false;
    return fcntl(fd, F_SETFD, flags | FD_CLOEXEC) == 0;
}

// Set O_NONBLOCK on a file descriptor
static bool set_nonblock(int fd) {
    int flags = fcntl(fd, F_GETFL);
    if (flags < 0) return false;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0;
}

// Close all file descriptors >= lowfd
static void close_fds_from(int lowfd) {
#if defined(__APPLE__)
    // macOS has closefrom() in unistd.h (available since macOS 10.x)
    // But it's not always declared — use manual approach for portability
    int maxfd = static_cast<int>(sysconf(_SC_OPEN_MAX));
    if (maxfd < 0) maxfd = 1024;
    for (int fd = lowfd; fd < maxfd; fd++)
        close(fd);
#elif defined(__linux__)
    // Try /proc/self/fd first (faster on Linux)
    DIR *dir = opendir("/proc/self/fd");
    if (dir) {
        int dirfd_val = dirfd(dir);
        struct dirent *ent;
        while ((ent = readdir(dir)) != nullptr) {
            int fd = atoi(ent->d_name);
            if (fd >= lowfd && fd != dirfd_val)
                close(fd);
        }
        closedir(dir);
    } else {
        int maxfd = static_cast<int>(sysconf(_SC_OPEN_MAX));
        if (maxfd < 0) maxfd = 1024;
        for (int fd = lowfd; fd < maxfd; fd++)
            close(fd);
    }
#else
    int maxfd = static_cast<int>(sysconf(_SC_OPEN_MAX));
    if (maxfd < 0) maxfd = 1024;
    for (int fd = lowfd; fd < maxfd; fd++)
        close(fd);
#endif
}

// List of dangerous environment variables to strip
static const char *DANGEROUS_ENV_VARS[] = {
    "LD_PRELOAD",
    "LD_LIBRARY_PATH",
    "BASH_ENV",
    "ENV",
    "CDPATH",
    nullptr
};

// Check if a variable name starts with a dangerous prefix
static bool is_dangerous_env_prefix(const char *name, size_t name_len) {
    // DYLD_* variables (macOS)
    if (name_len >= 5 && strncmp(name, "DYLD_", 5) == 0)
        return true;
    return false;
}

std::vector<std::string> sanitize_environment(const std::vector<std::string> &env) {
    std::vector<std::string> result;
    bool has_term = false;

    for (const auto &entry : env) {
        // Individual entry size limit: 4 KB
        if (entry.size() > 4096) {
            LOG_WARN("dropping oversized env var (%zu bytes)", entry.size());
            continue;
        }

        // Extract variable name (everything before '=')
        size_t eq = entry.find('=');
        if (eq == std::string::npos)
            continue;

        std::string name = entry.substr(0, eq);

        // Check against dangerous variable names
        bool dangerous = false;
        for (const char **dv = DANGEROUS_ENV_VARS; *dv; dv++) {
            if (name == *dv) {
                dangerous = true;
                break;
            }
        }
        if (dangerous) {
            LOG_DEBUG("stripping dangerous env: %s", name.c_str());
            continue;
        }

        // Check dangerous prefixes
        if (is_dangerous_env_prefix(name.c_str(), name.size())) {
            LOG_DEBUG("stripping dangerous env prefix: %s", name.c_str());
            continue;
        }

        // Sanitize PATH: remove '.' and empty components
        if (name == "PATH") {
            std::string value = entry.substr(eq + 1);
            std::string clean_path;
            size_t start = 0;
            while (start <= value.size()) {
                size_t colon = value.find(':', start);
                if (colon == std::string::npos)
                    colon = value.size();
                std::string component = value.substr(start, colon - start);
                if (!component.empty() && component[0] == '/') {
                    if (!clean_path.empty())
                        clean_path += ':';
                    clean_path += component;
                }
                start = colon + 1;
            }
            result.push_back("PATH=" + clean_path);
        } else {
            result.push_back(entry);
        }

        if (name == "TERM")
            has_term = true;
    }

    // Ensure TERM is set
    if (!has_term)
        result.push_back("TERM=xterm-256color");

    // Total environment size limit: 32 KB
    size_t total = 0;
    for (const auto &e : result)
        total += e.size() + 1;
    if (total > 32768) {
        LOG_WARN("total environment size (%zu) exceeds 32KB limit", total);
        // Keep it but warn — don't silently truncate
    }

    return result;
}

bool validate_shell_path(const char *path) {
    if (!path || path[0] == '\0')
        return false;

    struct stat st;
    if (stat(path, &st) != 0) {
        LOG_ERROR("shell path does not exist: %s", path);
        return false;
    }
    if (S_ISDIR(st.st_mode)) {
        LOG_ERROR("shell path is a directory: %s", path);
        return false;
    }
    if (access(path, X_OK) != 0) {
        LOG_ERROR("shell path is not executable: %s", path);
        return false;
    }
    return true;
}

DaemonSession *session_create(const char *shell_path,
                              const std::vector<std::string> &args,
                              const std::vector<std::string> &env,
                              const char *cwd,
                              uint16_t rows, uint16_t cols,
                              size_t ring_capacity) {
    if (!validate_shell_path(shell_path))
        return nullptr;

    // Sanitize environment
    auto clean_env = sanitize_environment(env);

    // Open PTY pair
    int master_fd = -1, slave_fd = -1;
    if (openpty(&master_fd, &slave_fd, nullptr, nullptr, nullptr) != 0) {
        LOG_ERROR("openpty failed: %s", strerror(errno));
        return nullptr;
    }

    // Set FD_CLOEXEC on both fds
    set_cloexec(master_fd);
    set_cloexec(slave_fd);

    // Set slave permissions to 0600
    fchmod(slave_fd, 0600);

    // Set initial window size
    struct winsize ws = {};
    ws.ws_row = rows;
    ws.ws_col = cols;
    ioctl(master_fd, TIOCSWINSZ, &ws);

    // Build argv for execvp.
    // login_name must outlive argv (which stores a raw pointer into it).
    std::string login_name;
    std::vector<const char *> argv;
    if (args.empty()) {
        // Default: use shell name as argv[0] with leading '-' for login shell
        const char *slash = strrchr(shell_path, '/');
        const char *base = slash ? slash + 1 : shell_path;
        login_name = std::string("-") + base;
        argv.push_back(login_name.c_str());
    } else {
        for (const auto &a : args)
            argv.push_back(a.c_str());
    }
    argv.push_back(nullptr);

    // Build envp for execve
    std::vector<const char *> envp;
    for (const auto &e : clean_env)
        envp.push_back(e.c_str());
    envp.push_back(nullptr);

    // Fork
    pid_t pid = fork();
    if (pid < 0) {
        LOG_ERROR("fork failed: %s", strerror(errno));
        close(master_fd);
        close(slave_fd);
        return nullptr;
    }

    if (pid == 0) {
        // ----- Child process -----

        // Create new session
        setsid();

        // Set controlling terminal
        ioctl(slave_fd, TIOCSCTTY, 0);

        // Dup slave fd to stdin/stdout/stderr
        dup2(slave_fd, STDIN_FILENO);
        dup2(slave_fd, STDOUT_FILENO);
        dup2(slave_fd, STDERR_FILENO);

        // Set foreground process group
        pid_t child_pid = getpid();
        tcsetpgrp(STDIN_FILENO, child_pid);

        // Close all fds >= 3
        close_fds_from(3);

        // Reset signal handlers to default
        struct sigaction sa = {};
        sa.sa_handler = SIG_DFL;
        sigemptyset(&sa.sa_mask);
        for (int sig = 1; sig < NSIG; sig++)
            sigaction(sig, &sa, nullptr);

        // Unblock all signals
        sigset_t mask;
        sigemptyset(&mask);
        sigprocmask(SIG_SETMASK, &mask, nullptr);

        // Change directory
        if (cwd && cwd[0] != '\0') {
            if (chdir(cwd) != 0) {
                // Fall back to home directory
                const char *home = getenv("HOME");
                if (home)
                    (void)chdir(home);
            }
        }

        // Exec the shell
        execve(shell_path,
               const_cast<char *const *>(argv.data()),
               const_cast<char *const *>(envp.data()));

        // If execve fails, write error and exit
        const char *err = "crt-sessiond: exec failed\n";
        (void)::write(STDERR_FILENO, err, strlen(err));
        _exit(127);
    }

    // ----- Parent process -----

    // Close slave fd (child owns it now)
    close(slave_fd);

    // Set master fd non-blocking
    set_nonblock(master_fd);

    // Allocate ring buffer
    RingBuffer *ring = new (std::nothrow) RingBuffer(ring_capacity);
    if (!ring || !ring->valid()) {
        LOG_ERROR("failed to allocate ring buffer (%zu bytes)", ring_capacity);
        delete ring;
        close(master_fd);
        kill(pid, SIGKILL);
        waitpid(pid, nullptr, 0);
        return nullptr;
    }

    // Allocate session
    DaemonSession *s = new (std::nothrow) DaemonSession{};
    if (!s) {
        LOG_ERROR("failed to allocate session");
        delete ring;
        close(master_fd);
        kill(pid, SIGKILL);
        waitpid(pid, nullptr, 0);
        return nullptr;
    }

    // Generate UUID
    if (!uuid_generate(s->uuid, sizeof(s->uuid))) {
        LOG_ERROR("failed to generate UUID");
        delete ring;
        delete s;
        close(master_fd);
        kill(pid, SIGKILL);
        waitpid(pid, nullptr, 0);
        return nullptr;
    }

    s->master_fd = master_fd;
    s->shell_pid = pid;
    s->rows = rows;
    s->cols = cols;
    s->ring = ring;
    s->client_fd = -1;
    s->created_at = time(nullptr);
    s->detached_at = 0;
    strncpy(s->cwd, cwd ? cwd : "", PATH_MAX - 1);
    s->cwd[PATH_MAX - 1] = '\0';
    strncpy(s->shell, shell_path, PATH_MAX - 1);
    s->shell[PATH_MAX - 1] = '\0';
    s->alive = true;
    s->exit_code = 0;
    memset(&s->saved_termios, 0, sizeof(s->saved_termios));
    s->has_saved_termios = false;
    s->flow_paused = false;
    s->cached_fg_pid = 0;

    LOG_INFO("session created: %s (shell=%s, pid=%d, %dx%d)",
             s->uuid, shell_path, pid, cols, rows);

    return s;
}

void session_destroy(DaemonSession *session) {
    if (!session) return;

    LOG_INFO("session destroyed: %s", session->uuid);

    // Close master fd
    if (session->master_fd >= 0) {
        close(session->master_fd);
        session->master_fd = -1;
    }

    // Kill shell if still alive
    if (session->alive && session->shell_pid > 0) {
        kill(session->shell_pid, SIGHUP);
        // Give it a moment
        int status;
        pid_t r = waitpid(session->shell_pid, &status, WNOHANG);
        if (r == 0) {
            // Still running — escalate to SIGKILL
            usleep(100000); // 100ms
            kill(session->shell_pid, SIGKILL);
            waitpid(session->shell_pid, &status, 0);
        }
    }

    // Secure-clear and free ring buffer
    if (session->ring) {
        delete session->ring;
        session->ring = nullptr;
    }

    // Secure-clear the session struct itself
    memset(session->uuid, 0, sizeof(session->uuid));
    memset(&session->saved_termios, 0, sizeof(session->saved_termios));

    delete session;
}

DaemonSession *session_handle_child_exit(DaemonSession **sessions, int count,
                                         pid_t pid, int status) {
    for (int i = 0; i < count; i++) {
        if (sessions[i] && sessions[i]->shell_pid == pid) {
            sessions[i]->alive = false;
            if (WIFEXITED(status)) {
                sessions[i]->exit_code = WEXITSTATUS(status);
                LOG_INFO("session %s: shell exited with code %d",
                         sessions[i]->uuid, sessions[i]->exit_code);
            } else if (WIFSIGNALED(status)) {
                sessions[i]->exit_code = 128 + WTERMSIG(status);
                LOG_INFO("session %s: shell killed by signal %d",
                         sessions[i]->uuid, WTERMSIG(status));
            }
            return sessions[i];
        }
    }
    return nullptr;
}
