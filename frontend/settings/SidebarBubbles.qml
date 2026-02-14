import QtQuick 2.15
import ".." as App

Item {
    anchors.fill: parent
    visible: App.EnvironmentTheme.active.sidebarBubbles

    property var bubbles: []
    property bool initialized: false

    Component.onCompleted: {
        if (visible) initBubbles()
    }
    onVisibleChanged: {
        if (visible && !initialized) initBubbles()
    }

    function initBubbles() {
        var b = []
        for (var i = 0; i < 14; i++) {
            b.push({
                x: Math.random(),
                y: Math.random(),
                size: 1.5 + Math.random() * 4.5,
                speed: 0.003 + Math.random() * 0.005,
                wobblePhase: Math.random() * Math.PI * 2,
                wobbleSpeed: 0.02 + Math.random() * 0.03,
                wobbleAmp: 0.01 + Math.random() * 0.02
            })
        }
        bubbles = b
        initialized = true
    }

    Timer {
        interval: 100  // ~10fps — RPi friendly
        running: visible && App.EnvironmentTheme.active.sidebarBubbles
        repeat: true
        onTriggered: {
            var b = parent.bubbles.slice()
            for (var i = 0; i < b.length; i++) {
                b[i].y -= b[i].speed
                b[i].wobblePhase += b[i].wobbleSpeed
                if (b[i].y < -0.05) {
                    b[i].y = 1.05
                    b[i].x = Math.random()
                    b[i].size = 1.5 + Math.random() * 4.5
                }
            }
            parent.bubbles = b
            bubbleCanvas.requestPaint()
        }
    }

    Canvas {
        id: bubbleCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var ar = App.Style.accent.r
            var ag = App.Style.accent.g
            var ab = App.Style.accent.b

            var b = parent.bubbles
            for (var i = 0; i < b.length; i++) {
                var bx = (b[i].x + Math.sin(b[i].wobblePhase) * b[i].wobbleAmp) * width
                var by = b[i].y * height
                var sz = b[i].size

                // Fade in at bottom, fade out at top
                var alpha = 1.0
                if (b[i].y > 0.85) alpha = (1.0 - b[i].y) / 0.15
                else if (b[i].y < 0.15) alpha = b[i].y / 0.15
                alpha *= 0.3

                // Bubble outline
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, alpha)
                ctx.lineWidth = 0.5
                ctx.beginPath()
                ctx.arc(bx, by, sz, 0, Math.PI * 2)
                ctx.stroke()

                // Bubble highlight (small arc at top-left)
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, alpha * 0.8)
                ctx.lineWidth = 0.8
                ctx.beginPath()
                ctx.arc(bx - sz * 0.25, by - sz * 0.25, sz * 0.4, Math.PI * 1.2, Math.PI * 1.8)
                ctx.stroke()

                // Inner fill (very subtle)
                ctx.fillStyle = Qt.rgba(ar, ag, ab, alpha * 0.08)
                ctx.beginPath()
                ctx.arc(bx, by, sz, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}
