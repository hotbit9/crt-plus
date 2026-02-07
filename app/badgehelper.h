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
#ifndef BADGEHELPER_H
#define BADGEHELPER_H

#include <QObject>
#include "macutils.h"

class BadgeHelper : public QObject
{
    Q_OBJECT
public:
    explicit BadgeHelper(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void updateBadge(int count) { setDockBadge(count); }
};

#endif // BADGEHELPER_H
