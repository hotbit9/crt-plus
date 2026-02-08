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
    signal sessionFinished()
    signal activated()
    signal bellRequested()
    signal activityDetected()

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
            // Retrieve the variable set in main.cpp if arguments are passed.
            if (defaultCmd) {
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
        id: shortContextMenu
        ShortContextMenu { }
    }

    Component {
        id: fullContextMenu
        FullContextMenu { }
    }

    Loader {
        id: menuLoader
        sourceComponent: (appSettings.isMacOS || (appSettings.showMenubar && !terminalWindow.fullscreen) ? shortContextMenu : fullContextMenu)
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
                var openTarget = ""
                var rpath = kterminal.resolveFilePathAt(rcoord.x, rcoord.y)
                if (rpath !== "") {
                    openTarget = rpath
                } else {
                    var ht = kterminal.hotSpotTypeAt(rcoord.x, rcoord.y)
                    if (ht === 1 /* Link */ || ht === 3 /* FilePath */) {
                        if (ht === 3) {
                            var info = kterminal.hotSpotFilePathAt(rcoord.x, rcoord.y)
                            if (info !== "") openTarget = info.split(":")[0]
                        } else {
                            openTarget = "link" // URL detected
                        }
                    }
                }
                contextmenu.openFilePath = openTarget
                contextmenu.openFileCoordX = rcoord.x
                contextmenu.openFileCoordY = rcoord.y
                contextmenu.hasSelection = kterminal.hasSelection()
                // Highlight the target while the context menu is open
                if (openTarget !== "")
                    kterminal.updateHoverHotSpot(rcoord.x, rcoord.y, true)
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
                    // No regex hotspot — try filesystem-based smart resolve
                    // (handles filenames with spaces, etc.)
                    if (!_isRemoteSession() && kterminal.resolveAndOpenFileAt(coord.x, coord.y))
                        return
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
                var hotType = kterminal.updateHoverHotSpot(coord.x, coord.y, true)
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

    function _openRemoteFile(x, y) {
        var info = kterminal.hotSpotFilePathAt(x, y)
        if (info === "") return
        var parts = info.split(":")
        var path = parts[0], line = parts[1] || "1"
        var editor = appSettings.remoteEditorCommand || "vim"
        ksession.sendText(editor + " +" + line + " " + path + "\n")
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
