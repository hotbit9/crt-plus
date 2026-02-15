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

Menu {
    id: contextmenu
    property string openFilePath: ""
    property int openFileCoordX: 0
    property int openFileCoordY: 0
    property bool hasSelection: false
    property bool isRemoteSession: false
    property bool isFile: false
    property bool isFolder: false
    property bool isLink: false
    property bool hasOpenTarget: isFile || isFolder || isLink
    property bool optionHeld: false
    property bool showExtendedMenus: false

    Timer {
        interval: 80; repeat: true
        running: contextmenu.visible
        onTriggered: contextmenu.optionHeld = fileIO.isOptionPressed()
    }
    onClosed: optionHeld = false

    MenuItem {
        text: qsTr("Open File")
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
        enabled: contextmenu.isFile
        onTriggered: terminalContainer.actionOpenFile(contextmenu.openFileCoordX, contextmenu.openFileCoordY, contextmenu.openFilePath)
    }
    MenuItem {
        text: contextmenu.optionHeld ? qsTr("Open File in New Pane Right") : qsTr("Open File in New Pane")
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
        enabled: contextmenu.isFile
        onTriggered: terminalContainer.actionOpenFileInSplit(contextmenu.openFileCoordX, contextmenu.openFileCoordY, contextmenu.openFilePath,
            contextmenu.optionHeld ? Qt.Horizontal : Qt.Vertical)
    }
    MenuItem {
        text: qsTr("Open Folder")
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
        enabled: contextmenu.isFolder
        onTriggered: terminalContainer.actionOpenFolder(contextmenu.openFilePath)
    }
    MenuItem {
        text: contextmenu.optionHeld ? qsTr("Open Folder in New Pane Right") : qsTr("Open Folder in New Pane")
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
        enabled: contextmenu.isFolder
        onTriggered: terminalContainer.actionOpenFolderInSplit(contextmenu.openFilePath,
            contextmenu.optionHeld ? Qt.Horizontal : Qt.Vertical)
    }
    MenuItem {
        text: qsTr("Open Link")
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
        enabled: contextmenu.isLink
        onTriggered: terminalContainer.actionOpenLink(contextmenu.openFileCoordX, contextmenu.openFileCoordY)
    }
    MenuItem {
        text: qsTr("Copy")
        enabled: contextmenu.hasSelection || contextmenu.openFilePath !== ""
        onTriggered: {
            if (contextmenu.hasSelection)
                kterminal.copyClipboard()
            else
                kterminal.copyTextToClipboard(contextmenu.openFilePath)
        }
    }
    MenuSeparator {
        visible: contextmenu.hasOpenTarget
        height: visible ? implicitHeight : 0
    }
    MenuItem {
        text: qsTr("Paste")
        onTriggered: kterminal.pasteClipboard()
    }
    MenuItem {
        action: showsettingsAction
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
    }

    Menu {
        title: qsTr("File")
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
        MenuItem {
            action: newWindowAction
        }
        MenuItem {
            action: newTabAction
        }
        MenuSeparator {}
        MenuItem {
            action: closeWindowAction
        }
    }
    Menu {
        title: qsTr("Edit")
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
        MenuItem {
            text: qsTr("Copy")
            visible: contextmenu.hasSelection || contextmenu.openFilePath !== ""
            height: visible ? implicitHeight : 0
            onTriggered: {
                if (contextmenu.hasSelection)
                    kterminal.copyClipboard()
                else
                    kterminal.copyTextToClipboard(contextmenu.openFilePath)
            }
        }
        MenuItem {
            text: qsTr("Paste")
            onTriggered: kterminal.pasteClipboard()
        }
        MenuSeparator {}
        MenuItem {
            action: showsettingsAction
        }
    }
    Menu {
        title: qsTr("View")
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
        MenuItem {
            action: fullscreenAction
            visible: fullscreenAction.enabled
        }
        MenuItem {
            action: zoomIn
        }
        MenuItem {
            action: zoomOut
        }
    }
    Menu {
        id: profilesMenu
        title: qsTr("Profiles")
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
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
        visible: contextmenu.showExtendedMenus
        height: visible ? implicitHeight : 0
        MenuItem {
            action: showAboutAction
        }
    }
}
