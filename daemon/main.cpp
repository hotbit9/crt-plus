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

#include "event_loop.h"
#include "log.h"
#include "protocol.h"
#include "server.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>

// Global debug flag (declared extern in log.h)
bool g_debug_mode = false;

// -------------------------------------------------------------------
// Signal handlers
// -------------------------------------------------------------------

static void signal_handler(int /*sig*/) {
    signal_pipe_notify();
}

static void shutdown_handler(int /*sig*/) {
    // Set a flag that the event loop checks
    extern volatile sig_atomic_t g_shutdown_requested;
    g_shutdown_requested = 1;
    signal_pipe_notify();
}

// Defined in event_loop.cpp — needed for shutdown_handler
extern volatile sig_atomic_t g_shutdown_requested;

// -------------------------------------------------------------------
// CLI argument parsing
// -------------------------------------------------------------------

struct CliArgs {
    bool version;
    bool shutdown;
    bool debug;
    bool foreground;
    size_t buffer_size;
};

static CliArgs parse_args(int argc, char *argv[]) {
    CliArgs args = {};
    args.buffer_size = DEFAULT_RING_BUFFER_SIZE;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--version") == 0 || strcmp(argv[i], "-v") == 0) {
            args.version = true;
        } else if (strcmp(argv[i], "--shutdown") == 0) {
            args.shutdown = true;
        } else if (strcmp(argv[i], "--debug") == 0) {
            args.debug = true;
            args.foreground = true;  // Debug implies foreground
        } else if (strcmp(argv[i], "--foreground") == 0 || strcmp(argv[i], "-f") == 0) {
            args.foreground = true;
        } else if (strcmp(argv[i], "--buffer-size") == 0 && i + 1 < argc) {
            i++;
            long val = strtol(argv[i], nullptr, 10);
            if (val > 0 && val <= 64 * 1024 * 1024)  // Max 64 MB
                args.buffer_size = static_cast<size_t>(val);
            else
                fprintf(stderr, "invalid buffer size: %s\n", argv[i]);
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("Usage: crt-sessiond [OPTIONS]\n\n"
                   "Options:\n"
                   "  --version, -v       Print version and exit\n"
                   "  --shutdown          Send SIGTERM to running daemon and exit\n"
                   "  --debug             Run in foreground with verbose logging\n"
                   "  --foreground, -f    Run in foreground (don't daemonize)\n"
                   "  --buffer-size N     Ring buffer size in bytes (default: %zu)\n"
                   "  --help, -h          Show this help\n",
                   DEFAULT_RING_BUFFER_SIZE);
            exit(0);
        } else {
            fprintf(stderr, "unknown option: %s\n", argv[i]);
            exit(1);
        }
    }

    return args;
}

// -------------------------------------------------------------------
// Daemonize (double-fork)
// -------------------------------------------------------------------

static bool daemonize() {
    // First fork
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return false;
    }
    if (pid > 0)
        _exit(0);  // Parent exits

    // Create new session
    if (setsid() < 0) {
        perror("setsid");
        return false;
    }

    // Second fork (prevent reacquiring a controlling terminal)
    pid = fork();
    if (pid < 0) {
        perror("fork");
        return false;
    }
    if (pid > 0)
        _exit(0);  // First child exits

    // Redirect stdin/stdout/stderr to /dev/null
    int devnull = open("/dev/null", O_RDWR);
    if (devnull >= 0) {
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        if (devnull > STDERR_FILENO)
            close(devnull);
    }

    // Set file creation mask
    umask(0077);

    return true;
}

// -------------------------------------------------------------------
// Main
// -------------------------------------------------------------------

int main(int argc, char *argv[]) {
    CliArgs args = parse_args(argc, argv);

    // --version
    if (args.version) {
        printf("crt-sessiond %s (protocol %d)\n", DAEMON_VERSION, PROTOCOL_VERSION);
        return 0;
    }

    // --debug
    g_debug_mode = args.debug;

    // --shutdown: send SIGTERM to running daemon
    if (args.shutdown) {
        pid_t pid = read_pid_file();
        if (pid <= 0) {
            fprintf(stderr, "no running daemon found\n");
            return 1;
        }
        if (kill(pid, SIGTERM) != 0) {
            fprintf(stderr, "failed to send SIGTERM to pid %d: %s\n",
                    pid, strerror(errno));
            return 1;
        }
        printf("sent SIGTERM to daemon (pid %d)\n", pid);
        return 0;
    }

    // Create socket directory
    if (!create_socket_dir()) {
        fprintf(stderr, "failed to create socket directory\n");
        return 1;
    }

    // Check if daemon is already running
    pid_t existing = read_pid_file();
    if (existing > 0 && kill(existing, 0) == 0) {
        fprintf(stderr, "daemon already running (pid %d)\n", existing);
        return 1;
    }

    // Daemonize unless --foreground or --debug
    if (!args.foreground) {
        if (!daemonize())
            return 1;
    }

    // Initialize signal pipe
    if (!signal_pipe_init()) {
        LOG_ERROR("failed to initialize signal pipe");
        return 1;
    }

    // Install signal handlers
    struct sigaction sa = {};
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    sigaction(SIGCHLD, &sa, nullptr);

    sa.sa_handler = shutdown_handler;
    sigaction(SIGTERM, &sa, nullptr);
    sigaction(SIGINT, &sa, nullptr);

    // Ignore SIGPIPE (detect write errors via return value)
    signal(SIGPIPE, SIG_IGN);

    // Create listening socket
    int listen_fd = create_listen_socket();
    if (listen_fd < 0) {
        LOG_ERROR("failed to create listen socket");
        return 1;
    }

    // Write PID file
    if (!write_pid_file(getpid())) {
        LOG_ERROR("failed to write PID file");
        close(listen_fd);
        return 1;
    }

    LOG_INFO("crt-sessiond %s started (pid %d, protocol %d)",
             DAEMON_VERSION, getpid(), PROTOCOL_VERSION);

    // Set ring buffer capacity
    set_ring_buffer_capacity(args.buffer_size);

    // Enter event loop
    event_loop_run(listen_fd);

    // Cleanup
    close(listen_fd);
    cleanup_socket_files();

    LOG_INFO("crt-sessiond shut down cleanly");
    return 0;
}
