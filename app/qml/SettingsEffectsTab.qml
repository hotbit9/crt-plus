import QtQuick 2.2
import QtQuick.Controls 2.0
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
        spacing: 2

        // EFFECTS //////////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Effects")
            showSeparator: false
        }
        ColumnLayout {
            Layout.fillWidth: true

            CheckableSlider {
                name: qsTr("Bloom")
                onNewValue: function(newValue) { appSettings.bloom = newValue }
                value: appSettings.bloom
            }
            CheckableSlider {
                name: qsTr("BurnIn")
                onNewValue: function(newValue) { appSettings.burnIn = newValue }
                value: appSettings.burnIn
            }
            CheckableSlider {
                name: qsTr("Static Noise")
                onNewValue: function(newValue) { appSettings.staticNoise = newValue }
                value: appSettings.staticNoise
            }
            CheckableSlider {
                name: qsTr("Jitter")
                onNewValue: function(newValue) { appSettings.jitter = newValue }
                value: appSettings.jitter
            }
            CheckableSlider {
                name: qsTr("Glow Line")
                onNewValue: function(newValue) { appSettings.glowingLine = newValue }
                value: appSettings.glowingLine
            }
            CheckableSlider {
                name: qsTr("Screen Curvature")
                onNewValue: function(newValue) { appSettings.screenCurvature = newValue }
                value: appSettings.screenCurvature
            }
            CheckableSlider {
                name: qsTr("Ambient Light")
                onNewValue: function(newValue) { appSettings.ambientLight = newValue }
                value: appSettings.ambientLight
            }
            CheckableSlider {
                name: qsTr("Flickering")
                onNewValue: function(newValue) { appSettings.flickering = newValue }
                value: appSettings.flickering
            }
            CheckableSlider {
                name: qsTr("Horizontal Sync")
                onNewValue: function(newValue) { appSettings.horizontalSync = newValue }
                value: appSettings.horizontalSync
            }
            CheckableSlider {
                name: qsTr("RGB Shift")
                onNewValue: function(newValue) { appSettings.rgbShift = newValue }
                value: appSettings.rgbShift
            }
            CheckableSlider {
                name: qsTr("Frame Shininess")
                onNewValue: function(newValue) { appSettings._frameShininess = newValue }
                value: appSettings._frameShininess
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Impedance")
                    Layout.preferredWidth: 160
                }
                Label {
                    text: qsTr("75\u03A9")
                }
                Switch {
                    onCheckedChanged: appSettings.highImpedance = checked
                    Binding on checked { value: appSettings.highImpedance }
                }
                Label {
                    text: qsTr("Hi-Z")
                }
                Item { Layout.fillWidth: true }
            }
        }

        // PERFORMANCE //////////////////////////////////////////////////////////
        SectionHeader {
            text: qsTr("Performance")
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4

            Label {
                text: qsTr("Effects FPS")
            }
            StyledSlider {
                Layout.fillWidth: true
                Layout.columnSpan: 2
                id: effectsFpsSlider
                onValueChanged: appSettings.effectsFrameSkip = Math.round(value)
                stepSize: 1
                from: 5
                to: 1
                Binding on value { value: appSettings.effectsFrameSkip }
            }
            SizedLabel {
                text: Math.round(100 / Math.max(1, Math.round(effectsFpsSlider.value))) + "%"
            }
            Label {
                text: qsTr("Texture Quality")
            }
            StyledSlider {
                id: txtslider
                Layout.fillWidth: true
                Layout.columnSpan: 2
                onValueChanged: appSettings.windowScaling = value
                stepSize: 0.05
                from: 0.25
                Binding on value { value: appSettings.windowScaling }
            }
            SizedLabel {
                text: Math.round(txtslider.value * 100) + "%"
            }

            Label {
                text: qsTr("Bloom Quality")
            }
            StyledSlider {
                Layout.fillWidth: true
                Layout.columnSpan: 2
                id: bloomSlider
                onValueChanged: appSettings.bloomQuality = value
                stepSize: 0.05
                from: 0.25
                Binding on value { value: appSettings.bloomQuality }
            }
            SizedLabel {
                text: Math.round(bloomSlider.value * 100) + "%"
            }

            Label {
                text: qsTr("BurnIn Quality")
            }
            StyledSlider {
                Layout.fillWidth: true
                id: burnInSlider
                Layout.columnSpan: 2
                onValueChanged: appSettings.burnInQuality = value
                stepSize: 0.05
                from: 0.25
                Binding on value { value: appSettings.burnInQuality }
            }
            SizedLabel {
                text: Math.round(burnInSlider.value * 100) + "%"
            }
        }

        Item { height: 20 }
    }
}
