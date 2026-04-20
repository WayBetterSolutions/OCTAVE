// GalleryTile.qml
//
// Reusable tile for the Primitives Gallery popup in OBDMenu. Temporary
// dev/showcase component — delete when Phase 3 in-app editor ships
// (see TODO/dashboards-roadmap.md).
//
// Usage:
//     GalleryTile {
//         title: "CircularGauge"
//         props: "paramId: RPM · showNeedle"
//         Gauges.CircularGauge { anchors.centerIn: parent; ... }
//     }
//
// Child items go into the preview area (default property). Use
// `anchors.fill: parent` or `anchors.centerIn: parent` inside —
// `parent` resolves to the preview Rectangle.

import QtQuick 2.15
import QtQuick.Layouts 1.15
import "." as App

Rectangle {
    id: root

    property string title: ""
    property string props: ""

    // Child items added to a GalleryTile{} block land inside the preview area.
    default property alias _content: previewArea.data

    Layout.fillWidth: true
    Layout.preferredHeight: App.Spacing.dp(240)

    radius: App.Spacing.dpMin(12, 4)
    color: Qt.darker(App.Style.obdBoxBackground, 1.05)
    border.color: Qt.darker(App.Style.obdBarColor, 1.5)
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: App.Spacing.dp(12)
        spacing: App.Spacing.dp(8)

        // Header: primitive name
        Text {
            Layout.fillWidth: true
            text: root.title
            color: App.Style.obdValueColor
            font.pixelSize: App.Spacing.overallText * 1.05
            font.bold: true
            font.family: App.Style.fontFamily
            elide: Text.ElideRight
        }

        // Preview area — children of the GalleryTile land here.
        Rectangle {
            id: previewArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: App.Spacing.dpMin(8, 2)
            color: App.Style.backgroundColor
            clip: true
        }

        // Footer: props line (monospace-ish, subdued)
        Text {
            Layout.fillWidth: true
            text: root.props
            color: App.Style.obdLabelColor
            font.pixelSize: App.Spacing.overallText * 0.75
            font.family: App.Style.fontFamily
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }
}
