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

#include "server.h"
#include "log.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <sys/ucred.h>
#endif

// -------------------------------------------------------------------
// Socket directory and paths
// -------------------------------------------------------------------

std::string get_socket_dir() {
#if defined(__APPLE__)
    const char *tmpdir = getenv("TMPDIR");
    if (!tmpdir || tmpdir[0] == '\0')
        tmpdir = "/tmp";
    char buf[512];
    snprintf(buf, sizeof(buf), "%s/crt-plus-%u", tmpdir, static_cast<unsigned>(getuid()));
    return std::string(buf);
#else
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (xdg && xdg[0] != '\0') {
        return std::string(xdg) + "/crt-plus";
    }
    char buf[512];
    snprintf(buf, sizeof(buf), "/tmp/crt-plus-%u", static_cast<unsigned>(getuid()));
    return std::string(buf);
#endif
}

std::string get_socket_path() {
    return get_socket_dir() + "/sessiond.sock";
}

std::string get_pid_file_path() {
    return get_socket_dir() + "/sessiond.pid";
}

// -------------------------------------------------------------------
// TOCTOU-safe directory creation
// -------------------------------------------------------------------

bool create_socket_dir() {
    std::string dir = get_socket_dir();

    // Find parent directory
    size_t last_slash = dir.rfind('/');
    if (last_slash == std::string::npos) {
        LOG_ERROR("invalid socket dir path: %s", dir.c_str());
        return false;
    }
    std::string parent = dir.substr(0, last_slash);
    std::string basename = dir.substr(last_slash + 1);

    // Open parent directory
    int parent_fd = open(parent.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (parent_fd < 0) {
        LOG_ERROR("cannot open parent dir %s: %s", parent.c_str(), strerror(errno));
        return false;
    }

    // Create our directory (may fail with EEXIST, that's fine)
    mkdirat(parent_fd, basename.c_str(), 0700);

    // Open our directory with O_NOFOLLOW to prevent symlink attacks
    int dir_fd = openat(parent_fd, basename.c_str(),
                        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    close(parent_fd);

    if (dir_fd < 0) {
        LOG_ERROR("cannot open socket dir %s (symlink?): %s",
                  dir.c_str(), strerror(errno));
        return false;
    }

    // Verify ownership and permissions
    struct stat st;
    if (fstat(dir_fd, &st) != 0) {
        LOG_ERROR("fstat on socket dir failed: %s", strerror(errno));
        close(dir_fd);
        return false;
    }

    if (st.st_uid != getuid()) {
        LOG_ERROR("socket dir owned by uid %u, expected %u",
                  st.st_uid, static_cast<unsigned>(getuid()));
        close(dir_fd);
        return false;
    }

    if ((st.st_mode & 0777) != 0700) {
        // Try to fix permissions
        if (fchmod(dir_fd, 0700) != 0) {
            LOG_ERROR("socket dir mode is %o, expected 0700, and chmod failed",
                      st.st_mode & 0777);
            close(dir_fd);
            return false;
        }
        LOG_WARN("fixed socket dir permissions to 0700");
    }

    close(dir_fd);
    return true;
}

// -------------------------------------------------------------------
// Listen socket
// -------------------------------------------------------------------

int create_listen_socket() {
    std::string path = get_socket_path();

    if (path.size() >= sizeof(sockaddr_un::sun_path)) {
        LOG_ERROR("socket path too long (%zu): %s", path.size(), path.c_str());
        return -1;
    }

    // Check for stale socket
    pid_t old_pid = read_pid_file();
    if (old_pid > 0) {
        if (kill(old_pid, 0) == 0) {
            LOG_ERROR("daemon already running (pid %d)", old_pid);
            return -1;
        }
        // Stale PID file — remove
        LOG_INFO("removing stale PID file (pid %d)", old_pid);
        unlink(get_pid_file_path().c_str());
    }

    // Remove stale socket if present
    unlink(path.c_str());

    // Create socket
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        LOG_ERROR("socket() failed: %s", strerror(errno));
        return -1;
    }

    // Set FD_CLOEXEC
    int flags = fcntl(fd, F_GETFD);
    if (flags >= 0)
        fcntl(fd, F_SETFD, flags | FD_CLOEXEC);

    // Bind with restrictive umask
    mode_t old_umask = umask(0077);
    struct sockaddr_un addr = {};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);

    if (bind(fd, reinterpret_cast<struct sockaddr *>(&addr), sizeof(addr)) != 0) {
        LOG_ERROR("bind(%s) failed: %s", path.c_str(), strerror(errno));
        umask(old_umask);
        close(fd);
        return -1;
    }
    umask(old_umask);

    if (listen(fd, 5) != 0) {
        LOG_ERROR("listen() failed: %s", strerror(errno));
        close(fd);
        unlink(path.c_str());
        return -1;
    }

    LOG_INFO("listening on %s", path.c_str());
    return fd;
}

