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
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

Item {
    id: tabsRoot

    readonly property int innerPadding: 6
    readonly property string currentTitle: {
        var entry = tabsModel.get(currentIndex)
        if (!entry) return "CRT Plus"
        return displayTitle(entry.customTitle, entry.title, entry.currentDir)
    }
    property alias currentIndex: tabBar.currentIndex
    readonly property alias tabsModel: tabsModel
    readonly property int count: tabsModel.count
    property size terminalSize: Qt.size(0, 0)

    // Per-tab profile support
    property int _previousIndex: -1
    property bool _initialized: false
    property bool _isLoadingTabProfile: false
    property string defaultProfileString: ""

    property string _homeDir: typeof homeDir !== "undefined" ? homeDir : ""

    function shortDir(path) {
        if (!path || path === "") return ""
        if (_homeDir !== "") {
            if (path === _homeDir)
                return "~"
            if (path.indexOf(_homeDir + "/") === 0)
                return "~/" + path.substring(_homeDir.length + 1)
        }
        return path
    }

    function displayTitle(customTitle, autoTitle, currentDir) {
        var dir = shortDir(currentDir)
        if (customTitle && customTitle !== "") {
            var suffix = autoTitle && autoTitle !== "" ? ": " + autoTitle : ""
            if (dir !== "")
                return customTitle + " (" + dir + ")" + suffix
            return customTitle + suffix
        }
        if (autoTitle && autoTitle !== "") {
            if (dir !== "")
                return dir + ": " + autoTitle
            return autoTitle
        }
        if (dir !== "")
            return dir
        return "CRT Plus"
    }

    function normalizeTitle(rawTitle) {
        if (rawTitle === undefined || rawTitle === null) {
            return ""
        }
        return String(rawTitle).trim()
    }

    readonly property var _shells: ["zsh", "bash", "fish", "sh", "tcsh", "csh", "ksh", "dash", "login"]
    function isShellProcess(name) {
        return _shells.indexOf(name) !== -1
    }

    function addTab() {
        var profile
        if (defaultProfileString !== "") {
            profile = defaultProfileString
        } else if (appSettings.defaultProfileName !== "") {
            var defaultIndex = appSettings.getProfileIndexByName(appSettings.defaultProfileName)
            if (defaultIndex !== -1) {
                profile = appSettings.profilesList.get(defaultIndex).obj_string
            } else {
                profile = terminalWindow.profileSettings.composeProfileString()
            }
        } else {
            profile = terminalWindow.profileSettings.composeProfileString()
        }
        tabsModel.append({ title: "", customTitle: "", currentDir: "",
                           profileString: profile,
                           profileIndex: terminalWindow.profileSettings.currentProfileIndex })
        tabBar.currentIndex = tabsModel.count - 1
    }

    function closeTab(index) {
        if (tabsModel.count <= 1) {
            terminalWindow.close()
            return
        }

        var wasCurrent = (index === tabBar.currentIndex)

        tabsModel.remove(index)

        var newIndex = Math.min(tabBar.currentIndex, tabsModel.count - 1)
        tabBar.currentIndex = newIndex
        _previousIndex = newIndex

        if (wasCurrent) {
            loadTabProfile(newIndex)
        }
    }

    // Load a profile into the current tab (used by context/window menu)
    function loadProfileForCurrentTab(profileString) {
        _isLoadingTabProfile = true
        terminalWindow.profileSettings.loadFromString(profileString)
        if (appRoot.activeTerminalWindow === terminalWindow) {
            terminalWindow.profileSettings.syncToAppSettings()
        }
        _isLoadingTabProfile = false
        if (tabBar.currentIndex >= 0 && tabBar.currentIndex < tabsModel.count) {
            tabsModel.setProperty(tabBar.currentIndex, "profileString",
                                  terminalWindow.profileSettings.composeProfileString())
            tabsModel.setProperty(tabBar.currentIndex, "profileIndex",
                                  terminalWindow.profileSettings.currentProfileIndex)
        }
    }

    function saveCurrentTabProfile(index) {
        if (index >= 0 && index < tabsModel.count) {
            tabsModel.setProperty(index, "profileString",
                                  terminalWindow.profileSettings.composeProfileString())
            tabsModel.setProperty(index, "profileIndex",
                                  terminalWindow.profileSettings.currentProfileIndex)
        }
    }

    function loadTabProfile(index) {
        if (index >= 0 && index < tabsModel.count) {
            var entry = tabsModel.get(index)
            if (entry.profileString && entry.profileString !== "") {
                _isLoadingTabProfile = true
                terminalWindow.profileSettings.loadFromString(entry.profileString)
                terminalWindow.profileSettings.currentProfileIndex = entry.profileIndex
                if (appRoot.activeTerminalWindow === terminalWindow) {
                    terminalWindow.profileSettings.syncToAppSettings()
                }
                _isLoadingTabProfile = false
            }
        }
    }

    Connections {
        target: terminalWindow.profileSettings
        function onProfileChanged() {
            if (tabsRoot._initialized && !tabsRoot._isLoadingTabProfile
                && tabBar.currentIndex >= 0 && tabBar.currentIndex < tabsModel.count) {
                tabsRoot.saveCurrentTabProfile(tabBar.currentIndex)
            }
        }
    }

    ListModel {
        id: tabsModel
    }

    property int _renameTabIndex: -1

    function resetCustomTitle(tabIndex) {
        if (tabIndex >= 0 && tabIndex < tabsModel.count) {
            tabsModel.setProperty(tabIndex, "customTitle", "")
        }
    }

    function openRenameDialog(tabIndex) {
        _renameTabIndex = tabIndex
        var entry = tabsModel.get(tabIndex)
        renameField.text = entry.customTitle !== "" ? entry.customTitle : entry.title
        renameDialog.open()
        renameField.selectAll()
        renameField.forceActiveFocus()
    }

    Dialog {
        id: renameDialog
        title: qsTr("Rename Tab")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (_renameTabIndex >= 0 && _renameTabIndex < tabsModel.count) {
                tabsModel.setProperty(_renameTabIndex, "customTitle", renameField.text.trim())
            }
        }
        RowLayout {
            anchors.fill: parent
            Label { text: qsTr("Name:") }
            TextField {
                id: renameField
                Layout.fillWidth: true
                onAccepted: renameDialog.accept()
            }
        }
    }

    Component.onCompleted: {
        addTab()
        _previousIndex = 0
        _initialized = true
        terminalWindow.profileSettings.currentProfileIndex = appSettings.currentProfileIndex
        loadTabProfile(0)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: tabRow
            Layout.fillWidth: true
            height: rowLayout.implicitHeight
            color: palette.window
            visible: tabsModel.count > 1

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                spacing: 0

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focusPolicy: Qt.NoFocus

                    onCurrentIndexChanged: {
                        if (!tabsRoot._initialized) return

                        // Save outgoing tab's profile
                        if (tabsRoot._previousIndex >= 0
                            && tabsRoot._previousIndex < tabsModel.count
                            && tabsRoot._previousIndex !== currentIndex) {
                            tabsRoot.saveCurrentTabProfile(tabsRoot._previousIndex)
                        }

                        // Load incoming tab's profile
                        if (currentIndex >= 0 && currentIndex < tabsModel.count) {
                            tabsRoot.loadTabProfile(currentIndex)
                        }

                        tabsRoot._previousIndex = currentIndex
                    }

                    Repeater {
                        model: tabsModel
                        TabButton {
                            id: tabButton
                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors { leftMargin: innerPadding; rightMargin: innerPadding }
                                spacing: innerPadding

                                Label {
                                    text: tabsRoot.displayTitle(model.customTitle, model.title, model.currentDir)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ToolButton {
                                    text: "\u00d7"
                                    focusPolicy: Qt.NoFocus
                                    padding: innerPadding
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: tabsRoot.closeTab(index)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: {
                                    tabContextMenu.tabIndex = index
                                    tabContextMenu.hasCustomTitle = (model.customTitle !== "")
                                    tabContextMenu.popup()
                                }
                            }
                        }
                    }

                    Menu {
                        id: tabContextMenu
                        property int tabIndex: -1
                        property bool hasCustomTitle: false
                        MenuItem {
                            text: qsTr("Rename Tab…")
                            onTriggered: tabsRoot.openRenameDialog(tabContextMenu.tabIndex)
                        }
                        MenuItem {
                            text: qsTr("Reset Name")
                            visible: tabContextMenu.hasCustomTitle
                            height: visible ? implicitHeight : 0
                            onTriggered: tabsRoot.resetCustomTitle(tabContextMenu.tabIndex)
                        }
                    }
                }

                ToolButton {
                    id: addTabButton
                    text: "+"
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: tabsRoot.addTab()
                }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Repeater {
                model: tabsModel
                TerminalContainer {
                    property bool shouldHaveFocus: terminalWindow.active && StackLayout.isCurrentItem
                    onShouldHaveFocusChanged: {
                        if (shouldHaveFocus) {
                            activate()
                        }
                    }
                    onTitleChanged: tabsModel.setProperty(index, "title", normalizeTitle(title))
                    onCurrentDirChanged: tabsModel.setProperty(index, "currentDir", currentDir || "")
                    onForegroundProcessChanged: {
                        if (isShellProcess(foregroundProcessName))
                            tabsModel.setProperty(index, "title", "")
                    }
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onSessionFinished: tabsRoot.closeTab(index)
                    onTerminalSizeChanged: updateTerminalSize()

                    function updateTerminalSize() {
                        // Every tab will have the same size so we can simply take the first one.
                        if (index == 0) {
                            tabsRoot.terminalSize = terminalSize
                        }
                    }
                }
            }
        }
    }
}
