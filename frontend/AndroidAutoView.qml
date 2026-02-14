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

    // DHU embedding state
    property bool dhuEmbedded: false
    property bool launchFailed: false
    property string errorMessage: ""

    // Dark background
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Embedded DHU display - the DHU window is embedded directly inside OCTAVE
    Item {
        id: dhuContainer
        anchors.fill: parent
        visible: dhuEmbedded

        // This is the embedded DHU widget - the actual DHU window becomes a child of this
        EmbeddedDhuItem {
            id: embeddedDhu
            anchors.fill: parent

            Component.onCompleted: {
                if (androidAutoManager) {
                    connectToManager(androidAutoManager)
                }
            }

            onStreamStarted: {
                console.log("DHU stream started - embedded seamlessly")
            }

            onStreamStopped: {
                console.log("DHU stream stopped")
                androidAutoView.dhuEmbedded = false
            }

            onErrorOccurred: function(error) {
                console.log("DHU error:", error)
                androidAutoView.launchFailed = true
                androidAutoView.errorMessage = error
            }
        }

        // Close button overlay
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: App.Spacing.dp(10)
            width: App.Spacing.dp(40)
            height: App.Spacing.dp(40)
            radius: App.Spacing.dpMin(20, 2)
            color: "#AA000000"
            z: 10

            Text {
                anchors.centerIn: parent
                text: "X"
                font.pixelSize: App.Spacing.dp(20)
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
            font.pixelSize: App.Spacing.dp(24)
            font.family: androidAutoView.globalFont
            color: "white"
            visible: dhuEmbedded && !embeddedDhu.isStreaming
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
            anchors.margins: App.Spacing.dp(15)
            text: "< Back"
            font.pixelSize: App.Spacing.dp(16)
            font.family: androidAutoView.globalFont

            background: Rectangle {
                color: parent.pressed ? App.Style.accent : "transparent"
                border.color: App.Style.accent
                border.width: 2
                radius: App.Spacing.dpMin(8, 2)
            }

            contentItem: Text {
                text: parent.text
                font: parent.font
                color: App.Style.primaryTextColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                stackView.pop()
            }
        }

        // Main content - centered
        ColumnLayout {
            anchors.centerIn: parent
            spacing: App.Spacing.dp(25)
            width: parent.width * 0.8

            // Loading state (before we know if it failed)
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: App.Spacing.dp(20)
                visible: !launchFailed

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Starting Android Auto..."
                    font.pixelSize: App.Spacing.dp(24)
                    font.family: androidAutoView.globalFont
                    color: App.Style.primaryTextColor
                }

                // Progress indicator
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: App.Spacing.dp(200)
                    height: App.Spacing.dp(4)
                    radius: 2
                    color: App.Style.secondaryTextColor
                    opacity: 0.3

                    Rectangle {
                        id: progressBar
                        width: App.Spacing.dp(60)
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
                spacing: App.Spacing.dp(20)
                visible: launchFailed

                // Error icon
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: App.Spacing.dp(80)
                    height: App.Spacing.dp(80)
                    radius: App.Spacing.dpMin(40, 2)
                    color: "#442222"
                    border.color: "#FF6666"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        font.pixelSize: App.Spacing.dp(48)
                        font.bold: true
                        color: "#FF6666"
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Could not start Android Auto"
                    font.pixelSize: App.Spacing.dp(24)
                    font.bold: true
                    font.family: androidAutoView.globalFont
                    color: "#FF6666"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: errorMessage
                    font.pixelSize: App.Spacing.dp(16)
                    font.family: androidAutoView.globalFont
                    color: App.Style.secondaryTextColor
                    visible: errorMessage !== ""
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                // Instructions box
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(App.Spacing.dp(500), parent.width)
                    height: instructionsColumn.height + App.Spacing.dp(30)
                    color: "#1a2a1a"
                    radius: App.Spacing.dpMin(8, 2)
                    border.color: "#44AA44"
                    border.width: 1

                    ColumnLayout {
                        id: instructionsColumn
                        anchors.centerIn: parent
                        width: parent.width - App.Spacing.dp(40)
                        spacing: App.Spacing.dp(12)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Setup Instructions"
                            font.pixelSize: App.Spacing.dp(18)
                            font.bold: true
                            font.family: androidAutoView.globalFont
                            color: "#88DD88"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "1. Connect your phone via USB"
                            font.pixelSize: App.Spacing.dp(14)
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "2. Enable Developer Mode in Android Auto app"
                            font.pixelSize: App.Spacing.dp(14)
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "(Settings > Tap version 10 times)"
                            font.pixelSize: App.Spacing.dp(12)
                            font.family: androidAutoView.globalFont
                            color: "#888888"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "3. Start 'Head unit server' on your phone"
                            font.pixelSize: App.Spacing.dp(14)
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "4. Make sure Google DHU is installed"
                            font.pixelSize: App.Spacing.dp(14)
                            font.family: androidAutoView.globalFont
                            color: "#CCCCCC"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: parent.width
                            text: "Install via Android Studio:\nTools > SDK Manager > SDK Tools >\n'Android Auto Desktop Head Unit Emulator'"
                            font.pixelSize: App.Spacing.dp(11)
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
                    Layout.topMargin: App.Spacing.dp(10)
                    text: "Try Again"
                    font.pixelSize: App.Spacing.dp(16)
                    font.family: androidAutoView.globalFont
                    Layout.preferredWidth: App.Spacing.dp(150)
                    Layout.preferredHeight: App.Spacing.dp(45)

                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(App.Style.accent, 1.2) : App.Style.accent
                        radius: App.Spacing.dpMin(8, 2)
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
        }
    }

    // Handle view becoming visible/hidden for detach/reattach
    onVisibleChanged: {
        if (visible && dhuEmbedded) {
            embeddedDhu.reattach()
        } else if (!visible && dhuEmbedded) {
            embeddedDhu.detach()
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
                // Reattach the embedded window
                embeddedDhu.reattach()
            } else {
                // Launch DHU
                var success = androidAutoManager.launchDhuSeamless()
                if (!success) {
                    launchFailed = true
                    errorMessage = "DHU not found or failed to start"
                }
            }
        }
    }
}
