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
#include "uuid.h"

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <vector>

// -------------------------------------------------------------------
// Self-pipe for signal handling
// -------------------------------------------------------------------

static int g_signal_pipe[2] = {-1, -1};

bool signal_pipe_init() {
    if (pipe(g_signal_pipe) != 0) {
        LOG_ERROR("pipe() for signal pipe failed: %s", strerror(errno));
        return false;
    }

    // Set both ends non-blocking and CLOEXEC
    for (int i = 0; i < 2; i++) {
        int flags = fcntl(g_signal_pipe[i], F_GETFD);
        if (flags >= 0)
            fcntl(g_signal_pipe[i], F_SETFD, flags | FD_CLOEXEC);
        int fl = fcntl(g_signal_pipe[i], F_GETFL);
        if (fl >= 0)
            fcntl(g_signal_pipe[i], F_SETFL, fl | O_NONBLOCK);
    }

    return true;
}

int signal_pipe_read_fd() {
    return g_signal_pipe[0];
}

void signal_pipe_notify() {
    // Async-signal-safe: write 1 byte
    char c = 1;
    (void)write(g_signal_pipe[1], &c, 1);
}

void signal_pipe_drain() {
    char buf[64];
    while (read(g_signal_pipe[0], buf, sizeof(buf)) > 0)
        ;
}

// -------------------------------------------------------------------
// State
// -------------------------------------------------------------------

static std::vector<DaemonSession *> g_sessions;
static std::vector<Client *> g_clients;
volatile sig_atomic_t g_shutdown_requested = 0;
static size_t g_ring_capacity = DEFAULT_RING_BUFFER_SIZE;
static time_t g_last_activity = 0;  // Last time any session or client was active

void set_ring_buffer_capacity(size_t capacity) {
    g_ring_capacity = capacity;
}

// -------------------------------------------------------------------
// Session lookup
// -------------------------------------------------------------------

static DaemonSession *find_session(const char *uuid) {
    for (auto *s : g_sessions) {
        if (s && strncmp(s->uuid, uuid, SESSION_ID_LEN) == 0)
            return s;
    }
    return nullptr;
}

static void remove_session(DaemonSession *session) {
    for (auto it = g_sessions.begin(); it != g_sessions.end(); ++it) {
        if (*it == session) {
            g_sessions.erase(it);
            return;
        }
    }
}

static Client *find_client_for_session(const DaemonSession *session) {
    for (auto *c : g_clients) {
        if (!c) continue;
        for (const auto &sid : c->attached_sessions) {
            if (strncmp(sid.c_str(), session->uuid, SESSION_ID_LEN) == 0)
                return c;
        }
    }
    return nullptr;
}

// -------------------------------------------------------------------
// Detach a specific session from its client
// -------------------------------------------------------------------

static void detach_session_from_client(DaemonSession *session, Client *client) {
    if (!session || !client) return;

    // Save termios
    if (session->master_fd >= 0) {
        if (tcgetattr(session->master_fd, &session->saved_termios) == 0)
            session->has_saved_termios = true;
    }

    session->client_fd = -1;
    session->detached_at = time(nullptr);

    // Remove from client's attached list
    auto &list = client->attached_sessions;
    list.erase(std::remove(list.begin(), list.end(),
                           std::string(session->uuid, SESSION_ID_LEN)),
               list.end());

    LOG_INFO("session %s detached from client fd=%d", session->uuid, client->fd);
}

// -------------------------------------------------------------------
// Detach all sessions belonging to a client
// -------------------------------------------------------------------

static void detach_all_client_sessions(Client *client) {
    if (!client) return;
    // Copy the list since we modify it during iteration
    auto sessions_copy = client->attached_sessions;
    for (const auto &sid : sessions_copy) {
        DaemonSession *s = find_session(sid.c_str());
        if (s)
            detach_session_from_client(s, client);
    }
}

// -------------------------------------------------------------------
// Extract session UUID from payload and look up session.
// Sends error response and returns nullptr on failure.
// -------------------------------------------------------------------

static DaemonSession *find_session_from_payload(Client *client,
                                                 const uint8_t *payload,
                                                 uint32_t len,
                                                 const char *msg_name,
                                                 char uuid_out[UUID_STR_LEN]) {
    if (len < SESSION_ID_LEN) {
        char err[64];
        snprintf(err, sizeof(err), "%s payload too short", msg_name);
        queue_error(client, ERR_PROTOCOL_ERROR, err);
        return nullptr;
    }
    memcpy(uuid_out, payload, SESSION_ID_LEN);
    uuid_out[SESSION_ID_LEN] = '\0';

    DaemonSession *s = find_session(uuid_out);
    if (!s)
        queue_error(client, ERR_SESSION_NOT_FOUND, "session not found");
    return s;
}

