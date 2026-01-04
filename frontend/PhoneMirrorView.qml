import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Basic 2.15
import OCTAVE.PhoneMirror 1.0
import "." as App

Item {
    id: phoneMirrorView
    property StackView stackView
    property var mainWindow: null
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string globalFont: App.Style.fontFamily

    // Mirror state - uses frame capture approach
    property bool mirrorRunning: false
    property int frameCounter: 0  // Used to refresh the image
    property bool launchFailed: false
    property string errorMessage: ""

    // Handle when this view becomes active again
    StackView.onActivated: {
        console.log("PhoneMirrorView activated")
        if (phoneMirrorManager && phoneMirrorManager.isRunning) {
            console.log("Scrcpy is running, resuming capture...")
            resumeCapture()
        }
    }

    // Handle when this view is deactivated
    StackView.onDeactivated: {
        console.log("PhoneMirrorView deactivated - pausing capture")
        pauseCapture()
    }

    function pauseCapture() {
        if (scrcpyCapture) {
            scrcpyCapture.stopCapture()
        }
    }

    function resumeCapture() {
        if (scrcpyCapture && phoneMirrorManager && phoneMirrorManager.isRunning) {
            var hwnd = phoneMirrorManager.scrcpyWindowHandle
            if (hwnd) {
                scrcpyCapture.setWindowHandle(hwnd)
                scrcpyCapture.startCapture()
                mirrorRunning = true
            }
        }
    }

    // Dark background
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Phone Mirror display - shows captured frames from scrcpy
    Rectangle {
        id: phoneDisplay
        anchors.fill: parent
        color: "black"
        visible: mirrorRunning

        // Display captured scrcpy frames
        Image {
            id: phoneFrame
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: false
            smooth: true
            antialiasing: true
            mipmap: true
            // The source URL includes frameCounter to force refresh
            source: mirrorRunning ? "image://scrcpyframe/frame?" + frameCounter : ""
        }

        // Touch/click forwarding to scrcpy
        MouseArea {
            id: touchArea
            anchors.fill: parent
            hoverEnabled: false

            property bool isDragging: false
            property real lastX: 0
            property real lastY: 0

            function getRelativePosition(mouseX, mouseY) {
                // Get the painted image bounds (accounting for aspect ratio letterboxing)
                var imgX = (phoneFrame.width - phoneFrame.paintedWidth) / 2
                var imgY = (phoneFrame.height - phoneFrame.paintedHeight) / 2
                var imgW = phoneFrame.paintedWidth
                var imgH = phoneFrame.paintedHeight

                if (imgW <= 0 || imgH <= 0) {
                    return { x: 0, y: 0, valid: false }
                }

                // Check if within image bounds
                if (mouseX >= imgX && mouseX <= imgX + imgW &&
                    mouseY >= imgY && mouseY <= imgY + imgH) {
                    // Get position relative to image (0.0 to 1.0)
                    var relX = (mouseX - imgX) / imgW
                    var relY = (mouseY - imgY) / imgH
                    return { x: relX, y: relY, valid: true }
                }
                return { x: 0, y: 0, valid: false }
            }

            onPressed: function(mouse) {
                var pos = getRelativePosition(mouse.x, mouse.y)
                if (pos.valid && scrcpyCapture) {
                    isDragging = true
                    lastX = pos.x
                    lastY = pos.y
                    // Send relative position (0.0-1.0) - capture will scale to actual window
                    scrcpyCapture.sendTouchEvent(pos.x, pos.y, true)
                }
            }

            onReleased: function(mouse) {
                if (isDragging && scrcpyCapture) {
                    var pos = getRelativePosition(mouse.x, mouse.y)
                    var finalX = pos.valid ? pos.x : lastX
                    var finalY = pos.valid ? pos.y : lastY
                    scrcpyCapture.sendTouchEvent(finalX, finalY, false)
                }
                isDragging = false
            }

            onPositionChanged: function(mouse) {
                if (isDragging && scrcpyCapture) {
                    var pos = getRelativePosition(mouse.x, mouse.y)
                    if (pos.valid) {
                        lastX = pos.x
                        lastY = pos.y
                        scrcpyCapture.sendTouchMove(pos.x, pos.y)
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
                    if (scrcpyCapture) {
                        scrcpyCapture.stopCapture()
                    }
                    if (phoneMirrorManager) {
                        phoneMirrorManager.stopScrcpy()
                    }
                    mirrorRunning = false
                    stackView.pop()
                }
            }
        }

        // Loading indicator (show briefly while frames start)
        Text {
            anchors.centerIn: parent
            text: "Connecting..."
            font.pixelSize: 24
            font.family: phoneMirrorView.globalFont
            color: "white"
            visible: mirrorRunning && frameCounter < 10
        }
    }

    // Error/Setup screen - shown when mirror is not running
    Item {
        anchors.fill: parent
        visible: !mirrorRunning

        // Back button (top left)
        Button {
            id: backButton
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 15
            text: "< Back"
            font.pixelSize: 16
            font.family: phoneMirrorView.globalFont

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
                if (scrcpyCapture) {
                    scrcpyCapture.stopCapture()
                }
                if (phoneMirrorManager) {
                    phoneMirrorManager.stopScrcpy()
                }
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
                    text: "Starting Phone Mirror..."
                    font.pixelSize: 24
                    font.family: phoneMirrorView.globalFont
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
                            running: !launchFailed && !mirrorRunning
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
                spacing: 15
                visible: launchFailed

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Phone Mirror Failed"
                    font.pixelSize: 28
                    font.family: phoneMirrorView.globalFont
                    font.bold: true
                    color: "#FF6666"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: errorMessage
                    font.pixelSize: 16
                    font.family: phoneMirrorView.globalFont
                    color: App.Style.secondaryTextColor
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: parent.width
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    text: "Setup Instructions"
                    font.pixelSize: 20
                    font.family: phoneMirrorView.globalFont
                    font.bold: true
                    color: App.Style.primaryTextColor
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: phoneMirrorManager ? phoneMirrorManager.getInstallInstructions() : "Phone Mirror manager not available"
                    font.pixelSize: 14
                    font.family: phoneMirrorView.globalFont
                    color: App.Style.secondaryTextColor
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: parent.width * 0.8
                }

                // Retry button
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    text: "Retry"
                    font.pixelSize: 18
                    font.family: phoneMirrorView.globalFont

                    background: Rectangle {
                        color: parent.pressed ? App.Style.accent : "transparent"
                        border.color: App.Style.accent
                        border.width: 2
                        radius: 8
                        implicitWidth: 150
                        implicitHeight: 50
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: App.Style.primaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        launchFailed = false
                        errorMessage = ""
                        frameCounter = 0
                        startMirror()
                    }
                }
            }
        }
    }

    // Function to start the mirror
    function startMirror() {
        if (!phoneMirrorManager) {
            launchFailed = true
            errorMessage = "Phone Mirror manager not available"
            return
        }

        // If already running, just resume capture
        if (phoneMirrorManager.isRunning) {
            console.log("Phone Mirror: already running, resuming capture")
            resumeCapture()
            return
        }

        if (!phoneMirrorManager.isScrcpyInstalled) {
            launchFailed = true
            errorMessage = "scrcpy not installed. Download from https://github.com/Genymobile/scrcpy"
            return
        }

        if (!phoneMirrorManager.hasConnectedDevice()) {
            launchFailed = true
            errorMessage = "No Android device connected. Connect via USB and enable USB debugging."
            return
        }

        // Start scrcpy - the scrcpyStarted signal will trigger capture
        console.log("Starting scrcpy via manager")
        phoneMirrorManager.startScrcpy()
    }

    // Connect to manager signals
    Connections {
        target: phoneMirrorManager

        function onScrcpyStarted(hwnd) {
            console.log("Phone Mirror: scrcpy started with hwnd", hwnd)
            if (scrcpyCapture) {
                scrcpyCapture.setWindowHandle(hwnd)
                scrcpyCapture.startCapture()
            }
            mirrorRunning = true
            launchFailed = false
        }

        function onScrcpyStopped() {
            console.log("Phone Mirror: scrcpy stopped")
            if (scrcpyCapture) {
                scrcpyCapture.stopCapture()
            }
            mirrorRunning = false
            frameCounter = 0
        }

        function onScrcpyError(error) {
            console.log("Phone Mirror: error -", error)
            if (scrcpyCapture) {
                scrcpyCapture.stopCapture()
            }
            mirrorRunning = false
            launchFailed = true
            errorMessage = error
        }
    }

    // Connect to capture signals
    Connections {
        target: scrcpyCapture

        function onFrameReady() {
            // Increment counter to force image refresh
            phoneMirrorView.frameCounter++
        }

        function onError(errorMsg) {
            console.log("Phone Mirror capture error:", errorMsg)
            mirrorRunning = false
            launchFailed = true
            errorMessage = errorMsg
        }
    }

    // Initial frame refresh timer (ensures smooth startup)
    Timer {
        id: initialRefreshTimer
        interval: 50
        repeat: true
        running: mirrorRunning && frameCounter < 100
        onTriggered: {
            phoneMirrorView.frameCounter++
        }
    }

    Component.onCompleted: {
        console.log("PhoneMirrorView loaded")
        console.log("phoneMirrorManager available:", phoneMirrorManager ? "yes" : "no")
        console.log("scrcpyCapture available:", scrcpyCapture ? "yes" : "no")

        if (phoneMirrorManager) {
            console.log("scrcpy installed:", phoneMirrorManager.isScrcpyInstalled)
            console.log("scrcpy path:", phoneMirrorManager.scrcpyPath)
            console.log("scrcpy already running:", phoneMirrorManager.isRunning)

            // Start mirror
            startMirror()
        } else {
            launchFailed = true
            errorMessage = "Phone Mirror manager not available"
        }
    }

    Component.onDestruction: {
        console.log("PhoneMirrorView destroyed")
        if (scrcpyCapture) {
            scrcpyCapture.stopCapture()
        }
    }
}
