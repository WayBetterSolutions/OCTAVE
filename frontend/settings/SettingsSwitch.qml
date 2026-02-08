import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as App

Switch {
    id: control

    indicator: Rectangle {
        implicitWidth: 48
        implicitHeight: 26
        x: control.leftPadding
        y: control.height / 2 - height / 2
        radius: 13
        color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
        border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor

        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: "white"

            Behavior on x { NumberAnimation { duration: 150 } }
        }
    }

    contentItem: Text {
        text: control.text
        color: App.Style.primaryTextColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        font.family: App.Style.fontFamily
    }
}
