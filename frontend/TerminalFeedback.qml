import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

// Reusable terminal-style feedback component for displaying backend progress
// Usage: Add to settings or any page where backend feedback is needed
// Call appendLine(text) to add lines, clear() to reset
// Touch-friendly with flick scrolling

Rectangle {
    id: terminalFeedback

    // Configurable properties
    property int maxLines: 50           // Maximum lines to keep in buffer
    property bool autoScroll: true      // Auto-scroll to bottom on new lines
    property string title: "Output"     // Header title
    property bool showHeader: true      // Show/hide header
    property color terminalBackground: "#1a1a1a"
    property color terminalBorder: "#333333"
    property color textColor: "#00ff00"  // Classic terminal green
    property color errorColor: "#ff4444"
    property color infoColor: "#4a9eff"
    property color successColor: "#44ff44"
    property color warningColor: "#ffaa00"
    property real fontSize: App.Spacing.settingsTextFieldSize * 0.75

    // Internal state
    property var lines: []

    color: terminalBackground
    border.color: terminalBorder
    border.width: 1
    radius: 4
    clip: true

    // Default size (can be overridden)
    implicitHeight: 150
    implicitWidth: 300

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        // Header bar
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: showHeader ? 36 : 0  // Larger for touch
            visible: showHeader
            color: "#2d2d2d"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: terminalFeedback.title
                    color: "#888888"
                    font.pixelSize: terminalFeedback.fontSize
                    font.family: App.Style.fontFamily
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Clear button - larger touch target
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: clearMouseArea.pressed ? "#555555" :
                           clearMouseArea.containsMouse ? "#444444" : "#333333"

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: "#aaaaaa"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: terminalFeedback.clear()
                    }
                }
            }
        }

        // Terminal content area - touch-friendly Flickable
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flickable
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: contentColumn.height
                clip: true

                // Touch-friendly flicking
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                pressDelay: 0  // Immediate response for touch

                // Momentum and deceleration for smooth touch scrolling
                flickDeceleration: 1500
                maximumFlickVelocity: 4000

                // Content column with all lines
                Column {
                    id: contentColumn
                    width: flickable.width
                    spacing: 4

                    Repeater {
                        model: terminalFeedback.lines

                        Text {
                            width: contentColumn.width
                            text: modelData.text
                            color: modelData.color || terminalFeedback.textColor
                            font.pixelSize: terminalFeedback.fontSize
                            font.family: "Consolas, Monaco, monospace"
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            textFormat: Text.PlainText
                            lineHeight: 1.3  // Better readability
                        }
                    }
                }

                // Auto-scroll to bottom when content changes
                onContentHeightChanged: {
                    if (terminalFeedback.autoScroll && contentHeight > height) {
                        scrollToBottomAnimation.to = contentHeight - height
                        scrollToBottomAnimation.start()
                    }
                }

                // Smooth scroll animation
                NumberAnimation {
                    id: scrollToBottomAnimation
                    target: flickable
                    property: "contentY"
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            // Vertical scroll indicator (touch-friendly, visible when scrolling)
            Rectangle {
                id: scrollIndicator
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 4
                radius: 2
                color: "#666666"
                opacity: flickable.moving ? 0.8 : (flickable.contentHeight > flickable.height ? 0.3 : 0)
                visible: flickable.contentHeight > flickable.height

                // Calculate position and size
                y: {
                    var ratio = flickable.contentY / (flickable.contentHeight - flickable.height)
                    var trackHeight = flickable.height - height
                    return Math.max(0, Math.min(trackHeight, ratio * trackHeight)) + 8
                }
                height: Math.max(30, (flickable.height / flickable.contentHeight) * (flickable.height - 16))

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
        }
    }

    // Public function to append a line with automatic color detection
    function appendLine(text) {
        var lineColor = textColor

        // Auto-detect color based on prefix
        if (text.indexOf("[ERROR]") === 0) {
            lineColor = errorColor
        } else if (text.indexOf("[DONE]") === 0 || text.indexOf("[SUCCESS]") === 0) {
            lineColor = successColor
        } else if (text.indexOf("[INFO]") === 0 || text.indexOf("[SCAN]") === 0 || text.indexOf("[CLEAR]") === 0) {
            lineColor = infoColor
        } else if (text.indexOf("[WARN]") === 0 || text.indexOf("[WARNING]") === 0) {
            lineColor = warningColor
        } else if (text.indexOf("[FOUND]") === 0) {
            lineColor = successColor
        } else if (text.indexOf("[PATH]") === 0) {
            lineColor = "#aaaaaa"  // Gray for paths
        }

        // Add timestamp
        var now = new Date()
        var timestamp = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss")
        var formattedText = "[" + timestamp + "] " + text

        // Create new array with the new line
        var newLines = lines.slice()
        newLines.push({ text: formattedText, color: lineColor })

        // Trim to max lines
        while (newLines.length > maxLines) {
            newLines.shift()
        }

        lines = newLines
    }

    // Public function to append a line with specific color
    function appendLineWithColor(text, color) {
        var now = new Date()
        var timestamp = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss")
        var formattedText = "[" + timestamp + "] " + text

        var newLines = lines.slice()
        newLines.push({ text: formattedText, color: color })

        while (newLines.length > maxLines) {
            newLines.shift()
        }

        lines = newLines
    }

    // Public function to clear all lines
    function clear() {
        lines = []
    }
}
