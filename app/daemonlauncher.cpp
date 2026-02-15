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
#include "daemonlauncher.h"

#include <QCoreApplication>
#include <QLocalSocket>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QThread>
#include <QtDebug>

#include <spawn.h>
#include <unistd.h>
#include <signal.h>

extern char **environ;

QString DaemonLauncher::socketPath()
{
#if defined(Q_OS_MAC)
    QString tmpDir = qEnvironmentVariable("TMPDIR", "/tmp");
    return QDir(tmpDir).filePath(
        QString("crt-plus-%1/sessiond.sock").arg(getuid()));
#else
    // Linux: prefer XDG_RUNTIME_DIR, fall back to /tmp
    QString xdgRuntime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (!xdgRuntime.isEmpty()) {
        return QDir(xdgRuntime).filePath("crt-plus/sessiond.sock");
    }
    return QString("/tmp/crt-plus-%1/sessiond.sock").arg(getuid());
#endif
}

QString DaemonLauncher::pidFilePath()
{
    QFileInfo sockInfo(socketPath());
    return sockInfo.dir().filePath("sessiond.pid");
}

void DaemonLauncher::cleanupStaleDaemon()
{
    // Try to kill the old daemon via PID file
    QString pidPath = pidFilePath();
    if (QFile::exists(pidPath)) {
        QFile pidFile(pidPath);
        if (pidFile.open(QIODevice::ReadOnly)) {
            bool ok;
            pid_t pid = pidFile.readAll().trimmed().toInt(&ok);
            pidFile.close();
            if (ok && pid > 0) {
                // Check if process exists
                if (::kill(pid, 0) == 0) {
                    ::kill(pid, SIGTERM);
                    // Wait briefly for graceful exit
                    for (int i = 0; i < 10; ++i) {
                        QThread::msleep(100);
                        if (::kill(pid, 0) != 0) break;
                    }
                    // Force kill if still alive
                    if (::kill(pid, 0) == 0)
                        ::kill(pid, SIGKILL);
                }
            }
        }
        QFile::remove(pidPath);
    }
    // Remove stale socket
    QFile::remove(socketPath());
}

bool DaemonLauncher::isDaemonRunning()
{
    QString path = socketPath();
    if (!QFile::exists(path))
        return false;

    QLocalSocket socket;
    socket.connectToServer(path);
    if (socket.waitForConnected(500)) {
        socket.disconnectFromServer();
        return true;
    }
    return false;
}

QString DaemonLauncher::daemonBinaryPath()
{
    // First try: same directory as the app binary (macOS .app bundle MacOS/)
    QString appDir = QCoreApplication::applicationDirPath();
    QString candidate = appDir + "/crt-sessiond";
    if (QFile::exists(candidate))
        return candidate;

    // Second try: Linux system install location
    candidate = QStringLiteral("/usr/lib/crt-plus/crt-sessiond");
    if (QFile::exists(candidate))
        return candidate;

    qWarning() << "DaemonLauncher: crt-sessiond binary not found";
    return QString();
}

bool DaemonLauncher::launchDaemon()
{
    QString binPath = daemonBinaryPath();
    if (binPath.isEmpty())
        return false;

    QByteArray binPathUtf8 = binPath.toLocal8Bit();

    // Build argv
    char *argv[] = { binPathUtf8.data(), nullptr };

    // Configure posix_spawn attributes: create new session (setsid)
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSID);

    pid_t pid = 0;
    int result = posix_spawn(&pid, binPathUtf8.constData(), nullptr, &attr,
                             argv, environ);

    posix_spawnattr_destroy(&attr);

    if (result != 0) {
        qWarning() << "DaemonLauncher: posix_spawn failed with error" << result;
        return false;
    }

    qDebug() << "DaemonLauncher: launched crt-sessiond with PID" << pid;
    return true;
}

bool DaemonLauncher::ensureDaemonRunning()
{
    if (isDaemonRunning())
        return true;

    // Socket exists but can't connect — stale daemon. Clean up and retry.
    if (QFile::exists(socketPath()))
        cleanupStaleDaemon();

    if (!launchDaemon())
        return false;

    // Poll for up to 2 seconds, checking every 100ms
    for (int i = 0; i < 20; ++i) {
        QThread::msleep(100);
        if (isDaemonRunning())
            return true;
    }

    qWarning() << "DaemonLauncher: daemon did not become ready within 2 seconds";
    return isDaemonRunning();
}