// -------------------------------------------------------------------
// Send replay data for a session
// -------------------------------------------------------------------

static void send_replay(DaemonSession *session, Client *client) {
    if (!session || !client || !session->ring || session->ring->empty()) {
        // Always send REPLAY_END even if no data
        if (client && session)
            queue_message(client, MSG_REPLAY_END,
                          reinterpret_cast<const uint8_t *>(session->uuid),
                          SESSION_ID_LEN);
        return;
    }

    const uint8_t *p1, *p2;
    size_t len1, len2;
    session->ring->readAll(&p1, &len1, &p2, &len2);

    // Find UTF-8 boundary at start
    size_t skip = session->ring->findUtf8Boundary(0);
    size_t total_len = len1 + len2;

    // Combine into a single contiguous buffer for chunking
    std::vector<uint8_t> replay_data;
    replay_data.reserve(total_len - skip);
    if (skip < len1) {
        replay_data.insert(replay_data.end(), p1 + skip, p1 + len1);
        if (len2 > 0)
            replay_data.insert(replay_data.end(), p2, p2 + len2);
    } else {
        size_t skip2 = skip - len1;
        if (skip2 < len2)
            replay_data.insert(replay_data.end(), p2 + skip2, p2 + len2);
    }

    // Send in REPLAY_CHUNK_SIZE chunks, each prefixed with [36B uuid]
    size_t offset = 0;
    while (offset < replay_data.size()) {
        size_t chunk = std::min(static_cast<size_t>(REPLAY_CHUNK_SIZE),
                                replay_data.size() - offset);
        std::vector<uint8_t> msg(SESSION_ID_LEN + chunk);
        memcpy(msg.data(), session->uuid, SESSION_ID_LEN);
        memcpy(msg.data() + SESSION_ID_LEN, replay_data.data() + offset, chunk);
        queue_message(client, MSG_REPLAY_DATA,
                      msg.data(),
                      static_cast<uint32_t>(msg.size()));
        offset += chunk;
    }

    // Send REPLAY_END with [36B uuid]
    queue_message(client, MSG_REPLAY_END,
                  reinterpret_cast<const uint8_t *>(session->uuid),
                  SESSION_ID_LEN);

    LOG_DEBUG("sent replay: %zu bytes in %zu chunks for session %s",
              replay_data.size(),
              (replay_data.size() + REPLAY_CHUNK_SIZE - 1) / REPLAY_CHUNK_SIZE,
              session->uuid);
}

// -------------------------------------------------------------------
// Protocol message handlers
// -------------------------------------------------------------------

static void handle_hello(Client *client, const uint8_t *payload, uint32_t len) {
    // HELLO payload: [1B version][4B capabilities][4B client_pid]
    if (len < 9) {
        queue_error(client, ERR_PROTOCOL_ERROR, "HELLO payload too short");
        return;
    }

    uint8_t version = payload[0];
    uint32_t client_caps = read_u32_le(payload + 1);
    uint32_t client_pid = read_u32_le(payload + 5);

    if (version != PROTOCOL_VERSION) {
        queue_error(client, ERR_PROTOCOL_ERROR, "unsupported protocol version");
        return;
    }

    // Verify PID matches peer credentials (if available)
    if (client->peer_pid > 0 && static_cast<pid_t>(client_pid) != client->peer_pid) {
        LOG_WARN("HELLO PID %u doesn't match peer PID %d",
                 client_pid, client->peer_pid);
        queue_error(client, ERR_PERMISSION_DENIED, "PID mismatch");
        return;
    }

    // Negotiate capabilities
    client->capabilities = client_caps & DAEMON_CAPABILITIES;
    client->authenticated = true;

    // Build HELLO_OK: [1B version][4B capabilities][4B daemon_pid]
    uint8_t resp[9];
    resp[0] = PROTOCOL_VERSION;
    write_u32_le(resp + 1, client->capabilities);
    write_u32_le(resp + 5, static_cast<uint32_t>(getpid()));

    queue_message(client, MSG_HELLO_OK, resp, sizeof(resp));
    LOG_INFO("client fd=%d authenticated (caps=0x%x)", client->fd, client->capabilities);
}

