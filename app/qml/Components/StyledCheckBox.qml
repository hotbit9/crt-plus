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

// CheckBox with a visible indicator in both light and dark mode.
// Fusion style draws a nearly invisible box in dark mode.
CheckBox {
    id: control
    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: (parent.height - height) / 2
        radius: 3
        color: control.checked ? palette.highlight : "transparent"
        border.color: control.checked ? palette.highlight : Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.5)
        border.width: 1.5

        Text {
            anchors.centerIn: parent
            text: "\u2713"
            font.pixelSize: 13
            font.bold: true
            color: "white"
            visible: control.checked
        }
    }
}
