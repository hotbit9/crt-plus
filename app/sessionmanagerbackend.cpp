/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://fromhelloworld.com
* https://github.com/hotbit9
*
* This file is part of CRT Plus.
*
* CRT Plus is free software: you can redistribute it and/or modify
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
#include "sessionmanagerbackend.h"
#include "DaemonClient.h"

using namespace Konsole;

SessionManagerBackend::SessionManagerBackend(QObject *parent)
    : QObject(parent)
{
    connect(DaemonClient::instance(), &DaemonClient::listResult,
            this, [this](const QList<DaemonSessionInfo> &sessions) {
        QVariantList result;
        for (const auto &s : sessions) {
            QVariantMap entry;
            entry["sessionId"] = QString::fromLatin1(s.sessionId);
            entry["alive"] = s.alive;
            entry["hasClient"] = s.hasClient;
            result.append(entry);
        }
        emit sessionsListed(result);
    });
}

void SessionManagerBackend::queryDaemonSessions()
{
    if (!DaemonClient::instance()->isConnected()) {
        DaemonClient::instance()->connectToDaemon();
    }
    DaemonClient::instance()->sendList();
}

void SessionManagerBackend::destroyDaemonSession(const QString &uuid)
{
    DaemonClient::instance()->sendDestroy(uuid.toLatin1());
}
