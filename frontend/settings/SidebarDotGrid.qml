import QtQuick 2.15
import ".." as App

Canvas {
    anchors.fill: parent
    visible: App.EnvironmentTheme.active.sidebarGrid
    opacity: 0.15
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = App.Style.accent
        var spacing = 20
        for (var y = spacing; y < height; y += spacing) {
            for (var x = spacing; x < width; x += spacing) {
                ctx.beginPath()
                ctx.arc(x, y, 1, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}
