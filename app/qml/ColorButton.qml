/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
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
import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Dialogs

Item {
    id: rootItem

    signal colorSelected(color color)
    property color color
    property string name

    ColorDialog {
        id: colorDialog
        title: qsTr("Choose a color")
        modality: Qt.ApplicationModal
        selectedColor: rootItem.color

        onSelectedColorChanged: {
            if (!appSettings.isMacOS && visible)
                colorSelected(selectedColor)
        }
        onAccepted: colorSelected(selectedColor)
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: palette.button
        border.color: mouseArea.containsMouse ? palette.highlight : Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.2)
        border.width: mouseArea.containsMouse ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            // Color swatch
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 6
                color: rootItem.color
                border.color: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.3)
                border.width: 1
            }

            // Label and hex value
            Column {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: rootItem.name
                    font.pixelSize: 11
                    color: palette.text
                    opacity: 0.7
                }
                Text {
                    text: rootItem.color.toString().toUpperCase()
                    font.pixelSize: 12
                    font.bold: true
                    color: palette.text
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: colorDialog.open()
    }
}
