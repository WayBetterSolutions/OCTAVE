import QtQuick 2.15
import "." as App

// Reusable pulsing corner bracket overlay for spacecraft theme.
// Drop inside any Rectangle parent — anchors.fill is set automatically.
// Caller controls visibility; pulse animation runs internally.
Item {
    id: brackets
    anchors.fill: parent

    property real bracketLength: App.Spacing.dp(12)

    // Internal pulse
    property real _pulse: 0.5
    SequentialAnimation on _pulse {
        running: brackets.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.8; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.3; duration: 2000; easing.type: Easing.InOutSine }
    }

    property color _color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, _pulse)

    // Top Left
    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.topMargin: -1; anchors.leftMargin: -1; width: brackets.bracketLength; height: 1; color: brackets._color }
    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.topMargin: -1; anchors.leftMargin: -1; width: 1; height: brackets.bracketLength; color: brackets._color }

    // Top Right
    Rectangle { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -1; anchors.rightMargin: -1; width: brackets.bracketLength; height: 1; color: brackets._color }
    Rectangle { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -1; anchors.rightMargin: -1; width: 1; height: brackets.bracketLength; color: brackets._color }

    // Bottom Left
    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.bottomMargin: -1; anchors.leftMargin: -1; width: brackets.bracketLength; height: 1; color: brackets._color }
    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.bottomMargin: -1; anchors.leftMargin: -1; width: 1; height: brackets.bracketLength; color: brackets._color }

    // Bottom Right
    Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.bottomMargin: -1; anchors.rightMargin: -1; width: brackets.bracketLength; height: 1; color: brackets._color }
    Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.bottomMargin: -1; anchors.rightMargin: -1; width: 1; height: brackets.bracketLength; color: brackets._color }
}
