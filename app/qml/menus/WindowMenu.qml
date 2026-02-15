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
        title: qsTr("Shell")
        MenuItem { action: newWindowAction }
        Menu {
            title: qsTr("New Window with Profile")
            Repeater {
                model: appSettings.profilesList
                MenuItem {
                    required property int index
                    required property string obj_string
                    text: appSettings.profilesList.get(index).text
                    enabled: obj_string !== ""
                    onTriggered: appRoot.createWindow(obj_string)
                }
            }
        }
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
        MenuItem { action: renameWindowAction }
        MenuItem {
            text: qsTr("Reset Window Name")
            enabled: terminalTabs.customWindowTitle !== ""
            onTriggered: terminalTabs.resetWindowTitle()
        }
        MenuSeparator { }
        MenuItem { action: closeWindowAction }
    }
    Menu {
        title: qsTr("Pane")
        MenuItem { action: splitHorizontalAction }
        MenuItem { action: splitVerticalAction }
        MenuSeparator {}
        MenuItem { action: nextPaneAction }
        MenuItem { action: previousPaneAction }
        MenuSeparator {}
        MenuItem { action: closePaneAction }
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
        Repeater {
            model: appRoot.windows.length
            MenuItem {
                required property int index
                text: appRoot.windows[index] ? (appRoot.windows[index].title || "CRT Plus") : "CRT Plus"
                checkable: true
                checked: appRoot.windows[index] === terminalWindow
                onTriggered: {
                    var win = appRoot.windows[index]
                    if (win) {
                        win.raise()
                        win.requestActivate()
                    }
                }
            }
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
