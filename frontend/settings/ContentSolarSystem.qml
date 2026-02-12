import QtQuick 2.15
import ".." as App

Item {
    anchors.fill: parent
    visible: App.EnvironmentTheme.active.scanlineOverlay
    z: 0

    property real orbitPhase: 0

    Timer {
        interval: 80  // ~12fps — RPi friendly
        running: App.EnvironmentTheme.active.scanlineOverlay
        repeat: true
        onTriggered: {
            parent.orbitPhase += 0.4
            if (parent.orbitPhase >= 360) parent.orbitPhase -= 360
            solarCanvas.requestPaint()
        }
    }

    Canvas {
        id: solarCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var ar = App.Style.accent.r
            var ag = App.Style.accent.g
            var ab = App.Style.accent.b
            var phase = parent.orbitPhase

            // Center of the system — slightly offset
            var cx = width * 0.55
            var cy = height * 0.50

            // Isometric compression — flattens Y to give 3D tilt
            var isoRatio = 0.35

            // ── Static elements ──

            // Coordinate crosshairs (dashed)
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.08)
            ctx.lineWidth = 1
            ctx.setLineDash([8, 12])
            ctx.beginPath()
            ctx.moveTo(cx, 0); ctx.lineTo(cx, height)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(0, cy); ctx.lineTo(width, cy)
            ctx.stroke()

            // Diagonal crosshairs
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.04)
            ctx.beginPath()
            ctx.moveTo(cx - height, cy - height)
            ctx.lineTo(cx + height, cy + height)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(cx + height, cy - height)
            ctx.lineTo(cx - height, cy + height)
            ctx.stroke()
            ctx.setLineDash([])

            // Central star
            ctx.fillStyle = Qt.rgba(ar, ag, ab, 0.25)
            ctx.beginPath()
            ctx.arc(cx, cy, 4, 0, Math.PI * 2)
            ctx.fill()

            // Inner glow ring
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.14)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(cx, cy, 10, 0, Math.PI * 2)
            ctx.stroke()

            // Outer glow ring
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.07)
            ctx.beginPath()
            ctx.arc(cx, cy, 18, 0, Math.PI * 2)
            ctx.stroke()

            // ── Orbits and animated planets ──

            var orbits = [
                { rx: 50,  speed: 5.0,  pSize: 2.0, start: 30  },
                { rx: 95,  speed: 3.5,  pSize: 2.5, start: 120 },
                { rx: 155, speed: 2.2,  pSize: 3.0, start: 220 },
                { rx: 230, speed: 1.4,  pSize: 4.5, start: 75  },  // Gas giant
                { rx: 320, speed: 0.8,  pSize: 2.5, start: 310 },
                { rx: 430, speed: 0.5,  pSize: 3.0, start: 170 }
            ]

            for (var i = 0; i < orbits.length; i++) {
                var orb = orbits[i]
                var rx = orb.rx
                var ry = rx * isoRatio

                // Draw orbit ellipse
                var orbitAlpha = 0.08 - (i * 0.007)
                if (orbitAlpha < 0.03) orbitAlpha = 0.03
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, orbitAlpha)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
                ctx.stroke()

                // Planet angle — each orbits at its own speed
                var angle = ((orb.start + phase * orb.speed) % 360) * (Math.PI / 180)
                var px = cx + rx * Math.cos(angle)
                var py = cy + ry * Math.sin(angle)

                // Depth effect: bottom of ellipse = "closer" = bigger & brighter
                var depthFactor = (Math.sin(angle) + 1) / 2  // 0=far(top), 1=near(bottom)
                var sizeScale = 0.7 + depthFactor * 0.6
                var alphaBase = 0.10 + depthFactor * 0.14

                // Gas giant boost
                if (i === 3) alphaBase += 0.08

                // Trail dots — 4 dots behind the planet showing recent path
                for (var tr = 4; tr >= 1; tr--) {
                    var trailAngle = angle - (tr * 0.09)
                    var trPx = cx + rx * Math.cos(trailAngle)
                    var trPy = cy + ry * Math.sin(trailAngle)
                    var trailFade = 1 - (tr * 0.22)
                    ctx.fillStyle = Qt.rgba(ar, ag, ab, alphaBase * trailFade * 0.4)
                    ctx.beginPath()
                    ctx.arc(trPx, trPy, orb.pSize * sizeScale * (1 - tr * 0.15), 0, Math.PI * 2)
                    ctx.fill()
                }

                // Planet glow halo
                ctx.fillStyle = Qt.rgba(ar, ag, ab, alphaBase * 0.25)
                ctx.beginPath()
                ctx.arc(px, py, orb.pSize * sizeScale * 2.5, 0, Math.PI * 2)
                ctx.fill()

                // Planet body
                ctx.fillStyle = Qt.rgba(ar, ag, ab, alphaBase)
                ctx.beginPath()
                ctx.arc(px, py, orb.pSize * sizeScale, 0, Math.PI * 2)
                ctx.fill()
            }

            // Nav tick marks on outermost orbit
            var outerRx = 430
            var outerRy = outerRx * isoRatio
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.06)
            ctx.lineWidth = 1
            for (var t = 0; t < 36; t++) {
                var ta = (t / 36) * Math.PI * 2
                var tCos = Math.cos(ta)
                var tSin = Math.sin(ta)
                ctx.beginPath()
                ctx.moveTo(cx + (outerRx - 5) * tCos, cy + (outerRy - 5) * tSin)
                ctx.lineTo(cx + (outerRx + 5) * tCos, cy + (outerRy + 5) * tSin)
                ctx.stroke()
            }

            // Scattered background stars
            var stars = [
                [0.08, 0.12], [0.15, 0.85], [0.25, 0.35],
                [0.35, 0.08], [0.42, 0.72], [0.55, 0.18],
                [0.72, 0.88], [0.78, 0.42], [0.88, 0.15],
                [0.92, 0.65], [0.12, 0.55], [0.48, 0.45],
                [0.82, 0.72], [0.05, 0.38], [0.95, 0.28],
                [0.32, 0.92], [0.68, 0.05], [0.18, 0.68]
            ]
            for (var s = 0; s < stars.length; s++) {
                var sx = stars[s][0] * width
                var sy = stars[s][1] * height
                var starAlpha = 0.06 + (s % 3) * 0.04
                ctx.fillStyle = Qt.rgba(ar, ag, ab, starAlpha)
                ctx.beginPath()
                ctx.arc(sx, sy, (s % 3) === 0 ? 1.5 : 1, 0, Math.PI * 2)
                ctx.fill()
            }

            // Trajectory arc — dashed flight path curving into the star
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.08)
            ctx.lineWidth = 1
            ctx.setLineDash([6, 8])
            ctx.beginPath()
            ctx.moveTo(width * 0.1, height * 0.9)
            ctx.quadraticCurveTo(cx - 50, cy + 30, cx, cy)
            ctx.stroke()

            // Arrowhead at trajectory end
            ctx.setLineDash([])
            ctx.fillStyle = Qt.rgba(ar, ag, ab, 0.12)
            ctx.beginPath()
            ctx.moveTo(cx - 8, cy + 2)
            ctx.lineTo(cx, cy)
            ctx.lineTo(cx - 6, cy + 8)
            ctx.closePath()
            ctx.fill()
        }
    }
}
