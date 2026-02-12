/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://fromhelloworld.com
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
import QtQuick 2.2
import QtQuick.Controls 2.0

// Slider with visible track and handle in both light and dark mode.
// Fusion style draws nearly invisible controls in dark mode.
Slider {
    id: control

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.15)

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: palette.highlight
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - implicitWidth)
        y: control.topPadding + control.availableHeight / 2 - implicitHeight / 2
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: control.pressed ? Qt.darker(palette.button, 1.1) : palette.button
        border.color: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.3)
        border.width: 1
    }
}