// -------------------------------------------------------------------
// PID file
// -------------------------------------------------------------------

bool write_pid_file(pid_t pid) {
    std::string path = get_pid_file_path();

    // Open with O_CREAT|O_EXCL to prevent TOCTOU
    int fd = open(path.c_str(), O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0600);
    if (fd < 0) {
        if (errno == EEXIST) {
            // Check if stale
            pid_t old = read_pid_file();
            if (old > 0 && kill(old, 0) == 0) {
                LOG_ERROR("PID file exists and daemon is running (pid %d)", old);
                return false;
            }
            // Stale — remove and retry
            unlink(path.c_str());
            fd = open(path.c_str(), O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0600);
            if (fd < 0) {
                LOG_ERROR("cannot create PID file: %s", strerror(errno));
                return false;
            }
        } else {
            LOG_ERROR("cannot create PID file: %s", strerror(errno));
            return false;
        }
    }

    char buf[32];
    int len = snprintf(buf, sizeof(buf), "%d\n", pid);
    ssize_t written = write(fd, buf, static_cast<size_t>(len));
    close(fd);

    if (written != len) {
        LOG_ERROR("failed to write PID file");
        unlink(path.c_str());
        return false;
    }

    return true;
}

pid_t read_pid_file() {
    std::string path = get_pid_file_path();
    int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return 0;

    char buf[32] = {};
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);

    if (n <= 0)
        return 0;

    long pid = strtol(buf, nullptr, 10);
    if (pid <= 0 || pid > 99999999)
        return 0;

    return static_cast<pid_t>(pid);
}

void cleanup_socket_files() {
    unlink(get_socket_path().c_str());
    unlink(get_pid_file_path().c_str());
    LOG_INFO("cleaned up socket and PID files");
}

// -------------------------------------------------------------------
// Peer authentication
// -------------------------------------------------------------------

static bool authenticate_peer(int client_fd, pid_t *peer_pid) {
    uid_t peer_uid;

#if defined(__APPLE__)
    uid_t euid;
    gid_t egid;
    if (getpeereid(client_fd, &euid, &egid) != 0) {
        LOG_ERROR("getpeereid failed: %s", strerror(errno));
        return false;
    }
    peer_uid = euid;

    // Get peer PID via LOCAL_PEERPID on macOS
    pid_t ppid = 0;
    socklen_t ppid_len = sizeof(ppid);
    if (getsockopt(client_fd, SOL_LOCAL, LOCAL_PEERPID, &ppid, &ppid_len) == 0) {
        *peer_pid = ppid;
    }
#elif defined(__linux__)
    struct ucred cred;
    socklen_t cred_len = sizeof(cred);
    if (getsockopt(client_fd, SOL_SOCKET, SO_PEERCRED, &cred, &cred_len) != 0) {
        LOG_ERROR("getsockopt(SO_PEERCRED) failed: %s", strerror(errno));
        return false;
    }
    peer_uid = cred.uid;
    *peer_pid = cred.pid;
#else
    (void)peer_pid;
    LOG_ERROR("peer authentication not supported on this platform");
    return false;
#endif

    if (peer_uid != getuid()) {
        LOG_ERROR("peer uid %u does not match daemon uid %u",
                  peer_uid, static_cast<unsigned>(getuid()));
        return false;
    }

    return true;
}

// -------------------------------------------------------------------
// Client management
// -------------------------------------------------------------------

