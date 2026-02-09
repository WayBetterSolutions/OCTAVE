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

        delegate: Item {
            required property int index
            required property var modelData

            id: chipWrapper
            width: chipRect.width
            height: chipRect.height

            // Glow behind selected chip (spacecraft) — replaces DropShadow
            Rectangle {
                anchors.centerIn: chipRect
                width: chipRect.width + 4
                height: chipRect.height + 4
                radius: chipRect.radius + 2
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                visible: App.EnvironmentTheme.active.chipAccentBorder && modelData === control.currentValue
            }

            Rectangle {
                id: chipRect
                width: chipText.width + App.Spacing.overallSpacing * 3
                height: App.Spacing.formElementHeight * 0.8
                radius: App.EnvironmentTheme.active.chipRadius === -1
                    ? height / 2 : App.EnvironmentTheme.active.chipRadius

                color: modelData === control.currentValue ? App.Style.accent : App.Style.hoverColor

                border.width: App.EnvironmentTheme.active.chipAccentBorder
                    ? 1
                    : (modelData === control.currentValue ? 0 : 1)
                border.color: App.EnvironmentTheme.active.chipAccentBorder
                    ? (modelData === control.currentValue
                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                        : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                    : Qt.rgba(App.Style.primaryTextColor.r,
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
                    onEntered: chipRect.scale = 1.05
                    onExited: chipRect.scale = 1.0
                }

                // Standard DropShadow (hidden in spacecraft mode)
                layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && modelData === control.currentValue
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
}
