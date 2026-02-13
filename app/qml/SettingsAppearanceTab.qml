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

        // SCREEN ///////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Screen")
            showSeparator: false
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            Label {
                text: qsTr("Brightness")
            }
            SimpleSlider {
                onValueChanged: appSettings.brightness = value
                Binding on value { value: appSettings.brightness }
            }
            Label {
                text: qsTr("Contrast")
            }
            SimpleSlider {
                onValueChanged: appSettings.contrast = value
                Binding on value { value: appSettings.contrast }
            }
            Label {
                text: qsTr("Margin")
            }
            SimpleSlider {
                onValueChanged: appSettings._margin = value
                Binding on value { value: appSettings._margin }
            }
            Label {
                text: qsTr("Radius")
            }
            SimpleSlider {
                onValueChanged: appSettings._screenRadius = value
                Binding on value { value: appSettings._screenRadius }
            }
            Label {
                text: qsTr("Opacity")
                visible: !appSettings.isMacOS
            }
            SimpleSlider {
                onValueChanged: appSettings.windowOpacity = value
                Binding on value { value: appSettings.windowOpacity }
                visible: !appSettings.isMacOS
            }
        }

        // COLORS ///////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Colors")
        }
        ColumnLayout {
            Layout.fillWidth: true
            CheckableSlider {
                name: qsTr("Chroma Color")
                onNewValue: function(newValue) { appSettings.chromaColor = newValue }
                value: appSettings.chromaColor
            }
            CheckableSlider {
                name: qsTr("Saturation Color")
                onNewValue: function(newValue) { appSettings.saturationColor = newValue }
                value: appSettings.saturationColor
                enabled: appSettings.chromaColor !== 0
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ColorButton {
                name: qsTr("Font")
                height: 50
                Layout.fillWidth: true
                onColorSelected: appSettings._fontColor = color
                color: appSettings._fontColor
            }
            ColorButton {
                name: qsTr("Background")
                height: 50
                Layout.fillWidth: true
                onColorSelected: appSettings._backgroundColor = color
                color: appSettings._backgroundColor
            }
            ColorButton {
                name: qsTr("Frame")
                height: 50
                Layout.fillWidth: true
                onColorSelected: appSettings._frameColor = color
                color: appSettings._frameColor
            }
        }

        // FRAME ////////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Frame")
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            Label {
                text: qsTr("Size")
            }
            SimpleSlider {
                onValueChanged: appSettings._frameSize = value
                Binding on value { value: appSettings._frameSize }
            }
            StyledCheckBox {
                text: qsTr("Solid color")
                Layout.columnSpan: 2
                onCheckedChanged: {
                    appSettings.solidFrameColor = checked
                    if (!checked)
                        appSettings.flatFrame = false
                }
                Binding on checked { value: appSettings.solidFrameColor }
            }
            StyledCheckBox {
                text: qsTr("Flat")
                Layout.columnSpan: 2
                Layout.leftMargin: 24
                onCheckedChanged: appSettings.flatFrame = checked
                Binding on checked { value: appSettings.flatFrame }
                enabled: appSettings.solidFrameColor
            }
        }

        Item { height: 20 }
    }
}
