import QtQuick 2.2
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.1
import QtQuick.Dialogs

RowLayout {
    id: profilesTab
    spacing: 12

    // Selection state — tracks index into appSettings.profilesList
    property int selectedIndex: appSettings.currentProfileIndex

    // Shared style for profile list boxes
    readonly property color listBorderColor: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.15)

    Connections {
        target: appSettings
        function onProfileChanged() {
            selectedIndex = appSettings.currentProfileIndex
        }
    }

    // PROFILE LISTS ////////////////////////////////////////////////////////
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Label {
            id: builtinLabel
            text: qsTr("Built-in")
            font.bold: true
            font.pixelSize: 13
            opacity: 0.6
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: palette.base
            border.width: 1
            border.color: listBorderColor
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                contentHeight: builtinColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: builtinColumn
                    width: parent.width
                    Repeater {
                        model: appSettings.profilesList
                        delegate: Rectangle {
                            property bool isSeparator: appSettings.profilesList.get(index).obj_string === ""
                            property bool isBuiltin: appSettings.profilesList.get(index).builtin
                            width: builtinColumn.width
                            height: isBuiltin && !isSeparator ? delegateLabel.height : 0
                            visible: isBuiltin && !isSeparator
                            color: index === selectedIndex ? palette.highlight : "transparent"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: selectedIndex = index
                                onDoubleClicked: appSettings.loadProfile(index)
                            }
                            Label {
                                id: delegateLabel
                                leftPadding: 4
                                text: {
                                    var name = appSettings.profilesList.get(index).text
                                    if (name === appSettings.defaultProfileName)
                                        return name + " \u2605"
                                    return name
                                }
                                font.bold: index === appSettings.currentProfileIndex
                                color: index === selectedIndex ? palette.highlightedText : palette.text
                            }
                        }
                    }
                }
            }
        }

        Label {
            text: qsTr("Custom")
            font.bold: true
            font.pixelSize: 13
            opacity: 0.6
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: palette.base
            border.width: 1
            border.color: listBorderColor
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                contentHeight: customColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: customColumn
                    width: parent.width
                    Repeater {
                        model: appSettings.profilesList
                        delegate: Rectangle {
                            property bool isSeparator: appSettings.profilesList.get(index).obj_string === ""
                            property bool isBuiltin: appSettings.profilesList.get(index).builtin
                            width: customColumn.width
                            height: !isBuiltin && !isSeparator ? delegateLabel.height : 0
                            visible: !isBuiltin && !isSeparator
                            color: index === selectedIndex ? palette.highlight : "transparent"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: selectedIndex = index
                                onDoubleClicked: appSettings.loadProfile(index)
                            }
                            Label {
                                id: delegateLabel
                                leftPadding: 4
                                text: {
                                    var name = appSettings.profilesList.get(index).text
                                    if (name === appSettings.defaultProfileName)
                                        return name + " \u2605"
                                    return name
                                }
                                font.bold: index === appSettings.currentProfileIndex
                                color: index === selectedIndex ? palette.highlightedText : palette.text
                            }
                        }
                    }
                }
            }
        }
    }

    // ACTION BUTTONS ///////////////////////////////////////////////////////
    ColumnLayout {
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: builtinLabel.implicitHeight + 10
        Button {
            Layout.fillWidth: true
            text: qsTr("Duplicate")
            enabled: selectedIndex >= 0
            onClicked: {
                var profile = appSettings.profilesList.get(selectedIndex)
                insertname._sourceProfileString = profile.obj_string
                insertname.profileName = profile.text
                insertname.show()
            }
        }
        Button {
            Layout.fillWidth: true
            enabled: selectedIndex >= 0
            text: qsTr("Apply")
            onClicked: appSettings.loadProfile(selectedIndex)
        }
        Button {
            Layout.fillWidth: true
            text: qsTr("Update")
            enabled: appSettings.currentProfileIndex >= 0
                     && appSettings.profileDirty
            onClicked: {
                var idx = appSettings.currentProfileIndex
                appSettings.profilesList.setProperty(idx, "obj_string",
                                                     appSettings.composeProfileString())
                appSettings.storeCustomProfiles()
                appSettings.storage.setSetting("_MODIFIED_BUILTINS",
                                               appSettings.composeModifiedBuiltinsString())
                appSettings._profileSnapshot = appSettings.composeProfileString()
                selectedIndex = idx
                feedbackLabel.text = qsTr("\u2713 Updated"); feedbackTimer.restart()
            }
        }
        Button {
            Layout.fillWidth: true
            text: qsTr("Reset")
            enabled: selectedIndex >= 0
                     && appSettings.profilesList.get(selectedIndex).builtin
                     && appSettings.isBuiltinProfileModified(selectedIndex)
            onClicked: {
                appSettings.resetBuiltinProfile(selectedIndex)
                appSettings.loadProfile(selectedIndex)
                feedbackLabel.text = qsTr("\u2713 Reset"); feedbackTimer.restart()
            }
        }
        Button {
            Layout.fillWidth: true
            text: qsTr("Remove")
            enabled: selectedIndex >= 0 && !appSettings.profilesList.get(
                         selectedIndex).builtin
            onClicked: {
                confirmRemoveDialog.profileIndex = selectedIndex
                confirmRemoveDialog.profileName = appSettings.profilesList.get(selectedIndex).text
                confirmRemoveDialog.open()
            }
        }
        Button {
            Layout.fillWidth: true
            text: qsTr("Set Default")
            enabled: selectedIndex >= 0 && appSettings.profilesList.get(
                         selectedIndex).text !== appSettings.defaultProfileName
            onClicked: {
                appSettings.setDefaultProfile(selectedIndex)
                feedbackLabel.text = qsTr("\u2713 Default set"); feedbackTimer.restart()
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
            Layout.fillWidth: true
            text: qsTr("Export")
            enabled: selectedIndex >= 0 && !appSettings.profilesList.get(
                         selectedIndex).builtin
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

                    var extension = urlString.substring(
                                urlString.length - 5, urlString.length)
                    var urlTail = (extension === ".json" ? "" : ".json")
                    url += urlTail

                    if (appSettings.verbose)
                        console.log("Storing file: " + url)

                    var profileObject = appSettings.profilesList.get(
                                selectedIndex)
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

    // DIALOGS //////////////////////////////////////////////////////////////
    InsertNameDialog {
        id: insertname
        property string _sourceProfileString: ""
        onNameSelected: {
            appSettings.appendCustomProfile(name, _sourceProfileString)
            appSettings.storeCustomProfiles()
            var newIndex = appSettings.profilesList.count - 1
            appSettings.loadProfile(newIndex)
            selectedIndex = newIndex
        }
    }
    Dialog {
        id: confirmRemoveDialog
        property int profileIndex: -1
        property string profileName
        title: qsTr("Remove Profile")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Yes | Dialog.No
        Label {
            text: qsTr("Remove \"%1\"?").arg(confirmRemoveDialog.profileName)
        }
        onAccepted: {
            var removedIndex = profileIndex
            var wasLoaded = (removedIndex === appSettings.currentProfileIndex)

            if (appSettings.profilesList.get(removedIndex).text === appSettings.defaultProfileName) {
                appSettings.defaultProfileName = ""
                appSettings.storage.setSetting("_DEFAULT_PROFILE_NAME", "")
            }

            appSettings.profilesList.remove(removedIndex)
            appSettings.storeCustomProfiles()

            if (wasLoaded) {
                var defaultIndex = appSettings.getProfileIndexByName(appSettings.defaultProfileName)
                if (defaultIndex < 0) defaultIndex = 0
                appSettings.loadProfile(defaultIndex)
                selectedIndex = defaultIndex
            } else if (removedIndex < appSettings.currentProfileIndex) {
                appSettings.currentProfileIndex--
                selectedIndex = appSettings.currentProfileIndex
            }

            feedbackLabel.text = qsTr("\u2713 Removed"); feedbackTimer.restart()
        }
    }
    Dialog {
        id: messageDialog
        property alias text: messageLabel.text
        title: qsTr("File Error")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        Label { id: messageLabel }
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
