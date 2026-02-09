import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

TextField {
    id: control
    Layout.preferredHeight: App.Spacing.formElementHeight
    Layout.preferredWidth: 500
    Layout.maximumWidth: 800
    color: App.Style.primaryTextColor
    font.pixelSize: App.Spacing.overallText
    placeholderTextColor: App.Style.secondaryTextColor
    leftPadding: 20
    rightPadding: 20
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        color: App.Style.hoverColor
        radius: App.EnvironmentTheme.active.textFieldRadius
        border.color: control.activeFocus ? App.Style.accent : "transparent"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        // Corner marks — Top Left (spacecraft)
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left
            anchors.topMargin: -1; anchors.leftMargin: -1
            width: 8; height: 1
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left
            anchors.topMargin: -1; anchors.leftMargin: -1
            width: 1; height: 8
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }

        // Corner marks — Top Right (spacecraft)
        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -1; anchors.rightMargin: -1
            width: 8; height: 1
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }
        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -1; anchors.rightMargin: -1
            width: 1; height: 8
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }

        // Corner marks — Bottom Left (spacecraft)
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left
            anchors.bottomMargin: -1; anchors.leftMargin: -1
            width: 8; height: 1
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left
            anchors.bottomMargin: -1; anchors.leftMargin: -1
            width: 1; height: 8
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }

        // Corner marks — Bottom Right (spacecraft)
        Rectangle {
            anchors.bottom: parent.bottom; anchors.right: parent.right
            anchors.bottomMargin: -1; anchors.rightMargin: -1
            width: 8; height: 1
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }
        Rectangle {
            anchors.bottom: parent.bottom; anchors.right: parent.right
            anchors.bottomMargin: -1; anchors.rightMargin: -1
            width: 1; height: 8
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                control.activeFocus ? 0.8 : 0.4)
            visible: App.EnvironmentTheme.active.textFieldCornerMarks
        }

        Behavior on border.color { ColorAnimation { duration: 200 } }
    }
}
