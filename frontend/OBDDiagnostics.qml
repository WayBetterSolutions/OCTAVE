import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: obdDiagnosticsPage
    objectName: "obdDiagnostics"
    required property StackView stackView
    required property ApplicationWindow mainWindow

    // Global font binding for all text in this component
    property string globalFont: App.Style.fontFamily

    // Define background and accent colors matching OBDMenu
    property color backgroundColor: App.Style.obdBoxBackground
    property color accentColor: App.Style.obdBarColor
    property color textColor: App.Style.primaryTextColor

    // Diagnostic data storage
    property var dtcCodes: []
    property int dtcCount: 0
    property bool milStatus: false
    property var freezeFrameData: []
    property bool isLoading: false
    property string statusMessage: ""

    // OBD Diagnostic Connections
    Connections {
        target: obdManager

        function onDtcCodesChanged(codes) {
            dtcCodes = codes
            isLoading = false
            statusMessage = codes.length > 0 ? "Found " + codes.length + " DTC(s)" : "No DTCs found"

            // Output to terminal
            if (codes.length > 0) {
                terminalOutput.appendLine("[FOUND] " + codes.length + " DTC(s) detected:")
                for (var i = 0; i < codes.length; i++) {
                    var dtc = codes[i]
                    terminalOutput.appendLine("[DTC] " + dtc.code + " - " + dtc.description)
                }
            } else {
                terminalOutput.appendLine("[DONE] No trouble codes found")
            }
        }

        function onDtcCountChanged(count) {
            dtcCount = count
            terminalOutput.appendLine("[INFO] DTC count: " + count)
        }

        function onMilStatusChanged(status) {
            milStatus = status
            if (status) {
                terminalOutput.appendLine("[WARN] Check Engine Light is ON")
            } else {
                terminalOutput.appendLine("[DONE] Check Engine Light is OFF")
            }
        }

        function onDtcClearResult(success, message) {
            isLoading = false
            statusMessage = message
            if (success) {
                dtcCodes = []
                dtcCount = 0
                milStatus = false
                terminalOutput.appendLine("[SUCCESS] " + message)
            } else {
                terminalOutput.appendLine("[ERROR] " + message)
            }
        }

        function onFreezeFrameChanged(data) {
            freezeFrameData = data
            isLoading = false

            if (data.length > 0) {
                terminalOutput.appendLine("[FOUND] Freeze frame data:")
                for (var i = 0; i < data.length; i++) {
                    var ff = data[i]
                    terminalOutput.appendLine("[DTC] " + ff.code + " - " + ff.description)
                }
            } else {
                terminalOutput.appendLine("[DONE] No freeze frame data stored")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: App.Spacing.overallMargin
            spacing: 15


            // 4x2 Grid - 4 buttons on top, terminal + clear on bottom
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 4
                rows: 2
                rowSpacing: 15
                columnSpacing: 15

                // Row 1: Read DTCs, Current DTCs, Read Status, Freeze Frame

                // Read DTCs Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 0
                    radius: 12
                    color: mouseAreaReadDTC.pressed ? Qt.darker(accentColor, 1.2) : accentColor

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Read DTCs"
                            font.pixelSize: Math.min(32, parent.width * 0.16)
                            font.bold: true
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Stored trouble codes"
                            font.pixelSize: Math.min(18, parent.width * 0.09)
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseAreaReadDTC
                        anchors.fill: parent
                        onClicked: {
                            isLoading = true
                            statusMessage = "Reading DTCs..."
                            terminalOutput.appendLine("[SCAN] Reading stored DTCs...")
                            obdManager.read_dtc()
                        }
                    }
                }

                // Read Current DTCs Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 1
                    radius: 12
                    color: mouseAreaReadCurrentDTC.pressed ? Qt.darker(accentColor, 1.2) : accentColor

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Current DTCs"
                            font.pixelSize: Math.min(32, parent.width * 0.16)
                            font.bold: true
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Active this drive cycle"
                            font.pixelSize: Math.min(18, parent.width * 0.09)
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseAreaReadCurrentDTC
                        anchors.fill: parent
                        onClicked: {
                            isLoading = true
                            statusMessage = "Reading current DTCs..."
                            terminalOutput.appendLine("[SCAN] Reading current drive cycle DTCs...")
                            obdManager.read_current_dtc()
                        }
                    }
                }

                // Read Status Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 2
                    radius: 12
                    color: mouseAreaReadStatus.pressed ? Qt.darker(accentColor, 1.2) : accentColor

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Read Status"
                            font.pixelSize: Math.min(32, parent.width * 0.16)
                            font.bold: true
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "CEL & DTC count"
                            font.pixelSize: Math.min(18, parent.width * 0.09)
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseAreaReadStatus
                        anchors.fill: parent
                        onClicked: {
                            isLoading = true
                            statusMessage = "Reading vehicle status..."
                            terminalOutput.appendLine("[SCAN] Reading vehicle status...")
                            obdManager.read_status()
                        }
                    }
                }

                // Freeze Frame Button (row 0, column 3)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 0
                    Layout.column: 3
                    radius: 12
                    color: mouseAreaFreezeFrame.pressed ? Qt.darker(accentColor, 1.2) : accentColor

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Freeze Frame"
                            font.pixelSize: Math.min(32, parent.width * 0.16)
                            font.bold: true
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Snapshot at fault"
                            font.pixelSize: Math.min(18, parent.width * 0.09)
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseAreaFreezeFrame
                        anchors.fill: parent
                        onClicked: {
                            isLoading = true
                            statusMessage = "Reading freeze frame..."
                            terminalOutput.appendLine("[SCAN] Reading freeze frame data...")
                            obdManager.read_freeze_frame()
                        }
                    }
                }

                // Row 2: Terminal Results Panel (3 cols), Clear DTCs (1 col)

                // Terminal-style Results Panel (spans 3 columns)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 1
                    Layout.column: 0
                    Layout.columnSpan: 3
                    radius: 12
                    color: "#1a1a1a"
                    border.color: "#333333"
                    border.width: 2
                    clip: true

                    // Scanline overlay effect
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        z: 10

                        // CRT scanline effect
                        Canvas {
                            id: scanlineCanvas
                            anchors.fill: parent
                            opacity: 0.03

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "#000000"
                                ctx.lineWidth = 1
                                for (var y = 0; y < height; y += 2) {
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(width, y)
                                    ctx.stroke()
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 1
                        spacing: 0

                        // Terminal header bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: "#2d2d2d"
                            radius: 12

                            // Bottom corners not rounded
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 12
                                color: parent.color
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "DIAGNOSTIC OUTPUT"
                                    color: "#888888"
                                    font.pixelSize: 18
                                    font.family: "Consolas, Monaco, monospace"
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                BusyIndicator {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    running: isLoading
                                    visible: isLoading
                                }
                            }
                        }

                        // Terminal content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: terminalFlickable
                                anchors.fill: parent
                                anchors.margins: 8
                                contentWidth: width
                                contentHeight: terminalContent.height
                                clip: true
                                flickableDirection: Flickable.VerticalFlick
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: terminalContent
                                    width: terminalFlickable.width
                                    spacing: 3

                                    Repeater {
                                        model: terminalOutput.lines

                                        Text {
                                            width: terminalContent.width
                                            text: modelData.text
                                            color: modelData.color || "#00ff00"
                                            font.pixelSize: 18
                                            font.family: "Consolas, Monaco, monospace"
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        }
                                    }
                                }

                                onContentHeightChanged: {
                                    if (contentHeight > height) {
                                        contentY = contentHeight - height
                                    }
                                }
                            }

                            // Empty state
                            Text {
                                anchors.centerIn: parent
                                visible: terminalOutput.lines.length === 0 && !isLoading
                                text: "> Awaiting command..."
                                font.pixelSize: 20
                                font.family: "Consolas, Monaco, monospace"
                                color: "#00ff00"
                                opacity: 0.5
                            }

                            // Cursor blink effect
                            Rectangle {
                                visible: terminalOutput.lines.length === 0 && !isLoading
                                anchors.left: parent.horizontalCenter
                                anchors.leftMargin: 70
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 14
                                color: "#00ff00"
                                opacity: cursorTimer.blink ? 0.8 : 0

                                Timer {
                                    id: cursorTimer
                                    property bool blink: true
                                    interval: 530
                                    repeat: true
                                    running: terminalOutput.lines.length === 0
                                    onTriggered: blink = !blink
                                }
                            }
                        }
                    }

                    // Terminal output data handler
                    QtObject {
                        id: terminalOutput
                        property var lines: []
                        property int maxLines: 50

                        function appendLine(text) {
                            var lineColor = "#00ff00"  // Default green

                            if (text.indexOf("[ERROR]") === 0) {
                                lineColor = "#ff4444"
                            } else if (text.indexOf("[DONE]") === 0 || text.indexOf("[SUCCESS]") === 0) {
                                lineColor = "#44ff44"
                            } else if (text.indexOf("[INFO]") === 0 || text.indexOf("[SCAN]") === 0) {
                                lineColor = "#4a9eff"
                            } else if (text.indexOf("[WARN]") === 0) {
                                lineColor = "#ffaa00"
                            } else if (text.indexOf("[FOUND]") === 0) {
                                lineColor = "#44ff44"
                            } else if (text.indexOf("[CLEAR]") === 0) {
                                lineColor = "#ff6600"
                            } else if (text.indexOf("[DTC]") === 0) {
                                lineColor = "#ff6600"
                            }

                            var now = new Date()
                            var timestamp = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss")
                            var formattedText = "[" + timestamp + "] " + text

                            var newLines = lines.slice()
                            newLines.push({ text: formattedText, color: lineColor })

                            while (newLines.length > maxLines) {
                                newLines.shift()
                            }

                            lines = newLines
                        }

                        function clear() {
                            lines = []
                        }
                    }
                }

                // Clear DTCs Button (row 1, column 3 - bottom right)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: 1
                    Layout.column: 3
                    radius: 12
                    color: mouseAreaClearDTC.pressed ? Qt.darker("#CC0000", 1.2) : "#CC0000"

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Clear DTCs"
                            font.pixelSize: Math.min(32, parent.width * 0.16)
                            font.bold: true
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Reset CEL & codes"
                            font.pixelSize: Math.min(18, parent.width * 0.09)
                            font.family: obdDiagnosticsPage.globalFont
                            color: "white"
                            opacity: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseAreaClearDTC
                        anchors.fill: parent
                        onClicked: {
                            clearConfirmDialog.open()
                        }
                    }
                }
            }
        }
    }

    // Clear DTCs Confirmation Dialog
    Dialog {
        id: clearConfirmDialog
        title: "Clear Diagnostic Trouble Codes"
        anchors.centerIn: parent
        width: 400
        modal: true
        standardButtons: Dialog.Yes | Dialog.No

        background: Rectangle {
            color: App.Style.backgroundColor
            radius: 8
            border.color: accentColor
            border.width: 2
        }

        contentItem: ColumnLayout {
            spacing: 15

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 360
                text: "Are you sure you want to clear all DTCs?"
                font.pixelSize: 16
                font.family: obdDiagnosticsPage.globalFont
                color: obdDiagnosticsPage.textColor
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "This will also reset the Check Engine Light and clear freeze frame data."
                font.pixelSize: 14
                font.family: obdDiagnosticsPage.globalFont
                color: obdDiagnosticsPage.textColor
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Warning: This may affect emissions testing readiness."
                font.pixelSize: 13
                font.family: obdDiagnosticsPage.globalFont
                color: "#FF6600"
                wrapMode: Text.WordWrap
            }
        }

        onAccepted: {
            isLoading = true
            statusMessage = "Clearing DTCs..."
            terminalOutput.appendLine("[CLEAR] Clearing all DTCs and resetting CEL...")
            obdManager.clear_dtc()
        }
    }

    // Load status on component creation
    Component.onCompleted: {
        terminalOutput.appendLine("[INFO] Diagnostic mode initialized")
        terminalOutput.appendLine("[SCAN] Reading vehicle status...")
        obdManager.read_status()
    }
}
