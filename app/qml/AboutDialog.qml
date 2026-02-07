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
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import QtQuick.Window 2.0

ApplicationWindow {
    id: dialogwindow
    title: qsTr("About")
    width: 600
    height: 400

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "CRT Plus"
            color: palette.text
            font {
                bold: true
                pointSize: 18
            }
        }
        Loader {
            id: mainContent
            Layout.fillHeight: true
            Layout.fillWidth: true

            states: [
                State {
                    name: "Default"
                    PropertyChanges {
                        target: mainContent
                        sourceComponent: defaultComponent
                    }
                },
                State {
                    name: "License"
                    PropertyChanges {
                        target: mainContent
                        sourceComponent: licenseComponent
                    }
                }
            ]
            Component.onCompleted: mainContent.state = "Default"
        }
        Item {
            Layout.fillWidth: true
            height: childrenRect.height
            Button {
                anchors.left: parent.left
                text: qsTr("License")
                onClicked: {
                    mainContent.state == "Default" ? mainContent.state
                                                     = "License" : mainContent.state = "Default"
                }
            }
            Button {
                anchors.right: parent.right
                text: qsTr("Close")
                onClicked: dialogwindow.close()
            }
        }
    }
    // MAIN COMPONENTS ////////////////////////////////////////////////////////
    Component {
        id: defaultComponent
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
                Canvas {
                    id: iconCanvas
                    width: Math.min(parent.width, parent.height)
                    height: width
                    anchors.centerIn: parent
                    property real cornerRadius: width * 0.22
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.save()
                        var r = cornerRadius, w = width, h = height
                        ctx.beginPath()
                        ctx.moveTo(r, 0)
                        ctx.lineTo(w - r, 0)
                        ctx.arcTo(w, 0, w, r, r)
                        ctx.lineTo(w, h - r)
                        ctx.arcTo(w, h, w - r, h, r)
                        ctx.lineTo(r, h)
                        ctx.arcTo(0, h, 0, h - r, r)
                        ctx.lineTo(0, r)
                        ctx.arcTo(0, 0, r, 0, r)
                        ctx.closePath()
                        ctx.clip()
                        ctx.drawImage("images/crt256.png", 0, 0, w, h)
                        ctx.restore()
                    }
                    Component.onCompleted: loadImage("images/crt256.png")
                    onImageLoaded: requestPaint()
                }
            }
            Text {
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                color: palette.text
                linkColor: palette.link
                textFormat: Text.RichText
                onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                text: appSettings.version + "<br><br>"
                          + qsTr("By: ") + "Alex Fabri<br>" + qsTr(
                          "Website: ") + "<a href=\"https://fromhelloworld.com\">fromhelloworld.com</a><br>" + qsTr(
                          "Source: ") + "<a href=\"https://github.com/hotbit9/cool-retro-term\">github.com/hotbit9/cool-retro-term</a><br><br>"
                          + qsTr("Based on cool-retro-term by: ") + "Filippo Scognamiglio<br>" + qsTr(
                          "Email: ") + "<a href=\"mailto:flscogna@gmail.com\">flscogna@gmail.com</a><br>" + qsTr(
                          "Source: ") + "<a href=\"https://github.com/Swordfish90/cool-retro-term\">github.com/Swordfish90/cool-retro-term</a>"
            }
        }
    }
    Component {
        id: licenseComponent
        ScrollView {
            anchors.fill: parent
            clip: true
            TextArea {
                readOnly: true
                wrapMode: TextEdit.Wrap
                color: palette.text
                text: "Copyright (c) 2013-2025 Filippo Scognamiglio <flscogna@gmail.com>\n\n"
                      + "https://github.com/Swordfish90/cool-retro-term\n\n" +
                      "cool-retro-term is free software: you can redistribute it and/or modify "
                      + "it under the terms of the GNU General Public License as published by "
                      + "the Free Software Foundation, either version 3 of the License, or "
                      + "(at your option) any later version.\n\n" +
                      "This program is distributed in the hope that it will be useful, "
                      + "but WITHOUT ANY WARRANTY; without even the implied warranty of "
                      + "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the "
                      + "GNU General Public License for more details.\n\n" +
                      "You should have received a copy of the GNU General Public License "
                      + "along with this program.  If not, see <http://www.gnu.org/licenses/>."
            }
        }
    }
}
