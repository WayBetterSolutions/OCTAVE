import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

// Equal-size button grid for choosing one of N options, used in place of
// SettingsChips inside the Now Playing studio. Every button takes the same
// cell width so the grid reads as a tidy matrix regardless of label length.
GridLayout {
    id: root
    function dp(s) { return Math.round(s * (App.Spacing.effectiveScale || 1.0)) }

    property var options: []
    property string currentValue: ""
    signal selected(string value)

    Layout.fillWidth: true
    columns: 2
    columnSpacing: root.dp(8)
    rowSpacing: root.dp(8)

    Repeater {
        model: root.options
        delegate: Rectangle {
            id: btn
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(36)
            radius: root.dp(8)

            property bool isSelected: root.currentValue === modelData

            color: isSelected
                ? App.Style.accent
                : (btnMouse.containsMouse
                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.18)
                    : Qt.rgba(App.Style.primaryTextColor.r,
                              App.Style.primaryTextColor.g,
                              App.Style.primaryTextColor.b, 0.06))
            border.width: 1
            border.color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.4)
            scale: btnMouse.pressed ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                anchors.leftMargin: root.dp(6)
                anchors.rightMargin: root.dp(6)
                text: modelData
                color: btn.isSelected ? "white" : App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText - 1
                font.family: App.Style.fontFamily
                elide: Text.ElideRight
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(modelData)
            }
        }
    }
}
