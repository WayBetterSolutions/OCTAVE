import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as App

RadioButton {
    id: control

    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: control.leftPadding
        y: control.height / 2 - height / 2
        radius: App.EnvironmentTheme.active.radioSquare ? 3 : 10
        border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
        border.width: 2

        Rectangle {
            width: 10
            height: 10
            x: 5
            y: 5
            radius: App.EnvironmentTheme.active.radioSquare ? 2 : 5
            color: control.checked ? App.Style.accent : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    contentItem: Text {
        text: control.text
        color: App.Style.primaryTextColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        elide: Text.ElideRight
        width: control.width - control.indicator.width - control.spacing - 10
        font.family: App.Style.fontFamily
    }
}
