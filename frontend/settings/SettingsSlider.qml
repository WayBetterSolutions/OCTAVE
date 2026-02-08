import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Slider {
    id: control
    Layout.fillWidth: true

    implicitHeight: App.Spacing.overallSliderHeight * 2.5

    property color activeColor: App.Style.settingsSliderColor
    property double visualValue: value
    property string valueDisplay: ""

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: App.Spacing.overallSliderWidth
        height: App.Spacing.overallSliderHeight
        radius: App.Spacing.overallSliderRadius
        color: control.pressed ? Qt.darker(control.activeColor, 1.1) : control.activeColor

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: App.Spacing.overallSliderHeight / 2
        radius: height / 2
        color: App.Style.secondaryTextColor

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            color: control.activeColor
            radius: parent.radius
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) {
            var newPos = Math.max(0, Math.min(1, (mouseX - control.leftPadding) / control.availableWidth))
            control.value = control.from + newPos * (control.to - control.from)
            control.pressed = true
            mouse.accepted = false
        }
        onReleased: function(mouse) {
            control.pressed = false
            mouse.accepted = false
        }
    }
}
