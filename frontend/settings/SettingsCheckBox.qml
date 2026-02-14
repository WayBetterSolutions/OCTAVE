import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Item {
    id: control
    height: App.Spacing.dp(44)
    implicitHeight: App.Spacing.dp(44)
    Layout.fillWidth: true

    property bool checked: false
    property string text: ""
    signal toggled(bool checked)

    RowLayout {
        anchors.fill: parent
        spacing: App.Spacing.overallSpacing * 1.5

        Item {
            width: App.Spacing.dp(30)
            height: App.Spacing.dp(30)

            // Glow behind checkbox (spacecraft, when checked)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: parent.height + 6
                radius: App.Spacing.dpMin(App.EnvironmentTheme.active.checkboxRadius + 2, 2)
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
                visible: App.EnvironmentTheme.active.accentBorder && control.checked
            }

            Rectangle {
                id: checkboxRect
                anchors.fill: parent
                radius: App.Spacing.dpMin(App.EnvironmentTheme.active.checkboxRadius, 2)
                color: control.checked ? App.Style.accent : "transparent"
                border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
                border.width: 2

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    visible: control.checked
                    text: "✓"
                    font.pixelSize: App.Spacing.dp(22)
                    color: "white"
                    anchors.centerIn: parent
                    font.family: App.Style.fontFamily
                }

                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.checkboxRadius, 2)
                    opacity: checkboxArea.containsMouse ? 0.1 : 0
                }
            }
        }

        Text {
            text: control.text
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: App.Style.fontFamily
        }
    }

    MouseArea {
        id: checkboxArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            control.checked = !control.checked
            control.toggled(control.checked)
        }
    }
}