Client *accept_client(int listen_fd) {
    struct sockaddr_un addr;
    socklen_t addr_len = sizeof(addr);
    int fd = accept(listen_fd, reinterpret_cast<struct sockaddr *>(&addr), &addr_len);
    if (fd < 0) {
        if (errno != EAGAIN && errno != EWOULDBLOCK)
            LOG_ERROR("accept() failed: %s", strerror(errno));
        return nullptr;
    }

    // Set FD_CLOEXEC
    int flags = fcntl(fd, F_GETFD);
    if (flags >= 0)
        fcntl(fd, F_SETFD, flags | FD_CLOEXEC);

    // Set non-blocking
    int fl = fcntl(fd, F_GETFL);
    if (fl >= 0)
        fcntl(fd, F_SETFL, fl | O_NONBLOCK);

    // Authenticate peer
    pid_t peer_pid = 0;
    if (!authenticate_peer(fd, &peer_pid)) {
        LOG_WARN("rejected connection from unauthorized peer");
        close(fd);
        return nullptr;
    }

    Client *c = new (std::nothrow) Client{};
    if (!c) {
        close(fd);
        return nullptr;
    }

    c->fd = fd;
    c->authenticated = false;  // Needs HELLO handshake
    c->capabilities = 0;
    c->peer_pid = peer_pid;
    c->last_message_at = time(nullptr);
    c->congested = false;

    LOG_INFO("accepted client fd=%d pid=%d", fd, peer_pid);
    return c;
}

void close_client(Client *client) {
    if (!client) return;
    LOG_INFO("closing client fd=%d", client->fd);
    close(client->fd);
    delete client;
}

// -------------------------------------------------------------------
// Message framing
// -------------------------------------------------------------------

void queue_message(Client *client, uint8_t type,
                   const uint8_t *payload, uint32_t payload_len) {
    if (!client) return;

    size_t old_size = client->send_buf.size();
    client->send_buf.resize(old_size + HEADER_SIZE + payload_len);
    uint8_t *hdr = client->send_buf.data() + old_size;

    write_header(hdr, type, payload_len);
    if (payload_len > 0)
        memcpy(hdr + HEADER_SIZE, payload, payload_len);
}

void queue_error(Client *client, uint8_t error_code, const char *message) {
    size_t msg_len = message ? strlen(message) : 0;
    // Error payload: 1 byte code + 2 byte string len + string
    std::vector<uint8_t> payload(1 + 2 + msg_len);
    payload[0] = error_code;
    write_u16_le(payload.data() + 1, static_cast<uint16_t>(msg_len));
    if (msg_len > 0)
        memcpy(payload.data() + 3, message, msg_len);

    queue_message(client, MSG_ERROR, payload.data(), static_cast<uint32_t>(payload.size()));
}

bool try_parse_message(std::vector<uint8_t> &recv_buf, ParsedMessage *msg, bool *error) {
    *error = false;

    if (recv_buf.size() < HEADER_SIZE)
        return false;

    uint8_t type = recv_buf[0];
    uint32_t payload_len = read_u32_le(recv_buf.data() + 1);

    // Validate message size
    if (payload_len > MAX_MESSAGE_SIZE) {
        LOG_ERROR("message too large: %u bytes", payload_len);
        *error = true;
        return false;
    }

    // Check if we have the full message
    size_t total = HEADER_SIZE + payload_len;
    if (recv_buf.size() < total)
        return false;

    msg->type = type;
    msg->payload = recv_buf.data() + HEADER_SIZE;
    msg->payload_len = payload_len;

    return true;
}

bool flush_send_buf(Client *client) {
    if (!client || client->send_buf.empty())
        return true;

    while (!client->send_buf.empty()) {
        ssize_t n = ::write(client->fd,
                            client->send_buf.data(),
                            client->send_buf.size());
        if (n > 0) {
            client->send_buf.erase(client->send_buf.begin(),
                                   client->send_buf.begin() + n);
            client->congested = false;
        } else if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                client->congested = true;
                return true;  // Not an error, just flow control
            }
            if (errno == EINTR)
                continue;
            LOG_ERROR("write to client fd=%d failed: %s",
                      client->fd, strerror(errno));
            return false;
        }
    }
    return true;
}