static void handle_create(Client *client, const uint8_t *payload, uint32_t len) {
    if (static_cast<int>(g_sessions.size()) >= MAX_SESSIONS) {
        queue_error(client, ERR_TOO_MANY_SESSIONS, "max sessions reached");
        return;
    }

    // Parse CREATE payload:
    // [2B len][shell] [2B count][args...] [2B count][env...] [2B len][cwd] [2B rows][2B cols]
    size_t pos = 0;
    const char *str;
    uint16_t str_len;
    size_t consumed;

    // Shell path
    if (!read_string(payload + pos, len - pos, &str, &str_len, &consumed)) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad shell");
        return;
    }
    std::string shell(str, str_len);
    pos += consumed;

    // Args array
    if (pos + 2 > len) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad args count");
        return;
    }
    uint16_t arg_count = read_u16_le(payload + pos);
    pos += 2;
    std::vector<std::string> args;
    for (uint16_t i = 0; i < arg_count; i++) {
        if (!read_string(payload + pos, len - pos, &str, &str_len, &consumed)) {
            queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad arg");
            return;
        }
        args.emplace_back(str, str_len);
        pos += consumed;
    }

    // Env array
    if (pos + 2 > len) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad env count");
        return;
    }
    uint16_t env_count = read_u16_le(payload + pos);
    pos += 2;
    std::vector<std::string> env;
    for (uint16_t i = 0; i < env_count; i++) {
        if (!read_string(payload + pos, len - pos, &str, &str_len, &consumed)) {
            queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad env");
            return;
        }
        env.emplace_back(str, str_len);
        pos += consumed;
    }

    // Working directory
    if (!read_string(payload + pos, len - pos, &str, &str_len, &consumed)) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad cwd");
        return;
    }
    std::string cwd(str, str_len);
    pos += consumed;

    // Rows and cols
    if (pos + 4 > len) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid CREATE: bad dimensions");
        return;
    }
    uint16_t rows = read_u16_le(payload + pos);
    uint16_t cols = read_u16_le(payload + pos + 2);
    pos += 4;

    // Create the session
    DaemonSession *session = session_create(shell.c_str(), args, env,
                                            cwd.c_str(), rows, cols,
                                            g_ring_capacity);
    if (!session) {
        queue_error(client, ERR_SHELL_NOT_FOUND, "failed to create session");
        return;
    }

    g_sessions.push_back(session);
    g_last_activity = time(nullptr);

    // Auto-attach the creating client to the new session
    session->client_fd = client->fd;
    session->detached_at = 0;
    client->attached_sessions.push_back(std::string(session->uuid, SESSION_ID_LEN));

    // Send CREATE_OK: [36B session_id]
    queue_message(client, MSG_CREATE_OK,
                  reinterpret_cast<const uint8_t *>(session->uuid),
                  SESSION_ID_LEN);

    LOG_INFO("created session %s for client fd=%d", session->uuid, client->fd);
}

static void handle_attach(Client *client, const uint8_t *payload, uint32_t len) {
    if (len < SESSION_ID_LEN) {
        queue_error(client, ERR_PROTOCOL_ERROR, "ATTACH payload too short");
        return;
    }

    char uuid[UUID_STR_LEN];
    memcpy(uuid, payload, SESSION_ID_LEN);
    uuid[SESSION_ID_LEN] = '\0';

    if (!uuid_validate(uuid, SESSION_ID_LEN)) {
        queue_error(client, ERR_INVALID_SESSION_ID, "invalid session ID format");
        return;
    }

    DaemonSession *session = find_session(uuid);
    if (!session) {
        queue_error(client, ERR_SESSION_NOT_FOUND, "session not found");
        return;
    }

    if (session->client_fd >= 0) {
        queue_error(client, ERR_SESSION_BUSY, "session already attached");
        return;
    }

    // Restore termios if saved
    if (session->has_saved_termios && session->master_fd >= 0) {
        tcsetattr(session->master_fd, TCSANOW, &session->saved_termios);
        session->has_saved_termios = false;
    }

    // Attach
    session->client_fd = client->fd;
    session->detached_at = 0;
    client->attached_sessions.push_back(std::string(uuid, SESSION_ID_LEN));

    // Send ATTACH_OK: [36B session_id][2B rows][2B cols][4B replay_size]
    uint8_t resp[SESSION_ID_LEN + 2 + 2 + 4];
    memcpy(resp, uuid, SESSION_ID_LEN);
    write_u16_le(resp + SESSION_ID_LEN, session->rows);
    write_u16_le(resp + SESSION_ID_LEN + 2, session->cols);
    uint32_t replay_size = static_cast<uint32_t>(session->ring ? session->ring->used() : 0);
    write_u32_le(resp + SESSION_ID_LEN + 4, replay_size);
    queue_message(client, MSG_ATTACH_OK, resp, sizeof(resp));

    // Send replay data
    send_replay(session, client);

    // If session is dead, notify after replay
    if (!session->alive) {
        // SESSION_EXITED: [36B session_id][4B exit_code]
        uint8_t exited[SESSION_ID_LEN + 4];
        memcpy(exited, uuid, SESSION_ID_LEN);
        write_u32_le(exited + SESSION_ID_LEN, static_cast<uint32_t>(session->exit_code));
        queue_message(client, MSG_SESSION_EXITED, exited, sizeof(exited));
    }

    LOG_INFO("session %s attached to client fd=%d", uuid, client->fd);
    g_last_activity = time(nullptr);
}

