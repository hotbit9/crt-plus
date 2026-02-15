/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://fromhelloworld.com
* https://github.com/hotbit9/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
#ifndef DAEMONLAUNCHER_H
#define DAEMONLAUNCHER_H

#include <QString>

class DaemonLauncher {
public:
    // Check if daemon is running by trying to connect to its socket
    static bool isDaemonRunning();

    // Find daemon binary path
    static QString daemonBinaryPath();

    // Launch daemon via posix_spawn (detached, setsid)
    static bool launchDaemon();

    // Ensure daemon is running: check, launch if needed, wait up to 2s
    static bool ensureDaemonRunning();

private:
    static QString socketPath();
    static QString pidFilePath();
    static void cleanupStaleDaemon();
};

#endif // DAEMONLAUNCHER_H
