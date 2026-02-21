/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://crtplus.fromhelloworld.com
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
#ifndef SFSYMBOLPROVIDER_H
#define SFSYMBOLPROVIDER_H

#include <QQuickImageProvider>

// QML image provider for macOS SF Symbols.
// Usage:  Image { source: "image://sfsymbol/bell.badge.fill?size=16&dark=1" }
// Renders with a two-color palette (red accent + theme-adapted base).
class SFSymbolProvider : public QQuickImageProvider
{
public:
    SFSymbolProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};

#endif // SFSYMBOLPROVIDER_H
