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
import QtQuick.Controls 2.3

MenuBar {
    id: defaultMenuBar
    visible: appSettings.isMacOS || appSettings.showMenubar

    Menu {
        title: qsTr("File")
        MenuItem { action: newWindowAction }
        MenuItem { action: newTabAction }
        MenuSeparator { }
        MenuItem { action: renameTabAction }
        MenuItem {
            text: qsTr("Reset Tab Name")
            enabled: {
                var entry = terminalTabs.tabsModel.get(terminalTabs.currentIndex)
                return entry ? entry.customTitle !== "" : false
            }
            onTriggered: terminalTabs.resetCustomTitle(terminalTabs.currentIndex)
        }
        MenuSeparator { }
        MenuItem { action: quitAction }
    }
    Menu {
        title: qsTr("Edit")
        MenuItem { action: copyAction }
        MenuItem { action: pasteAction }
        MenuSeparator {}
        MenuItem { action: showsettingsAction }
    }
    Menu {
        id: viewMenu
        title: qsTr("View")
        Instantiator {
            model: !appSettings.isMacOS ? 1 : 0
            delegate: MenuItem { action: fullscreenAction }
            onObjectAdded: (index, object) => viewMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => viewMenu.removeItem(object)
        }
        MenuItem { action: zoomIn }
        MenuItem { action: zoomOut }
    }
    Menu {
        id: windowMenu
        title: qsTr("Window")
        MenuItem { action: minimizeAction }
        MenuSeparator { }
        Instantiator {
            model: appRoot.windows
            delegate: MenuItem {
                required property var modelData
                required property int index
                text: modelData.title || "CRT Plus"
                checkable: true
                checked: modelData === terminalWindow
                onTriggered: {
                    modelData.raise()
                    modelData.requestActivate()
                }
            }
            onObjectAdded: (index, object) => windowMenu.insertItem(index + 2, object)
            onObjectRemoved: (index, object) => windowMenu.removeItem(object)
        }
    }
    Menu {
        id: profilesMenu
        title: qsTr("Profiles")
        Repeater {
            model: appSettings.profilesList
            MenuItem {
                required property int index
                required property string obj_string
                text: appSettings.profilesList.get(index).text
                enabled: obj_string !== ""
                onTriggered: {
                    terminalWindow.profileSettings.currentProfileIndex = index
                    terminalTabs.loadProfileForCurrentTab(obj_string)
                }
            }
        }
    }
    Menu {
        title: qsTr("Help")
        MenuItem {
            action: showAboutAction
        }
    }
}