static void handle_detach(Client *client, const uint8_t *payload, uint32_t len) {
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "DETACH", uuid);
    if (!session) return;

    detach_session_from_client(session, client);
    queue_message(client, MSG_DETACH_OK, nullptr, 0);
}

static void handle_destroy(Client *client, const uint8_t *payload, uint32_t len) {
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "DESTROY", uuid);
    if (!session) return;

    // Detach from its actual attached client (may differ from requesting client)
    if (session->client_fd >= 0) {
        Client *attached = find_client_for_session(session);
        if (attached)
            detach_session_from_client(session, attached);
    }

    // Kill the shell and mark dead so session_destroy doesn't double-kill
    if (session->alive && session->shell_pid > 0) {
        kill(session->shell_pid, SIGHUP);
        usleep(100000);
        int status;
        pid_t r = waitpid(session->shell_pid, &status, WNOHANG);
        if (r == 0) {
            kill(session->shell_pid, SIGKILL);
            waitpid(session->shell_pid, &status, 0);
        }
        session->alive = false;
    }

    remove_session(session);
    session_destroy(session);

    queue_message(client, MSG_DESTROY_OK, nullptr, 0);
    g_last_activity = time(nullptr);
}

static void handle_resize(Client *client, const uint8_t *payload, uint32_t len) {
    // RESIZE: [36B session_id][2B rows][2B cols]
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "RESIZE", uuid);
    if (!session) return;
    if (len < SESSION_ID_LEN + 4) {
        queue_error(client, ERR_PROTOCOL_ERROR, "RESIZE payload too short");
        return;
    }

    uint16_t rows = read_u16_le(payload + SESSION_ID_LEN);
    uint16_t cols = read_u16_le(payload + SESSION_ID_LEN + 2);

    session->rows = rows;
    session->cols = cols;

    if (session->master_fd >= 0) {
        struct winsize ws = {};
        ws.ws_row = rows;
        ws.ws_col = cols;
        ioctl(session->master_fd, TIOCSWINSZ, &ws);

        // Send SIGWINCH to shell process group
        if (session->alive && session->shell_pid > 0)
            kill(-session->shell_pid, SIGWINCH);
    }

    LOG_DEBUG("session %s resized to %dx%d", uuid, cols, rows);
}

static void handle_input(Client *client, const uint8_t *payload, uint32_t len) {
    // INPUT: [36B session_id][raw_bytes...]
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "INPUT", uuid);
    if (!session) return;

    if (!session->alive || session->master_fd < 0)
        return;

    const uint8_t *data = payload + SESSION_ID_LEN;
    uint32_t data_len = len - SESSION_ID_LEN;

    // Write to PTY master
    size_t written = 0;
    while (written < data_len) {
        ssize_t n = write(session->master_fd,
                          data + written,
                          data_len - written);
        if (n > 0) {
            written += static_cast<size_t>(n);
        } else if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK)
                break;
            if (errno == EINTR)
                continue;
            LOG_ERROR("write to PTY master fd=%d failed: %s",
                      session->master_fd, strerror(errno));
            break;
        }
    }
}

static void handle_list(Client *client) {
    // LIST_OK: [2B count] then per session:
    //   [36B id][1B alive][2B rows][2B cols][2B shell_len][shell]
    //   [2B cwd_len][cwd][8B created_at][8B detached_at][1B has_client]
    std::vector<uint8_t> payload;

    // Count non-null sessions (g_sessions may contain gaps after removal)
    uint16_t count = 0;
    for (auto *s : g_sessions) {
        if (s) count++;
    }
    payload.resize(2);
    write_u16_le(payload.data(), count);

    for (auto *s : g_sessions) {
        if (!s) continue;

        size_t base = payload.size();
        size_t shell_len = strlen(s->shell);
        size_t cwd_len = strlen(s->cwd);
        size_t entry_size = SESSION_ID_LEN + 1 + 2 + 2 +
                            2 + shell_len + 2 + cwd_len +
                            8 + 8 + 1;
        payload.resize(base + entry_size);
        uint8_t *p = payload.data() + base;

        memcpy(p, s->uuid, SESSION_ID_LEN);
        p += SESSION_ID_LEN;

        *p++ = s->alive ? 1 : 0;

        write_u16_le(p, s->rows); p += 2;
        write_u16_le(p, s->cols); p += 2;

        write_u16_le(p, static_cast<uint16_t>(shell_len)); p += 2;
        memcpy(p, s->shell, shell_len); p += shell_len;

        write_u16_le(p, static_cast<uint16_t>(cwd_len)); p += 2;
        memcpy(p, s->cwd, cwd_len); p += cwd_len;

        write_u64_le(p, static_cast<uint64_t>(s->created_at)); p += 8;
        write_u64_le(p, static_cast<uint64_t>(s->detached_at)); p += 8;

        *p++ = (s->client_fd >= 0) ? 1 : 0;
    }

    queue_message(client, MSG_LIST_OK, payload.data(),
                  static_cast<uint32_t>(payload.size()));
}

