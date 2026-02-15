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
#ifndef SESSIONMANAGERBACKEND_H
#define SESSIONMANAGERBACKEND_H

#include <QObject>
#include <QVariantList>

class SessionManagerBackend : public QObject {
    Q_OBJECT
public:
    explicit SessionManagerBackend(QObject *parent = nullptr);

    Q_INVOKABLE void queryDaemonSessions();
    Q_INVOKABLE void destroyDaemonSession(const QString &uuid);

signals:
    void sessionsListed(const QVariantList &sessions);
};

#endif // SESSIONMANAGERBACKEND_H
