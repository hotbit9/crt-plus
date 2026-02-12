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
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.1
import QtQuick.Dialogs

import "Components"

ColumnLayout {
    GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        title: qsTr("Profile")
        padding: appSettings.defaultMargin
        RowLayout {
            anchors.fill: parent
            ListView {
                id: profilesView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: appSettings.profilesList
                currentIndex: appSettings.currentProfileIndex
                clip: true
                Connections {
                    target: appSettings
                    function onProfileChanged() {
                        profilesView.currentIndex = appSettings.currentProfileIndex
                    }
                }
                section.property: "builtin"
                section.delegate: Rectangle {
                    width: profilesView.width
                    height: sectionLabel.implicitHeight + 4
                    color: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.08)
                    Label {
                        id: sectionLabel
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 4
                        text: section === "true" ? qsTr("Built-in") : qsTr("Custom")
                        font.italic: true
                        opacity: 0.6
                    }
                }
                delegate: Rectangle {
                    property bool isSeparator: appSettings.profilesList.get(index).obj_string === ""
                    width: profilesView.width
                    height: isSeparator ? 0 : label.height
                    visible: !isSeparator
                    color: index == profilesView.currentIndex ? palette.highlight : palette.base
                    MouseArea {
                        anchors.fill: parent
                        onClicked: profilesView.currentIndex = index
                        onDoubleClicked: appSettings.loadProfile(index)
                    }
                    Label {
                        id: label
                        text: {
                            var name = appSettings.profilesList.get(index).text
                            if (name === appSettings.defaultProfileName)
                                return name + " \u2605"
                            return name
                        }
                        font.bold: index == appSettings.currentProfileIndex
                    }
                }
            }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: false
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Duplicate")
                    onClicked: {
                        insertname.profileName = ""
                        insertname.show()
                    }
                }
                Button {
                    Layout.fillWidth: true
                    property alias currentIndex: profilesView.currentIndex
                    enabled: currentIndex >= 0
                    text: qsTr("Load")
                    onClicked: {
                        var index = currentIndex
                        if (index >= 0)
                            appSettings.loadProfile(index)
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Update")
                    property alias currentIndex: profilesView.currentIndex
                    enabled: currentIndex >= 0
                             && currentIndex === appSettings.currentProfileIndex
                    onClicked: {
                        appSettings.profilesList.setProperty(currentIndex, "obj_string",
                                                             appSettings.composeProfileString())
                        appSettings.storeCustomProfiles()
                        appSettings.storage.setSetting("_MODIFIED_BUILTINS",
                                                       appSettings.composeModifiedBuiltinsString())
                        feedbackLabel.text = qsTr("✓ Updated"); feedbackTimer.restart()
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Reset")
                    property alias currentIndex: profilesView.currentIndex
                    enabled: currentIndex >= 0
                             && appSettings.profilesList.get(currentIndex).builtin
                             && appSettings.isBuiltinProfileModified(currentIndex)
                    onClicked: {
                        appSettings.resetBuiltinProfile(currentIndex)
                        appSettings.loadProfile(currentIndex)
                        feedbackLabel.text = qsTr("✓ Reset"); feedbackTimer.restart()
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Remove")
                    property alias currentIndex: profilesView.currentIndex

                    enabled: currentIndex >= 0 && !appSettings.profilesList.get(
                                 currentIndex).builtin
                    onClicked: {
                        confirmRemoveDialog.profileIndex = currentIndex
                        confirmRemoveDialog.profileName = appSettings.profilesList.get(currentIndex).text
                        confirmRemoveDialog.open()
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Set Default")
                    property alias currentIndex: profilesView.currentIndex
                    enabled: currentIndex >= 0 && appSettings.profilesList.get(
                                 currentIndex).text !== appSettings.defaultProfileName
                    onClicked: {
                        appSettings.setDefaultProfile(currentIndex)
                        feedbackLabel.text = qsTr("✓ Default set"); feedbackTimer.restart()
                    }
                }
                Label {
                    id: feedbackLabel
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    opacity: feedbackTimer.running ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Timer {
                    id: feedbackTimer
                    interval: 2000
                }
                Item {
                    // Spacing
                    Layout.fillHeight: true
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("Import")
                    onClicked: {
                        fileDialog.selectExisting = true
                        fileDialog.callBack = function (url) {
                            loadFile(url)
                        }
                        fileDialog.open()
                    }
                    function loadFile(url) {
                        try {
                            if (appSettings.verbose)
                                console.log("Loading file: " + url)

                            var profileObject = JSON.parse(fileIO.read(url))
                            var name = profileObject.name

                            if (!name)
                                throw "Profile doesn't have a name"

                            var version = profileObject.version
                                    !== undefined ? profileObject.version : 1
                            if (version !== appSettings.profileVersion)
                                throw "This profile is not supported on this version of CRT."

                            delete profileObject.name

                            appSettings.appendCustomProfile(name,
                                                            JSON.stringify(
                                                                profileObject))
                        } catch (err) {
                            messageDialog.text = qsTr(err)
                            messageDialog.open()
                        }
                    }
                }
                Button {
                    property alias currentIndex: profilesView.currentIndex

                    Layout.fillWidth: true

                    text: qsTr("Export")
                    enabled: currentIndex >= 0 && !appSettings.profilesList.get(
                                 currentIndex).builtin
                    onClicked: {
                        fileDialog.selectExisting = false
                        fileDialog.callBack = function (url) {
                            storeFile(url)
                        }
                        fileDialog.open()
                    }
                    function storeFile(url) {
                        try {
                            var urlString = url.toString()

                            // Fix the extension if it's missing.
                            var extension = urlString.substring(
                                        urlString.length - 5, urlString.length)
                            var urlTail = (extension === ".json" ? "" : ".json")
                            url += urlTail

                            if (appSettings.verbose)
                                console.log("Storing file: " + url)

                            var profileObject = appSettings.profilesList.get(
                                        currentIndex)
                            var profileSettings = JSON.parse(
                                        profileObject.obj_string)
                            profileSettings["name"] = profileObject.text
                            profileSettings["version"] = appSettings.profileVersion

                            var result = fileIO.write(url, JSON.stringify(
                                                          profileSettings,
                                                          undefined, 2))
                            if (!result)
                                throw "The file could not be written."
                        } catch (err) {
                            console.log(err)
                            messageDialog.text = qsTr(
                                        "There has been an error storing the file.")
                            messageDialog.open()
                        }
                    }
                }
            }
        }
    }

    GroupBox {
        title: qsTr("Screen")
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: appSettings.defaultMargin
        GridLayout {
            anchors.fill: parent
            columns: 2
            Label {
                text: qsTr("Brightness")
            }
            SimpleSlider {
                onValueChanged: appSettings.brightness = value
                value: appSettings.brightness
            }
            Label {
                text: qsTr("Contrast")
            }
            SimpleSlider {
                onValueChanged: appSettings.contrast = value
                value: appSettings.contrast
            }
            Label {
                text: qsTr("Margin")
            }
            SimpleSlider {
                onValueChanged: appSettings._margin = value
                value: appSettings._margin
            }
            Label {
                text: qsTr("Radius")
            }
            SimpleSlider {
                onValueChanged: appSettings._screenRadius = value
                value: appSettings._screenRadius
            }
            Label {
                text: qsTr("Frame size")
            }
            SimpleSlider {
                onValueChanged: appSettings._frameSize = value
                value: appSettings._frameSize
            }
            // Solid: use frame color directly; off: mix with font/background based on ambient light
            StyledCheckBox {
                text: qsTr("Solid frame color")
                Layout.columnSpan: 2
                checked: appSettings.solidFrameColor
                onCheckedChanged: appSettings.solidFrameColor = checked
                enabled: appSettings._frameSize > 0
            }
            Label {
                text: qsTr("Opacity")
                visible: !appSettings.isMacOS
            }
            SimpleSlider {
                onValueChanged: appSettings.windowOpacity = value
                value: appSettings.windowOpacity
                visible: !appSettings.isMacOS
            }
        }
    }

    // DIALOGS ////////////////////////////////////////////////////////////////
    InsertNameDialog {
        id: insertname
        onNameSelected: {
            appSettings.appendCustomProfile(name,
                                            appSettings.composeProfileString())
        }
    }
    MessageDialog {
        id: confirmRemoveDialog
        property int profileIndex: -1
        property string profileName
        title: qsTr("Remove Profile")
        text: qsTr("Remove \"%1\"?").arg(profileName)
        buttons: MessageDialog.Yes | MessageDialog.No
        onAccepted: {
            var removedIndex = profileIndex

            if (appSettings.profilesList.get(removedIndex).text === appSettings.defaultProfileName) {
                appSettings.defaultProfileName = ""
                appSettings.storage.setSetting("_DEFAULT_PROFILE_NAME", "")
            }

            appSettings.profilesList.remove(removedIndex)

            if (removedIndex < appSettings.currentProfileIndex) {
                appSettings.currentProfileIndex--
            } else if (removedIndex === appSettings.currentProfileIndex) {
                appSettings.currentProfileIndex = -1
            }

            profilesView.selection.clear()

            // TODO This is a very ugly workaround. The view didn't update on Qt 5.3.2.
            profilesView.model = 0
            profilesView.model = appSettings.profilesList
            feedbackLabel.text = qsTr("✓ Removed"); feedbackTimer.restart()
        }
    }
    MessageDialog {
        id: messageDialog
        title: qsTr("File Error")
        buttons: MessageDialog.Ok
        onAccepted: {
            messageDialog.close()
        }
    }
    Loader {
        property var callBack
        property bool selectExisting: false
        id: fileDialog

        sourceComponent: FileDialog {
            nameFilters: ["Json files (*.json)"]
            fileMode: fileDialog.selectExisting ? FileDialog.OpenFile : FileDialog.SaveFile
            onAccepted: callBack(selectedFile)
        }

        onSelectExistingChanged: reload()

        function open() {
            item.open()
        }

        function reload() {
            active = false
            active = true
        }
    }
}