static void handle_send_signal(Client *client, const uint8_t *payload, uint32_t len) {
    // SEND_SIGNAL: [36B session_id][4B signal]
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "SEND_SIGNAL", uuid);
    if (!session) return;
    if (len < SESSION_ID_LEN + 4) {
        queue_error(client, ERR_PROTOCOL_ERROR, "SEND_SIGNAL payload too short");
        return;
    }

    uint32_t sig = read_u32_le(payload + SESSION_ID_LEN);

    if (sig < 1 || sig >= static_cast<uint32_t>(NSIG)) {
        queue_error(client, ERR_PROTOCOL_ERROR, "invalid signal number");
        return;
    }

    if (session->alive && session->shell_pid > 0) {
        kill(session->shell_pid, static_cast<int>(sig));
        LOG_DEBUG("sent signal %u to session %s (pid %d)",
                  sig, uuid, session->shell_pid);
    }

    // SIGNAL_OK: [36B session_id]
    queue_message(client, MSG_SIGNAL_OK,
                  reinterpret_cast<const uint8_t *>(uuid), SESSION_ID_LEN);
}

static void handle_set_termios(Client *client, const uint8_t *payload, uint32_t len) {
    // SET_TERMIOS: [36B session_id][4B iflag][4B oflag][4B cflag][4B lflag]
    //              [1B VERASE][1B flow_control][1B utf8]
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "SET_TERMIOS", uuid);
    if (!session) return;
    if (len < SESSION_ID_LEN + 19) {
        queue_error(client, ERR_PROTOCOL_ERROR, "SET_TERMIOS payload too short");
        return;
    }

    if (session->master_fd < 0)
        return;

    struct termios tio;
    if (tcgetattr(session->master_fd, &tio) != 0)
        return;

    size_t p = SESSION_ID_LEN;
    tio.c_iflag = static_cast<tcflag_t>(read_u32_le(payload + p)); p += 4;
    tio.c_oflag = static_cast<tcflag_t>(read_u32_le(payload + p)); p += 4;
    tio.c_cflag = static_cast<tcflag_t>(read_u32_le(payload + p)); p += 4;
    tio.c_lflag = static_cast<tcflag_t>(read_u32_le(payload + p)); p += 4;

    tio.c_cc[VERASE] = payload[p++];

    uint8_t flow_control = payload[p++];
    if (flow_control) {
        tio.c_iflag |= (IXON | IXOFF);
    } else {
        tio.c_iflag &= ~static_cast<tcflag_t>(IXON | IXOFF);
    }

    uint8_t utf8_mode = payload[p++];
#ifdef IUTF8
    if (utf8_mode) {
        tio.c_iflag |= IUTF8;
    } else {
        tio.c_iflag &= ~static_cast<tcflag_t>(IUTF8);
    }
#else
    (void)utf8_mode;
#endif

    tcsetattr(session->master_fd, TCSANOW, &tio);
    LOG_DEBUG("set termios for session %s", uuid);
}

static void handle_ping(Client *client, const uint8_t *payload, uint32_t len) {
    // PING: [8B timestamp] -> PONG: [8B timestamp]
    if (len < 8) {
        queue_error(client, ERR_PROTOCOL_ERROR, "PING payload too short");
        return;
    }
    queue_message(client, MSG_PONG, payload, 8);
}

