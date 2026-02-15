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

// Unix domain socket server: socket directory security, peer authentication,
// client connection management, and binary protocol message framing.

#ifndef CRT_SESSIOND_SERVER_H
#define CRT_SESSIOND_SERVER_H

#include "protocol.h"

#include <cstdint>
#include <string>
#include <vector>

// Client connection state
struct Client {
    int         fd;
    bool        authenticated;          // HELLO completed
    uint32_t    capabilities;           // Negotiated capabilities
    pid_t       peer_pid;               // Peer PID from credentials
    std::vector<uint8_t> recv_buf;      // Partial message accumulator
    std::vector<uint8_t> send_buf;      // Outbound queue
    std::vector<std::string> attached_sessions;  // Session UUIDs
    time_t      last_message_at;        // Last message timestamp (heartbeat)
    bool        congested;              // Socket write would block
};

// Parsed protocol message
struct ParsedMessage {
    uint8_t type;
    const uint8_t *payload;
    uint32_t payload_len;
};

// Get the socket directory path for this platform.
// macOS: $TMPDIR/crt-plus-$UID/
// Linux: $XDG_RUNTIME_DIR/crt-plus/ (fallback: /tmp/crt-plus-$UID/)
std::string get_socket_dir();

// Get the full socket path.
std::string get_socket_path();

// Get the PID file path.
std::string get_pid_file_path();

// Create and secure the socket directory (TOCTOU-safe).
// Returns true on success.
bool create_socket_dir();

// Create and bind the listening socket.
// Returns the listen fd, or -1 on error.
int create_listen_socket();

// Write the PID file. Returns true on success.
bool write_pid_file(pid_t pid);

// Read the PID from the PID file. Returns 0 if no valid PID file.
pid_t read_pid_file();

// Remove socket and PID file.
void cleanup_socket_files();

// Accept a new client connection with peer authentication.
// Returns a Client pointer, or nullptr if auth fails.
Client *accept_client(int listen_fd);

// Close a client and free its resources.
void close_client(Client *client);

// Queue a message to be sent to a client.
void queue_message(Client *client, uint8_t type,
                   const uint8_t *payload, uint32_t payload_len);

// Queue an ERROR message to a client.
void queue_error(Client *client, uint8_t error_code, const char *message);

// Try to parse a complete message from recv_buf.
// Returns true if a message was parsed (fills msg), false if need more data.
// On protocol error, returns false and sets *error to true.
bool try_parse_message(std::vector<uint8_t> &recv_buf, ParsedMessage *msg, bool *error);

// Flush as much of send_buf as possible to the client fd.
// Returns false if the connection should be closed (error).
bool flush_send_buf(Client *client);

#endif // CRT_SESSIOND_SERVER_H
