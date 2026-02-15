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

// Session lifecycle: PTY creation, shell spawning, environment sanitization,
// and child process management. Each DaemonSession owns a PTY master fd and ring buffer.

#ifndef CRT_SESSIOND_SESSION_H
#define CRT_SESSIOND_SESSION_H

#include "ring_buffer.h"
#include "uuid.h"

#include <cstdint>
#include <ctime>
#include <string>
#include <termios.h>
#include <sys/types.h>
#include <climits>
#include <vector>

struct DaemonSession {
    char        uuid[UUID_STR_LEN];   // Session UUID (36 chars + null)
    int         master_fd;            // PTY master fd
    pid_t       shell_pid;            // Shell process PID
    uint16_t    rows;                 // Current terminal rows
    uint16_t    cols;                 // Current terminal cols
    RingBuffer *ring;                 // Scrollback ring buffer
    int         client_fd;            // Attached client fd (-1 if detached)
    time_t      created_at;           // Session creation time
    time_t      detached_at;          // Last detach time (0 if attached)
    char        cwd[PATH_MAX];        // Initial working directory
    char        shell[PATH_MAX];      // Shell program path
    bool        alive;                // Shell process still running
    int         exit_code;            // Shell exit code (valid when !alive)
    struct termios saved_termios;     // Termios state captured on detach
    bool        has_saved_termios;    // True if termios was captured
    bool        flow_paused;          // PTY read paused: client socket returned EAGAIN,
                                      // cleared when send_buf fully flushed
    pid_t       cached_fg_pid;        // Last known foreground PID (for change detection)
};

// Create a new session: open PTY, fork shell, allocate ring buffer.
// shell_path: path to shell binary
// args: argument vector (args[0] should be shell name)
// env: environment variables (KEY=VALUE strings)
// cwd: initial working directory
// rows, cols: initial window size
// ring_capacity: ring buffer size in bytes
// Returns session pointer on success, nullptr on failure.
DaemonSession *session_create(const char *shell_path,
                              const std::vector<std::string> &args,
                              const std::vector<std::string> &env,
                              const char *cwd,
                              uint16_t rows, uint16_t cols,
                              size_t ring_capacity);

// Destroy a session: secure-clear ring buffer, close master fd, free memory.
void session_destroy(DaemonSession *session);

// Handle SIGCHLD for a specific pid. Marks session alive=false if pid matches.
// Returns the session pointer if matched, nullptr otherwise.
DaemonSession *session_handle_child_exit(DaemonSession **sessions, int count,
                                         pid_t pid, int status);

// Sanitize an environment variable list: remove dangerous vars, validate PATH.
// Returns a new sanitized vector.
std::vector<std::string> sanitize_environment(const std::vector<std::string> &env);

// Validate a shell path: must exist, be executable, not be a directory.
bool validate_shell_path(const char *path);

#endif // CRT_SESSIOND_SESSION_H
