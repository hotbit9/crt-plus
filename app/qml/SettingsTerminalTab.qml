import QtQuick 2.2
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1

import "Components"

Flickable {
    contentHeight: column.implicitHeight
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: parent.width

        // FONT /////////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Font")
            showSeparator: false
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            Label {
                text: qsTr("Source")
            }
            RowLayout {
                Layout.fillWidth: true
                RadioButton {
                    text: qsTr("Bundled")
                    onClicked: appSettings.fontSource = appSettings.bundled_fonts
                    Binding on checked { value: appSettings.fontSource === appSettings.bundled_fonts }
                }
                RadioButton {
                    text: qsTr("System")
                    onClicked: appSettings.fontSource = appSettings.system_fonts
                    Binding on checked { value: appSettings.fontSource === appSettings.system_fonts }
                }
            }
            Label {
                text: qsTr("Rendering")
                enabled: appSettings.fontSource === appSettings.bundled_fonts
            }
            ComboBox {
                id: renderingBox
                Layout.fillWidth: true
                model: [qsTr("Default"), qsTr("Scanlines"), qsTr("Pixels"), qsTr("Sub-Pixels"), qsTr("Modern")]
                onCurrentIndexChanged: appSettings.rasterization = currentIndex
                Binding on currentIndex { value: appSettings.rasterization }
                enabled: appSettings.fontSource === appSettings.bundled_fonts
            }
            Label {
                text: qsTr("Name")
            }
            ComboBox {
                id: fontChanger
                Layout.fillWidth: true
                model: appSettings.filteredFontList
                textRole: "text"
                onActivated: {
                    var font = appSettings.filteredFontList.get(currentIndex)

                    if (!font.lowResolutionFont && appSettings.rasterization !== appSettings.modern_rasterization) {
                        appSettings.rasterization = appSettings.modern_rasterization
                    }
                    if (font.lowResolutionFont && appSettings.rasterization === appSettings.modern_rasterization) {
                        appSettings.rasterization = appSettings.no_rasterization
                    }

                    appSettings.fontName = font.name
                }
                function updateIndex() {
                    for (var i = 0; i < appSettings.filteredFontList.count; i++) {
                        var font = appSettings.filteredFontList.get(i)
                        if (font.name === appSettings.fontName) {
                            currentIndex = i
                            return
                        }
                    }
                    currentIndex = 0
                }
                Connections {
                    target: appSettings.fontManager

                    onTerminalFontChanged: {
                        fontChanger.updateIndex()
                    }

                    onFilteredFontListChanged: {
                        fontChanger.updateIndex()
                    }
                }
                Component.onCompleted: updateIndex()
            }
            Label {
                text: qsTr("Scaling")
            }
            RowLayout {
                Layout.fillWidth: true
                StyledSlider {
                    Layout.fillWidth: true
                    id: fontScalingChanger
                    onValueChanged: appSettings.fontScaling = value
                    Binding on value { value: appSettings.fontScaling }
                    stepSize: 0.05
                    from: appSettings.minimumFontScaling
                    to: appSettings.maximumFontScaling
                }
                SizedLabel {
                    text: Math.round(fontScalingChanger.value * 100) + "%"
                }
            }
            Label {
                text: qsTr("Font Width")
            }
            RowLayout {
                Layout.fillWidth: true
                StyledSlider {
                    Layout.fillWidth: true
                    id: widthChanger
                    onValueChanged: appSettings.fontWidth = value
                    Binding on value { value: appSettings.fontWidth }
                    stepSize: 0.05
                    from: 0.5
                    to: 1.5
                }
                SizedLabel {
                    text: Math.round(widthChanger.value * 100) + "%"
                }
            }
            Label {
                text: qsTr("Line Spacing")
            }
            RowLayout {
                Layout.fillWidth: true
                StyledSlider {
                    Layout.fillWidth: true
                    id: lineSpacingChanger
                    onValueChanged: appSettings.lineSpacing = value
                    Binding on value { value: appSettings.lineSpacing }
                    stepSize: 0.01
                    from: 0.0
                    to: 1.0
                }
                SizedLabel {
                    text: Math.round(lineSpacingChanger.value * 100) + "%"
                }
            }
        }

        // SHELL ////////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Shell")
        }
        ColumnLayout {
            Layout.fillWidth: true
            StyledCheckBox {
                id: useCustomCommand
                text: qsTr("Use custom command instead of shell at startup")
                checked: appSettings.useCustomCommand
                onCheckedChanged: appSettings.useCustomCommand = checked
            }
            TextField {
                id: customCommand
                Layout.fillWidth: true
                text: appSettings.customCommand
                enabled: useCustomCommand.checked
                onEditingFinished: appSettings.customCommand = text

                function saveSetting() {
                    appSettings.customCommand = text
                }
                Component.onCompleted: settings_window.closing.connect(
                                           saveSetting)
            }
            StyledCheckBox {
                id: blinkingCursor
                text: qsTr("Blinking Cursor")
                onCheckedChanged: appSettings.blinkingCursor = checked
                Binding on checked { value: appSettings.blinkingCursor }
            }
            StyledCheckBox {
                id: showMenubar
                text: qsTr("Show Menubar")
                enabled: !appSettings.isMacOS
                checked: appSettings.showMenubar
                onCheckedChanged: appSettings.showMenubar = checked
            }
        }

        // EDITORS //////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Editors")
        }
        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Open file paths with (local editor)")
            }
            TextField {
                id: editorCommand
                Layout.fillWidth: true
                text: appSettings.editorCommand
                placeholderText: qsTr("Auto-detect (code, subl, vim...)")
                onEditingFinished: appSettings.editorCommand = text
                function saveSetting() { appSettings.editorCommand = text }
                Component.onCompleted: settings_window.closing.connect(saveSetting)
            }
            Label { text: qsTr("Open remote file paths with (over SSH)") }
            TextField {
                id: remoteEditorCommand
                Layout.fillWidth: true
                text: appSettings.remoteEditorCommand
                placeholderText: qsTr("Default: vim")
                onEditingFinished: appSettings.remoteEditorCommand = text
                function saveSetting() { appSettings.remoteEditorCommand = text }
                Component.onCompleted: settings_window.closing.connect(saveSetting)
            }
            Label { text: qsTr("Shell prompt characters (for split pane detection)") }
            TextField {
                id: promptCharacters
                Layout.fillWidth: true
                text: appSettings.promptCharacters
                placeholderText: qsTr("Default: $, #, %, >")
                onEditingFinished: appSettings.promptCharacters = text
                function saveSetting() { appSettings.promptCharacters = text }
                Component.onCompleted: settings_window.closing.connect(saveSetting)
            }
        }

        Item { height: 20 }
    }
}
