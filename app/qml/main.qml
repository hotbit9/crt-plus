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

import "menus"

QtObject {
    id: appRoot

    property var windows: []
    property var activeTerminalWindow: null

    property ApplicationSettings appSettings: ApplicationSettings {
        onInitializedSettings: {
            var defaultProfile = ""
            if (appSettings.defaultProfileName !== "") {
                var defaultIndex = appSettings.getProfileIndexByName(appSettings.defaultProfileName)
                if (defaultIndex !== -1) {
                    defaultProfile = appSettings.profilesList.get(defaultIndex).obj_string
                } else {
                    defaultProfile = appSettings.composeProfileString()
                }
            }
            createWindow(defaultProfile)
        }
    }

    property TimeManager timeManager: TimeManager {
        enableTimer: true
    }

    property SettingsWindow settingsWindow: SettingsWindow {
        visible: false
    }

    property AboutDialog aboutDialog: AboutDialog {
        visible: false
    }

    property Component windowComponent: Component {
        TerminalWindow { }
    }

    function createWindow(profileString) {
        var win = windowComponent.createObject(appRoot)

        if (profileString && profileString !== "") {
            win.defaultProfileString = profileString
        }

        // Cascade position from the last window
        if (windows.length > 0) {
            var lastWin = windows[windows.length - 1]
            win.x = lastWin.x + 30
            win.y = lastWin.y + 30
        }

        windows = windows.concat([win])
        win.visible = true
    }

    function closeWindow(window) {
        // Save current tab profile before removing
        var idx = windows.indexOf(window)
        if (idx === -1) return

        var newList = windows.slice()
        newList.splice(idx, 1)
        windows = newList

        window.destroy()

        if (windows.length === 0) {
            appSettings.close()
        }
    }
}
