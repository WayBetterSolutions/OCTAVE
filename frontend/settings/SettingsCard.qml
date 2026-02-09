import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: card
    default property alias cardContent: cardLayout.data

    Layout.fillWidth: true
    color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.15)
    radius: App.EnvironmentTheme.active.cardRadius
    implicitHeight: cardLayout.implicitHeight + App.Spacing.overallSpacing * 3
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

    // Top-edge accent highlight (spacecraft)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: App.EnvironmentTheme.active.cardRadius
        anchors.rightMargin: App.EnvironmentTheme.active.cardRadius
        height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
        visible: App.EnvironmentTheme.active.accentBorder && !App.EnvironmentTheme.active.cardGlassEffect
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

    // Soft top-edge glow (deep sea — inset accent shimmer)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: App.EnvironmentTheme.active.cardRadius * 0.5
        anchors.rightMargin: App.EnvironmentTheme.active.cardRadius * 0.5
        height: 1
        radius: 0.5
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse * 0.3)
        visible: App.EnvironmentTheme.active.cardGlassEffect
    }

    // Corner brackets — Top Left
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: 15; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        anchors.topMargin: -1; anchors.leftMargin: -1
        width: 1; height: 15
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Top Right
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: 15; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: -1; anchors.rightMargin: -1
        width: 1; height: 15
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Left
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: 15; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left
        anchors.bottomMargin: -1; anchors.leftMargin: -1
        width: 1; height: 15
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Corner brackets — Bottom Right
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: 15; height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.bottomMargin: -1; anchors.rightMargin: -1
        width: 1; height: 15
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, card.bracketPulse)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    ColumnLayout {
        id: cardLayout
        anchors {
            fill: parent
            margins: App.Spacing.overallSpacing * 1.5
        }
        spacing: App.Spacing.rowSpacing
    }
}
