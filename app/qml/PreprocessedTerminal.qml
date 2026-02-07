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

    MouseArea {
        property real margin: profileSettings.margin
        property real frameSize: profileSettings.frameSize * terminalWindow.normalizedWindowScale

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        anchors.fill: parent
        cursorShape: kterminal.terminalUsesMouse ? Qt.ArrowCursor : Qt.IBeamCursor
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
                contextmenu.popup();
            } else {
                var coord = correctDistortion(mouse.x, mouse.y);
                kterminal.simulateMousePress(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers)
            }
        }
        onReleased: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseRelease(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onPositionChanged: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseMove(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
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
