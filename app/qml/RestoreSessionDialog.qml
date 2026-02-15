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
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"

ApplicationWindow {
    id: restoreDialog
    title: "CRT Plus"
    width: 400
    height: 180
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint
    modality: Qt.ApplicationModal

    property int windowCount: 0
    property int tabCount: 0

    signal restoreRequested()
    signal discardRequested()
    signal alwaysRestoreRequested()

    property bool _handled: false
    onClosing: { if (!_handled) { _handled = true; discardRequested() } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Label {
            text: {
                var parts = []
                if (windowCount === 1) parts.push("1 window")
                else parts.push(windowCount + " windows")
                if (tabCount === 1) parts.push("1 tab")
                else parts.push(tabCount + " tabs")
                return "CRT Plus found " + parts.join(" with ") + " from your last session."
            }
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        StyledCheckBox {
            id: alwaysCheck
            text: "Always restore without asking"
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                text: "Don't Restore"
                onClicked: { restoreDialog._handled = true; restoreDialog.discardRequested() }
            }
            Button {
                text: "Restore"
                highlighted: true
                focus: true
                onClicked: {
                    restoreDialog._handled = true
                    if (alwaysCheck.checked)
                        restoreDialog.alwaysRestoreRequested()
                    else
                        restoreDialog.restoreRequested()
                }
            }
        }
    }
}
