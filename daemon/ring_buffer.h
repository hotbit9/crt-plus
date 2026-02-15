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

// Fixed-capacity circular byte buffer for storing terminal output.
// Supports wrap-around writes, two-segment reads, and secure deletion.

#ifndef CRT_SESSIOND_RING_BUFFER_H
#define CRT_SESSIOND_RING_BUFFER_H

#include <cstddef>
#include <cstdint>

class RingBuffer {
public:
    explicit RingBuffer(size_t capacity);
    ~RingBuffer();

    // Non-copyable
    RingBuffer(const RingBuffer &) = delete;
    RingBuffer &operator=(const RingBuffer &) = delete;

    // Write data into the buffer. Wraps around, overwriting oldest data.
    void write(const uint8_t *data, size_t len);

    // Get readable data as up to two contiguous segments (handles wrap-around).
    // p1/len1 is the first segment, p2/len2 is the second (may be zero).
    void readAll(const uint8_t **p1, size_t *len1,
                 const uint8_t **p2, size_t *len2) const;

    // Find a valid UTF-8 lead byte boundary starting from the given offset
    // into the readable data. Skips at most 3 continuation bytes.
    // Returns the adjusted offset.
    size_t findUtf8Boundary(size_t offset) const;

    // Secure-clear and reset.
    void clear();

    size_t capacity() const { return _capacity; }
    size_t used() const { return _used; }
    bool empty() const { return _used == 0; }
    bool valid() const { return _buf != nullptr || _capacity == 0; }

private:
    uint8_t *_buf;
    size_t _capacity;
    size_t _head;  // next write position
    size_t _used;  // current bytes stored

    // Read a byte at a given offset into the readable data (0 = oldest).
    uint8_t byteAt(size_t offset) const;
};

#endif // CRT_SESSIOND_RING_BUFFER_H
