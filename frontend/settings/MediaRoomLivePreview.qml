import QtQuick 2.15
import ".." as App

// Live MediaRoom preview pinned inside a settings card. Renders a real
// MediaRoom instance at the host window's design dimensions, then visually
// scales it to fit, drawing the accent border around the exact perimeter
// of the visible MediaRoom rect (not the wider container slot).
Item {
    id: livePreview

    function dp(s) { return Math.round(s * (App.Spacing.effectiveScale || 1.0)) }

    // Forwards a synthetic track-transition trigger into the embedded
    // MediaRoom. `style` overrides the carousel's bound value for this one
    // animation so the user sees the just-tapped chip fire immediately.
    function previewTrackTransition(direction, style) {
        if (roomLoader.item && typeof roomLoader.item.previewTrackTransition === "function")
            roomLoader.item.previewTrackTransition(direction, style)
    }

    // Design canvas — defaults to the actual app window so the preview is
    // a faithful miniature of what the user will see when they exit settings.
    property real designWidth:  mainWindow ? mainWindow.width  : 1280
    property real designHeight: mainWindow ? mainWindow.height : 720

    // "Fit" letterboxes/pillarboxes the canvas inside the slot (no cropping).
    // "Fill" scales until the slot is filled and clips overflow (no bars).
    // Default is Fit; the immersive Now Playing Studio uses Fill so its very
    // wide central slot doesn't show big side bars around centered content.
    property string fillMode: "Fit"

    readonly property real fitScale: {
        if (designWidth <= 0 || designHeight <= 0 || width <= 0 || height <= 0) return 0.0001
        var sx = width / designWidth
        var sy = height / designHeight
        return fillMode === "Fill" ? Math.max(sx, sy) : Math.min(sx, sy)
    }
    readonly property real visibleW: designWidth * fitScale
    readonly property real visibleH: designHeight * fitScale

    // Visible MediaRoom rect — clipped, exact-fit, centered. The accent
    // border below sits at this rect's perimeter.
    // In Fill mode the inner stage (scale = max) overflows this host; clip:true
    // keeps the overflow inside the slot. So the host caps at the slot bounds.
    Item {
        id: stageHost
        width:  Math.min(livePreview.visibleW, livePreview.width)
        height: Math.min(livePreview.visibleH, livePreview.height)
        anchors.centerIn: parent
        clip: true

        Item {
            id: stage
            width: livePreview.designWidth
            height: livePreview.designHeight
            anchors.centerIn: parent
            transformOrigin: Item.Center
            scale: livePreview.fitScale

            Loader {
                id: roomLoader
                anchors.fill: parent
                // Tear down the inner MediaRoom when this preview isn't
                // visible so we're not double-rendering vinyl rotation /
                // FFT analysis in the background.
                source: livePreview.visible ? "../MediaRoom.qml" : ""
                asynchronous: true
            }
        }
    }

    // Accent border, locked to the actual MediaRoom perimeter.
    Rectangle {
        anchors.fill: stageHost
        color: "transparent"
        border.width: 2
        border.color: App.Style.accent
        z: 1
    }
}
