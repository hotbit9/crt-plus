import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0

ColumnLayout {
    property string text: ""
    property bool showSeparator: true

    spacing: 0
    Layout.fillWidth: true
    Layout.topMargin: showSeparator ? 16 : 0

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: palette.text
        opacity: 0.12
        visible: showSeparator
    }
    Label {
        Layout.topMargin: showSeparator ? 12 : 0
        Layout.bottomMargin: 8
        text: parent.text
        font.bold: true
        font.pixelSize: 13
        opacity: 0.6
    }
}
