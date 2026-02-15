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
    property real _launchTime: Date.now()
    property bool _isQuitting: false

    // On cold launch, replace the default tab with one at the requested folder.
    function _replaceFreshWindow(workDir) {
        var justLaunched = (Date.now() - _launchTime) < 5000
        if (justLaunched && windows.length === 1 && windows[0].tabCount === 1) {
            windows[0].replaceFirstTab(workDir)
            return true
        }
        return false
    }

    property var _savedState: null

    property ApplicationSettings appSettings: ApplicationSettings {
        onInitializedSettings: _tryRestore()
    }

    function _defaultProfile() {
        if (appSettings.defaultProfileName !== "") {
            var defaultIndex = appSettings.getProfileIndexByName(appSettings.defaultProfileName)
            if (defaultIndex !== -1)
                return appSettings.profilesList.get(defaultIndex).obj_string
            return appSettings.composeProfileString()
        }
        return ""
    }

    function _startFresh() {
        _savedState = null
        createWindow(_defaultProfile())
    }

    function _tryRestore() {
        // Skip restore when launched with -e (explicit command) or --workdir
        var args = Qt.application.arguments
        if (args.indexOf("-e") >= 0 || args.indexOf("--workdir") >= 0) {
            _startFresh()
            return
        }

        var stateJson = appSettings.storage.getSetting("_SESSION_STATE")
        if (!stateJson) { _startFresh(); return }

        try { _savedState = JSON.parse(stateJson) } catch(e) { _startFresh(); return }
        if (!_savedState.windows || _savedState.windows.length === 0) { _startFresh(); return }

        if (appSettings.autoRestoreSessions) {
            _performRestore()
        } else {
            // Query daemon for alive sessions to decide whether to show dialog
            sessionManager.queryDaemonSessions()
        }
    }

    function _performRestore() {
        var state = _savedState; _savedState = null
        appSettings.storage.setSetting("_SESSION_STATE", "")
        for (var w = 0; w < state.windows.length; w++)
            _restoreWindow(state.windows[w])
    }

    function _restoreWindow(winState) {
        var win = windowComponent.createObject(appRoot, {
            "defaultProfileString": winState.defaultProfileString || "",
            "_restoreMode": true
        })
        if (winState.geometry) {
            win.x = winState.geometry.x; win.y = winState.geometry.y
            win.width = winState.geometry.width; win.height = winState.geometry.height
        }
        if (winState.fullscreen) win.fullscreen = true
        win.badgeCountChanged.connect(_updateDockBadge)
        windows = windows.concat([win])
        win.visible = true
        Qt.callLater(function() {
            win.restoreTabs(winState.tabs, winState.activeTabIndex, winState.customWindowTitle)
        })
    }

    function _discardAndStartFresh() {
        // Destroy orphan daemon sessions from the saved state
        if (_savedState && _savedState.windows) {
            for (var w = 0; w < _savedState.windows.length; w++) {
                var tabs = _savedState.windows[w].tabs
                if (!tabs) continue
                for (var t = 0; t < tabs.length; t++) {
                    _destroySplitTreeSessions(tabs[t].splitTree)
                }
            }
        }
        _startFresh()
    }

    function _destroySplitTreeSessions(tree) {
        if (!tree) return
        if (tree.type === "leaf") {
            if (tree.sessionId && tree.sessionId !== "")
                sessionManager.destroyDaemonSession(tree.sessionId)
        } else {
            _destroySplitTreeSessions(tree.child1)
            _destroySplitTreeSessions(tree.child2)
        }
    }

    property TimeManager timeManager: TimeManager {
        enableTimer: true
    }

    // Periodic save for crash protection
    property Timer _periodicSaveTimer: Timer {
        interval: 60000; repeat: true
        running: windows.length > 0
        onTriggered: saveSessionState()
    }

    property Connections _sessionManagerConn: Connections {
        target: sessionManager
        function onSessionsListed(sessions) {
            if (!_savedState) return
            var aliveCount = 0
            for (var i = 0; i < sessions.length; i++) {
                if (sessions[i].alive && !sessions[i].hasClient)
                    aliveCount++
            }
            if (aliveCount > 0) {
                _showRestoreDialog()
            } else {
                // No alive sessions — restore layout with fresh shells
                _performRestore()
            }
        }
    }

    function _showRestoreDialog() {
        var totalTabs = 0
        for (var w = 0; w < _savedState.windows.length; w++) {
            totalTabs += _savedState.windows[w].tabs ? _savedState.windows[w].tabs.length : 0
        }
        restoreDialogLoader.active = true
        restoreDialogLoader.item.windowCount = _savedState.windows.length
        restoreDialogLoader.item.tabCount = totalTabs
        restoreDialogLoader.item.show()
    }

    property Loader restoreDialogLoader: Loader {
        active: false
        sourceComponent: RestoreSessionDialog {
            onRestoreRequested: {
                restoreDialogLoader.active = false
                _performRestore()
            }
            onDiscardRequested: {
                restoreDialogLoader.active = false
                _discardAndStartFresh()
            }
            onAlwaysRestoreRequested: {
                appSettings.autoRestoreSessions = true
                restoreDialogLoader.active = false
                _performRestore()
            }
        }
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

    function _updateDockBadge() {
        var total = 0
        for (var i = 0; i < windows.length; i++)
            total += windows[i].badgeCount
        if (typeof badgeHelper !== "undefined")
            badgeHelper.updateBadge(total)
    }

    function getProfileList() {
        var result = []
        for (var i = 0; i < appSettings.profilesList.count; i++) {
            var p = appSettings.profilesList.get(i)
            if (p.obj_string !== "")
                result.push({"name": p.text, "profileString": p.obj_string})
        }
        return result
    }

    function createWindow(profileString, workDir) {
        var props = {}
        if (profileString && profileString !== "")
            props.defaultProfileString = profileString
        if (workDir && workDir !== "")
            props.initialWorkDir = workDir
        var win = windowComponent.createObject(appRoot, props)

        // Cascade position from the last window
        if (windows.length > 0) {
            var lastWin = windows[windows.length - 1]
            win.x = lastWin.x + 30
            win.y = lastWin.y + 30
        }

        win.badgeCountChanged.connect(_updateDockBadge)
        windows = windows.concat([win])
        win.visible = true
    }

    // Split the focused pane in the active window.
    // Called from the macOS dock menu; orientation is Qt.Vertical or Qt.Horizontal.
    function splitFocusedPane(orientation) {
        if (!activeTerminalWindow) return
        activeTerminalWindow.splitFocusedPane(orientation)
    }

    function renameActiveWindow() {
        if (!activeTerminalWindow) return
        activeTerminalWindow.renameWindow()
    }

    function resetActiveWindowTitle() {
        if (!activeTerminalWindow) return
        activeTerminalWindow.resetWindowTitle()
    }

    // Called from Finder Services: "New CRT Plus at Folder"
    function createWindowAtFolder(workDir) {
        if (!_replaceFreshWindow(workDir))
            createWindow("", workDir)
    }

    // Called from Finder Services: "New CRT Plus Tab at Folder"
    function createTabInActiveWindow(workDir) {
        if (_replaceFreshWindow(workDir))
            return

        var target = activeTerminalWindow
        if (!target && windows.length > 0)
            target = windows[windows.length - 1]

        if (target) {
            target.addTabWithWorkDir(workDir)
        } else {
            createWindow("", workDir)
        }
    }

    function activeWindowHasTabs() {
        if (!activeTerminalWindow) return false
        return activeTerminalWindow.tabCount > 1
    }

    function activeWindowHasCustomTitle() {
        if (!activeTerminalWindow) return false
        return activeTerminalWindow.customWindowTitle !== ""
    }

    function captureAllState() {
        var state = {"version": 1, "timestamp": Date.now(), "windows": []}
        for (var i = 0; i < windows.length; i++)
            state.windows.push(windows[i].captureWindowState())
        return state
    }

    // Called by C++ aboutToQuit signal and by closeWindow() for last window.
    // Does NOT set _isQuitting — that's done by markQuitting().
    function saveSessionState() {
        if (windows.length === 0) return
        var state = captureAllState()
        appSettings.storage.setSetting("_SESSION_STATE", JSON.stringify(state))
    }

    // Called from C++ AppEventFilter on QEvent::Quit.
    function markQuitting() {
        _isQuitting = true
        saveSessionState()
    }

    function closeWindow(window) {
        var idx = windows.indexOf(window)
        if (idx === -1) return

        if (!_isQuitting) {
            if (windows.length === 1) {
                // Last window: save state and let sessions survive (DETACH via
                // destructor). On relaunch, sessions will be reattached with
                // scrollback, or start fresh if daemon timed them out.
                saveSessionState()
            } else {
                window.destroyAllSessions()
            }
        }

        window.badgeCountChanged.disconnect(_updateDockBadge)

        var newList = windows.slice()
        newList.splice(idx, 1)
        windows = newList

        window.destroy()

        _updateDockBadge()

        if (windows.length === 0) {
            appSettings.close()
        } else {
            // Activate a surviving window so macOS picks up its menu bar
            var survivor = windows[Math.min(idx, windows.length - 1)]
            survivor.raise()
            survivor.requestActivate()
        }
    }
}
