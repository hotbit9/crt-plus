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

// UUID v4 generation from /dev/urandom and format validation.

#ifndef CRT_SESSIOND_UUID_H
#define CRT_SESSIOND_UUID_H

#include <cstddef>

// UUID v4 string length (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx) + null
inline constexpr size_t UUID_STR_LEN = 37;

// Generate a UUID v4 string into buf (must be >= UUID_STR_LEN bytes).
// Returns true on success, false if /dev/urandom cannot be read.
bool uuid_generate(char *buf, size_t buflen);

// Validate that a string is a well-formed UUID v4 (36 chars, correct format).
bool uuid_validate(const char *str, size_t len);

#endif // CRT_SESSIOND_UUID_H
