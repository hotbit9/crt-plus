/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://crtplus.fromhelloworld.com
* https://github.com/hotbit9/crt-plus
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
#ifndef SPARKLEUPDATER_H
#define SPARKLEUPDATER_H

#ifdef HAVE_SPARKLE

#include <QObject>
#include "macutils.h"

class SparkleUpdater : public QObject
{
    Q_OBJECT
public:
    explicit SparkleUpdater(QObject *parent = nullptr)
        : QObject(parent) { initSparkle(); }
    Q_INVOKABLE void checkForUpdates() { sparkleCheckForUpdates(); }
    Q_INVOKABLE void startUpdater() { sparkleStartUpdater(); }
};

#endif // HAVE_SPARKLE
#endif // SPARKLEUPDATER_H
