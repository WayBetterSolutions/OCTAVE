import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../.." as App

Rectangle {
    id: chip

    property string text: ""
    signal clicked()

    Layout.preferredWidth: chipText.implicitWidth + App.Spacing.overallSpacing * 1.4
    implicitWidth: chipText.implicitWidth + App.Spacing.overallSpacing * 1.4
    implicitHeight: App.Spacing.dp(26)
    radius: App.EnvironmentTheme.active.chipRadius === -1
        ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

    color: chipArea.containsMouse
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
        : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.1)

    border.width: 1
    border.color: chipArea.containsMouse
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.6)
        : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.text
        color: chipArea.containsMouse ? App.Style.accent : App.Style.primaryTextColor
        font.pixelSize: App.Spacing.overallText * 0.85
        font.family: App.Style.fontFamily

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
