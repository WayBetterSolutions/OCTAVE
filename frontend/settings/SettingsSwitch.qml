import QtQuick 2.15
import QtQuick.Controls 2.15
import ".." as App

Switch {
    id: control

    indicator: Item {
        implicitWidth: App.Spacing.dp(48)
        implicitHeight: App.Spacing.dp(26)
        x: control.leftPadding
        y: control.height / 2 - height / 2

        // Glow behind track (spacecraft, when checked)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: App.Spacing.dpMin(App.EnvironmentTheme.active.switchRadius + 3, 2)
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
            visible: App.EnvironmentTheme.active.accentBorder && control.checked
        }

        // Track
        Rectangle {
            anchors.fill: parent
            radius: App.Spacing.dpMin(App.EnvironmentTheme.active.switchRadius, 2)
            color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
            border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
            border.color: control.checked
                ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                : Qt.rgba(App.Style.secondaryTextColor.r, App.Style.secondaryTextColor.g, App.Style.secondaryTextColor.b, 0.5)

            Behavior on color { ColorAnimation { duration: 150 } }

            // Knob
            Rectangle {
                x: control.checked ? parent.width - width - App.Spacing.dp(3) : App.Spacing.dp(3)
                width: App.Spacing.dp(20)
                height: App.Spacing.dp(20)
                radius: App.Spacing.dpMin(App.EnvironmentTheme.active.switchKnobRadius, 2)
                anchors.verticalCenter: parent.verticalCenter
                color: "white"

                Behavior on x { NumberAnimation { duration: 150 } }
            }
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
