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
    radius: App.EnvironmentTheme.active.cardRadius
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

    // Solid accent-tinted card background
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: {
            var base = App.Style.contentColor
            return Qt.rgba(
                base.r * 0.92 + App.Style.accent.r * 0.08,
                base.g * 0.92 + App.Style.accent.g * 0.08,
                base.b * 0.92 + App.Style.accent.b * 0.08,
                0.95
            )
        }
    }

    // Frosted glass gradient overlay (deep sea)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: App.EnvironmentTheme.active.cardGlassEffect
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.05) }
            GradientStop { position: 0.4; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.03) }
        }
    }

    // Corner brackets — Top Left (spacecraft)
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: 12; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: 1; height: 12
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Top Right (spacecraft)
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: 12; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: 1; height: 12
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Left (spacecraft)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: 12; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: 1; height: 12
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Right (spacecraft)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: 12; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, hubCard.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: 1; height: 12
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
            columnSpacing: App.Spacing.overallSpacing * 0.8
            rowSpacing: 2
            visible: hubCard.widgetItems.length > 0

            Repeater {
                model: hubCard.widgetItems.length

                Row {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing * 0.3

                    // Status dot — only visible when statusColor is set
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: (hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor)
                               ? hubCard.widgetItems[index].statusColor : "transparent"
                        visible: hubCard.widgetItems[index] && hubCard.widgetItems[index].statusColor !== ""
                        anchors.verticalCenter: parent.verticalCenter
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
