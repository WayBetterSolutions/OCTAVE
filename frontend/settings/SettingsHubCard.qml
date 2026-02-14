import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: hubCard

    property string categoryName: ""
    property string section: ""
    property var widgetItems: []
    property string categoryIcon: ""
    property int cardSpan: 1

    signal categorySelected(string section)

    color: "transparent"
    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.cardRadius, 2)
    clip: true

    // Accent border (spacecraft)
    border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
    border.color: App.EnvironmentTheme.active.accentBorder
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                  App.EnvironmentTheme.active.accentBorderOpacity) : "transparent"

    // Pulsing opacity for corner brackets (spacecraft)
    property real bracketPulse: 0.5
    SequentialAnimation on bracketPulse {
        running: App.EnvironmentTheme.active.pulsingElements
        loops: Animation.Infinite
        NumberAnimation { to: 0.8; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.3; duration: 2000; easing.type: Easing.InOutSine }
    }

    // Glassy translucent card background
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: {
            var base = App.Style.contentColor
            return Qt.rgba(base.r, base.g, base.b, 0.55)
        }
    }

    // Frosted highlight gradient — lighter at top edge, fading down
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top edge highlight line
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Corner brackets — Top Left (spacecraft)
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: App.Spacing.dp(12); height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: 1; height: App.Spacing.dp(12)
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Top Right (spacecraft)
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: App.Spacing.dp(12); height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: 1; height: App.Spacing.dp(12)
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Left (spacecraft)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: App.Spacing.dp(12); height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: 1; height: App.Spacing.dp(12)
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Right (spacecraft)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: App.Spacing.dp(12); height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: 1; height: App.Spacing.dp(12)
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Bottom accent line
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: App.Style.accent }
            GradientStop { position: 0.7; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: 0.6
    }

    // Hover glow overlay
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 1.0)
        opacity: cardMouseArea.containsMouse ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // Card content
    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: App.Spacing.overallSpacing * 1.2
            rightMargin: App.Spacing.overallSpacing * 1.2
            topMargin: App.Spacing.overallSpacing * 0.8
            bottomMargin: App.Spacing.overallSpacing * 0.8
        }
        spacing: App.Spacing.rowSpacing * 0.3

        // Category name row with chevron
        RowLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.overallSpacing * 0.5

            Text {
                text: hubCard.categoryName
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.3
                font.bold: true
                font.family: App.Style.fontFamily
                font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
                font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "\u203A"
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.1
                font.family: App.Style.fontFamily
            }
        }

        // Widget info rows — flows into 2 columns for wide (span-2) cards
        GridLayout {
            Layout.fillWidth: true
            columns: hubCard.cardSpan >= 2 ? 2 : 1
            columnSpacing: App.Spacing.overallSpacing * 0.4
            rowSpacing: App.Spacing.overallSpacing * 0.25
            visible: hubCard.widgetItems.length > 0

            Repeater {
                model: hubCard.widgetItems.length

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dataRow.height + App.Spacing.overallSpacing * 0.5
                    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.cardRadius * 0.5, 2)
                    color: Qt.rgba(App.Style.backgroundColor.r, App.Style.backgroundColor.g, App.Style.backgroundColor.b, 0.7)

                    Row {
                        id: dataRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: App.Spacing.overallSpacing * 0.5
                        anchors.right: parent.right
                        anchors.rightMargin: App.Spacing.overallSpacing * 0.5
                        spacing: App.Spacing.overallSpacing * 0.3

                        // Status dot with pulse — only visible when statusColor is set
                        Item {
                            width: App.Spacing.dp(7)
                            height: App.Spacing.dp(7)
                            visible: hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor !== ""
                            anchors.verticalCenter: parent.verticalCenter

                            // Glow ring
                            Rectangle {
                                width: App.Spacing.dp(11)
                                height: App.Spacing.dp(11)
                                radius: width / 2
                                anchors.centerIn: parent
                                color: (hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor)
                                       ? hubCard.widgetItems[index].statusColor : "transparent"
                                property real pulseOpacity: 0.3
                                opacity: pulseOpacity
                                SequentialAnimation on pulseOpacity {
                                    running: hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor !== ""
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.5; duration: 1500; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.1; duration: 1500; easing.type: Easing.InOutSine }
                                }
                            }

                            // Solid dot
                            Rectangle {
                                width: App.Spacing.dp(7)
                                height: App.Spacing.dp(7)
                                radius: width / 2
                                anchors.centerIn: parent
                                color: (hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor)
                                       ? hubCard.widgetItems[index].statusColor : "transparent"
                            }
                        }

                        Text {
                            text: hubCard.widgetItems[index] ? hubCard.widgetItems[index].label + ":" : ""
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: App.Style.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: hubCard.widgetItems[index] ? hubCard.widgetItems[index].value : ""
                            color: App.Style.accent
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.bold: true
                            font.family: App.Style.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hubCard.categorySelected(hubCard.section)
    }
}
