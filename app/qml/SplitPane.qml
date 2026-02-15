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
    property string initialWorkDir: ""
    property bool _syncingPaneProfile: false
    property var _splitPaneComponentCache: null
    // When a leaf is promoted via removeChild, the survivor SplitPane is kept
    // as a transparent wrapper so the terminal inside it never gets reparented
    // (reparenting QQuickPaintedItem + ShaderEffect chains corrupts rendering).
    property Item _terminalWrapper: null

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
        var ps = profileSettingsComponent.createObject(terminalWindow)
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

    // Recursively collect all leaf SplitPanes in left-to-right order
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
        if (leaf && leaf.terminal && leaf._alive) {
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

    // Push a pane's profile to the window-level profileSettings (and appSettings)
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

    // Emit all focused-* signals so TerminalTabs can update its model
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
    function split(orientation, newTermProps) {
        if (!isLeaf || !terminal) return

        var existingTerminal = terminal
        var existingProfile = paneProfileSettings
        var wrapper = _terminalWrapper

        // Create SplitView
        var sv = splitViewComponent.createObject(splitPaneRoot, {
            "orientation": orientation
        })

        // Create child1 — gets existing terminal and shares existing profile.
        // All profiles are parented to terminalWindow (not to child panes)
        // so they survive child pane destruction without cascade-delete issues.
        var c1 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot,
            "isFocused": false,
            "_skipAutoCreate": true
        })
        c1.paneProfileSettings = existingProfile
        existingTerminal.anchors.fill = undefined
        fileIO.reparentItem(existingTerminal, c1)
        existingTerminal.anchors.fill = c1
        c1.terminal = existingTerminal
        _rootPane()._connectTerminalToPane(existingTerminal, c1)

        // Clean up wrapper from a previous removeChild. The terminal was just
        // reparented out of it, so the wrapper is empty and safe to destroy.
        if (wrapper) {
            wrapper.terminal = null
            wrapper.paneProfileSettings = null
            wrapper.visible = false
            wrapper.destroy()
        }

        // Create child2 with new terminal + new profile (parented to terminalWindow)
        var c2 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot,
            "isFocused": false,
            "_skipAutoCreate": true
        })
        var newProfile = profileSettingsComponent.createObject(terminalWindow)
        newProfile.loadFromString(existingProfile.composeProfileString())
        newProfile.currentProfileIndex = existingProfile.currentProfileIndex
        c2.paneProfileSettings = newProfile
        // Pass profileSettings as initial property (see comment in onCompleted below)
        var termProps = newTermProps || {}
        termProps.profileSettings = newProfile
        var newTerminal = terminalComponent.createObject(c2, termProps)
        c2.terminal = newTerminal
        _rootPane()._connectTerminalToPane(newTerminal, c2)

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
        _terminalWrapper = null
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

        // Hide and destroy the dead child ONLY (NOT the SplitView yet — hiding
        // the SplitView would hide the survivor's subtree, causing its
        // ShaderEffectSource to stop capturing and go ghostly).
        deadChild._alive = false
        deadChild.visible = false
        deadChild.destroyAllSessions()
        if (deadChild.isLeaf) {
            _destroyLeafContents(deadChild)
        } else {
            _destroyTree(deadChild)
        }
        deadChild.destroy()

        if (survivor.isLeaf) {
            // Leaf promotion: wrap survivor so its terminal never moves
            _reparentAsWrapper(survivor)
            terminal = survivor.terminal
            paneProfileSettings = survivor.paneProfileSettings
            _terminalWrapper = survivor
            splitOrientation = -1
            splitView = null
            child1 = null
            child2 = null
            _rootPane()._connectTerminalToPane(terminal, splitPaneRoot)
        } else {
            // Branch promotion: wrap survivor so its terminal descendants never move
            _reparentAsWrapper(survivor)
            splitView = survivor.splitView
            child1 = survivor.child1
            child2 = survivor.child2
            splitOrientation = survivor.splitOrientation
            _terminalWrapper = survivor

            // Children point to root for tree traversal
            if (child1) child1.parentSplitPane = splitPaneRoot
            if (child2) child2.parentSplitPane = splitPaneRoot
        }

        // NOW hide and destroy the old SplitView — survivor has been reparented out.
        oldSv.visible = false
        oldSv.destroy()

        // Ensure all surviving terminals are visible (reparenting out of a
        // hidden SplitView can leave inherited visibility stale).
        var root = _rootPane()
        var leaves = root.allLeaves()
        for (var i = 0; i < leaves.length; i++) {
            if (leaves[i].terminal)
                leaves[i].terminal.visible = true
        }
        if (leaves.length > 0)
            root.focusPane(leaves[0])
    }

    // Recursively destroy an entire subtree (used when a branch is the dead child)
    function _destroyTree(node) {
        node._alive = false
        node.visible = false
        if (node.isLeaf) {
            _destroyLeafContents(node)
        } else {
            if (node.child1) _destroyTree(node.child1)
            if (node.child2) _destroyTree(node.child2)
            if (node.splitView) node.splitView.destroy()
        }
    }

    // Walk up the tree to find the root SplitPane (the one owned by TerminalTabs)
    function _rootPane() {
        var node = splitPaneRoot
        while (node.parentSplitPane) node = node.parentSplitPane
        return node
    }

    // Invalidate signal token, hide, and destroy a leaf's terminal + profile
    function _destroyLeafContents(node) {
        if (node.terminal) {
            if (node.terminal._connectionToken)
                node.terminal._connectionToken.valid = false
            node.terminal.visible = false
            node.terminal.destroy()
        }
        if (node.paneProfileSettings) node.paneProfileSettings.destroy()
    }

    // Reparent a survivor SplitPane to this node as a transparent wrapper.
    // Only the plain Item moves — any terminals inside stay in place,
    // preserving their QQuickPaintedItem + ShaderEffect rendering chain.
    function _reparentAsWrapper(item) {
        item.anchors.fill = undefined
        item.parent = splitPaneRoot
        fileIO.reparentObject(item, splitPaneRoot)
        item.anchors.fill = splitPaneRoot
        item.parentSplitPane = null
    }

    // Explicitly DESTROY all daemon sessions in this subtree
    function destroyAllSessions() {
        var leaves = allLeaves()
        for (var i = 0; i < leaves.length; i++) {
            if (leaves[i].terminal)
                leaves[i].terminal.closeSession()
        }
    }

    // Capture the split tree structure for session persistence
    function captureSplitTree() {
        if (isLeaf) {
            var node = {
                "type": "leaf",
                "sessionId": terminal ? terminal.getDaemonSessionId() : "",
                "isFocused": isFocused
            }
            if (paneProfileSettings) {
                node.profileString = paneProfileSettings.composeProfileString()
                node.profileIndex = paneProfileSettings.currentProfileIndex
            }
            return node
        }
        var ratio = 0.5
        if (child1 && splitView) {
            // Inactive tabs in StackLayout may have zero dimensions — keep default 0.5
            if (splitOrientation === Qt.Horizontal && splitPaneRoot.width > 0)
                ratio = child1.width / splitPaneRoot.width
            else if (splitOrientation === Qt.Vertical && splitPaneRoot.height > 0)
                ratio = child1.height / splitPaneRoot.height
        }
        return {
            "type": "branch",
            "orientation": splitOrientation,
            "splitRatio": ratio,
            "child1": child1 ? child1.captureSplitTree() : null,
            "child2": child2 ? child2.captureSplitTree() : null
        }
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

    // Signal connections use closures that capture `pane`. When a terminal is
    // promoted via removeChild, it gets reconnected to a new pane, but the old
    // anonymous connections can't be disconnected. A plain JS token object acts
    // as a gate: when reconnecting, the old token is invalidated so old handlers
    // bail out immediately without touching the (possibly destroyed) old pane.
    function _connectTerminalToPane(t, pane) {
        var token = { valid: true }
        if (t._connectionToken) t._connectionToken.valid = false
        t._connectionToken = token

        t.onTitleChanged.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTitleChanged(t.title || "")
        })
        t.onCurrentDirChanged.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedCurrentDirChanged(t.currentDir || "")
        })
        t.foregroundProcessChanged.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedForegroundProcessChanged(
                    t.foregroundProcessName || "", t.foregroundProcessLabel || "")
        })
        t.onTerminalSizeChanged.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            var leaf = root.focusedLeaf()
            if (leaf && leaf.terminal === t)
                root.focusedTerminalSizeChanged(t.terminalSize)
        })
        t.sessionFinished.connect(function() {
            if (!token.valid) return
            pane._handleSessionFinished(pane)
        })
        t.activated.connect(function() {
            if (!token.valid) return
            pane._rootPane().focusPane(pane)
        })
        t.bellRequested.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            if (!root.shouldHaveFocus || !pane.isFocused) {
                pane.paneBadgeCount++
                root.badgeCountChanged()
            }
        })
        t.activityDetected.connect(function() {
            if (!token.valid) return
            var root = pane._rootPane()
            if (!root.shouldHaveFocus || !pane.isFocused) {
                if (pane.paneBadgeCount === 0) {
                    pane.paneBadgeCount = 1
                    root.badgeCountChanged()
                }
            }
        })
        t.openInSplitRequested.connect(function(termProps) {
            if (!token.valid) return
            var orientation = termProps.splitOrientation !== undefined ? termProps.splitOrientation : Qt.Horizontal
            delete termProps.splitOrientation
            pane.split(orientation, termProps)
        })
    }

    // When a shell exits: close the pane (or the whole tab if it's the last one)
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

    // Restore a split tree from saved state (session persistence)
    function restoreFromTree(tree) {
        if (!tree) return
        if (tree.type === "leaf") {
            _restoreLeaf(tree)
            return
        }
        // Branch: build tree structure (similar to split() but from saved state)
        var sv = splitViewComponent.createObject(splitPaneRoot, {"orientation": tree.orientation})
        var c1 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot, "isFocused": false, "_skipAutoCreate": true
        })
        var c2 = _getSplitPaneComponent().createObject(sv, {
            "parentSplitPane": splitPaneRoot, "isFocused": false, "_skipAutoCreate": true
        })
        var ratio = (tree.splitRatio > 0 && tree.splitRatio < 1) ? tree.splitRatio : 0.5
        // Use actual size or a reference value for inactive tabs (zero size in
        // StackLayout). SplitView scales preferred sizes proportionally, so
        // arbitrary values work — the ratio is what matters.
        var refSize = (tree.orientation === Qt.Horizontal) ? splitPaneRoot.width : splitPaneRoot.height
        if (refSize <= 0) refSize = 1000
        if (tree.orientation === Qt.Horizontal) {
            c1.SplitView.preferredWidth = refSize * ratio
            c2.SplitView.preferredWidth = refSize * (1 - ratio)
        } else {
            c1.SplitView.preferredHeight = refSize * ratio
            c2.SplitView.preferredHeight = refSize * (1 - ratio)
        }
        splitView = sv; child1 = c1; child2 = c2; splitOrientation = tree.orientation
        c1.restoreFromTree(tree.child1)
        c2.restoreFromTree(tree.child2)
    }

    function _restoreLeaf(leafData) {
        var ps
        if (leafData.profileString) {
            ps = profileSettingsComponent.createObject(terminalWindow)
            ps.loadFromString(leafData.profileString)
            if (leafData.profileIndex !== undefined)
                ps.currentProfileIndex = leafData.profileIndex
        } else {
            ps = _createPaneProfile()
        }
        paneProfileSettings = ps
        var props = {profileSettings: ps, _attachSessionId: leafData.sessionId || ""}
        var t = terminalComponent.createObject(splitPaneRoot, props)
        _rootPane()._connectTerminalToPane(t, splitPaneRoot)
        terminal = t
        isFocused = leafData.isFocused || false
    }

    // Auto-create the initial terminal when instantiated as a leaf
    // (skipped for children created by split(), which manage their own terminals)
    Component.onCompleted: {
        if (isLeaf && !terminal && !_skipAutoCreate && !terminalWindow._restoreMode) {
            paneProfileSettings = _createPaneProfile()
            // Pass profileSettings as initial property so it's set BEFORE
            // Component.onCompleted — the font handler connect() in
            // PreprocessedTerminal must bind to the pane's FontManager,
            // not the window-level one.
            var props = {profileSettings: paneProfileSettings}
            if (initialWorkDir !== "")
                props.initialWorkDir = initialWorkDir
            var t = terminalComponent.createObject(splitPaneRoot, props)
            _rootPane()._connectTerminalToPane(t, splitPaneRoot)
            terminal = t
        }
    }
}
