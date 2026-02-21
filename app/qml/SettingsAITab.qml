/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://crtplus.fromhelloworld.com
* https://github.com/hotbit9
*
* This file is part of CRT Plus.
*
* CRT Plus is free software: you can redistribute it and/or modify
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

        SectionHeader {
            text: qsTr("Notifications")
            showSeparator: false
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("AI coding assistants like Claude and Gemini set a special character in the terminal title when they need your attention. Unlike traditional CLI tools, most AI assistants don't send a BEL (bell) signal when they finish, so CRT Plus watches for these title characters instead to show a badge on the tab and dock icon when you're on a different tab or app. You can add or remove characters below. Clear the field to disable detection.")
        }

        // Product names "Claude" and "Gemini" are used here under nominative
        // use — factually describing what those tools do, not implying
        // endorsement or affiliation.  Google's Brand Resource Center
        // explicitly permits informational plain-text references.  Anthropic
        // has no published trademark guidelines but the same principle applies.
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.6
            text: qsTr("Known defaults:  \u2733 Claude (idle)  \u00B7  \u25C7 Gemini (ready)  \u00B7  \u270B Gemini (action required)")
        }

        TextField {
            id: attentionField
            Layout.fillWidth: true
            text: appSettings.attentionChars
            placeholderText: appSettings.defaultAttentionChars
            onEditingFinished: appSettings.attentionChars = text
            function saveSetting() { appSettings.attentionChars = text }
            Component.onCompleted: settings_window.closing.connect(saveSetting)

            Connections {
                target: appSettings
                onAttentionCharsChanged: attentionField.text = appSettings.attentionChars
            }
        }

        Button {
            text: qsTr("Reset to Defaults")
            onClicked: appSettings.attentionChars = appSettings.defaultAttentionChars
        }

        Item { height: 20 }
    }
}
