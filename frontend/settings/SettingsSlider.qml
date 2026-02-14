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

    handle: Item {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: App.Spacing.overallSliderWidth
        height: App.Spacing.overallSliderHeight

        // Glow rectangle behind handle (spacecraft only)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: App.EnvironmentTheme.active.sliderHandleRadius === -1
                ? (width / 2) : App.Spacing.dpMin(App.EnvironmentTheme.active.sliderHandleRadius + 3, 2)
            color: Qt.rgba(control.activeColor.r, control.activeColor.g, control.activeColor.b, 0.25)
            visible: App.EnvironmentTheme.active.sliderHandleGlow
        }

        // Actual handle
        Rectangle {
            anchors.fill: parent
            radius: App.EnvironmentTheme.active.sliderHandleRadius === -1
                ? App.Spacing.overallSliderRadius : App.Spacing.dpMin(App.EnvironmentTheme.active.sliderHandleRadius, 2)
            color: control.pressed ? Qt.darker(control.activeColor, 1.1) : control.activeColor

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: App.Spacing.overallSliderHeight / 2

        // Track background
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: App.Style.secondaryTextColor

            // Active track fill
            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                color: control.activeColor
                radius: parent.radius
            }
        }

        // Tick marks below the track (spacecraft only)
        Row {
            anchors.top: parent.bottom
            anchors.topMargin: App.Spacing.dp(4)
            anchors.left: parent.left
            anchors.right: parent.right
            visible: App.EnvironmentTheme.active.sliderTickMarks

            Repeater {
                model: 11
                Item {
                    width: parent.width / 10
                    height: App.Spacing.dp(6)
                    Rectangle {
                        anchors.horizontalCenter: parent.left
                        width: 1
                        height: index % 5 === 0 ? App.Spacing.dp(6) : App.Spacing.dp(3)
                        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                    }
                }
            }
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
