import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: clockMenu
    required property StackView stackView
    required property ApplicationWindow mainWindow
    width: parent.width
    height: parent.height

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    Rectangle {
        anchors.fill: parent
        color: "#2c3e50"  // Dark blue-gray background

        ColumnLayout {
            anchors.centerIn: parent
            spacing: App.Spacing.dp(30)

            // Digital Clock
            Text {
                id: digitalClock
                Layout.alignment: Qt.AlignCenter
                color: "white"
                font {
                    pixelSize: App.Spacing.dp(72)
                    family: clockMenu.globalFont
                    bold: true
                }
            }

            // Date display
            Text {
                id: dateDisplay
                Layout.alignment: Qt.AlignCenter
                color: "#ecf0f1"
                font {
                    pixelSize: App.Spacing.dp(24)
                    family: clockMenu.globalFont
                }
            }

            // Analog clock face
            Rectangle {
                id: clockFace
                Layout.alignment: Qt.AlignCenter
                width: App.Spacing.dp(200)
                height: App.Spacing.dp(200)
                radius: width/2
                color: "transparent"
                border.color: "white"
                border.width: App.Spacing.dp(3)

                // Hour hand
                Rectangle {
                    id: hourHand
                    width: App.Spacing.dp(4)
                    height: parent.height * 0.3
                    color: "white"
                    antialiasing: true
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.verticalCenter
                    }
                    transformOrigin: Item.Bottom
                }

                // Minute hand
                Rectangle {
                    id: minuteHand
                    width: App.Spacing.dp(2)
                    height: parent.height * 0.4
                    color: "white"
                    antialiasing: true
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.verticalCenter
                    }
                    transformOrigin: Item.Bottom
                }

                // Second hand
                Rectangle {
                    id: secondHand
                    width: 1
                    height: parent.height * 0.45
                    color: "#e74c3c"  // Red color
                    antialiasing: true
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.verticalCenter
                    }
                    transformOrigin: Item.Bottom
                }

                // Center dot
                Rectangle {
                    width: App.Spacing.dp(8)
                    height: App.Spacing.dp(8)
                    radius: 4
                    color: "#e74c3c"
                    anchors.centerIn: parent
                }
            }
        }
    }

    Connections {
        target: clock
        function onTimeChanged(time) {
            // Update digital clock
            digitalClock.text = time

            // Update date
            var date = new Date()
            dateDisplay.text = Qt.formatDate(date, "dddd, MMMM d, yyyy")

            // Update analog clock hands
            var hours = parseInt(time.split(":")[0])
            var minutes = parseInt(time.split(":")[1])
            var seconds = parseInt(time.split(":")[2])

            // Calculate rotations
            hourHand.rotation = (hours % 12) * 30 + (minutes / 60) * 30
            minuteHand.rotation = minutes * 6 + (seconds / 60) * 6
            secondHand.rotation = seconds * 6
        }
    }
}