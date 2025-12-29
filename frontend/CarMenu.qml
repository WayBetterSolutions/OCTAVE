import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.AssetUtils
import "." as App

Item {
    id: carMenu
    width: parent.width
    height: parent.height

    // Required properties
    required property var stackView
    property var mainWindow

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily
    
    // Simulation properties for accelerometer
    property real currentPitch: 0
    property real currentRoll: 0
    property bool simulationRunning: false
    
    // Debugging output
    Component.onCompleted: {
        console.log("CarMenu component created successfully")
    }

    // Timer to update simulated values
    Timer {
        id: simulationTimer
        interval: 50
        running: simulationRunning
        repeat: true
        onTriggered: {
            // Create some simple motion for demonstration
            currentPitch = 30 * Math.sin(Date.now() * 0.001)
            currentRoll = 45 * Math.cos(Date.now() * 0.0015)
            
            // Apply to model
            carModel.eulerRotation.x = currentPitch
            carModel.eulerRotation.z = currentRoll
        }
    }

    // Background with accent color
    Rectangle {
        anchors.fill: parent
        color: App.Style.accent
        
        // 3D View container
        Rectangle {
            id: modelContainer
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: controlPanel.top
                margins: App.Spacing.overallMargin
            }
            color: "black"
            
            View3D {
                id: view3d
                anchors.fill: parent
                
                environment: SceneEnvironment {
                    clearColor: "#87CEEB" // Sky blue
                    backgroundMode: SceneEnvironment.Color
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.High
                    aoStrength: 100
                }
                
                PerspectiveCamera {
                    id: camera
                    position: Qt.vector3d(0, 60, 120)
                    eulerRotation.x: -20
                    clipNear: 10
                    clipFar: 1000
                }
                
                // Main light - made to feel "larger"
                DirectionalLight {
                    id: mainLight
                    position: Qt.vector3d(500, 500, 500)
                    eulerRotation.x: -45
                    eulerRotation.y: 45
                    brightness: 2
                    ambientColor: "#FFFFFF"
                    castsShadow: true
                    shadowBias: 0.005
                    shadowFactor: 50
                    shadowFilter: 50
                    shadowMapQuality: Light.ShadowMapQualityHigh
                }
                
                // Fill light
                PointLight {
                    id: fillLight
                    position: Qt.vector3d(-50, 100, 150)
                    brightness: 0.5
                    ambientColor: "#FFFFEE"
                    castsShadow: false
                    quadraticFade: 0.3
                }
                
                // Car model
                Node {
                    id: carModel
                    position: Qt.vector3d(0, 0, 0)
                    scale: Qt.vector3d(30, 30, 30)
                    
                    RuntimeLoader {
                        id: modelLoader
                        source: "./assets/cam.glb"
                        onStatusChanged: {
                            console.log("Model status:", status, statusString)
                        }
                    }
                }
            }
            
            // Mouse area for rotating the model's yaw
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                property real lastX: 0
                property bool dragging: false

                onPressed: (event) => {
                    lastX = event.x
                    dragging = true
                }

                onReleased: (event) => {
                    dragging = false
                }

                onPositionChanged: (event) => {
                    if (!dragging)
                        return

                    let dx = event.x - lastX
                    
                    // Only horizontal drag to rotate around Y-axis (yaw)
                    carModel.eulerRotation.y += dx * 0.5
                    
                    lastX = event.x
                }
            }
            
            // Off-road style inclinometer - pitch and roll gauge (BIGGER)
            Rectangle {
                id: inclinometerGauge
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 20
                width: 300  // Increased size
                height: 300 // Increased size
                radius: width / 2
                color: "#222222"
                border.color: "#444444"
                border.width: 4
                
                // Circular background with degree markings
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        
                        var centerX = width / 2
                        var centerY = height / 2
                        var radius = width / 2 - 20
                        
                        // Draw degree markings
                        ctx.lineWidth = 2
                        ctx.strokeStyle = "white"
                        ctx.fillStyle = "white"
                        
                        // Draw angle ticks
                        for (var i = 0; i < 360; i += 5) {
                            var angle = i * Math.PI / 180
                            var length = (i % 10 === 0) ? 10 : 5
                            
                            if (i % 30 === 0) {
                                length = 15
                            }
                            
                            var startX = centerX + (radius - length) * Math.cos(angle)
                            var startY = centerY + (radius - length) * Math.sin(angle)
                            var endX = centerX + radius * Math.cos(angle)
                            var endY = centerY + radius * Math.sin(angle)
                            
                            ctx.beginPath()
                            ctx.moveTo(startX, startY)
                            ctx.lineTo(endX, endY)
                            ctx.stroke()
                            
                            // Add text for major angles
                            if (i % 30 === 0) {
                                var textX = centerX + (radius - 30) * Math.cos(angle)
                                var textY = centerY + (radius - 30) * Math.sin(angle)
                                ctx.font = "14px sans-serif"  // Larger font
                                ctx.textAlign = "center"
                                ctx.textBaseline = "middle"
                                ctx.fillText(i.toString() + "°", textX, textY)
                            }
                        }
                        
                        // Draw danger zones (red areas for severe inclinations)
                        ctx.fillStyle = "rgba(255, 0, 0, 0.2)"
                        
                        // Pitch danger zone (front/back)
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 45 * Math.PI / 180, 135 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 225 * Math.PI / 180, 315 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        // Roll danger zone (sides)
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 135 * Math.PI / 180, 225 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 315 * Math.PI / 180, 360 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 0, 45 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        // Caution zones (yellow areas for moderate inclinations)
                        ctx.fillStyle = "rgba(255, 255, 0, 0.2)"
                        
                        // Pitch caution zone
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 30 * Math.PI / 180, 45 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 135 * Math.PI / 180, 150 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 210 * Math.PI / 180, 225 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                        
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, 315 * Math.PI / 180, 330 * Math.PI / 180)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                
                // Center reference
                Rectangle {
                    anchors.centerIn: parent
                    width: 15  // Larger
                    height: 15  // Larger
                    radius: 7.5
                    color: "white"
                    border.color: "black"
                    border.width: 1
                    z: 2
                }
                
                // Pitch and roll indicator (bubble)
                Rectangle {
                    id: bubbleIndicator
                    width: 40  // Larger
                    height: 40  // Larger
                    radius: width / 2
                    color: "lightgreen"
                    border.color: "black"
                    border.width: 2
                    opacity: 0.8
                    
                    // Position based on pitch and roll
                    x: parent.width / 2 - width / 2 + Math.sin(currentRoll * Math.PI / 180) * (parent.width / 3)
                    y: parent.height / 2 - height / 2 - Math.sin(currentPitch * Math.PI / 180) * (parent.height / 3)
                    
                    Behavior on x { NumberAnimation { duration: 100 } }
                    Behavior on y { NumberAnimation { duration: 100 } }
                }
                
                // Cross reference lines
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    height: 2
                    color: "white"
                    opacity: 0.5
                }
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height - 40
                    color: "white"
                    opacity: 0.5
                }
                
                // Add gauge title
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    text: "VEHICLE ORIENTATION"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: carMenu.globalFont
                }
                
                // Digital readouts inside the gauge
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 35
                    spacing: 5
                    
                    Rectangle {
                        width: 110
                        height: 30
                        color: "#333333"
                        radius: 5
                        border.color: "#666666"
                        border.width: 1
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            
                            Text {
                                text: "PITCH:"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: carMenu.globalFont
                            }

                            Text {
                                text: currentPitch.toFixed(1) + "°"
                                color: Math.abs(currentPitch) > 30 ? "red" :
                                      Math.abs(currentPitch) > 20 ? "yellow" : "lime"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: carMenu.globalFont
                            }
                        }
                    }
                    
                    Rectangle {
                        width: 110
                        height: 30
                        color: "#333333"
                        radius: 5
                        border.color: "#666666"
                        border.width: 1
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            
                            Text {
                                text: "ROLL:"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: carMenu.globalFont
                            }

                            Text {
                                text: currentRoll.toFixed(1) + "°"
                                color: Math.abs(currentRoll) > 30 ? "red" :
                                      Math.abs(currentRoll) > 20 ? "yellow" : "lime"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: carMenu.globalFont
                            }
                        }
                    }
                }
            }
            
            // Improved Roll visualization (front view only)
            Rectangle {
                id: rollVisual
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                width: 200
                height: 200
                color: "transparent"
                border.color: "#444444"
                border.width: 2
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    text: "ROLL INDICATOR"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: carMenu.globalFont
                }
                
                // Ground line
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2
                    width: parent.width - 20
                    height: 2
                    color: "#666666"
                    
                    transform: Rotation {
                        origin.x: (parent.width - 20) / 2
                        origin.y: 0
                        angle: currentRoll
                    }
                }
                
                // Vehicle icon (front view)
                Item {
                    id: vehicleIcon
                    anchors.centerIn: parent
                    width: 100
                    height: 60
                    
                    transform: Rotation {
                        origin.x: 50
                        origin.y: 30
                        angle: currentRoll
                    }
                    
                    // Vehicle body
                    Rectangle {
                        anchors.centerIn: parent
                        width: 80
                        height: 40
                        radius: 10
                        color: "#888888"
                        border.color: "#444444"
                        border.width: 1
                    }
                    
                    // Wheels
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        width: 20
                        height: 20
                        radius: width / 2
                        color: "black"
                        border.color: "#444444"
                        border.width: 1
                    }
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        width: 20
                        height: 20
                        radius: width / 2
                        color: "black"
                        border.color: "#444444"
                        border.width: 1
                    }
                    
                    // Roof
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        width: 50
                        height: 10
                        radius: 5
                        color: "#666666"
                    }
                }
                
                // Angle indicators
                Repeater {
                    model: [-60, -45, -30, -15, 0, 15, 30, 45, 60]
                    Rectangle {
                        width: 2
                        height: 10
                        color: "white"
                        x: parent.width / 2
                        y: parent.height / 2 - 60
                        
                        transform: Rotation {
                            origin.x: 0
                            origin.y: 60
                            angle: modelData
                        }
                    }
                }
                
                // Angle labels
                Repeater {
                    model: [-60, -45, -30, -15, 0, 15, 30, 45, 60]
                    Text {
                        text: modelData + "°"
                        color: Math.abs(modelData) > 30 ? "red" :
                               Math.abs(modelData) > 20 ? "yellow" : "white"
                        font.pixelSize: 10
                        font.family: carMenu.globalFont
                        x: parent.width / 2 - 10 + 70 * Math.sin(modelData * Math.PI / 180)
                        y: parent.height / 2 - 10 - 70 * Math.cos(modelData * Math.PI / 180)
                    }
                }
                
                // Current angle pointer
                Rectangle {
                    width: 3
                    height: 15
                    color: "red"
                    x: parent.width / 2
                    y: parent.height / 2 - 60
                    
                    transform: Rotation {
                        origin.x: 0
                        origin.y: 60
                        angle: currentRoll
                    }
                }
                
                // Digital display
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 100
                    height: 30
                    color: "#333333"
                    radius: 5
                    border.color: "#666666"
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: currentRoll.toFixed(1) + "°"
                        color: Math.abs(currentRoll) > 30 ? "red" :
                               Math.abs(currentRoll) > 20 ? "yellow" : "lime"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: carMenu.globalFont
                    }
                }
            }
        }
        
        // Control panel
        Rectangle {
            id: controlPanel
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: App.Spacing.overallMargin
            width: parent.width - (App.Spacing.overallMargin * 2)
            height: 60
            color: "#333333"
            radius: 10
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 20
                
                Button {
                    text: simulationRunning ? "Stop Simulation" : "Start Simulation"
                    onClicked: {
                        simulationRunning = !simulationRunning
                    }
                }
                
                Button {
                    text: "Reset Position"
                    onClicked: {
                        currentPitch = 0
                        currentRoll = 0
                        carModel.eulerRotation = Qt.vector3d(0, carModel.eulerRotation.y, 0)
                    }
                }
                
                Slider {
                    Layout.preferredWidth: 150
                    from: -90
                    to: 90
                    value: currentPitch
                    onMoved: {
                        if (!simulationRunning) {
                            currentPitch = value
                            carModel.eulerRotation.x = currentPitch
                        }
                    }
                    
                    Text {
                        anchors.bottom: parent.top
                        text: "Pitch"
                        color: "white"
                        font.pixelSize: 12
                        font.family: carMenu.globalFont
                    }
                }
                
                Slider {
                    Layout.preferredWidth: 150
                    from: -90
                    to: 90
                    value: currentRoll
                    onMoved: {
                        if (!simulationRunning) {
                            currentRoll = value
                            carModel.eulerRotation.z = currentRoll
                        }
                    }
                    
                    Text {
                        anchors.bottom: parent.top
                        text: "Roll"
                        color: "white"
                        font.pixelSize: 12
                        font.family: carMenu.globalFont
                    }
                }
            }
        }
    }
}