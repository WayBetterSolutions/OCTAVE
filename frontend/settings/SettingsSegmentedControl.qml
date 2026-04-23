import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

RowLayout {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: control
    spacing: 1
    Layout.fillWidth: true

    property var options: []
    property string currentValue: ""
    property var onSelected: function(value) {}

    Repeater {
        model: control.options

        delegate: Rectangle {
            required property int index
            required property var modelData

            id: segmentRect
            Layout.fillWidth: true
            Layout.minimumWidth: dp(80)
            height: App.Spacing.formElementHeight

            color: modelData === control.currentValue ? App.Style.accent : App.Style.hoverColor
            border.color: App.Style.hoverColor

            property bool isHovered: false

            Text {
                anchors.centerIn: parent
                text: modelData
                color: modelData === control.currentValue ? "white" : App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                font.family: App.Style.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: control.onSelected(modelData)
                onEntered: segmentRect.isHovered = true
                onExited: segmentRect.isHovered = false
            }

            Rectangle {
                anchors.fill: parent
                color: segmentRect.isHovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                visible: modelData !== control.currentValue
            }

            // Accent glow bar at bottom of selected segment (spacecraft)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: App.Style.accent
                opacity: modelData === control.currentValue ? 1.0 : 0
                visible: App.EnvironmentTheme.active.segmentGlowBar

                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }
}
