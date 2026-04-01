import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Rectangle {
    id: card

    property string label: ""
    property string value: "--"
    property string unit: ""
    property string icon: ""
    property real barValue: -1  // 0-1 for bar, -1 to hide
    property string globalFont: ""
    property bool connected: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: App.Spacing.dp(100)
    radius: App.Spacing.dp(10)
    color: App.Style.headerBackgroundColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: App.Spacing.dp(14)
        spacing: App.Spacing.dp(6)

        // Label row
        RowLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.dp(6)

            Text {
                text: card.icon
                color: App.Style.accent
                font.pixelSize: App.Spacing.dp(16)
            }

            Text {
                text: card.label
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.dp(11)
                font.bold: true
                font.family: card.globalFont
                font.letterSpacing: App.Spacing.dp(1.5)
            }
        }

        Item { Layout.fillHeight: true }

        // Value
        Text {
            text: connected ? card.value : "--"
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.dp(36)
            font.bold: true
            font.family: card.globalFont

            Behavior on text {
                enabled: false
            }
        }

        // Unit
        Text {
            text: card.unit
            color: App.Style.secondaryTextColor
            font.pixelSize: App.Spacing.dp(14)
            font.family: card.globalFont
        }

        // Optional bar indicator
        Rectangle {
            Layout.fillWidth: true
            height: App.Spacing.dp(4)
            radius: App.Spacing.dp(2)
            color: Qt.rgba(App.Style.secondaryTextColor.r, App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.2)
            visible: card.barValue >= 0

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.barValue))
                height: parent.height
                radius: parent.radius
                color: App.Style.accent

                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
