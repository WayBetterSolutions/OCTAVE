import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Basic 2.15
import OCTAVE.AndroidAuto 1.0
import "." as App

Item {
    id: androidAutoView
    property StackView stackView
    property ApplicationWindow mainWindow
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string globalFont: App.Style.fontFamily

    // Android Auto state from backend
    property string connectionState: androidAutoManager ? androidAutoManager.state : "disconnected"
    property bool isConnected: androidAutoManager ? androidAutoManager.isConnected : false
    property bool isStreaming: androidAutoManager ? androidAutoManager.isStreaming : false
    property string statusMessage: "Waiting for Android device..."
    property string transportMode: "tcp"  // "usb" or "tcp" - default to TCP (no cert needed)

    // DHU embedding state
    property int dhuWindowHandle: 0
    property bool dhuEmbedded: false
    property int frameCounter: 0  // Used to refresh the image

    // Dark background
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor
    }

    // Header with back button
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            // Back button
            Button {
                text: "< Back"
                font.pixelSize: 16
                font.family: androidAutoView.globalFont

                background: Rectangle {
                    color: parent.pressed ? App.Style.accent : "transparent"
                    border.color: App.Style.accent
                    border.width: 2
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: App.Style.primaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (androidAutoManager) {
                        androidAutoManager.stop()
                    }
                    stackView.pop()
                }
            }

            Text {
                text: "Android Auto"
                font.pixelSize: 24
                font.bold: true
                font.family: androidAutoView.globalFont
                color: App.Style.primaryTextColor
                Layout.fillWidth: true
            }

            // Connection status indicator
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: {
                    if (isStreaming) return "#44FF44"
                    if (isConnected) return "#FFAA00"
                    return "#FF4444"
                }

                SequentialAnimation on opacity {
                    running: !isConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
        }
    }

    // Seamless DHU display - shows captured frames from the DHU
    Rectangle {
        id: dhuDisplay
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "black"
        visible: dhuEmbedded

        // Display captured DHU frames
        Image {
            id: dhuFrame
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: false
            // The source URL includes frameCounter to force refresh
            source: dhuEmbedded ? "image://dhuframe/frame?" + frameCounter : ""
        }

        // Touch/click forwarding to DHU
        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                // Calculate position relative to the image
                var imgRect = dhuFrame.paintedWidth > 0 ? {
                    x: (dhuFrame.width - dhuFrame.paintedWidth) / 2,
                    y: (dhuFrame.height - dhuFrame.paintedHeight) / 2,
                    width: dhuFrame.paintedWidth,
                    height: dhuFrame.paintedHeight
                } : { x: 0, y: 0, width: dhuFrame.width, height: dhuFrame.height }

                // Only forward if click is within the image bounds
                if (mouse.x >= imgRect.x && mouse.x <= imgRect.x + imgRect.width &&
                    mouse.y >= imgRect.y && mouse.y <= imgRect.y + imgRect.height) {
                    // Scale to DHU coordinates (assuming 800x480)
                    var dhuX = Math.round((mouse.x - imgRect.x) / imgRect.width * 800)
                    var dhuY = Math.round((mouse.y - imgRect.y) / imgRect.height * 480)
                    console.log("DHU click:", dhuX, dhuY)
                    if (androidAutoManager) {
                        androidAutoManager.sendDhuClick(dhuX, dhuY)
                    }
                }
            }
        }

        // Close button overlay
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            width: 40
            height: 40
            radius: 20
            color: "#AA000000"
            z: 10

            Text {
                anchors.centerIn: parent
                text: "X"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (androidAutoManager) {
                        androidAutoManager.closeDhu()
                    }
                    dhuEmbedded = false
                    dhuWindowHandle = 0
                }
            }
        }

        // Loading indicator when starting
        Text {
            anchors.centerIn: parent
            text: "Starting Android Auto..."
            font.pixelSize: 24
            font.family: androidAutoView.globalFont
            color: "white"
            visible: dhuEmbedded && frameCounter < 5
        }
    }

    // Main content area (setup screen)
    Item {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        visible: !dhuEmbedded  // Hide when DHU is embedded

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 30
            width: parent.width * 0.8

            // Android Auto Logo
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 120
                radius: 60
                color: App.Style.accent
                opacity: 0.2

                Text {
                    anchors.centerIn: parent
                    text: "AA"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: androidAutoView.globalFont
                    color: App.Style.accent
                }

                SequentialAnimation on opacity {
                    running: !isConnected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0.2; duration: 1000; easing.type: Easing.InOutQuad }
                }
            }

            // Status text
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: statusMessage
                font.pixelSize: 20
                font.family: androidAutoView.globalFont
                color: App.Style.primaryTextColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // Connection state
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "State: " + connectionState
                font.pixelSize: 14
                font.family: androidAutoView.globalFont
                color: App.Style.secondaryTextColor
            }

            // Progress indicator
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 200
                height: 4
                radius: 2
                color: App.Style.secondaryTextColor
                opacity: 0.3
                visible: !isConnected

                Rectangle {
                    id: progressBar
                    width: 60
                    height: parent.height
                    radius: 2
                    color: App.Style.accent

                    SequentialAnimation on x {
                        running: !isConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 140; duration: 1000; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutQuad }
                    }
                }
            }

            // Connection mode selector
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                visible: !isConnected

                Text {
                    text: "Mode:"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                }

                Button {
                    text: "TCP"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 35

                    background: Rectangle {
                        color: transportMode === "tcp" ? App.Style.accent : "transparent"
                        border.color: App.Style.accent
                        border.width: 2
                        radius: 6
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: transportMode === "tcp" ? "white" : App.Style.primaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: transportMode = "tcp"
                }

                Button {
                    text: "USB"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 35

                    background: Rectangle {
                        color: transportMode === "usb" ? App.Style.accent : "transparent"
                        border.color: App.Style.accent
                        border.width: 2
                        radius: 6
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: transportMode === "usb" ? "white" : App.Style.primaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: transportMode = "usb"
                }
            }

            // Start/Stop button
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: isConnected ? "Stop Android Auto" : "Start Android Auto"
                font.pixelSize: 18
                font.family: androidAutoView.globalFont
                Layout.preferredWidth: 250
                Layout.preferredHeight: 50

                background: Rectangle {
                    color: parent.pressed ? Qt.darker(App.Style.accent, 1.2) : App.Style.accent
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (androidAutoManager) {
                        if (isConnected) {
                            androidAutoManager.stop()
                        } else {
                            if (transportMode === "tcp") {
                                androidAutoManager.startTcp()
                            } else {
                                androidAutoManager.startUsb()
                            }
                        }
                    }
                }
            }

            // Instructions for TCP mode
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                spacing: 8
                visible: !isConnected && transportMode === "tcp"

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "TCP Mode Setup:"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "1. Enable Developer Mode in Android Auto"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.8
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "   (Tap version number 10 times)"
                    font.pixelSize: 12
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.6
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "2. Select 'Start head unit server' on phone"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.8
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "3. Run: adb forward tcp:5277 tcp:5277"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.accent
                    opacity: 1.0
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "4. Click Start Android Auto"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.8
                }
            }

            // Instructions for USB mode
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                spacing: 8
                visible: !isConnected && transportMode === "usb"

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "USB Mode Setup:"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "1. Connect phone via USB cable"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.8
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "2. Accept prompts on phone"
                    font.pixelSize: 14
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    opacity: 0.8
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Note: Requires Android Auto 12.6 or earlier"
                    font.pixelSize: 12
                    font.family: androidAutoView.globalFont
                    color: "#FFAA00"
                    opacity: 0.9
                }
            }

            // Google DHU section - alternative that works with all AA versions
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                width: parent.width
                height: dhuColumn.height + 30
                color: "#2a4a2a"
                radius: 8
                border.color: "#44AA44"
                border.width: 1
                visible: !isConnected

                ColumnLayout {
                    id: dhuColumn
                    anchors.centerIn: parent
                    spacing: 10
                    width: parent.width - 40

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Alternative: Google DHU"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: androidAutoView.globalFont
                        color: "#88DD88"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Works with all Android Auto versions"
                        font.pixelSize: 12
                        font.family: androidAutoView.globalFont
                        color: "#88DD88"
                        opacity: 0.8
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Button {
                            text: "Start Seamless"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 40

                            background: Rectangle {
                                color: parent.pressed ? "#2a6a2a" : "#3a8a3a"
                                radius: 6
                                border.color: "#44AA44"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                if (androidAutoManager) {
                                    var success = androidAutoManager.launchDhuSeamless()
                                    if (!success) {
                                        dhuInstallInstructions.visible = true
                                    }
                                }
                            }
                        }

                        Button {
                            text: "Launch External"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 40

                            background: Rectangle {
                                color: parent.pressed ? "#2a4a2a" : "transparent"
                                radius: 6
                                border.color: "#44AA44"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#88DD88"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                if (androidAutoManager) {
                                    var success = androidAutoManager.launchGoogleDhu()
                                    if (!success) {
                                        dhuInstallInstructions.visible = true
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: dhuInstallInstructions
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: parent.width - 20
                        visible: false
                        text: "Install via Android Studio:\nTools → SDK Manager → SDK Tools tab\n→ 'Android Auto Desktop Head Unit Emulator'"
                        font.pixelSize: 11
                        font.family: androidAutoView.globalFont
                        color: "#FFAA44"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Debug info (for development)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                width: parent.width
                height: debugColumn.height + 20
                color: App.Style.hoverColor
                radius: 8
                opacity: 0.5

                ColumnLayout {
                    id: debugColumn
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "Debug Info"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: androidAutoView.globalFont
                        color: App.Style.secondaryTextColor
                    }

                    Text {
                        text: "Manager available: " + (androidAutoManager ? "Yes" : "No")
                        font.pixelSize: 11
                        font.family: androidAutoView.globalFont
                        color: App.Style.secondaryTextColor
                    }

                    Text {
                        text: "Connection state: " + connectionState
                        font.pixelSize: 11
                        font.family: androidAutoView.globalFont
                        color: App.Style.secondaryTextColor
                    }

                    Text {
                        text: "Is connected: " + isConnected
                        font.pixelSize: 11
                        font.family: androidAutoView.globalFont
                        color: App.Style.secondaryTextColor
                    }

                    Text {
                        text: "Transport mode: " + transportMode.toUpperCase()
                        font.pixelSize: 11
                        font.family: androidAutoView.globalFont
                        color: App.Style.secondaryTextColor
                    }
                }
            }
        }
    }

    // Connect to Android Auto manager signals
    Connections {
        target: androidAutoManager

        function onStateChanged(state) {
            androidAutoView.connectionState = state
        }

        function onConnectionProgress(message) {
            androidAutoView.statusMessage = message
        }

        function onError(errorMessage) {
            androidAutoView.statusMessage = "Error: " + errorMessage
        }

        function onDhuWindowReady(hwnd) {
            console.log("DHU window ready:", hwnd)
            androidAutoView.dhuWindowHandle = hwnd
            androidAutoView.dhuEmbedded = true
        }

        function onDhuEmbeddedChanged(embedded) {
            androidAutoView.dhuEmbedded = embedded
            if (!embedded) {
                androidAutoView.dhuWindowHandle = 0
                androidAutoView.frameCounter = 0
            }
        }
    }

    // Connection to DHU capture for frame updates
    Connections {
        target: androidAutoManager ? androidAutoManager.dhuCapture : null

        function onFrameReady() {
            // Increment counter to force image refresh
            androidAutoView.frameCounter++
        }
    }

    Component.onCompleted: {
        console.log("AndroidAutoView loaded")
        console.log("androidAutoManager available:", androidAutoManager ? "yes" : "no")
    }
}
