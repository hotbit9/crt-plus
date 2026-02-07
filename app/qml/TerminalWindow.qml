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
import QtQuick.Window 2.1
import QtQuick.Controls 2.3

import "menus"

ApplicationWindow {
    id: terminalWindow

    width: 1024
    height: 768

    minimumWidth: 320
    minimumHeight: 240

    visible: false

    property string defaultProfileString: ""
    property alias profileSettings: profileSettings
    readonly property int badgeCount: terminalTabs.totalBadgeCount

    ProfileSettings {
        id: profileSettings
    }

    property bool fullscreen: false
    onFullscreenChanged: visibility = (fullscreen ? Window.FullScreen : Window.Windowed)

    menuBar: WindowMenu { }

    property real normalizedWindowScale: 1024 / ((0.5 * width + 0.5 * height))

    color: "#00000000"

    title: (badgeCount > 0 ? "\u25CF " : "") + terminalTabs.currentTitle

    onActiveChanged: {
        if (!terminalTabs._initialized) return
        if (active) {
            appRoot.activeTerminalWindow = terminalWindow
            terminalTabs.loadTabProfile(terminalTabs.currentIndex)
            // Clear badge on the focused pane when window becomes active
            var root = terminalTabs.currentRootSplitPane()
            if (root) {
                var leaf = root.focusedLeaf()
                if (leaf && leaf.paneBadgeCount > 0) {
                    leaf.paneBadgeCount = 0
                    root.badgeCountChanged()
                }
            }
        } else {
            terminalTabs.saveCurrentTabProfile(terminalTabs.currentIndex)
        }
    }

    Timer {
        id: _appSettingsSyncTimer
        interval: 0
        onTriggered: {
            if (appRoot.activeTerminalWindow === terminalWindow && !profileSettings._syncing) {
                profileSettings.syncFromAppSettings()
            }
        }
    }

    Component.onCompleted: {
        var scheduleSync = function() { _appSettingsSyncTimer.restart() }
        var props = [
            "_backgroundColor", "_fontColor", "_frameColor", "flickering",
            "horizontalSync", "staticNoise", "chromaColor", "saturationColor",
            "screenCurvature", "glowingLine", "burnIn", "bloom", "jitter",
            "rgbShift", "brightness", "contrast", "highImpedance", "ambientLight",
            "windowOpacity", "_margin", "_frameSize", "_screenRadius",
            "_frameShininess", "blinkingCursor", "rasterization", "fontSource",
            "fontName", "fontWidth", "lineSpacing", "currentProfileIndex"
        ]
        for (var i = 0; i < props.length; i++) {
            var sig = appSettings[props[i] + "Changed"]
            if (sig) sig.connect(scheduleSync)
        }
        appSettings.profileChanged.connect(scheduleSync)
    }

    Action {
        id: fullscreenAction
        text: qsTr("Fullscreen")
        enabled: !appSettings.isMacOS
        shortcut: StandardKey.FullScreen
        onTriggered: fullscreen = !fullscreen
        checkable: true
        checked: fullscreen
    }
    Action {
        id: minimizeAction
        text: qsTr("Minimize")
        shortcut: appSettings.isMacOS ? "Meta+M" : ""
        onTriggered: terminalWindow.showMinimized()
    }
    Action {
        id: newWindowAction
        text: qsTr("New Window")
        shortcut: appSettings.isMacOS ? "Meta+N" : "Ctrl+Shift+N"
        onTriggered: appRoot.createWindow()
    }
    Action {
        id: quitAction
        text: qsTr("Quit")
        shortcut: appSettings.isMacOS ? StandardKey.Close : "Ctrl+Shift+Q"
        onTriggered: terminalWindow.close()
    }
    Action {
        id: showsettingsAction
        text: qsTr("Settings")
        onTriggered: {
            settingsWindow.show()
            settingsWindow.requestActivate()
            settingsWindow.raise()
        }
    }
    Action {
        id: copyAction
        text: qsTr("Copy")
        shortcut: appSettings.isMacOS ? StandardKey.Copy : "Ctrl+Shift+C"
    }
    Action {
        id: pasteAction
        text: qsTr("Paste")
        shortcut: appSettings.isMacOS ? StandardKey.Paste : "Ctrl+Shift+V"
    }
    Action {
        id: zoomIn
        text: qsTr("Zoom In")
        shortcut: StandardKey.ZoomIn
        onTriggered: appSettings.incrementScaling()
    }
    Action {
        id: zoomOut
        text: qsTr("Zoom Out")
        shortcut: StandardKey.ZoomOut
        onTriggered: appSettings.decrementScaling()
    }
    Action {
        id: showAboutAction
        text: qsTr("About")
        onTriggered: {
            aboutDialog.show()
            aboutDialog.requestActivate()
            aboutDialog.raise()
        }
    }
    Action {
        id: newTabAction
        text: qsTr("New Tab")
        shortcut: appSettings.isMacOS ? StandardKey.AddTab : "Ctrl+Shift+T"
        onTriggered: terminalTabs.addTab()
    }
    Action {
        id: renameTabAction
        text: qsTr("Rename Tab…")
        shortcut: appSettings.isMacOS ? "Meta+R" : "Ctrl+Shift+R"
        onTriggered: terminalTabs.openRenameDialog(terminalTabs.currentIndex)
    }
    Action {
        id: splitHorizontalAction
        text: qsTr("Split Right")
        shortcut: appSettings.isMacOS ? "Meta+D" : "Ctrl+Shift+D"
        onTriggered: {
            var root = terminalTabs.currentRootSplitPane()
            if (root) {
                var leaf = root.focusedLeaf()
                if (leaf) leaf.split(Qt.Horizontal)
            }
        }
    }
    Action {
        id: splitVerticalAction
        text: qsTr("Split Down")
        shortcut: appSettings.isMacOS ? "Meta+Shift+D" : "Ctrl+Shift+E"
        onTriggered: {
            var root = terminalTabs.currentRootSplitPane()
            if (root) {
                var leaf = root.focusedLeaf()
                if (leaf) leaf.split(Qt.Vertical)
            }
        }
    }
    Action {
        id: nextPaneAction
        text: qsTr("Next Pane")
        shortcut: appSettings.isMacOS ? "Meta+]" : "Ctrl+Shift+]"
        onTriggered: {
            var root = terminalTabs.currentRootSplitPane()
            if (root) root.focusNext()
        }
    }
    Action {
        id: previousPaneAction
        text: qsTr("Previous Pane")
        shortcut: appSettings.isMacOS ? "Meta+[" : "Ctrl+Shift+["
        onTriggered: {
            var root = terminalTabs.currentRootSplitPane()
            if (root) root.focusPrevious()
        }
    }
    Action {
        id: closePaneAction
        text: qsTr("Close Pane")
        shortcut: appSettings.isMacOS ? "Meta+Shift+W" : "Ctrl+Shift+W"
        onTriggered: {
            var root = terminalTabs.currentRootSplitPane()
            if (root) root.closeFocusedPane()
        }
    }
    TerminalTabs {
        id: terminalTabs
        width: parent.width
        height: (parent.height + Math.abs(y))
        defaultProfileString: terminalWindow.defaultProfileString
    }
    Loader {
        anchors.centerIn: parent
        active: appSettings.showTerminalSize
        sourceComponent: SizeOverlay {
            z: 3
            terminalSize: terminalTabs.terminalSize
        }
    }
    onClosing: function(close) {
        close.accepted = false
        profileSettings.syncToAppSettings()
        appRoot.closeWindow(terminalWindow)
    }
}
