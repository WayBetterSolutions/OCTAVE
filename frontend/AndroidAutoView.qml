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
    property bool autoLaunchSeamless: true  // Always auto-launch seamless DHU
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string globalFont: App.Style.fontFamily

    // DHU embedding state
    property bool dhuEmbedded: false
    property int frameCounter: 0  // Used to refresh the image
    property bool launchFailed: false
    property string errorMessage: ""

    // Dark background
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Seamless DHU display - shows captured frames from the DHU
    Rectangle {
        id: dhuDisplay
        anchors.fill: parent
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
                    stackView.pop()
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

    // Error/Setup screen - shown when DHU is not embedded
    Item {
        anchors.fill: parent
        visible: !dhuEmbedded

        // Back button (top left)
        Button {
            id: backButton
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 15
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
                // Just go back - don't close DHU, let it run in background
                stackView.pop()
            }
        }

        // Main content - centered
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 25
            width: parent.width * 0.8

            // Loading state (before we know if it failed)
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                visible: !launchFailed

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Starting Android Auto..."
                    font.pixelSize: 24
                    font.family: androidAutoView.globalFont
                    color: App.Style.primaryTextColor
                }

                // Progress indicator
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 200
                    height: 4
                    radius: 2
                    color: App.Style.secondaryTextColor
                    opacity: 0.3

                    Rectangle {
                        id: progressBar
                        width: 60
                        height: parent.height
                        radius: 2
                        color: App.Style.accent

                        SequentialAnimation on x {
                            running: !launchFailed && !dhuEmbedded
                            loops: Animation.Infinite
                            NumberAnimation { to: 140; duration: 1000; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // Error state
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                visible: launchFailed

                // Error icon
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 80
                    height: 80
                    radius: 40
                    color: "#442222"
                    border.color: "#FF6666"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        font.pixelSize: 48
                        font.bold: true
                        color: "#FF6666"
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Could not start Android Auto"
                    font.pixelSize: 24
                    font.bold: true
                    font.family: androidAutoView.globalFont
                    color: "#FF6666"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: errorMessage
                    font.pixelSize: 16
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    visible: errorMessage !== ""
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                // Instructions box
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(500, parent.width)
                    height: instructionsColumn.height + 30
                    color: "#1a2a1a"
                    radius: 8
                    border.color: "#44AA44"
                    border.width: 1

                    ColumnLayout {
                        id: instructionsColumn
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Setup Instructions"
                            font.pixelSize: 18
                            font.bold: true
                            font.family: androidAutoView.globalFont
                            color: "#88DD88"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "1. Connect your phone via USB"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "2. Enable Developer Mode in Android Auto app"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "(Settings > Tap version 10 times)"
                            font.pixelSize: 12
                            font.family: androidAutoView.globalFont
                            color: "#888888"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "3. Start 'Head unit server' on your phone"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "4. Make sure Google DHU is installed"
                            font.pixelSize: 14
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: parent.width
                            text: "Install via Android Studio:\nTools > SDK Manager > SDK Tools >\n'Android Auto Desktop Head Unit Emulator'"
                            font.pixelSize: 11
                            font.family: androidAutoView.globalFont
                            color: "#FFAA44"
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Retry button
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    text: "Try Again"
                    font.pixelSize: 16
                    font.family: androidAutoView.globalFont
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 45

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
                        launchFailed = false
                        errorMessage = ""
                        if (androidAutoManager) {
                            var success = androidAutoManager.launchDhuSeamless()
                            if (!success) {
                                launchFailed = true
                                errorMessage = "DHU not found or failed to start"
                            }
                        }
                    }
                }
            }
        }
    }

    // Connect to Android Auto manager signals
    Connections {
        target: androidAutoManager

        function onError(msg) {
            androidAutoView.launchFailed = true
            androidAutoView.errorMessage = msg
        }

        function onDhuWindowReady(hwnd) {
            console.log("DHU window ready:", hwnd)
            androidAutoView.dhuEmbedded = true
            androidAutoView.launchFailed = false
        }

        function onDhuEmbeddedChanged(embedded) {
            androidAutoView.dhuEmbedded = embedded
            if (!embedded) {
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

    // Timer to force initial frame refresh when DHU becomes embedded
    Timer {
        id: initialRefreshTimer
        interval: 100
        repeat: true
        running: dhuEmbedded && frameCounter < 30  // Run for first ~3 seconds
        onTriggered: {
            // Force frame counter increment to ensure image refreshes
            androidAutoView.frameCounter++
        }
    }

    Component.onCompleted: {
        console.log("AndroidAutoView loaded")
        console.log("androidAutoManager available:", androidAutoManager ? "yes" : "no")

        if (androidAutoManager) {
            // Check if DHU is already running (user navigated back)
            if (androidAutoManager.isDhuEmbedded) {
                console.log("DHU already running, resuming display")
                dhuEmbedded = true
                launchFailed = false
            } else {
                // Launch seamless DHU
                var success = androidAutoManager.launchDhuSeamless()
                if (!success) {
                    launchFailed = true
                    errorMessage = "DHU not found or failed to start"
                }
            }
        }
    }
}
