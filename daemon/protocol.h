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

// Wire protocol constants, message types, error codes, and binary encoding helpers
// for communication between the CRT Plus app and the session daemon.

#ifndef CRT_SESSIOND_PROTOCOL_H
#define CRT_SESSIOND_PROTOCOL_H

#include <cstdint>
#include <cstring>

// Protocol version
inline constexpr uint8_t PROTOCOL_VERSION = 1;

// Daemon version string
inline constexpr const char *DAEMON_VERSION = "0.1.0";

// Header: 1 byte type + 4 bytes length (LE) = 5 bytes
inline constexpr size_t HEADER_SIZE = 5;

// Max message size: 2 MB
inline constexpr uint32_t MAX_MESSAGE_SIZE = 2 * 1024 * 1024;

// Replay chunk size: 64 KB
inline constexpr uint32_t REPLAY_CHUNK_SIZE = 64 * 1024;

// Session ID length (UUID string: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)
inline constexpr size_t SESSION_ID_LEN = 36;

// Default ring buffer size: 1 MB
inline constexpr size_t DEFAULT_RING_BUFFER_SIZE = 1024 * 1024;

// Max sessions
inline constexpr int MAX_SESSIONS = 256;

// Orphan timeout: 24 hours
inline constexpr int ORPHAN_TIMEOUT_SECS = 24 * 60 * 60;

// Idle daemon timeout: 30 minutes
inline constexpr int IDLE_TIMEOUT_SECS = 30 * 60;

// Dead session keep time: 60 seconds
inline constexpr int DEAD_SESSION_KEEP_SECS = 60;

// Poll timeout: 5 seconds
inline constexpr int POLL_TIMEOUT_MS = 5000;

// Heartbeat timeout: 90 seconds (daemon side)
inline constexpr int CLIENT_HEARTBEAT_TIMEOUT_SECS = 90;

// -------------------------------------------------------------------
// Message types
// -------------------------------------------------------------------
enum MsgType : uint8_t {
    MSG_CREATE            = 0x01,
    MSG_CREATE_OK         = 0x02,
    MSG_ATTACH            = 0x03,
    MSG_ATTACH_OK         = 0x04,
    MSG_REPLAY_DATA       = 0x05,
    MSG_REPLAY_END        = 0x06,
    MSG_DETACH            = 0x07,
    MSG_DETACH_OK         = 0x08,
    MSG_DESTROY           = 0x09,
    MSG_DESTROY_OK        = 0x0A,
    MSG_RESIZE            = 0x0B,
    MSG_INPUT             = 0x0C,
    MSG_OUTPUT            = 0x0D,
    MSG_LIST              = 0x0E,
    MSG_LIST_OK           = 0x0F,
    MSG_ERROR             = 0x10,
    MSG_SESSION_EXITED    = 0x11,
    MSG_HELLO             = 0x12,
    MSG_HELLO_OK          = 0x13,
    MSG_FG_PROCESS_QUERY  = 0x14,
    MSG_FG_PROCESS_INFO   = 0x15,
    MSG_SEND_SIGNAL       = 0x16,
    MSG_SIGNAL_OK         = 0x17,
    MSG_SET_TERMIOS       = 0x18,
    MSG_FG_PROCESS_UPDATE = 0x19,
    MSG_PING              = 0x1A,
    MSG_PONG              = 0x1B,
};

// -------------------------------------------------------------------
// Error codes
// -------------------------------------------------------------------
enum ErrorCode : uint8_t {
    ERR_SESSION_NOT_FOUND   = 0x01,
    ERR_SESSION_BUSY        = 0x02,
    ERR_OUT_OF_MEMORY       = 0x03,
    ERR_TOO_MANY_SESSIONS   = 0x04,
    ERR_PROTOCOL_ERROR      = 0x05,
    ERR_INVALID_SESSION_ID  = 0x06,
    ERR_PERMISSION_DENIED   = 0x07,
    ERR_SHELL_NOT_FOUND     = 0x08,
    ERR_INTERNAL_ERROR      = 0x09,
};

// -------------------------------------------------------------------
// Capability bits
// -------------------------------------------------------------------
inline constexpr uint32_t CAP_PERSISTENT_TERMIOS  = (1u << 0);
inline constexpr uint32_t CAP_FG_PROCESS_UPDATES  = (1u << 1);
inline constexpr uint32_t CAP_SIGNAL_FORWARDING   = (1u << 2);
inline constexpr uint32_t CAP_REPLAY_CHUNKED      = (1u << 3);

// All capabilities supported by this daemon
inline constexpr uint32_t DAEMON_CAPABILITIES =
    CAP_PERSISTENT_TERMIOS | CAP_FG_PROCESS_UPDATES |
    CAP_SIGNAL_FORWARDING  | CAP_REPLAY_CHUNKED;

// -------------------------------------------------------------------
// Wire format helpers (little-endian)
// -------------------------------------------------------------------
inline void write_u16_le(uint8_t *dst, uint16_t val) {
    dst[0] = static_cast<uint8_t>(val & 0xFF);
    dst[1] = static_cast<uint8_t>((val >> 8) & 0xFF);
}

inline void write_u32_le(uint8_t *dst, uint32_t val) {
    dst[0] = static_cast<uint8_t>(val & 0xFF);
    dst[1] = static_cast<uint8_t>((val >> 8) & 0xFF);
    dst[2] = static_cast<uint8_t>((val >> 16) & 0xFF);
    dst[3] = static_cast<uint8_t>((val >> 24) & 0xFF);
}

inline void write_u64_le(uint8_t *dst, uint64_t val) {
    for (int i = 0; i < 8; i++)
        dst[i] = static_cast<uint8_t>((val >> (i * 8)) & 0xFF);
}

inline uint16_t read_u16_le(const uint8_t *src) {
    return static_cast<uint16_t>(src[0]) |
           (static_cast<uint16_t>(src[1]) << 8);
}

inline uint32_t read_u32_le(const uint8_t *src) {
    return static_cast<uint32_t>(src[0]) |
           (static_cast<uint32_t>(src[1]) << 8) |
           (static_cast<uint32_t>(src[2]) << 16) |
           (static_cast<uint32_t>(src[3]) << 24);
}

inline uint64_t read_u64_le(const uint8_t *src) {
    uint64_t val = 0;
    for (int i = 0; i < 8; i++)
        val |= static_cast<uint64_t>(src[i]) << (i * 8);
    return val;
}

// Write a length-prefixed string (2-byte LE length + UTF-8 bytes).
// Returns number of bytes written.
inline size_t write_string(uint8_t *dst, const char *str, size_t len) {
    write_u16_le(dst, static_cast<uint16_t>(len));
    if (len > 0)
        memcpy(dst + 2, str, len);
    return 2 + len;
}

// Read a length-prefixed string. Returns false if not enough data.
// On success, sets *out and *out_len and returns true.
inline bool read_string(const uint8_t *src, size_t available,
                        const char **out, uint16_t *out_len, size_t *consumed) {
    if (available < 2)
        return false;
    uint16_t len = read_u16_le(src);
    if (available < 2u + len)
        return false;
    *out = reinterpret_cast<const char *>(src + 2);
    *out_len = len;
    *consumed = 2 + len;
    return true;
}

// Build a message header (type + payload length) into dst[0..4].
inline void write_header(uint8_t *dst, uint8_t type, uint32_t payload_len) {
    dst[0] = type;
    write_u32_le(dst + 1, payload_len);
}

#endif // CRT_SESSIOND_PROTOCOL_H