static void handle_fg_process_query(Client *client, const uint8_t *payload, uint32_t len) {
    // FG_PROCESS_QUERY: [36B session_id]
    char uuid[UUID_STR_LEN];
    DaemonSession *session = find_session_from_payload(client, payload, len, "FG_PROCESS_QUERY", uuid);
    if (!session) return;

    pid_t fg_pid = 0;
    if (session->master_fd >= 0)
        fg_pid = tcgetpgrp(session->master_fd);

    // FG_PROCESS_INFO: [36B session_id][4B pid][2B name_len][name][2B cwd_len][cwd]
    // We send just PID — the client does the /proc lookup
    std::vector<uint8_t> resp(SESSION_ID_LEN + 4 + 2 + 2);
    memcpy(resp.data(), uuid, SESSION_ID_LEN);
    write_u32_le(resp.data() + SESSION_ID_LEN, static_cast<uint32_t>(fg_pid));
    write_u16_le(resp.data() + SESSION_ID_LEN + 4, 0); // empty name
    write_u16_le(resp.data() + SESSION_ID_LEN + 6, 0); // empty cwd

    queue_message(client, MSG_FG_PROCESS_INFO, resp.data(),
                  static_cast<uint32_t>(resp.size()));
}

// -------------------------------------------------------------------
// Message dispatcher
// -------------------------------------------------------------------

static void handle_message(Client *client, uint8_t type,
                           const uint8_t *payload, uint32_t len) {
    client->last_message_at = time(nullptr);
    g_last_activity = time(nullptr);

    // Must authenticate first (except HELLO)
    if (!client->authenticated && type != MSG_HELLO) {
        queue_error(client, ERR_PROTOCOL_ERROR, "must send HELLO first");
        return;
    }

    switch (type) {
    case MSG_HELLO:             handle_hello(client, payload, len); break;
    case MSG_CREATE:            handle_create(client, payload, len); break;
    case MSG_ATTACH:            handle_attach(client, payload, len); break;
    case MSG_DETACH:            handle_detach(client, payload, len); break;
    case MSG_DESTROY:           handle_destroy(client, payload, len); break;
    case MSG_RESIZE:            handle_resize(client, payload, len); break;
    case MSG_INPUT:             handle_input(client, payload, len); break;
    case MSG_LIST:              handle_list(client); break;
    case MSG_SEND_SIGNAL:       handle_send_signal(client, payload, len); break;
    case MSG_SET_TERMIOS:       handle_set_termios(client, payload, len); break;
    case MSG_PING:              handle_ping(client, payload, len); break;
    case MSG_FG_PROCESS_QUERY:  handle_fg_process_query(client, payload, len); break;
    default:
        LOG_WARN("unknown message type 0x%02x from client fd=%d", type, client->fd);
        queue_error(client, ERR_PROTOCOL_ERROR, "unknown message type");
        break;
    }
}

// -------------------------------------------------------------------
// Process messages in a client's recv_buf
// -------------------------------------------------------------------

static void process_client_messages(Client *client) {
    while (true) {
        ParsedMessage msg;
        bool error = false;
        if (!try_parse_message(client->recv_buf, &msg, &error)) {
            if (error) {
                LOG_ERROR("protocol error from client fd=%d", client->fd);
                // Mark for disconnect by emptying recv_buf and returning
                client->recv_buf.clear();
            }
            break;
        }

        handle_message(client, msg.type, msg.payload, msg.payload_len);

        // Remove consumed message from recv_buf
        size_t total = HEADER_SIZE + msg.payload_len;
        client->recv_buf.erase(client->recv_buf.begin(),
                               client->recv_buf.begin() + static_cast<ptrdiff_t>(total));
    }
}

// -------------------------------------------------------------------
// Disconnect and remove a client from g_clients by index
// -------------------------------------------------------------------

static void remove_client_at(size_t &i) {
    Client *c = g_clients[i];
    LOG_INFO("removing client fd=%d", c->fd);
    detach_all_client_sessions(c);
    close_client(c);
    g_clients.erase(g_clients.begin() + static_cast<ptrdiff_t>(i));
    i--;
}

// -------------------------------------------------------------------
// Reap zombie children
// -------------------------------------------------------------------

static void reap_children() {
    int status;
    pid_t pid;
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
        session_handle_child_exit(g_sessions.data(),
                                  static_cast<int>(g_sessions.size()),
                                  pid, status);

        // Check if we need to notify an attached client
        for (auto *s : g_sessions) {
            if (s && s->shell_pid == pid && !s->alive && s->client_fd >= 0) {
                Client *c = find_client_for_session(s);
                if (c) {
                    uint8_t exited[SESSION_ID_LEN + 4];
                    memcpy(exited, s->uuid, SESSION_ID_LEN);
                    write_u32_le(exited + SESSION_ID_LEN,
                                 static_cast<uint32_t>(s->exit_code));
                    queue_message(c, MSG_SESSION_EXITED, exited, sizeof(exited));
                }
            }
        }
    }
}

// -------------------------------------------------------------------
// Proactive foreground process polling
// -------------------------------------------------------------------

static time_t g_last_fg_poll = 0;

