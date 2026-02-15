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

#include "uuid.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>

bool uuid_generate(char *buf, size_t buflen) {
    if (buflen < UUID_STR_LEN)
        return false;

    uint8_t bytes[16];
    int fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return false;

    ssize_t n = 0;
    while (n < 16) {
        ssize_t r = read(fd, bytes + n, 16 - static_cast<size_t>(n));
        if (r <= 0) {
            close(fd);
            return false;
        }
        n += r;
    }
    close(fd);

    // Set version 4: byte 6 high nibble = 0100
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Set variant 1: byte 8 high bits = 10
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    snprintf(buf, buflen,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
             bytes[0], bytes[1], bytes[2], bytes[3],
             bytes[4], bytes[5],
             bytes[6], bytes[7],
             bytes[8], bytes[9],
             bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);

    return true;
}

bool uuid_validate(const char *str, size_t len) {
    if (len != 36)
        return false;

    // Format: 8-4-4-4-12  (positions of hyphens: 8, 13, 18, 23)
    for (size_t i = 0; i < 36; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            if (str[i] != '-')
                return false;
        } else {
            char c = str[i];
            bool hex = (c >= '0' && c <= '9') ||
                       (c >= 'a' && c <= 'f') ||
                       (c >= 'A' && c <= 'F');
            if (!hex)
                return false;
        }
    }
    return true;
}
