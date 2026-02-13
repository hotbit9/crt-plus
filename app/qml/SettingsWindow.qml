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
import QtQuick.Controls 2.1
import QtQuick.Window 2.1
import QtQuick.Layouts 1.3

ApplicationWindow {
    id: settings_window
    title: qsTr("Settings")
    width: 640
    height: 720

    property int currentTab: 0

    readonly property var tabModel: [
        { icon: "\u2261", label: qsTr("Profiles") },
        { icon: "\u25D0", label: qsTr("Appearance") },
        { icon: "\u2738", label: qsTr("Effects") },
        { icon: ">_",     label: qsTr("Terminal") }
    ]

    Column {
        anchors.fill: parent

        // TOOLBAR //////////////////////////////////////////////////////////////
        Item {
            id: toolbar
            width: parent.width
            height: 60

            Row {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: tabModel

                    Rectangle {
                        width: 80
                        height: 52
                        radius: 6
                        color: {
                            if (index === currentTab)
                                return palette.highlight
                            if (hoverArea.containsMouse)
                                return Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.06)
                            return "transparent"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: 20
                                font.bold: true
                                color: index === currentTab ? palette.highlightedText : palette.text
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: 11
                                color: index === currentTab ? palette.highlightedText : palette.text
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: currentTab = index
                        }
                    }
                }
            }
        }

        // SEPARATOR ////////////////////////////////////////////////////////////
        Rectangle {
            width: parent.width
            height: 1
            color: palette.text
            opacity: 0.12
        }

        // CONTENT //////////////////////////////////////////////////////////////
        StackLayout {
            width: parent.width
            height: parent.height - toolbar.height - 1

            currentIndex: currentTab

            Item {
                SettingsProfilesTab {
                    anchors {
                        fill: parent
                        margins: 20
                    }
                }
            }
            Item {
                SettingsAppearanceTab {
                    anchors {
                        fill: parent
                        margins: 20
                    }
                }
            }
            Item {
                SettingsEffectsTab {
                    anchors {
                        fill: parent
                        margins: 20
                    }
                }
            }
            Item {
                SettingsTerminalTab {
                    anchors {
                        fill: parent
                        margins: 20
                    }
                }
            }
        }
    }
}