// Poll tcgetpgrp() on each attached session's PTY master to detect foreground
// process group changes.  Rate-limited to once per 2 seconds.  Called from
// check_timeouts() which runs every event-loop iteration.
static void poll_fg_processes() {
    time_t now = time(nullptr);
    if ((now - g_last_fg_poll) < 2)
        return;
    g_last_fg_poll = now;

    for (auto *s : g_sessions) {
        if (!s || !s->alive || s->master_fd < 0 || s->client_fd < 0)
            continue;

        pid_t fg_pid = tcgetpgrp(s->master_fd);
        if (fg_pid <= 0 || fg_pid == s->cached_fg_pid)
            continue;

        s->cached_fg_pid = fg_pid;

        Client *c = find_client_for_session(s);
        if (!c) continue;

        uint8_t payload[SESSION_ID_LEN + 4];
        memcpy(payload, s->uuid, SESSION_ID_LEN);
        write_u32_le(payload + SESSION_ID_LEN, static_cast<uint32_t>(fg_pid));
        queue_message(c, MSG_FG_PROCESS_UPDATE, payload, sizeof(payload));
    }
}

// -------------------------------------------------------------------
// Orphan reaper + idle timeout
// -------------------------------------------------------------------

static void check_timeouts() {
    time_t now = time(nullptr);

    // Check orphaned sessions (detached > ORPHAN_TIMEOUT_SECS)
    for (auto it = g_sessions.begin(); it != g_sessions.end(); ) {
        DaemonSession *s = *it;
        if (!s) { ++it; continue; }

        bool should_destroy = false;

        // Orphan: detached too long
        if (s->client_fd < 0 && s->detached_at > 0 &&
            (now - s->detached_at) > ORPHAN_TIMEOUT_SECS) {
            LOG_INFO("reaping orphaned session %s (detached %ld seconds)",
                     s->uuid, static_cast<long>(now - s->detached_at));
            should_destroy = true;
        }

        // Dead session past keep time (detached and dead)
        if (!s->alive && s->client_fd < 0 &&
            s->detached_at > 0 &&
            (now - s->detached_at) > DEAD_SESSION_KEEP_SECS) {
            LOG_INFO("cleaning up dead session %s", s->uuid);
            should_destroy = true;
        }

        if (should_destroy) {
            it = g_sessions.erase(it);
            session_destroy(s);
        } else {
            ++it;
        }
    }

    // Check client heartbeat timeout
    for (auto it = g_clients.begin(); it != g_clients.end(); ) {
        Client *c = *it;
        if (c && c->authenticated &&
            (now - c->last_message_at) > CLIENT_HEARTBEAT_TIMEOUT_SECS) {
            LOG_WARN("client fd=%d heartbeat timeout, detaching sessions", c->fd);
            detach_all_client_sessions(c);
            close_client(c);
            it = g_clients.erase(it);
        } else {
            ++it;
        }
    }

    // Poll foreground process changes
    poll_fg_processes();
}

static bool check_idle_timeout() {
    if (g_sessions.empty() && g_clients.empty()) {
        time_t now = time(nullptr);
        if (g_last_activity > 0 && (now - g_last_activity) > IDLE_TIMEOUT_SECS) {
            LOG_INFO("idle timeout reached, shutting down");
            return true;
        }
    }
    return false;
}

// -------------------------------------------------------------------
// Main event loop
// -------------------------------------------------------------------

