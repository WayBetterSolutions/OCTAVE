import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ".." as App

Flow {
    id: control
    spacing: App.Spacing.overallSpacing
    Layout.fillWidth: true

    property var options: []
    property string currentValue: ""
    property var onSelected: function(value) {}

    Repeater {
        model: control.options

        delegate: Rectangle {
            required property int index
            required property var modelData

            id: chipRect
            width: chipText.width + App.Spacing.overallSpacing * 3
            height: App.Spacing.formElementHeight * 0.8
            radius: height / 2

            color: modelData === control.currentValue ? App.Style.accent : App.Style.hoverColor
            property bool isHovered: false

            border.width: modelData === control.currentValue ? 0 : 1
            border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                App.Style.primaryTextColor.g,
                                App.Style.primaryTextColor.b, 0.1)

            Text {
                id: chipText
                anchors.centerIn: parent
                text: modelData
                color: modelData === control.currentValue ? "white" : App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                font.family: App.Style.fontFamily
            }

            MouseArea {
                id: chipMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: control.onSelected(modelData)
                onEntered: {
                    chipRect.isHovered = true
                    chipRect.scale = 1.05
                }
                onExited: {
                    chipRect.isHovered = false
                    chipRect.scale = 1.0
                }
            }

            layer.enabled: modelData === control.currentValue
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 2
                radius: 4.0
                samples: 9
                color: Qt.rgba(0, 0, 0, 0.2)
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
