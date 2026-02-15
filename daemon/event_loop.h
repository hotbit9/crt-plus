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

// Main event loop: poll()-based multiplexing of signal pipe, client sockets,
// and PTY master fds. Handles protocol dispatch, flow control, and timeouts.

#ifndef CRT_SESSIOND_EVENT_LOOP_H
#define CRT_SESSIOND_EVENT_LOOP_H

#include "session.h"
#include "server.h"

#include <cstddef>

// Initialize the self-pipe for signal handling.
// Returns true on success.
bool signal_pipe_init();

// Get the read end of the self-pipe (for poll array).
int signal_pipe_read_fd();

// Write a byte to the signal pipe (async-signal-safe).
void signal_pipe_notify();

// Drain the signal pipe (call after poll detects readable).
void signal_pipe_drain();

// Set the ring buffer capacity for new sessions.
void set_ring_buffer_capacity(size_t capacity);

// Run the main event loop.
// listen_fd: the bound+listening Unix socket fd
// Returns when SIGTERM/SIGINT is received or idle timeout expires.
void event_loop_run(int listen_fd);

#endif // CRT_SESSIOND_EVENT_LOOP_H
