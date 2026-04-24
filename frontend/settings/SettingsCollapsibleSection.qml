import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

ColumnLayout {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: root
    Layout.fillWidth: true
    spacing: 0

    property string title: ""
    property bool expanded: true
    default property alias content: contentColumn.children

    // Header row — click to toggle
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: App.Spacing.settingsButtonHeight * 0.8
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 2
                rightMargin: 2
            }
            spacing: dp(8)

            Text {
                text: root.title
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.3
                font.family: App.Style.fontFamily
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Text {
                id: sectionArrow
                text: root.expanded ? "\u25BC" : "\u25B6"
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.overallText
                opacity: 0.6

                Behavior on text {
                    // Rotation-like feel without actual transform
                    SequentialAnimation {
                        NumberAnimation { target: sectionArrow; property: "opacity"; to: 0; duration: 80 }
                        NumberAnimation { target: sectionArrow; property: "opacity"; to: 0.6; duration: 170 }
                    }
                }
            }
        }
    }

    // Collapsible content
    ColumnLayout {
        id: contentColumn
        Layout.fillWidth: true
        spacing: App.Spacing.rowSpacing
        visible: root.expanded

        // Animated height via clip + max height
        clip: true
        Layout.preferredHeight: root.expanded ? implicitHeight : 0

        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
    }
}
