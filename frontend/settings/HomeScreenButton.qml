import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Item {
    id: control
    width: 64
    height: 44
    Layout.alignment: Qt.AlignCenter

    property bool isActive: false
    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: control.isActive ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) : "transparent"
        border.color: control.isActive ? App.Style.accent : "transparent"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: homeButtonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        }

        Image {
            id: homeIcon
            anchors.centerIn: parent
            source: "../assets/home_button.svg"
            width: App.Spacing.settingsButtonHeight * .3
            height: App.Spacing.settingsButtonHeight * .3
            sourceSize.width: App.Spacing.settingsButtonHeight * .3
            sourceSize.height: App.Spacing.settingsButtonHeight * .3
        }
    }

    MouseArea {
        id: homeButtonArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: control.clicked()
    }
}
