/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://crtplus.fromhelloworld.com
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

// Switch with a visible track and thumb in both light and dark mode.
// Fusion style draws a nearly invisible switch in dark mode.
Switch {
    id: control
    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 20
        x: control.leftPadding
        y: (parent.height - height) / 2
        radius: height / 2
        color: control.checked ? palette.highlight : Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.2)
        border.color: control.checked ? palette.highlight : Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.4)
        border.width: 1

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: width / 2
            color: "white"

            Behavior on x {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
