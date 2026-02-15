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

    property string customWindowTitle: ""
    // When multiple tabs are open, each tab label shows its own title,
    // so the window title stays static to avoid duplication.
    readonly property string currentTitle: {
        if (tabsModel.count > 1) return customWindowTitle || "CRT Plus"
        var entry = tabsModel.get(currentIndex)
        if (!entry) return "CRT Plus"
        return displayTitle(entry.customTitle, entry.title, entry.currentDir, entry.foregroundProcess, entry.foregroundProcessLabel)
    }
    property alias currentIndex: tabBar.currentIndex
    readonly property alias tabsModel: tabsModel
    readonly property int count: tabsModel.count
    property size terminalSize: Qt.size(0, 0)
    property int totalBadgeCount: 0

    function _updateTotalBadge() {
        var total = 0
        for (var i = 0; i < tabsModel.count; i++)
            total += tabsModel.get(i).badgeCount
        totalBadgeCount = total
    }

    function currentRootSplitPane() {
        return tabRepeater.itemAt(tabBar.currentIndex)
    }

    // Per-tab profile support
    property int _previousIndex: -1
    property bool _initialized: false
    property bool _isLoadingTabProfile: false
    property string defaultProfileString: ""
    property string _initialWorkDir: ""

    // Drag-to-reorder state.
    // _dragActive stays true through tabsModel.move() so onCurrentIndexChanged
    // skips profile save/load during reorder. _dragAnimating gates Behavior
    // animations — disabled before the move so transforms snap to 0 instantly.
    property bool _dragActive: false
    property bool _dragAnimating: false
    property int _dragSourceIndex: -1
    property int _dragSlot: -1       // insertion slot (0..count), not final index
    property real _dragGhostX: 0
    property real _dragTabWidth: 0
    property string _dragTabTitle: ""

    // Dark mode: use ITU-R BT.601 luminance of the window background
    readonly property bool _isDark: (palette.window.r * 0.299 + palette.window.g * 0.587 + palette.window.b * 0.114) < 0.5

    // Tab bar theme (macOS Terminal style)
    readonly property color _tabContainerColor: _isDark ? "#494C48" : "#E5E5E5"
    readonly property color _tabActiveColor:    _isDark ? "#616460" : "#FFFFFF"
    readonly property color _tabHoverColor:     _isDark ? "#525551" : "#DBDBDB"
    readonly property color _tabTextColor:      _isDark ? "#E0E0E0" : "#333333"
    readonly property color _tabCloseColor:     _isDark ? "#AAAAAA" : "#666666"
    readonly property color _tabSeparatorColor: _isDark ? "#3A3C38" : "#D0D0D0"
    readonly property color _addBtnColor:       _isDark ? "#1A1C19" : "#E5E5E5"
    readonly property color _addBtnHoverColor:  _isDark ? "#2A2C28" : "#DBDBDB"
    readonly property color _addBtnShadowColor: _isDark ? "#101210" : "#D5D5D5"
    readonly property color _addBtnTextColor:   _isDark ? "#AAAAAA" : "#555555"

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

    // Build display title from tab state. Title format depends on context:
    //   Local:  dir | dir : appTitle | CustomName — dir [appTitle]
    //   Remote: user@host | user@host: remoteTitle | CustomName — user@host: remoteTitle
    // autoTitle is suppressed at shell prompts to avoid showing stale values from
    // a previous program (the terminal session retains the last escape-sequence title
    // even after the program exits, so onTitleChanged won't re-fire for the same value).
    function displayTitle(customTitle, autoTitle, currentDir, fgProcess, fgLabel) {
        var remote = isRemoteProcess(fgProcess)
        var shell = isShellProcess(fgProcess)
        var label = (fgLabel && fgLabel !== "") ? fgLabel : fgProcess
        var dir = remote ? "" : shortDir(currentDir)
        var title = (shell || !autoTitle) ? "" : autoTitle
        if (customTitle && customTitle !== "") {
            if (remote && title !== "")
                return customTitle + " \u2014 " + remoteTitle(label, title)
            if (remote)
                return customTitle + " \u2014 " + label
            var suffix = title !== "" ? " [" + title + "]" : ""
            if (dir !== "")
                return customTitle + " \u2014 " + dir + suffix
            return customTitle + suffix
        }
        if (remote) {
            if (title !== "")
                return remoteTitle(label, title)
            return label
        }
        if (title !== "") {
            if (dir !== "")
                return dir + " : " + title
            return title
        }
        if (dir !== "")
            return dir
        return "CRT Plus"
    }

    function remoteTitle(label, autoTitle) {
        // If autoTitle already contains the SSH label (e.g. shell set
        // "user@host: ~/path"), use it as-is to avoid redundancy.
        // Otherwise prefix with the label (e.g. "user@host: Claude Code").
        if (autoTitle.indexOf(label) !== -1)
            return autoTitle
        return label + ": " + autoTitle
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

    // Remote processes: hide stale local currentDir, use escape-sequence title instead
    readonly property var _remoteProcesses: ["ssh", "mosh", "telnet", "rlogin"]
    function isRemoteProcess(name) {
        return _remoteProcesses.indexOf(name) !== -1
    }

    // Capture source tab state and enter drag mode.
    function _startDrag(sourceIndex) {
        _dragSourceIndex = sourceIndex
        _dragSlot = sourceIndex
        var item = tabButtonRepeater.itemAt(sourceIndex)
        _dragTabWidth = item ? item.width : 100
        var entry = tabsModel.get(sourceIndex)
        _dragTabTitle = (entry.badgeCount > 0 ? "\u25CF " : "")
            + displayTitle(entry.customTitle, entry.title, entry.currentDir,
                           entry.foregroundProcess, entry.foregroundProcessLabel)
        tabBar.currentIndex = sourceIndex
        _dragAnimating = true
        _dragActive = true
    }

    // Position ghost and find insertion slot by comparing mouse X to tab midpoints.
    function _updateDrag(tabBarX) {
        var ghostPos = tabBar.mapToItem(tabRow, tabBarX - _dragTabWidth / 2, 0)
        _dragGhostX = Math.max(0, Math.min(ghostPos.x, tabRow.width - _dragTabWidth))

        var slot = tabsModel.count
        for (var i = 0; i < tabsModel.count; i++) {
            var item = tabButtonRepeater.itemAt(i)
            if (!item) continue
            if (tabBarX < item.x + item.width / 2) {
                slot = i
                break
            }
        }
        _dragSlot = slot
    }

    // Commit the reorder. Slot is an insertion point (0..count), so dropping
    // at slot == source or source+1 is a no-op (same position). For forward
    // moves (slot > source), subtract 1 because removing the source shifts
    // subsequent indices left.
    function _endDrag() {
        var from = _dragSourceIndex
        var slot = _dragSlot

        _dragAnimating = false
        _dragSourceIndex = -1
        _dragSlot = -1

        if (slot === from || slot === from + 1) {
            _dragActive = false
            return
        }

        var to = (slot > from) ? slot - 1 : slot
        tabsModel.move(from, to, 1)
        tabBar.currentIndex = to
        _previousIndex = to
        _dragActive = false
    }

    function addTabWithWorkDir(workDir) {
        _initialWorkDir = workDir || ""
        addTab()
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
        var wd = _initialWorkDir
        _initialWorkDir = ""
        tabsModel.append({ title: "", customTitle: "", currentDir: "",
                           foregroundProcess: "", foregroundProcessLabel: "",
                           badgeCount: 0, initialWorkDir: wd,
                           profileString: profile,
                           profileIndex: terminalWindow.profileSettings.currentProfileIndex })
        tabBar.currentIndex = tabsModel.count - 1
    }

    function replaceFirstTab(workDir) {
        addTabWithWorkDir(workDir)
        tabsModel.remove(0)
        tabBar.currentIndex = 0
        _previousIndex = 0
        loadTabProfile(0)
    }

    // Explicitly DESTROY all daemon sessions across all tabs
    function destroyAllSessions() {
        for (var i = 0; i < tabsModel.count; i++) {
            var rootPane = tabRepeater.itemAt(i)
            if (rootPane) rootPane.destroyAllSessions()
        }
    }

    // Capture full tab state for session persistence
    function captureState() {
        var tabs = []
        for (var i = 0; i < tabsModel.count; i++) {
            var entry = tabsModel.get(i)
            var rootPane = tabRepeater.itemAt(i)
            tabs.push({
                "customTitle": entry.customTitle || "",
                "profileString": entry.profileString || "",
                "profileIndex": entry.profileIndex || 0,
                "splitTree": rootPane ? rootPane.captureSplitTree() : null
            })
        }
        return {
            "activeTabIndex": currentIndex,
            "customWindowTitle": customWindowTitle,
            "tabs": tabs
        }
    }

    function closeTab(index) {
        if (tabsModel.count <= 1) {
            terminalWindow.close()
            return
        }

        var wasCurrent = (index === tabBar.currentIndex)

        // DESTROY daemon sessions for the closing tab
        var rootPane = tabRepeater.itemAt(index)
        if (rootPane) rootPane.destroyAllSessions()

        tabsModel.remove(index)

        var newIndex = Math.min(tabBar.currentIndex, tabsModel.count - 1)
        tabBar.currentIndex = newIndex
        _previousIndex = newIndex

        if (wasCurrent) {
            loadTabProfile(newIndex)
        }
    }

    // Load a profile into the current tab's focused pane (used by context/window menu)
    property var _pendingRestore: null

    function restoreTabs(tabs, activeTabIndex, windowTitle) {
        customWindowTitle = windowTitle || ""

        // Stage 1: Append all tabs to the model (synchronous — Repeater creates items)
        for (var i = 0; i < tabs.length; i++) {
            var profile = tabs[i].profileString || defaultProfileString
            tabsModel.append({
                title: "", customTitle: tabs[i].customTitle || "",
                currentDir: "", foregroundProcess: "", foregroundProcessLabel: "",
                badgeCount: 0, initialWorkDir: "",
                profileString: profile, profileIndex: tabs[i].profileIndex || 0
            })
        }

        // Stage 2: Defer split tree restoration to next event loop (items exist now)
        _pendingRestore = {tabs: tabs, activeTabIndex: activeTabIndex}
        _restoreTimer.start()
    }

    Timer {
        id: _restoreTimer
        interval: 0; repeat: false
        onTriggered: {
            if (!_pendingRestore) return
            var data = _pendingRestore
            _pendingRestore = null

            // Restore split trees for all tabs
            for (var i = 0; i < data.tabs.length; i++) {
                var splitTree = data.tabs[i].splitTree
                if (splitTree) {
                    var rootPane = tabRepeater.itemAt(i)
                    if (rootPane) rootPane.restoreFromTree(splitTree)
                }
            }

            // Stage 3: Finalize — set active tab, clear restore mode
            if (data.activeTabIndex >= 0 && data.activeTabIndex < tabsModel.count)
                tabBar.currentIndex = data.activeTabIndex
            _previousIndex = tabBar.currentIndex
            terminalWindow._restoreMode = false
            loadTabProfile(tabBar.currentIndex)
        }
    }

    function loadProfileForCurrentTab(profileString) {
        _isLoadingTabProfile = true
        terminalWindow.profileSettings.loadFromString(profileString)
        // Apply to the focused pane
        var root = currentRootSplitPane()
        if (root) {
            var leaf = root.focusedLeaf()
            if (leaf && leaf.paneProfileSettings) {
                leaf.paneProfileSettings.loadFromString(profileString)
                leaf.paneProfileSettings.currentProfileIndex =
                    terminalWindow.profileSettings.currentProfileIndex
            }
        }
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
        if (index < 0 || index >= tabsModel.count) return
        var entry = tabsModel.get(index)
        if (!entry.profileString || entry.profileString === "") return

        _isLoadingTabProfile = true
        terminalWindow.profileSettings.loadFromString(entry.profileString)
        terminalWindow.profileSettings.currentProfileIndex = entry.profileIndex

        // Push to the focused pane (ensures initial load sets the saved profile)
        var root = tabRepeater.itemAt(index)
        if (root) {
            var leaf = root.focusedLeaf()
            if (leaf && leaf.paneProfileSettings) {
                leaf.paneProfileSettings.loadFromString(entry.profileString)
                leaf.paneProfileSettings.currentProfileIndex = entry.profileIndex
            }
        }

        if (appRoot.activeTerminalWindow === terminalWindow)
            terminalWindow.profileSettings.syncToAppSettings()
        _isLoadingTabProfile = false
    }

    Connections {
        target: terminalWindow.profileSettings
        function onProfileChanged() {
            if (!tabsRoot._initialized) return
            var idx = tabBar.currentIndex
            if (idx < 0 || idx >= tabsModel.count) return

            if (!tabsRoot._isLoadingTabProfile) {
                tabsRoot.saveCurrentTabProfile(idx)
                // Propagate settings/menu changes to the focused pane
                var root = currentRootSplitPane()
                if (root && !root._syncingPaneProfile) {
                    var leaf = root.focusedLeaf()
                    if (leaf && leaf._alive && leaf.paneProfileSettings
                            && typeof leaf.paneProfileSettings.loadFromString === "function") {
                        leaf.paneProfileSettings.loadFromString(
                            terminalWindow.profileSettings.composeProfileString())
                        leaf.paneProfileSettings.currentProfileIndex =
                            terminalWindow.profileSettings.currentProfileIndex
                    }
                }
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

    function openRenameWindowDialog() {
        renameWindowField.text = customWindowTitle || "CRT Plus"
        renameWindowDialog.open()
        renameWindowField.selectAll()
        renameWindowField.forceActiveFocus()
    }

    function resetWindowTitle() {
        customWindowTitle = ""
    }

    Dialog {
        id: renameWindowDialog
        title: qsTr("Rename Window")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            customWindowTitle = renameWindowField.text.trim()
        }
        RowLayout {
            anchors.fill: parent
            Label { text: qsTr("Name:") }
            TextField {
                id: renameWindowField
                Layout.fillWidth: true
                onAccepted: renameWindowDialog.accept()
            }
        }
    }

    Component.onCompleted: {
        terminalWindow.profileSettings.currentProfileIndex = appSettings.currentProfileIndex
        _initialWorkDir = terminalWindow.initialWorkDir
        if (!terminalWindow._restoreMode) {
            addTab()
            _previousIndex = 0
            _initialized = true
            loadTabProfile(0)
        } else {
            _initialized = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab bar area (macOS Terminal style).
        // Structure: tabRow > rowLayout > [tabContainer > TabBar, addTabButton]
        // The tabContainer is a pill-shaped rounded Rectangle; clip: true
        // gives the tab strip rounded ends. Ghost tab is a sibling of
        // rowLayout so it floats above everything (z: 100).
        Item {
            id: tabRow
            Layout.fillWidth: true
            Layout.preferredHeight: rowLayout.implicitHeight + 10
            visible: tabsModel.count > 1

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Rectangle {
                    id: tabContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: tabBar.implicitHeight
                    radius: height / 2
                    color: tabsRoot._tabContainerColor
                    clip: true

                    TabBar {
                        id: tabBar
                        anchors.fill: parent
                        focusPolicy: Qt.NoFocus
                        clip: true
                        spacing: 0
                        background: Item {}

                    onCurrentIndexChanged: {
                        if (!tabsRoot._initialized) return
                        // Skip profile save/load during drag reorder —
                        // tabsModel.move() triggers intermediate index changes.
                        if (tabsRoot._dragActive) return

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
                        id: tabButtonRepeater
                        model: tabsModel
                        TabButton {
                            id: tabButton
                            // Source tab is invisible during drag; neighbors see it shift away
                            opacity: (tabsRoot._dragActive && tabsRoot._dragSourceIndex === index) ? 0.0 : 1.0
                            Behavior on opacity {
                                enabled: tabsRoot._dragAnimating
                                NumberAnimation { duration: 150 }
                            }
                            // Shift neighbors to open a gap at the drop slot.
                            // Dragging left: tabs in [slot, source) shift RIGHT to make room.
                            // Dragging right: tabs in (source, slot) shift LEFT to fill the gap.
                            transform: Translate {
                                x: {
                                    if (!tabsRoot._dragActive) return 0
                                    var src = tabsRoot._dragSourceIndex
                                    var slot = tabsRoot._dragSlot
                                    if (index === src) return 0
                                    if (slot < src && index >= slot && index < src)
                                        return tabsRoot._dragTabWidth
                                    if (slot > src + 1 && index > src && index < slot)
                                        return -tabsRoot._dragTabWidth
                                    return 0
                                }
                                Behavior on x {
                                    enabled: tabsRoot._dragAnimating
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                            topPadding: 6
                            bottomPadding: 6
                            leftPadding: 12
                            rightPadding: 4
                            // Pill background inset via margins so it never
                            // touches the tabContainer's clip boundary.
                            background: Item {
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 3
                                    anchors.bottomMargin: 3
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 2
                                    radius: height / 2
                                    color: tabButton.checked ? tabsRoot._tabActiveColor
                                         : tabDragArea.containsMouse && !tabsRoot._dragActive
                                           ? tabsRoot._tabHoverColor : "transparent"
                                }
                            }
                            contentItem: RowLayout {
                                spacing: 4

                                Label {
                                    text: (model.badgeCount > 0 ? "\u25CF " : "") + tabsRoot.displayTitle(model.customTitle, model.title, model.currentDir, model.foregroundProcess, model.foregroundProcessLabel)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    color: tabsRoot._tabTextColor
                                }

                                ToolButton {
                                    id: closeBtn
                                    focusPolicy: Qt.NoFocus
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    padding: 0
                                    background: Item {}
                                    Layout.alignment: Qt.AlignVCenter
                                    contentItem: Label {
                                        text: "\u00d7"
                                        color: tabsRoot._tabCloseColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Separator between inactive tabs
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: parent.height * 0.5
                                color: tabsRoot._tabSeparatorColor
                                visible: !tabButton.checked
                                         && index < tabsModel.count - 1
                                         && (index + 1) !== tabBar.currentIndex
                                         && !tabsRoot._dragActive
                            }

                            // Unified mouse handler: left-drag reorders tabs,
                            // left-click switches or closes, right-click opens context menu.
                            MouseArea {
                                id: tabDragArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: tabsRoot._dragActive && tabsRoot._dragSourceIndex === index
                                             ? Qt.ClosedHandCursor : Qt.ArrowCursor

                                property point _pressPos: Qt.point(0, 0)
                                property bool _dragging: false

                                function _isOverCloseBtn(localX, localY) {
                                    var cp = closeBtn.mapFromItem(tabDragArea, localX, localY)
                                    return cp.x >= 0 && cp.x <= closeBtn.width
                                        && cp.y >= 0 && cp.y <= closeBtn.height
                                }

                                onPressed: function(mouse) {
                                    if (mouse.button === Qt.RightButton) return
                                    _pressPos = Qt.point(mouse.x, mouse.y)
                                    _dragging = false
                                }

                                onPositionChanged: function(mouse) {
                                    if (!(mouse.buttons & Qt.LeftButton)) return
                                    if (!_dragging) {
                                        if (Math.abs(mouse.x - _pressPos.x) > 10) {
                                            if (_isOverCloseBtn(_pressPos.x, _pressPos.y))
                                                return
                                            _dragging = true
                                            tabsRoot._startDrag(index)
                                        }
                                    }
                                    if (_dragging) {
                                        var tbPos = tabDragArea.mapToItem(tabBar, mouse.x, 0)
                                        tabsRoot._updateDrag(tbPos.x)
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (mouse.button === Qt.RightButton) return
                                    if (_dragging) {
                                        tabsRoot._endDrag()
                                        _dragging = false
                                    } else if (_isOverCloseBtn(mouse.x, mouse.y)) {
                                        tabsRoot.closeTab(index)
                                    } else {
                                        tabBar.currentIndex = index
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        tabContextMenu.tabIndex = index
                                        tabContextMenu.hasCustomTitle = (model.customTitle !== "")
                                        tabContextMenu.popup()
                                    }
                                }
                            }
                        }
                    }

                    Menu {
                        id: tabContextMenu
                        property int tabIndex: -1
                        property bool hasCustomTitle: false
                        MenuItem {
                            text: qsTr("Close Tab")
                            onTriggered: tabsRoot.closeTab(tabContextMenu.tabIndex)
                        }
                        MenuSeparator { }
                        MenuItem {
                            text: qsTr("Rename Tab…")
                            onTriggered: tabsRoot.openRenameDialog(tabContextMenu.tabIndex)
                        }
                        MenuItem {
                            text: qsTr("Reset Tab Name")
                            visible: tabContextMenu.hasCustomTitle
                            height: visible ? implicitHeight : 0
                            onTriggered: tabsRoot.resetCustomTitle(tabContextMenu.tabIndex)
                        }
                        MenuSeparator { }
                        MenuItem {
                            text: qsTr("Rename Window…")
                            onTriggered: tabsRoot.openRenameWindowDialog()
                        }
                        MenuItem {
                            text: qsTr("Reset Window Name")
                            visible: tabsRoot.customWindowTitle !== ""
                            height: visible ? implicitHeight : 0
                            onTriggered: tabsRoot.resetWindowTitle()
                        }
                    }
                    }
                }

                // Add-tab button. Shadow is faked with two stacked Rectangles:
                // a darker one offset 1px down behind the main circle.
                ToolButton {
                    id: addTabButton
                    text: "+"
                    focusPolicy: Qt.NoFocus
                    implicitWidth: 28
                    implicitHeight: 28
                    padding: 0
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: tabsRoot.addTab()
                    background: Item {
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 1
                            radius: height / 2
                            color: tabsRoot._addBtnShadowColor
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 1
                            radius: height / 2
                            color: addTabButton.hovered ? tabsRoot._addBtnHoverColor : tabsRoot._addBtnColor
                        }
                    }
                    contentItem: Label {
                        text: "+"
                        color: tabsRoot._addBtnTextColor
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        topPadding: -1
                    }
                }
            }

            // Ghost tab (floating pill)
            Rectangle {
                visible: tabsRoot._dragActive
                x: tabsRoot._dragGhostX
                y: 5
                width: tabsRoot._dragTabWidth
                height: parent.height - 10
                color: tabsRoot._tabActiveColor
                border.color: tabsRoot._isDark ? "#505350" : "#CCCCCC"
                border.width: 1
                radius: height / 2
                opacity: 0.85
                z: 100

                Label {
                    anchors.centerIn: parent
                    text: tabsRoot._dragTabTitle
                    elide: Text.ElideRight
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    color: tabsRoot._tabTextColor
                }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Repeater {
                id: tabRepeater
                model: tabsModel
                SplitPane {
                    initialWorkDir: model.initialWorkDir || ""
                    property bool shouldHaveFocus: terminalWindow.active && StackLayout.isCurrentItem
                    onShouldHaveFocusChanged: {
                        if (shouldHaveFocus) {
                            activateFocused()
                        }
                    }
                    onFocusedTitleChanged: function(title) {
                        tabsModel.setProperty(index, "title", normalizeTitle(title))
                    }
                    onFocusedCurrentDirChanged: function(dir) {
                        tabsModel.setProperty(index, "currentDir", dir || "")
                    }
                    onFocusedForegroundProcessChanged: function(name, label) {
                        tabsModel.setProperty(index, "foregroundProcess", name)
                        tabsModel.setProperty(index, "foregroundProcessLabel", label)
                    }
                    onFocusedTerminalSizeChanged: function(terminalSize) {
                        if (index == 0)
                            tabsRoot.terminalSize = terminalSize
                    }
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onTabCloseRequested: tabsRoot.closeTab(index)
                    onBadgeCountChanged: {
                        var count = totalBadgeCount()
                        tabsModel.setProperty(index, "badgeCount", count)
                        tabsRoot._updateTotalBadge()
                    }
                }
            }
        }
    }
}