void event_loop_run(int listen_fd) {
    g_last_activity = time(nullptr);
    LOG_INFO("entering event loop");

    while (!g_shutdown_requested) {
        // Build poll array
        // [0] = signal pipe, [1] = listen fd, [2..N] = clients, [N+1..M] = PTY masters
        std::vector<struct pollfd> fds;

        // Signal pipe
        struct pollfd sig_pfd = {};
        sig_pfd.fd = signal_pipe_read_fd();
        sig_pfd.events = POLLIN;
        fds.push_back(sig_pfd);

        // Listen socket
        struct pollfd listen_pfd = {};
        listen_pfd.fd = listen_fd;
        listen_pfd.events = POLLIN;
        fds.push_back(listen_pfd);

        // Client fds
        size_t client_start = fds.size();
        for (auto *c : g_clients) {
            struct pollfd cpfd = {};
            cpfd.fd = c->fd;
            cpfd.events = POLLIN;
            if (!c->send_buf.empty())
                cpfd.events |= POLLOUT;
            fds.push_back(cpfd);
        }

        // PTY master fds for all alive sessions (attached non-congested + detached)
        std::vector<DaemonSession *> pty_sessions;
        size_t pty_start = fds.size();
        for (auto *s : g_sessions) {
            if (!s || !s->alive || s->master_fd < 0) continue;
            // Skip attached sessions where client is congested
            if (s->client_fd >= 0 && s->flow_paused) continue;

            struct pollfd ppfd = {};
            ppfd.fd = s->master_fd;
            ppfd.events = POLLIN;
            fds.push_back(ppfd);
            pty_sessions.push_back(s);
        }

        int ret = poll(fds.data(), static_cast<nfds_t>(fds.size()), POLL_TIMEOUT_MS);

        if (ret < 0) {
            if (errno == EINTR)
                continue;
            LOG_ERROR("poll() failed: %s", strerror(errno));
            break;
        }

        // 1. Signal pipe
        if (fds[0].revents & POLLIN) {
            signal_pipe_drain();
            reap_children();
            if (g_shutdown_requested)
                break;
        }

        // 2. Listen fd — accept new connections
        if (fds[1].revents & POLLIN) {
            Client *c = accept_client(listen_fd);
            if (c)
                g_clients.push_back(c);
        }

        // 3. Client fds — read data and process messages
        for (size_t i = 0; i < g_clients.size(); i++) {
            size_t pfd_idx = client_start + i;
            if (pfd_idx >= fds.size()) break;
            Client *c = g_clients[i];

            if (fds[pfd_idx].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                remove_client_at(i);
                continue;
            }

            if (fds[pfd_idx].revents & POLLIN) {
                uint8_t buf[8192];
                ssize_t n = read(c->fd, buf, sizeof(buf));
                if (n > 0) {
                    c->recv_buf.insert(c->recv_buf.end(), buf, buf + n);
                    process_client_messages(c);
                } else if (n == 0) {
                    remove_client_at(i);
                    continue;
                }
            }

            // 4. Client fds — flush send buffers
            if (fds[pfd_idx].revents & POLLOUT) {
                if (!flush_send_buf(c)) {
                    remove_client_at(i);
                    continue;
                }
                // If flushed completely, check if any sessions had paused flow
                if (!c->congested) {
                    for (const auto &sid : c->attached_sessions) {
                        DaemonSession *s = find_session(sid.c_str());
                        if (s) s->flow_paused = false;
                    }
                }
            }
        }

        // 5. PTY master fds — read output
        for (size_t i = 0; i < pty_sessions.size(); i++) {
            size_t pfd_idx = pty_start + i;
            if (pfd_idx >= fds.size()) break;
            DaemonSession *s = pty_sessions[i];

            if (fds[pfd_idx].revents & POLLIN) {
                uint8_t buf[8192];
                ssize_t n = read(s->master_fd, buf, sizeof(buf));
                if (n > 0) {
                    // Write to ring buffer
                    s->ring->write(buf, static_cast<size_t>(n));

                    // Forward to attached client
                    if (s->client_fd >= 0) {
                        Client *c = find_client_for_session(s);
                        if (c) {
                            // Build OUTPUT: [36B session_id][data...]
                            std::vector<uint8_t> output(SESSION_ID_LEN + static_cast<size_t>(n));
                            memcpy(output.data(), s->uuid, SESSION_ID_LEN);
                            memcpy(output.data() + SESSION_ID_LEN, buf, static_cast<size_t>(n));
                            queue_message(c, MSG_OUTPUT, output.data(),
                                          static_cast<uint32_t>(output.size()));

                            // Try to flush immediately
                            if (!flush_send_buf(c)) {
                                LOG_ERROR("flush failed for client fd=%d (output)", c->fd);
                            }
                            // Flow control: if client is congested, pause this session
                            if (c->congested)
                                s->flow_paused = true;
                        }
                    }
                } else if (n < 0 && errno != EAGAIN && errno != EIO) {
                    LOG_DEBUG("read from PTY master fd=%d: %s",
                              s->master_fd, strerror(errno));
                }
                // EIO on PTY master means shell exited — SIGCHLD will handle it
            }

            if (fds[pfd_idx].revents & (POLLERR | POLLHUP)) {
                // PTY closed — shell probably exited, SIGCHLD will handle cleanup
                LOG_DEBUG("PTY master fd=%d got POLLHUP/POLLERR", s->master_fd);
            }
        }

        // 6. Periodic checks (run every iteration, not just on timeout)
        check_timeouts();
        if (check_idle_timeout())
            break;
    }

    // Clean shutdown
    LOG_INFO("shutting down event loop");

    // Detach all clients
    for (auto *c : g_clients) {
        detach_all_client_sessions(c);
        close_client(c);
    }
    g_clients.clear();

    // Destroy all sessions
    for (auto *s : g_sessions)
        session_destroy(s);
    g_sessions.clear();
}
