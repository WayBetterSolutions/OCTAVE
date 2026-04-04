import QtQuick 2.15
import QtQuick.Layouts 1.15
import "." as App

Rectangle {
    id: card

    property real lateralG: 0
    property real longitudinalG: 0
    property real magnitude: 0
    property bool connected: false
    property string globalFont: ""
    property int decimalPlaces: 2
    property real maxG: 1.5

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: App.Spacing.dp(100)
    radius: App.Spacing.dp(10)
    color: App.Style.headerBackgroundColor

    // Trail history
    ListModel { id: trailModel }

    Timer {
        running: connected
        interval: 50
        repeat: true
        onTriggered: {
            trailModel.append({ "gx": lateralG, "gy": longitudinalG })
            if (trailModel.count > 30)
                trailModel.remove(0)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: App.Spacing.dp(10)
        spacing: App.Spacing.dp(4)

        // Label
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: App.Spacing.dp(6)

            Text {
                text: "\u2B07"
                color: App.Style.accent
                font.pixelSize: App.Spacing.dp(16)
            }
            Text {
                text: "G-FORCE"
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.dp(11)
                font.bold: true
                font.family: card.globalFont
                font.letterSpacing: App.Spacing.dp(1.5)
            }
        }

        // G-circle visualization
        Item {
            id: circleArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            property real circleSize: Math.min(width, height) * 0.92
            property real cx: width / 2
            property real cy: height / 2
            property real gScale: circleSize / 2 / maxG

            // Outer ring (maxG)
            Rectangle {
                anchors.centerIn: parent
                width: circleArea.circleSize
                height: circleArea.circleSize
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(App.Style.secondaryTextColor.r,
                    App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.2)
                border.width: 1
            }

            // 1g ring
            Rectangle {
                visible: maxG > 1.0
                anchors.centerIn: parent
                width: circleArea.circleSize * (1.0 / maxG)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(App.Style.accent.r, App.Style.accent.g,
                    App.Style.accent.b, 0.25)
                border.width: 1
            }

            // 0.5g ring
            Rectangle {
                anchors.centerIn: parent
                width: circleArea.circleSize * (0.5 / maxG)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(App.Style.secondaryTextColor.r,
                    App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.12)
                border.width: 1
            }

            // Crosshair horizontal
            Rectangle {
                x: circleArea.cx - circleArea.circleSize / 2
                y: circleArea.cy - 0.5
                width: circleArea.circleSize
                height: 1
                color: Qt.rgba(App.Style.secondaryTextColor.r,
                    App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.12)
            }

            // Crosshair vertical
            Rectangle {
                x: circleArea.cx - 0.5
                y: circleArea.cy - circleArea.circleSize / 2
                width: 1
                height: circleArea.circleSize
                color: Qt.rgba(App.Style.secondaryTextColor.r,
                    App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.12)
            }

            // Trail dots
            Repeater {
                model: trailModel
                Rectangle {
                    x: circleArea.cx + model.gx * circleArea.gScale - width / 2
                    y: circleArea.cy - model.gy * circleArea.gScale - height / 2
                    width: App.Spacing.dp(3)
                    height: App.Spacing.dp(3)
                    radius: width / 2
                    color: App.Style.accent
                    opacity: (index + 1) / trailModel.count * 0.3
                }
            }

            // Glow behind dot
            Rectangle {
                id: glow
                property real dotX: circleArea.cx + (connected ? lateralG : 0) * circleArea.gScale
                property real dotY: circleArea.cy - (connected ? longitudinalG : 0) * circleArea.gScale
                x: dotX - width / 2
                y: dotY - height / 2
                width: App.Spacing.dp(22)
                height: App.Spacing.dp(22)
                radius: width / 2
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)

                Behavior on dotX { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                Behavior on dotY { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
            }

            // Current G dot
            Rectangle {
                id: gDot
                x: glow.dotX - width / 2
                y: glow.dotY - height / 2
                width: App.Spacing.dp(10)
                height: App.Spacing.dp(10)
                radius: width / 2
                color: App.Style.accent
            }

            // Scale labels
            Text {
                x: circleArea.cx + circleArea.circleSize * (0.5 / maxG) / 2 + App.Spacing.dp(2)
                y: circleArea.cy + App.Spacing.dp(2)
                text: "0.5"
                color: Qt.rgba(App.Style.secondaryTextColor.r,
                    App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.4)
                font.pixelSize: App.Spacing.dp(8)
                font.family: card.globalFont
            }

            Text {
                visible: maxG > 1.0
                x: circleArea.cx + circleArea.circleSize * (1.0 / maxG) / 2 + App.Spacing.dp(2)
                y: circleArea.cy + App.Spacing.dp(2)
                text: "1.0"
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                font.pixelSize: App.Spacing.dp(8)
                font.family: card.globalFont
            }
        }

        // Value
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: connected ? magnitude.toFixed(decimalPlaces) + " g" : "--"
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.dp(20)
            font.bold: true
            font.family: card.globalFont
        }
    }
}
