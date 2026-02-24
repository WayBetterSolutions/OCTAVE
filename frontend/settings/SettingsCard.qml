import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: card
    default property alias cardContent: cardLayout.data

    Layout.fillWidth: true
    color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.07)
    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.cardRadius, 2)
    implicitHeight: cardLayout.implicitHeight + App.Spacing.overallSpacing * 3
    clip: true

    // Accent border (spacecraft)
    border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
    border.color: App.EnvironmentTheme.active.accentBorder
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                  App.EnvironmentTheme.active.accentBorderOpacity) : "transparent"

    // Top-edge accent highlight (spacecraft)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: App.Spacing.dp(App.EnvironmentTheme.active.cardRadius)
        anchors.rightMargin: App.Spacing.dp(App.EnvironmentTheme.active.cardRadius)
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
        anchors.leftMargin: App.Spacing.dp(App.EnvironmentTheme.active.cardRadius * 0.5)
        anchors.rightMargin: App.Spacing.dp(App.EnvironmentTheme.active.cardRadius * 0.5)
        height: 1
        radius: 0.5
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.15)
        visible: App.EnvironmentTheme.active.cardGlassEffect
    }

    App.CornerBrackets {
        bracketLength: App.Spacing.dp(15)
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
