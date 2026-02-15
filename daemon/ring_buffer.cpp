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

#include "ring_buffer.h"

#include <cstdlib>
#include <cstring>

// Use memset_s for secure deletion where available
#if defined(__STDC_LIB_EXT1__) || defined(__APPLE__)
#define HAVE_MEMSET_S 1
#else
#define HAVE_MEMSET_S 0
#endif

static void secure_zero(void *ptr, size_t len) {
#if HAVE_MEMSET_S
    memset_s(ptr, len, 0, len);
#else
    volatile uint8_t *p = static_cast<volatile uint8_t *>(ptr);
    while (len--)
        *p++ = 0;
#endif
}

RingBuffer::RingBuffer(size_t capacity)
    : _buf(nullptr), _capacity(capacity), _head(0), _used(0)
{
    if (_capacity > 0)
        _buf = static_cast<uint8_t *>(malloc(_capacity));
}

RingBuffer::~RingBuffer() {
    if (_buf) {
        secure_zero(_buf, _capacity);
        free(_buf);
    }
}

void RingBuffer::write(const uint8_t *data, size_t len) {
    if (!_buf || _capacity == 0 || len == 0)
        return;

    // If writing more than capacity, only keep the last _capacity bytes
    if (len >= _capacity) {
        memcpy(_buf, data + len - _capacity, _capacity);
        _head = 0;
        _used = _capacity;
        return;
    }

    // Two-memcpy wrap-around write
    size_t space_to_end = _capacity - _head;
    if (len <= space_to_end) {
        memcpy(_buf + _head, data, len);
    } else {
        memcpy(_buf + _head, data, space_to_end);
        memcpy(_buf, data + space_to_end, len - space_to_end);
    }

    _head = (_head + len) % _capacity;
    _used += len;
    if (_used > _capacity)
        _used = _capacity;
}

void RingBuffer::readAll(const uint8_t **p1, size_t *len1,
                         const uint8_t **p2, size_t *len2) const {
    if (!_buf || _used == 0) {
        *p1 = nullptr; *len1 = 0;
        *p2 = nullptr; *len2 = 0;
        return;
    }

    // Start of readable data
    size_t start;
    if (_used < _capacity) {
        start = 0;
    } else {
        start = _head; // oldest data starts where next write would go
    }

    if (start + _used <= _capacity) {
        // No wrap: single contiguous segment
        *p1 = _buf + start;
        *len1 = _used;
        *p2 = nullptr;
        *len2 = 0;
    } else {
        // Wrap: two segments
        *p1 = _buf + start;
        *len1 = _capacity - start;
        *p2 = _buf;
        *len2 = _used - *len1;
    }
}

uint8_t RingBuffer::byteAt(size_t offset) const {
    size_t start;
    if (_used < _capacity)
        start = 0;
    else
        start = _head;

    return _buf[(start + offset) % _capacity];
}

size_t RingBuffer::findUtf8Boundary(size_t offset) const {
    if (_used == 0 || offset >= _used)
        return offset;

    // Skip up to 3 UTF-8 continuation bytes (10xxxxxx pattern)
    for (int skipped = 0; skipped < 3 && offset < _used; skipped++) {
        uint8_t b = byteAt(offset);
        // A valid lead byte is NOT a continuation byte
        if ((b & 0xC0) != 0x80)
            return offset;
        offset++;
    }
    return offset;
}

void RingBuffer::clear() {
    if (_buf)
        secure_zero(_buf, _capacity);
    _head = 0;
    _used = 0;
}
