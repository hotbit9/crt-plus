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

    property ApplicationSettings appSettings: ApplicationSettings {
        onInitializedSettings: {
            if (initialX !== undefined && initialY !== undefined) {
                terminalWindow.x = initialX
                terminalWindow.y = initialY
            }
            terminalWindow.visible = true
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

    property TerminalWindow terminalWindow: TerminalWindow { }

    function createWindow() {
        var profileString
        if (appSettings.defaultProfileName !== "") {
            var defaultIndex = appSettings.getProfileIndexByName(appSettings.defaultProfileName)
            if (defaultIndex !== -1) {
                profileString = appSettings.profilesList.get(defaultIndex).obj_string
            } else {
                profileString = appSettings.composeProfileString()
            }
        } else {
            profileString = appSettings.composeProfileString()
        }
        fileIO.launchNewInstance(profileString,
                                terminalWindow.x + 30,
                                terminalWindow.y + 30)
    }
}
