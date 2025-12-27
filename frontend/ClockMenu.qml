import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: clockMenu
    required property StackView stackView
    required property ApplicationWindow mainWindow
    width: parent.width
    height: parent.height

    Rectangle {
        anchors.fill: parent
        color: "#2c3e50"  // Dark blue-gray background

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 30

            // Digital Clock
            Text {
                id: digitalClock
                Layout.alignment: Qt.AlignCenter
                color: "white"
                font {
                    pixelSize: 72
                    family: "Arial"
                    bold: true
                }
            }

            // Date display
            Text {
                id: dateDisplay
                Layout.alignment: Qt.AlignCenter
                color: "#ecf0f1"
                font {
                    pixelSize: 24
                    family: "Arial"
                }
            }

            // Analog clock face
            Rectangle {
                id: clockFace
                Layout.alignment: Qt.AlignCenter
                width: 200
                height: 200
                radius: width/2
                color: "transparent"
                border.color: "white"
                border.width: 3

                // Hour hand
                Rectangle {
                    id: hourHand
                    width: 4
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
                    width: 2
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
                    width: 8
                    height: 8
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