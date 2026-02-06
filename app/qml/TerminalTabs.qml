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
        return displayTitle(entry.customTitle, entry.title, "CRT Plus")
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

    function displayTitle(customTitle, autoTitle, fallback) {
        if (customTitle && customTitle !== "") {
            if (autoTitle && autoTitle !== "")
                return customTitle + ": " + autoTitle
            return customTitle
        }
        if (autoTitle && autoTitle !== "")
            return autoTitle
        return fallback
    }

    function normalizeTitle(rawTitle) {
        if (rawTitle === undefined || rawTitle === null) {
            return ""
        }
        return String(rawTitle).trim()
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
                profile = appSettings.composeProfileString()
            }
        } else {
            profile = appSettings.composeProfileString()
        }
        tabsModel.append({ title: "", customTitle: "", profileString: profile })
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
        appSettings.loadProfileString(profileString)
        if (tabBar.currentIndex >= 0 && tabBar.currentIndex < tabsModel.count) {
            tabsModel.setProperty(tabBar.currentIndex, "profileString",
                                  appSettings.composeProfileString())
        }
    }

    function saveCurrentTabProfile(index) {
        if (index >= 0 && index < tabsModel.count) {
            tabsModel.setProperty(index, "profileString",
                                  appSettings.composeProfileString())
        }
    }

    function loadTabProfile(index) {
        if (index >= 0 && index < tabsModel.count) {
            var profileString = tabsModel.get(index).profileString
            if (profileString && profileString !== "") {
                _isLoadingTabProfile = true
                appSettings.loadProfileString(profileString)
                _isLoadingTabProfile = false
            }
        }
    }

    Connections {
        target: appSettings
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
                                    text: tabsRoot.displayTitle(model.customTitle, model.title, "CRT Plus")
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
