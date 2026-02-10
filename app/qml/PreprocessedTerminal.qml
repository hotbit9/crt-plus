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
import QtQuick.Controls 2.0

import QMLTermWidget 2.0

import "menus"
import "utils.js" as Utils

Item{
    id: terminalContainer
    property QtObject profileSettings
    property string initialWorkDir: ""
    property string shellCommand: ""   // Custom program for split panes (e.g. "ssh")
    property var shellArgs: []         // Arguments for shellCommand (e.g. ["-t", "user@host"])
    property string initialSendText: "" // Text to send after prompt is detected (via sendTextOnceReady)
    signal sessionFinished()
    signal activated()
    signal bellRequested()
    signal activityDetected()
    signal openInSplitRequested(var termProps) // Emitted to open a new split pane with given properties

    property size virtualResolution: Qt.size(kterminal.totalWidth, kterminal.totalHeight)
    property alias mainTerminal: kterminal

    property ShaderEffectSource mainSource: kterminalSource
    property BurnInEffect burnInEffect: burnInEffect
    property real fontWidth: 1.0
    property real screenScaling: 1.0
    property real scaleTexture: 1.0
    property alias title: ksession.title
    property string currentDir: ""
    property string foregroundProcessName: ""
    property string foregroundProcessLabel: ""
    signal foregroundProcessChanged()
    onTitleChanged: currentDir = ksession.currentDir

    Timer {
        id: _dirPollTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            var dir = ksession.currentDir
            if (dir !== "" && dir !== terminalContainer.currentDir)
                terminalContainer.currentDir = dir

            var fg = ksession.foregroundProcessName
            var label = ksession.foregroundProcessLabel
            if (fg !== "" && fg !== terminalContainer.foregroundProcessName) {
                terminalContainer.foregroundProcessName = fg
                terminalContainer.foregroundProcessLabel = label
                terminalContainer.foregroundProcessChanged()
            } else if (label !== terminalContainer.foregroundProcessLabel) {
                terminalContainer.foregroundProcessLabel = label
            }
        }
    }
    property alias kterminal: kterminal

    property size terminalSize: kterminal.terminalSize
    property size fontMetrics: kterminal.fontMetrics

    // Manage copy and paste (gated on activeFocus so only focused pane responds)
    Connections {
        target: kterminal.activeFocus ? copyAction : null

        onTriggered: {
            kterminal.copyClipboard()
        }
    }
    Connections {
        target: kterminal.activeFocus ? pasteAction : null

        onTriggered: {
            kterminal.pasteClipboard()
        }
    }

    //When settings are updated sources need to be redrawn.
    Connections {
        target: appSettings

        onFontScalingChanged: {
            terminalContainer.updateSources()
        }
    }
    Connections {
        target: profileSettings

        onFontWidthChanged: {
            terminalContainer.updateSources()
        }
    }
    Connections {
        target: terminalContainer

        onWidthChanged: {
            terminalContainer.updateSources()
        }

        onHeightChanged: {
            terminalContainer.updateSources()
        }
    }

    function updateSources() {
        kterminal.update()
    }

    QMLTermWidget {
        id: kterminal

        property int textureResolutionScale: appSettings.lowResolutionFont ? Screen.devicePixelRatio : 1
        property int margin: profileSettings.margin / screenScaling
        property int totalWidth: Math.floor(parent.width / (screenScaling * fontWidth))
        property int totalHeight: Math.floor(parent.height / screenScaling)

        property int rawWidth: totalWidth - 2 * margin
        property int rawHeight: totalHeight - 2 * margin

        textureSize: Qt.size(width / textureResolutionScale, height / textureResolutionScale)

        width: ensureMultiple(rawWidth, Screen.devicePixelRatio)
        height: ensureMultiple(rawHeight, Screen.devicePixelRatio)

        /** Ensure size is a multiple of factor. This is needed for pixel perfect scaling on highdpi screens. */
        function ensureMultiple(size, factor) {
            return Math.round(size / factor) * factor;
        }

        fullCursorHeight: true
        blinkingCursor: profileSettings.blinkingCursor

        colorScheme: "cool-retro-term"

        session: QMLTermSession {
            id: ksession

            onFinished: {
                terminalContainer.sessionFinished()
            }
            onBellRequest: terminalContainer.bellRequested()
            onActivity: terminalContainer.activityDetected()
        }

        QMLTermScrollbar {
            id: kterminalScrollbar
            terminal: kterminal
            anchors.margins: width * 0.5
            width: terminal.fontMetrics.width * 0.75
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                color: "white"
                opacity: 0.7
            }
        }

        function handleFontChanged(fontFamily, pixelSize, lineSpacing, screenScaling, fontWidth, fallbackFontFamily, lowResolutionFont) {
            if (!kterminal) return
            kterminal.lineSpacing = lineSpacing;
            kterminal.antialiasText = !lowResolutionFont;
            kterminal.smooth = !lowResolutionFont;
            kterminal.enableBold = !lowResolutionFont;
            kterminal.enableItalic = !lowResolutionFont;

            kterminal.font = Qt.font({
                family: fontFamily,
                pixelSize: pixelSize
            });

            terminalContainer.fontWidth = fontWidth;
            terminalContainer.screenScaling = screenScaling;
            scaleTexture = Math.max(1.0, Math.floor(screenScaling * appSettings.windowScaling));
        }

        Connections {
            target: appSettings

            onWindowScalingChanged: {
                scaleTexture = Math.max(1.0, Math.floor(terminalContainer.screenScaling * appSettings.windowScaling));
            }
        }

        function startSession() {
            // Custom command for split pane (e.g. ssh -t user@host)
            if (terminalContainer.shellCommand !== "") {
                ksession.setShellProgram(terminalContainer.shellCommand);
                ksession.setArgs(terminalContainer.shellArgs);
            } else if (defaultCmd) {
                // Retrieve the variable set in main.cpp if arguments are passed.
                ksession.setShellProgram(defaultCmd);
                ksession.setArgs(defaultCmdArgs);
            } else if (appSettings.useCustomCommand) {
                var args = Utils.tokenizeCommandLine(appSettings.customCommand);
                ksession.setShellProgram(args[0]);
                ksession.setArgs(args.slice(1));
            } else if (!defaultCmd && appSettings.isMacOS) {
                // OSX Requires the following default parameters for auto login.
                ksession.setArgs(["-i", "-l"]);
            }

            var wd = terminalContainer.initialWorkDir !== "" ? terminalContainer.initialWorkDir : workdir
            if (wd)
                ksession.initialWorkingDirectory = wd;

            // Queue text to send after the shell prompt appears (e.g. cd after SSH login)
            if (terminalContainer.initialSendText !== "")
                ksession.sendTextOnceReady(terminalContainer.initialSendText, appSettings.promptCharacters)

            ksession.startShellProgram();
            forceActiveFocus();
        }
        Component.onCompleted: {
            profileSettings.fontManager.terminalFontChanged.connect(handleFontChanged);
            profileSettings.fontManager.refresh()
            kterminal.setFilePathEditorCommand(appSettings.editorCommand)
            startSession();
        }
        Component.onDestruction: {
            profileSettings.fontManager.terminalFontChanged.disconnect(handleFontChanged);
        }

    }

    Component {
        id: contextMenuComponent
        FullContextMenu {
            showExtendedMenus: !(appSettings.isMacOS || (appSettings.showMenubar && !terminalWindow.fullscreen))
        }
    }

    Loader {
        id: menuLoader
        sourceComponent: contextMenuComponent
    }
    property alias contextmenu: menuLoader.item
    Connections {
        target: contextmenu
        function onClosed() { kterminal.clearHoverHotSpot() }
    }

    MouseArea {
        id: terminalMouseArea
        property real margin: profileSettings.margin
        property real frameSize: profileSettings.frameSize * terminalWindow.normalizedWindowScale
        property bool hoverHotSpotActive: false

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        anchors.fill: parent
        cursorShape: hoverHotSpotActive ? Qt.PointingHandCursor : (kterminal.terminalUsesMouse ? Qt.ArrowCursor : Qt.IBeamCursor)
        onWheel: function(wheel) {
            if (wheel.modifiers & Qt.ControlModifier) {
               wheel.angleDelta.y > 0 ? zoomIn.trigger() : zoomOut.trigger();
            } else {
                var coord = correctDistortion(wheel.x, wheel.y);
                kterminal.simulateWheel(coord.x, coord.y, wheel.buttons, wheel.modifiers, wheel.angleDelta);
            }
        }
        onDoubleClicked: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseDoubleClick(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onPressed: function(mouse) {
            kterminal.forceActiveFocus()
            terminalContainer.activated()
            if ((!kterminal.terminalUsesMouse || mouse.modifiers & Qt.ShiftModifier) && mouse.button == Qt.RightButton) {
                // Check for openable target (file path or URL) under cursor
                var rcoord = correctDistortion(mouse.x, mouse.y);
                var isRemote = _isRemoteSession()
                var hasSelection = kterminal.hasSelection()
                var openTarget = ""
                var isFile = false, isFolder = false, isLink = false
                if (!hasSelection) {
                    if (!isRemote) {
                        var rpath = kterminal.resolveFilePathAt(rcoord.x, rcoord.y)
                        if (rpath !== "") {
                            var displayText = kterminal.extractPathTextAt(rcoord.x, rcoord.y)
                            openTarget = displayText !== "" ? displayText : rpath
                            isFile = true
                        }
                    }
                    if (openTarget === "") {
                        var ht = kterminal.hotSpotTypeAt(rcoord.x, rcoord.y)
                        if (ht === 1 /* Link */) {
                            var linkText = kterminal.hotSpotTextAt(rcoord.x, rcoord.y)
                            if (linkText !== "") { openTarget = linkText; isLink = true }
                        } else if (ht === 3 /* FilePath */) {
                            var fileText = kterminal.hotSpotTextAt(rcoord.x, rcoord.y)
                            if (fileText !== "") {
                                var fullText = _cleanPathText(kterminal.extractPathTextAt(rcoord.x, rcoord.y))
                                if ((fullText !== "" && fullText.endsWith("/")) || _looksLikeDirectory(fileText.split(":")[0])) {
                                    isFolder = true
                                    openTarget = fullText !== "" ? fullText : fileText
                                } else {
                                    isFile = true
                                    openTarget = fileText
                                }
                            }
                        }
                    }
                    if (openTarget === "" && isRemote) {
                        var remotePath = kterminal.extractPathTextAt(rcoord.x, rcoord.y)
                        if (remotePath !== "") {
                            openTarget = remotePath
                            var cleanedRemote = _cleanPathText(remotePath)
                            if (cleanedRemote.endsWith("/"))
                                isFolder = true
                            else
                                isFile = true
                        }
                    }
                }
                contextmenu.openFilePath = openTarget
                contextmenu.openFileCoordX = rcoord.x
                contextmenu.openFileCoordY = rcoord.y
                contextmenu.hasSelection = hasSelection
                contextmenu.isRemoteSession = isRemote
                contextmenu.isFile = isFile
                contextmenu.isFolder = isFolder
                contextmenu.isLink = isLink
                if (openTarget !== "")
                    kterminal.updateHoverHotSpot(rcoord.x, rcoord.y, true, isRemote)
                contextmenu.popup();
            } else {
                var coord = correctDistortion(mouse.x, mouse.y);
                // Cmd+click (macOS) / Ctrl+click (Linux) opens file paths and URLs
                var modKey = appSettings.isMacOS ? Qt.MetaModifier : Qt.ControlModifier
                if (mouse.button === Qt.LeftButton && (mouse.modifiers & modKey)) {
                    var hotType = kterminal.hotSpotTypeAt(coord.x, coord.y)
                    if (hotType > 0) {
                        if (_isRemoteSession() && hotType === 3 /* FilePath */) {
                            _openRemoteFile(coord.x, coord.y)
                        } else {
                            kterminal.activateHotSpotAt(coord.x, coord.y, "click-action")
                        }
                        return
                    }
                    // No regex hotspot — try smart resolve or remote path extraction
                    if (_isRemoteSession()) {
                        var pathText = kterminal.extractPathTextAt(coord.x, coord.y)
                        if (pathText !== "") { _openRemotePathText(pathText); return }
                    } else {
                        if (kterminal.resolveAndOpenFileAt(coord.x, coord.y))
                            return
                    }
                }
                kterminal.simulateMousePress(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers)
            }
        }
        onReleased: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseRelease(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onPositionChanged: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            // Cmd+hover (macOS) / Ctrl+hover (Linux) highlights clickable hotspots
            var modKey = appSettings.isMacOS ? Qt.MetaModifier : Qt.ControlModifier
            var cmdHeld = (mouse.modifiers & modKey) !== 0
            if (cmdHeld) {
                var hotType = kterminal.updateHoverHotSpot(coord.x, coord.y, true, _isRemoteSession())
                terminalMouseArea.hoverHotSpotActive = hotType > 0
            } else if (terminalMouseArea.hoverHotSpotActive) {
                kterminal.clearHoverHotSpot()
                terminalMouseArea.hoverHotSpotActive = false
            }
            // Only forward mouse move to terminal when buttons are pressed
            if (mouse.buttons !== Qt.NoButton)
                kterminal.simulateMouseMove(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onExited: {
            if (terminalMouseArea.hoverHotSpotActive) {
                kterminal.clearHoverHotSpot()
                terminalMouseArea.hoverHotSpotActive = false
            }
        }

        function correctDistortion(x, y) {
            x = (x - margin) / width;
            y = (y - margin) / height;

            x = x * (1 + frameSize * 2) - frameSize;
            y = y * (1 + frameSize * 2) - frameSize;

            var cc = Qt.size(0.5 - x, 0.5 - y);
            var distortion = (cc.height * cc.height + cc.width * cc.width)
                    * profileSettings.screenCurvature * appSettings.screenCurvatureSize
                    * terminalWindow.normalizedWindowScale;

            return Qt.point((x - cc.width  * (1+distortion) * distortion) * (kterminal.totalWidth),
                           (y - cc.height * (1+distortion) * distortion) * (kterminal.totalHeight))
        }
    }
    // Drop files onto the terminal to paste their escaped paths
    DropArea {
        anchors.fill: parent
        onDropped: function(drop) {
            if (drop.hasUrls) {
                var paths = [];
                for (var i = 0; i < drop.urls.length; i++) {
                    var url = drop.urls[i].toString();
                    var path = decodeURIComponent(url.replace(/^file:\/\//, ""));
                    paths.push(escapeShellPath(path));
                }
                ksession.sendText(paths.join(" "));
            }
        }

        function escapeShellPath(path) {
            // Remove control characters that could act as command separators
            path = path.replace(/[\n\r\t]/g, '')
            return path.replace(/[ !"#$&'()*,;<>?\\[\]^`{|}~]/g, '\\$&');
        }
    }

    // Keep file path filter working directory in sync
    Connections {
        target: terminalContainer
        onCurrentDirChanged: kterminal.setFilePathWorkDir(terminalContainer.currentDir)
    }
    Connections {
        target: appSettings
        onEditorCommandChanged: kterminal.setFilePathEditorCommand(appSettings.editorCommand)
    }

    function _isRemoteSession() {
        var fg = terminalContainer.foregroundProcessName
        return fg === "ssh" || fg === "mosh" || fg === "telnet" || fg === "rlogin"
    }

    function _shellQuotePath(path) {
        return "'" + path.replace(/'/g, "'\\''") + "'"
    }

    function _looksLikeDirectory(path) {
        // Only an explicit trailing slash indicates a directory.
        // We can't check the remote filesystem, and defaulting to "file"
        // is the better UX (covers /etc/passwd, Makefile, LICENSE, etc.)
        return path.endsWith("/")
    }

    function _cleanPathText(text) {
        // Strip surrounding quotes
        if (text.length >= 2) {
            var first = text[0], last = text[text.length - 1]
            if ((first === "'" && last === "'") || (first === '"' && last === '"') || (first === '`' && last === '`'))
                text = text.substring(1, text.length - 1)
        }
        // Strip trailing bare punctuation (not part of :line:col)
        text = text.replace(/[:;,]+$/, "")
        return text
    }

    function _getRemoteCwd() {
        var title = ksession.title
        if (!title || title === "") return ""
        // Common formats: "user@host: ~/path", "user@host:/path", "~/path", "/path"
        var path = ""
        var colonIdx = title.indexOf(": ")
        if (colonIdx !== -1) {
            path = title.substring(colonIdx + 2).trim()
        } else {
            // Try "user@host:/path" (no space after colon)
            var atIdx = title.indexOf("@")
            if (atIdx !== -1) {
                var c = title.indexOf(":", atIdx)
                if (c !== -1)
                    path = title.substring(c + 1).trim()
            } else if (title.startsWith("/") || title.startsWith("~")) {
                path = title.trim()
            }
        }
        if (path.startsWith("/") || path.startsWith("~"))
            return path
        return ""
    }

    function _buildSshEditorCommand(path, line, cwd) {
        var info = ksession.sshConnectionInfo()
        if (!info.host || info.host === "") return null
        var editor = appSettings.remoteEditorCommand || "vim"
        var remoteCmd = ""
        if (cwd && cwd !== "")
            remoteCmd = "cd " + _shellQuotePath(cwd) + " && "
        remoteCmd += editor + " +" + line + " " + _shellQuotePath(path)
        var args = ["-t"]
        if (info.port && info.port !== "")
            args = args.concat(["-p", info.port])
        var target = (info.user && info.user !== "") ? info.user + "@" + info.host : info.host
        args.push(target)
        args.push(remoteCmd)
        return { program: "ssh", args: args }
    }

    function _getFileInfo(x, y, pathText) {
        var ht = kterminal.hotSpotTypeAt(x, y)
        if (ht === 3) {
            var info = kterminal.hotSpotFilePathAt(x, y)
            if (info !== "") {
                var parts = info.split(":")
                return { path: parts[0], line: parts[1] || "1" }
            }
        }
        if (!_isRemoteSession()) {
            var resolved = kterminal.resolveFilePathAt(x, y)
            if (resolved !== "") {
                var rparts = resolved.split(":")
                return { path: rparts[0], line: rparts[1] || "1" }
            }
        }
        if (pathText && pathText !== "") {
            var cleaned = _cleanPathText(pathText)
            var suffixMatch = cleaned.match(/^(.+?):(\d+)(?::(\d+))?$/)
            if (suffixMatch) return { path: suffixMatch[1], line: suffixMatch[2] }
            return { path: cleaned, line: "1" }
        }
        return null
    }

    function actionOpenFile(x, y, pathText) {
        if (_isRemoteSession()) {
            var fi = _getFileInfo(x, y, pathText)
            if (!fi) return
            var editor = appSettings.remoteEditorCommand || "vim"
            ksession.sendText(editor + " +" + fi.line + " " + _shellQuotePath(fi.path) + "\n")
        } else {
            if (!kterminal.activateHotSpotAt(x, y, "click-action"))
                kterminal.resolveAndOpenFileAt(x, y)
        }
    }

    // Opens a file in a new split pane. For remote sessions, opens via SSH.
    // orientation: Qt.Vertical (below) or Qt.Horizontal (right), defaults to Vertical.
    function actionOpenFileInSplit(x, y, pathText, orientation) {
        var splitDir = orientation !== undefined ? orientation : Qt.Vertical
        var fi = _getFileInfo(x, y, pathText)
        if (!fi) return
        if (_isRemoteSession()) {
            var cwd = fi.path.startsWith("/") ? "" : _getRemoteCwd()
            var cmd = _buildSshEditorCommand(fi.path, fi.line, cwd)
            if (cmd) { openInSplitRequested({ shellCommand: cmd.program, shellArgs: cmd.args, splitOrientation: splitDir }); return }
            var editor = appSettings.remoteEditorCommand || "vim"
            ksession.sendText(editor + " +" + fi.line + " " + _shellQuotePath(fi.path) + "\n")
        } else {
            var localEditor = appSettings.remoteEditorCommand || "vim"
            openInSplitRequested({ shellCommand: localEditor, shellArgs: ["+" + fi.line, fi.path], splitOrientation: splitDir })
        }
    }

    function actionOpenFolder(folderPath) {
        folderPath = _cleanPathText(folderPath)
        if (_isRemoteSession()) {
            ksession.sendText("cd " + _shellQuotePath(folderPath) + "\n")
        } else {
            var absPath = folderPath.startsWith("/") ? folderPath : terminalContainer.currentDir + "/" + folderPath
            Qt.openUrlExternally("file://" + absPath)
        }
    }

    // Opens a folder in a new split pane. For remote sessions, opens a new SSH
    // connection and sends `cd /path` after the prompt is detected.
    // orientation: Qt.Vertical (below) or Qt.Horizontal (right), defaults to Vertical.
    function actionOpenFolderInSplit(folderPath, orientation) {
        var splitDir = orientation !== undefined ? orientation : Qt.Vertical
        folderPath = _cleanPathText(folderPath)
        if (_isRemoteSession()) {
            var info = ksession.sshConnectionInfo()
            if (info.host && info.host !== "") {
                var sshArgs = ["-t"]
                if (info.port && info.port !== "")
                    sshArgs = sshArgs.concat(["-p", info.port])
                var target = (info.user && info.user !== "") ? info.user + "@" + info.host : info.host
                sshArgs.push(target)
                var cdCmd = " cd " + _shellQuotePath(folderPath) + "\n"
                openInSplitRequested({ shellCommand: "ssh", shellArgs: sshArgs, initialSendText: cdCmd, splitOrientation: splitDir })
                return
            }
            ksession.sendText("cd " + _shellQuotePath(folderPath) + "\n")
        } else {
            var absPath = folderPath.startsWith("/") ? folderPath : terminalContainer.currentDir + "/" + folderPath
            openInSplitRequested({ initialWorkDir: absPath, splitOrientation: splitDir })
        }
    }

    function actionOpenLink(x, y) {
        kterminal.activateHotSpotAt(x, y, "click-action")
    }

    function _openRemotePathAndEdit(path, line) {
        if (_looksLikeDirectory(path)) {
            ksession.sendText("cd " + _shellQuotePath(path) + "\n")
            return
        }
        var cwd = path.startsWith("/") ? "" : _getRemoteCwd()
        var cmd = _buildSshEditorCommand(path, line, cwd)
        if (cmd) {
            openInSplitRequested({ shellCommand: cmd.program, shellArgs: cmd.args, splitOrientation: Qt.Vertical })
            return
        }
        var editor = appSettings.remoteEditorCommand || "vim"
        ksession.sendText(editor + " +" + line + " " + _shellQuotePath(path) + "\n")
    }

    function _openRemoteFile(x, y) {
        var info = kterminal.hotSpotFilePathAt(x, y)
        if (info === "") return
        // The hotspot regex may match a partial path (e.g. "bitsbytes.jp"
        // looks like a file extension in "/var/.../bitsbytes.jp/dev/cur/").
        // Check the broader text to detect trailing "/" that indicates a directory.
        var fullText = _cleanPathText(kterminal.extractPathTextAt(x, y))
        if (fullText !== "" && fullText.endsWith("/")) {
            ksession.sendText("cd " + _shellQuotePath(fullText) + "\n")
            return
        }
        var parts = info.split(":")
        _openRemotePathAndEdit(parts[0], parts[1] || "1")
    }

    function _openRemotePathText(pathText) {
        pathText = _cleanPathText(pathText)
        var suffixMatch = pathText.match(/^(.+?):(\d+)(?::(\d+))?$/)
        var path, line
        if (suffixMatch) {
            path = suffixMatch[1]
            line = suffixMatch[2]
        } else {
            path = pathText
            line = "1"
        }
        if (path.endsWith("/")) {
            ksession.sendText("cd " + _shellQuotePath(path) + "\n")
            return
        }
        _openRemotePathAndEdit(path, line)
    }

    ShaderEffectSource{
        id: kterminalSource
        sourceItem: kterminal
        hideSource: true
        wrapMode: ShaderEffectSource.Repeat
        visible: false
        textureSize: Qt.size(kterminal.totalWidth * scaleTexture, kterminal.totalHeight * scaleTexture)
        sourceRect: Qt.rect(-kterminal.margin, -kterminal.margin, kterminal.totalWidth, kterminal.totalHeight)
    }

    Item {
        id: burnInContainer

        property int burnInScaling: scaleTexture * appSettings.burnInQuality

        width: Math.round(appSettings.lowResolutionFont
               ? kterminal.totalWidth * Math.max(1, burnInScaling)
               : kterminal.totalWidth * scaleTexture * appSettings.burnInQuality)

        height: Math.round(appSettings.lowResolutionFont
                ? kterminal.totalHeight * Math.max(1, burnInScaling)
                : kterminal.totalHeight * scaleTexture * appSettings.burnInQuality)


        BurnInEffect {
            id: burnInEffect
        }
    }
}
