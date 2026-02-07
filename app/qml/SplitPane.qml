/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://fromhelloworld.com
* https://github.com/hotbit9/cool-retro-term
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

Item {
    id: splitPaneRoot

    // -1 = leaf, Qt.Horizontal = side-by-side, Qt.Vertical = stacked
    property int splitOrientation: -1
    readonly property bool isLeaf: splitOrientation === -1

    property TerminalContainer terminal: null
    property QtObject paneProfileSettings: null
    property Item splitView: null
    property Item child1: null
    property Item child2: null
    property Item parentSplitPane: null
    property bool isFocused: true
    property bool _skipAutoCreate: false
    property bool _alive: true
    property bool _syncingPaneProfile: false
    property var _splitPaneComponentCache: null

    function _getSplitPaneComponent() {
        if (!_splitPaneComponentCache)
            _splitPaneComponentCache = Qt.createComponent("SplitPane.qml")
        return _splitPaneComponentCache
    }

    Component {
        id: profileSettingsComponent
        ProfileSettings { }
    }

    function _createPaneProfile() {
        var ps = profileSettingsComponent.createObject(splitPaneRoot)
        ps.loadFromString(terminalWindow.profileSettings.composeProfileString())
        ps.currentProfileIndex = terminalWindow.profileSettings.currentProfileIndex
        return ps
    }

    property int paneBadgeCount: 0

    signal tabCloseRequested()
    signal focusedTitleChanged(string title)
    signal focusedCurrentDirChanged(string dir)
    signal focusedForegroundProcessChanged(string name, string label)
    signal focusedTerminalSizeChanged(size terminalSize)
    signal badgeCountChanged()

    // Return the currently focused leaf
    function focusedLeaf() {
        if (isLeaf) return isFocused ? splitPaneRoot : null
        var leaves = allLeaves()
        for (var i = 0; i < leaves.length; i++) {
            if (leaves[i].isFocused) return leaves[i]
        }
        if (leaves.length > 0) {
            focusPane(leaves[0])
            return leaves[0]
        }
        return null
    }

    // Recursively collect all leaf SplitPanes
    function allLeaves() {
        if (isLeaf) return [splitPaneRoot]
        var result = []
        if (child1) result = result.concat(child1.allLeaves())
        if (child2) result = result.concat(child2.allLeaves())
        return result
    }

    // Set focus on one leaf, unfocus all others (called on root)
    function focusPane(leaf, showBorder) {
        var leaves = allLeaves()
        for (var i = 0; i < leaves.length; i++) {
            leaves[i].isFocused = (leaves[i] === leaf)
        }
        if (leaf && leaf.terminal) {
            leaf.terminal.activate()
            _emitFocusedSignals(leaf)
            if (showBorder !== false && leaves.length > 1)
                leaf.flashBorder()
            _syncPaneToWindow(leaf)
            if (leaf.paneBadgeCount > 0) {
                leaf.paneBadgeCount = 0
                badgeCountChanged()
            }
        }
    }

    function _syncPaneToWindow(leaf) {
        if (!leaf || !leaf.paneProfileSettings) return
        _syncingPaneProfile = true
        terminalWindow.profileSettings.loadFromString(
            leaf.paneProfileSettings.composeProfileString())
        terminalWindow.profileSettings.currentProfileIndex =
            leaf.paneProfileSettings.currentProfileIndex
        terminalWindow.profileSettings.syncToAppSettings()
        _syncingPaneProfile = false
    }

    function flashBorder() {
        focusBorder.opacity = 1.0
        fadeOut.restart()
    }

    function focusNext() {
        var leaves = allLeaves()
        if (leaves.length <= 1) return
        var idx = _focusedIndex(leaves)
        focusPane(leaves[(idx + 1) % leaves.length])
    }

    function focusPrevious() {
        var leaves = allLeaves()
        if (leaves.length <= 1) return
        var idx = _focusedIndex(leaves)
        focusPane(leaves[(idx - 1 + leaves.length) % leaves.length])
    }

    function _focusedIndex(leaves) {
        for (var i = 0; i < leaves.length; i++) {
            if (leaves[i].isFocused) return i
        }
        return 0
    }

    function _emitFocusedSignals(leaf) {
        if (!leaf || !leaf.terminal) return
        focusedTitleChanged(leaf.terminal.title || "")
        focusedCurrentDirChanged(leaf.terminal.currentDir || "")
        focusedForegroundProcessChanged(
            leaf.terminal.foregroundProcessName || "",
            leaf.terminal.foregroundProcessLabel || "")
        focusedTerminalSizeChanged(leaf.terminal.terminalSize)
    }

    // Activate the currently focused leaf's terminal (for tab switching)
    function activateFocused() {
        var leaf = focusedLeaf()
        if (leaf && leaf.terminal)
            leaf.terminal.activate()
    }

    // Split this leaf into a branch
    function split(orientation) {
        if (!isLeaf || !terminal) return

        var existingTerminal = terminal
        var existingProfile = paneProfileSettings

        // Create SplitView
        var sv = splitViewComponent.createObject(splitPaneRoot, {
            "orientation": orientation
        })

        // Create child1 (gets existing terminal + profile)
        var c1 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot,
            "isFocused": false,
            "_skipAutoCreate": true
        })
        c1.paneProfileSettings = existingProfile
        existingTerminal.parent = c1
        existingTerminal.anchors.fill = c1
        c1.terminal = existingTerminal
        _connectTerminalToChild(existingTerminal, c1)

        // Create child2 with new terminal + copy of profile
        var c2 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot,
            "isFocused": false,
            "_skipAutoCreate": true
        })
        var newProfile = profileSettingsComponent.createObject(c2)
        newProfile.loadFromString(existingProfile.composeProfileString())
        newProfile.currentProfileIndex = existingProfile.currentProfileIndex
        c2.paneProfileSettings = newProfile
        var newTerminal = terminalComponent.createObject(c2)
        newTerminal.profileSettings = newProfile
        c2.terminal = newTerminal
        _connectTerminalToChild(newTerminal, c2)

        // Set equal sizes
        if (orientation === Qt.Horizontal) {
            c1.SplitView.preferredWidth = splitPaneRoot.width / 2
            c2.SplitView.preferredWidth = splitPaneRoot.width / 2
        } else {
            c1.SplitView.preferredHeight = splitPaneRoot.height / 2
            c2.SplitView.preferredHeight = splitPaneRoot.height / 2
        }

        // Convert from leaf to branch
        paneProfileSettings = null
        terminal = null
        splitView = sv
        child1 = c1
        child2 = c2
        splitOrientation = orientation

        // Focus the new pane (suppress border flash during split)
        _rootPane().focusPane(c2, false)
    }

    // Close the currently focused pane (called on root)
    function closeFocusedPane() {
        var leaf = focusedLeaf()
        if (!leaf) return
        if (leaf === splitPaneRoot && isLeaf) {
            tabCloseRequested()
            return
        }
        if (leaf.parentSplitPane)
            leaf.parentSplitPane.removeChild(leaf)
    }

    // Remove a child and promote the surviving sibling
    function removeChild(deadChild) {
        var survivor = (deadChild === child1) ? child2 : child1
        var oldSv = splitView

        // Destroy the dead child's contents
        deadChild._alive = false
        if (deadChild.isLeaf) {
            if (deadChild.terminal) deadChild.terminal.destroy()
            if (deadChild.paneProfileSettings) deadChild.paneProfileSettings.destroy()
        } else {
            _destroyTree(deadChild)
        }
        deadChild.destroy()

        if (survivor.isLeaf) {
            // Promote survivor's terminal + profile into this node
            var t = survivor.terminal
            var ps = survivor.paneProfileSettings
            survivor.terminal = null
            survivor.paneProfileSettings = null
            t.parent = splitPaneRoot
            t.anchors.fill = splitPaneRoot
            terminal = t
            paneProfileSettings = ps
            splitOrientation = -1
            splitView = null
            child1 = null
            child2 = null
            _connectTerminal(t)
        } else {
            // Promote survivor's branch into this node
            var sv = survivor.splitView
            var sc1 = survivor.child1
            var sc2 = survivor.child2
            survivor.splitView = null
            survivor.child1 = null
            survivor.child2 = null

            sv.parent = splitPaneRoot
            sv.anchors.fill = splitPaneRoot
            sc1.parentSplitPane = splitPaneRoot
            sc2.parentSplitPane = splitPaneRoot

            splitView = sv
            child1 = sc1
            child2 = sc2
            splitOrientation = survivor.splitOrientation
        }

        survivor._alive = false
        survivor.destroy()
        if (oldSv) oldSv.destroy()

        // Focus the next available leaf
        var root = _rootPane()
        var leaves = root.allLeaves()
        if (leaves.length > 0)
            root.focusPane(leaves[0])
    }

    function _destroyTree(node) {
        node._alive = false
        if (node.isLeaf) {
            if (node.terminal) node.terminal.destroy()
            if (node.paneProfileSettings) node.paneProfileSettings.destroy()
        } else {
            if (node.child1) _destroyTree(node.child1)
            if (node.child2) _destroyTree(node.child2)
            if (node.splitView) node.splitView.destroy()
        }
    }

    function _rootPane() {
        var node = splitPaneRoot
        while (node.parentSplitPane) node = node.parentSplitPane
        return node
    }

    function hasMultipleLeaves() {
        return allLeaves().length > 1
    }

    function totalBadgeCount() {
        var leaves = allLeaves()
        var total = 0
        for (var i = 0; i < leaves.length; i++)
            total += leaves[i].paneBadgeCount
        return total
    }

    function _connectTerminal(t) {
        t.onTitleChanged.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTitleChanged(t.title || "")
        })
        t.onCurrentDirChanged.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedCurrentDirChanged(t.currentDir || "")
        })
        t.foregroundProcessChanged.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedForegroundProcessChanged(
                    t.foregroundProcessName || "", t.foregroundProcessLabel || "")
        })
        t.onTerminalSizeChanged.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTerminalSizeChanged(t.terminalSize)
        })
        t.sessionFinished.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            _handleSessionFinished(splitPaneRoot)
        })
        t.activated.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            _rootPane().focusPane(splitPaneRoot)
        })
        t.bellRequested.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            if (!root.shouldHaveFocus || !splitPaneRoot.isFocused) {
                splitPaneRoot.paneBadgeCount++
                root.badgeCountChanged()
            }
        })
        t.activityDetected.connect(function() {
            if (splitPaneRoot.terminal !== t) return
            var root = _rootPane()
            if (!root.shouldHaveFocus || !splitPaneRoot.isFocused) {
                if (splitPaneRoot.paneBadgeCount === 0) {
                    splitPaneRoot.paneBadgeCount = 1
                    root.badgeCountChanged()
                }
            }
        })
    }

    function _connectTerminalToChild(t, childPane) {
        t.onTitleChanged.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTitleChanged(t.title || "")
        })
        t.onCurrentDirChanged.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedCurrentDirChanged(t.currentDir || "")
        })
        t.foregroundProcessChanged.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedForegroundProcessChanged(
                    t.foregroundProcessName || "", t.foregroundProcessLabel || "")
        })
        t.onTerminalSizeChanged.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTerminalSizeChanged(t.terminalSize)
        })
        t.sessionFinished.connect(function() {
            if (!childPane._alive) return
            childPane._handleSessionFinished(childPane)
        })
        t.activated.connect(function() {
            if (!childPane._alive) return
            childPane._rootPane().focusPane(childPane)
        })
        t.bellRequested.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            if (!root.shouldHaveFocus || !childPane.isFocused) {
                childPane.paneBadgeCount++
                root.badgeCountChanged()
            }
        })
        t.activityDetected.connect(function() {
            if (!childPane._alive) return
            var root = childPane._rootPane()
            if (!root.shouldHaveFocus || !childPane.isFocused) {
                if (childPane.paneBadgeCount === 0) {
                    childPane.paneBadgeCount = 1
                    root.badgeCountChanged()
                }
            }
        })
    }

    function _handleSessionFinished(pane) {
        var root = _rootPane()
        if (pane === root && pane.isLeaf) {
            root.tabCloseRequested()
            return
        }
        if (pane.parentSplitPane)
            pane.parentSplitPane.removeChild(pane)
    }

    // Dim unfocused panes with a dark overlay
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5
        z: 100
        visible: splitPaneRoot.isLeaf && splitPaneRoot.parentSplitPane && !splitPaneRoot.isFocused
    }

    // Focus border — flashes on focus then fades out
    Rectangle {
        id: focusBorder
        anchors.fill: parent
        color: "transparent"
        border.width: splitPaneRoot.isLeaf && splitPaneRoot.parentSplitPane ? 1 : 0
        border.color: {
            var ps = splitPaneRoot.paneProfileSettings || terminalWindow.profileSettings
            return Qt.rgba(ps.fontColor.r, ps.fontColor.g, ps.fontColor.b, 0.8)
        }
        z: 101
        opacity: 0
        visible: border.width > 0

    }
    NumberAnimation {
        id: fadeOut
        target: focusBorder
        property: "opacity"
        from: 1.0; to: 0.0; duration: 1000
    }

    // Dynamic components for split children
    Component {
        id: splitViewComponent
        SplitView {
            anchors.fill: parent
            handle: Rectangle {
                implicitWidth: 4
                implicitHeight: 4
                color: SplitHandle.pressed ? "#666666" : (SplitHandle.hovered ? "#555555" : "#444444")
            }
        }
    }

    Component {
        id: terminalComponent
        TerminalContainer {
            anchors.fill: parent
        }
    }

    // Auto-create the initial terminal when instantiated as a leaf
    // (skipped for children created by split(), which manage their own terminals)
    Component.onCompleted: {
        if (isLeaf && !terminal && !_skipAutoCreate) {
            paneProfileSettings = _createPaneProfile()
            var t = terminalComponent.createObject(splitPaneRoot)
            t.profileSettings = paneProfileSettings
            _connectTerminal(t)
            terminal = t
        }
    }
}
