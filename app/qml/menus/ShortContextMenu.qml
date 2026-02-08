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
    MenuItem {
        text: qsTr("Open")
        visible: contextmenu.openFilePath !== ""
        height: visible ? implicitHeight : 0
        onTriggered: {
            if (!kterminal.activateHotSpotAt(contextmenu.openFileCoordX, contextmenu.openFileCoordY, "click-action"))
                kterminal.resolveAndOpenFileAt(contextmenu.openFileCoordX, contextmenu.openFileCoordY)
        }
    }
    MenuItem {
        text: qsTr("Copy")
        enabled: contextmenu.hasSelection
        onTriggered: kterminal.copyClipboard()
    }
    MenuSeparator {
        visible: contextmenu.openFilePath !== ""
        height: visible ? implicitHeight : 0
    }
    MenuItem {
        text: qsTr("Paste")
        onTriggered: kterminal.pasteClipboard()
    }
}
