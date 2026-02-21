/*
    Copyright (c) 2026 Alex Fabri
    https://crtplus.fromhelloworld.com
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

#ifndef CRT_SESSIOND_LOG_H
#define CRT_SESSIOND_LOG_H

#include <cstdio>
#include <cstdarg>
#include <os/log.h>

// Global debug flag — set by --debug CLI flag
extern bool g_debug_mode;

namespace Log {

inline os_log_t logHandle() {
    static os_log_t h = os_log_create("com.fromhelloworld.crt-plus.sessiond", "daemon");
    return h;
}

inline void error(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
inline void error(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log_error(logHandle(), "%{public}s", buf);
    if (g_debug_mode)
        fprintf(stderr, "[ERROR] %s\n", buf);
}

inline void warn(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
inline void warn(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(logHandle(), "%{public}s", buf);
    if (g_debug_mode)
        fprintf(stderr, "[WARN]  %s\n", buf);
}

inline void info(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
inline void info(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log_info(logHandle(), "%{public}s", buf);
    if (g_debug_mode)
        fprintf(stderr, "[INFO]  %s\n", buf);
}

inline void debug(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
inline void debug(const char *fmt, ...) {
    if (!g_debug_mode)
        return;
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log_debug(logHandle(), "%{public}s", buf);
    fprintf(stderr, "[DEBUG] %s\n", buf);
}

} // namespace Log

// Convenience macros
#define LOG_ERROR(...) Log::error(__VA_ARGS__)
#define LOG_WARN(...)  Log::warn(__VA_ARGS__)
#define LOG_INFO(...)  Log::info(__VA_ARGS__)
#define LOG_DEBUG(...) Log::debug(__VA_ARGS__)

#endif // CRT_SESSIOND_LOG_H
