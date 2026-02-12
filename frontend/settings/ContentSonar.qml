import QtQuick 2.15
import ".." as App

Item {
    anchors.fill: parent
    visible: App.EnvironmentTheme.active.contentSonar
    z: 0

    property real sonarPhase: 0

    Timer {
        interval: 100  // ~10fps — RPi friendly
        running: App.EnvironmentTheme.active.contentSonar
        repeat: true
        onTriggered: {
            parent.sonarPhase += 1.0
            if (parent.sonarPhase >= 360) parent.sonarPhase -= 360
            sonarCanvas.requestPaint()
        }
    }

    Canvas {
        id: sonarCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var ar = App.Style.accent.r
            var ag = App.Style.accent.g
            var ab = App.Style.accent.b
            var phase = parent.sonarPhase

            // Sonar origin — lower-left quadrant
            var sx = width * 0.35
            var sy = height * 0.60

            // ── Depth gauge along right edge ──
            var gaugeX = width - 30
            for (var d = 0; d < 12; d++) {
                var gy = 20 + (d / 12) * (height - 40)
                var tickW = (d % 3 === 0) ? 18 : 10
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, (d % 3 === 0) ? 0.08 : 0.04)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(gaugeX, gy)
                ctx.lineTo(gaugeX + tickW, gy)
                ctx.stroke()
            }

            // Depth numbers at major ticks
            ctx.fillStyle = Qt.rgba(ar, ag, ab, 0.06)
            ctx.font = "9px monospace"
            ctx.textAlign = "right"
            for (var dn = 0; dn < 12; dn += 3) {
                var dny = 24 + (dn / 12) * (height - 40)
                ctx.fillText((dn * 50) + "m", gaugeX - 4, dny)
            }

            // Vertical gauge line
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.04)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(gaugeX, 20)
            ctx.lineTo(gaugeX, height - 20)
            ctx.stroke()

            // ── Horizontal current flow lines ──
            ctx.lineWidth = 1
            for (var cl = 0; cl < 5; cl++) {
                var curY = height * (0.12 + cl * 0.2)
                var offset = Math.sin(phase * 0.015 + cl * 1.5) * 10
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.03)
                ctx.beginPath()
                ctx.moveTo(0, curY + offset)
                for (var cx2 = 30; cx2 < width - 40; cx2 += 30) {
                    var ccy = curY + Math.sin((cx2 + phase * 1.5 + cl * 60) * 0.008) * 8 + offset
                    ctx.lineTo(cx2, ccy)
                }
                ctx.stroke()
            }

            // ── Sonar rings — expanding from origin ──
            var maxRadius = Math.max(width, height) * 0.8
            for (var r = 0; r < 4; r++) {
                var ringPhase = ((phase * 0.4 + r * 90) % 360) / 360
                var radius = ringPhase * maxRadius
                var ringAlpha = (1 - ringPhase) * 0.10
                if (ringAlpha > 0.01) {
                    ctx.strokeStyle = Qt.rgba(ar, ag, ab, ringAlpha)
                    ctx.lineWidth = 1.5
                    ctx.beginPath()
                    ctx.arc(sx, sy, radius, 0, Math.PI * 2)
                    ctx.stroke()
                }
            }

            // Sonar center point
            ctx.fillStyle = Qt.rgba(ar, ag, ab, 0.15)
            ctx.beginPath()
            ctx.arc(sx, sy, 3, 0, Math.PI * 2)
            ctx.fill()

            // Sonar center glow ring
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.08)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(sx, sy, 8, 0, Math.PI * 2)
            ctx.stroke()

            // ── Sonar sweep line (rotating) ──
            var sweepAngle = (phase * 1.5) * (Math.PI / 180)
            var sweepLen = maxRadius * 0.35
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.10)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(sx, sy)
            ctx.lineTo(sx + sweepLen * Math.cos(sweepAngle), sy + sweepLen * Math.sin(sweepAngle))
            ctx.stroke()

            // Trailing sweep glow (fading arc behind sweep)
            for (var sw = 1; sw <= 6; sw++) {
                var trailAngle = sweepAngle - sw * 0.06
                var trailAlpha = 0.06 * (1 - sw / 7)
                ctx.strokeStyle = Qt.rgba(ar, ag, ab, trailAlpha)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(sx, sy)
                ctx.lineTo(sx + sweepLen * Math.cos(trailAngle), sy + sweepLen * Math.sin(trailAngle))
                ctx.stroke()
            }

            // ── Scattered particles (silt/plankton) — gently drifting ──
            var particles = [
                [0.10, 0.15], [0.20, 0.80], [0.30, 0.40],
                [0.15, 0.60], [0.45, 0.25], [0.55, 0.70],
                [0.65, 0.15], [0.75, 0.50], [0.85, 0.80],
                [0.40, 0.90], [0.60, 0.35], [0.80, 0.20],
                [0.25, 0.55], [0.50, 0.85], [0.70, 0.45],
                [0.90, 0.60], [0.35, 0.10], [0.08, 0.45]
            ]
            for (var p = 0; p < particles.length; p++) {
                var px = particles[p][0] * width + Math.sin(phase * 0.025 + p * 0.7) * 4
                var py = particles[p][1] * height + Math.cos(phase * 0.018 + p * 0.5) * 3
                var pAlpha = 0.05 + (p % 3) * 0.025
                var pSize = (p % 3 === 0) ? 1.5 : 1
                ctx.fillStyle = Qt.rgba(ar, ag, ab, pAlpha)
                ctx.beginPath()
                ctx.arc(px, py, pSize, 0, Math.PI * 2)
                ctx.fill()
            }

            // ── Hull stress hatching in corners ──
            ctx.strokeStyle = Qt.rgba(ar, ag, ab, 0.03)
            ctx.lineWidth = 1
            for (var h = 0; h < 6; h++) {
                ctx.beginPath()
                ctx.moveTo(h * 8, 0)
                ctx.lineTo(0, h * 8)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(width - h * 8, height)
                ctx.lineTo(width, height - h * 8)
                ctx.stroke()
            }
        }
    }
}
