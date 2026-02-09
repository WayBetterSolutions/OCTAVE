import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import "." as App
import "settings"

Item {
    id: settingsMenu
    objectName: "settingsMenu"
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: initialSection

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        RowLayout {
            anchors.fill: parent
            spacing: 0


            Rectangle { // Left Navigation Panel
                id: sidebarPanel
                Layout.preferredWidth: App.Spacing.settingsNavWidth
                Layout.fillHeight: true
                color: App.Style.sidebarColor

                // Sidebar lighting gradient (subtle overhead light simulation)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.04) }
                        GradientStop { position: 0.6; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.06) }
                    }
                }

                // Dot-grid pattern overlay (spacecraft)
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

                // Lit edge highlight along the top
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                // Soft shadow on the right edge (replaces hard separator)
                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.right
                    }
                    width: 10
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.06) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: App.Spacing.settingsNavMargin
                    }
                    spacing: 0

                    ListView {
                        id: navListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        interactive: true
                        clip: true

                        model: ListModel {
                            ListElement { name: "Device"; section: "deviceSettings" }
                            ListElement { name: "Media"; section: "mediaSettings" }
                            ListElement { name: "Display"; section: "displaySettings" }
                            ListElement { name: "OBD"; section: "obdSettings" }
                            ListElement { name: "Clock"; section: "clockSettings" }
                            ListElement { name: "Android Auto"; section: "androidAutoSettings" }
                            ListElement { name: "Phone Mirror"; section: "phoneMirrorSettings" }
                            ListElement { name: "Volume Knob"; section: "volumeKnobSettings" }
                            ListElement { name: "About"; section: "about" }
                        }

                        delegate: Item {
                            required property string name
                            required property string section

                            // Check visibility from settings manager
                            property bool sectionVisible: settingsManager ? settingsManager.is_settings_section_visible(section) : true

                            width: navListView.width
                            height: sectionVisible ? App.Spacing.settingsButtonHeight : 0
                            visible: sectionVisible
                            clip: true

                            // Update visibility when settings change
                            Connections {
                                target: settingsManager
                                function onSettingsMenuVisibilityChanged() {
                                    sectionVisible = settingsManager.is_settings_section_visible(section)
                                }
                            }

                            // Elevation shadow - outer (soft, wide spread)
                            Rectangle {
                                x: navBackground.x - 2
                                y: navBackground.y + 4
                                width: navBackground.width + 4
                                height: navBackground.height + 2
                                radius: navBackground.radius + 3
                                color: Qt.rgba(0, 0, 0, 0.06)
                                opacity: currentSection === section ? 1.0
                                    : (navMouseArea.containsMouse ? 0.6 : 0)

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Elevation shadow - inner (sharper, tighter)
                            Rectangle {
                                x: navBackground.x - 1
                                y: navBackground.y + 2
                                width: navBackground.width + 2
                                height: navBackground.height + 1
                                radius: navBackground.radius + 1
                                color: Qt.rgba(0, 0, 0, 0.12)
                                opacity: currentSection === section
                                    ? (navMouseArea.pressed ? 0.4 : 1.0)
                                    : (navMouseArea.containsMouse ? 0.5 : 0)

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Background - rounded selection
                            Rectangle {
                                id: navBackground
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 8
                                    rightMargin: 8
                                    topMargin: 3
                                    bottomMargin: 3
                                }
                                radius: App.EnvironmentTheme.active.navItemRadius
                                color: currentSection === section
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                    : "transparent"
                                scale: navMouseArea.pressed ? 0.97 : 1.0

                                // Accent border (spacecraft)
                                border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
                                border.color: currentSection === section
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                                    : (navMouseArea.containsMouse
                                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                                        : "transparent")

                                // Top lit edge on selected/hovered item
                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: 2
                                        rightMargin: 2
                                    }
                                    height: 1
                                    radius: 0.5
                                    color: Qt.rgba(255, 255, 255, 0.1)
                                    opacity: currentSection === section ? 1.0
                                        : (navMouseArea.containsMouse ? 0.5 : 0)

                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                            }

                            // Pulsing glow behind accent bar (spacecraft)
                            Rectangle {
                                anchors.centerIn: accentBar
                                width: accentBar.width + 6
                                height: accentBar.height + 6
                                radius: accentBar.radius + 3
                                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, accentBarPulse)
                                visible: App.EnvironmentTheme.active.pulsingElements && currentSection === section

                                property real accentBarPulse: 0.15
                                SequentialAnimation on accentBarPulse {
                                    running: App.EnvironmentTheme.active.pulsingElements && currentSection === section
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 1500; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.15; duration: 1500; easing.type: Easing.InOutSine }
                                }
                            }

                            // Left accent bar for selected item
                            Rectangle {
                                id: accentBar
                                anchors {
                                    left: parent.left
                                    leftMargin: 4
                                    verticalCenter: parent.verticalCenter
                                }
                                width: App.EnvironmentTheme.active.navAccentBarWidth
                                height: currentSection === section
                                    ? (App.EnvironmentTheme.active.navAccentBarFullHeight
                                        ? parent.height * 0.8 : parent.height * 0.5)
                                    : 0
                                radius: App.EnvironmentTheme.active.navAccentBarWidth / 2
                                color: App.Style.accent

                                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            }

                            // Hover effect - rounded
                            Rectangle {
                                id: navHoverRectangle
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 8
                                    rightMargin: 8
                                    topMargin: 3
                                    bottomMargin: 3
                                }
                                radius: App.EnvironmentTheme.active.navItemRadius
                                color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)
                                opacity: 0

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Text
                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 24
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: name
                                color: currentSection === section ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.overallText * 2
                                font.bold: currentSection === section
                                font.family: App.Style.fontFamily
                                elide: Text.ElideRight
                            }

                            // Entire area clickable
                            MouseArea {
                                id: navMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    currentSection = section
                                    mainWindow.lastSettingsSection = section
                                    // Persist to settings
                                    if (settingsManager) {
                                        settingsManager.set_last_settings_section(section)
                                    }
                                }
                                hoverEnabled: true

                                onEntered: {
                                    if (currentSection !== section) {
                                        navHoverRectangle.opacity = 1
                                    }
                                }
                                onExited: {
                                    navHoverRectangle.opacity = 0
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { // Right Content Area
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: App.Style.contentColor

                // Top HUD line (spacecraft)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: App.Spacing.settingsContentMargin
                    anchors.rightMargin: App.Spacing.settingsContentMargin
                    height: 1
                    z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Bottom HUD line (spacecraft)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: App.Spacing.settingsContentMargin
                    anchors.rightMargin: App.Spacing.settingsContentMargin
                    height: 1
                    z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Top-left corner bracket (spacecraft)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Top-right corner bracket (spacecraft)
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Bottom-left corner bracket (spacecraft)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Bottom-right corner bracket (spacecraft)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Solar system nav diagram background (spacecraft) — isometric animated
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

                StackLayout {
                    id: contentStack
                    anchors {
                        fill: parent
                        margins: App.Spacing.settingsContentMargin
                    }
                    currentIndex: {
                        switch(currentSection) {
                            case "deviceSettings": return 0;
                            case "mediaSettings": return 1;
                            case "displaySettings": return 2;
                            case "obdSettings": return 3;
                            case "clockSettings": return 4;
                            case "androidAutoSettings": return 5;
                            case "phoneMirrorSettings": return 6;
                            case "volumeKnobSettings": return 7;
                            case "about": return 8;
                            default: return 0;
                        }
                    }

                    DeviceSettingsPage {
                        mainWindow: settingsMenu.mainWindow
                    }

                    MediaSettingsPage {
                        currentSection: settingsMenu.currentSection
                    }

                    DisplaySettingsPage {
                        stackView: settingsMenu.stackView
                        mainWindow: settingsMenu.mainWindow
                        currentSection: settingsMenu.currentSection
                    }

                    OBDSettingsPage {}

                    ClockSettingsPage {}

                    AndroidAutoSettingsPage {}

                    PhoneMirrorSettingsPage {}

                    VolumeKnobSettingsPage {}

                    AboutPage {}
                }
            }
        }
    }
}
