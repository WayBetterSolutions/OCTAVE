import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as App

RadioButton {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: control

    indicator: Rectangle {
        implicitWidth: dp(20)
        implicitHeight: dp(20)
        x: control.leftPadding
        y: control.height / 2 - height / 2
        radius: App.EnvironmentTheme.active.radioSquare ? dpMin(3, 1) : width / 2
        border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
        border.width: 2

        Rectangle {
            width: dp(10)
            height: dp(10)
            anchors.centerIn: parent
            radius: App.EnvironmentTheme.active.radioSquare ? dpMin(2, 1) : width / 2
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
        width: control.width - control.indicator.width - control.spacing - dp(10)
        font.family: App.Style.fontFamily
    }
}
