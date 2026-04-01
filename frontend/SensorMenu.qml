import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: sensorMenu
    required property StackView stackView
    required property ApplicationWindow mainWindow
    width: parent.width
    height: parent.height

    property string globalFont: App.Style.fontFamily

    // Live IMU values
    property real currentPitch: 0
    property real currentRoll: 0
    property real currentHeading: 0
    property real currentAltitude: 0
    property real currentGForce: 0
    property real currentBaroTemp: 0
    property bool imuConnected: false

    function headingToCardinal(h) {
        var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var idx = Math.round(h / 45) % 8
        return dirs[idx]
    }

    Component.onCompleted: {
        imuConnected = berryIMU.connected
    }

    Connections {
        target: berryIMU
        function onPitchChanged(val) { currentPitch = val }
        function onRollChanged(val) { currentRoll = val }
        function onHeadingChanged(val) { currentHeading = val }
        function onAltitudeChanged(val) { currentAltitude = val }
        function onAccelMagnitudeChanged(val) { currentGForce = val }
        function onBaroTempChanged(val) { currentBaroTemp = val }
        function onConnectionStatusChanged(status) { imuConnected = (status === "Connected") }
    }

    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: App.Spacing.overallMargin
            spacing: App.Spacing.dp(16)

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.dp(12)

                // Connection status indicator
                Rectangle {
                    width: App.Spacing.dp(12)
                    height: App.Spacing.dp(12)
                    radius: width / 2
                    color: imuConnected ? App.Style.statusConnected : App.Style.statusDisconnected

                    SequentialAnimation on opacity {
                        running: imuConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: "Sensors"
                    color: App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.dp(28)
                    font.bold: true
                    font.family: sensorMenu.globalFont
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: imuConnected ? "LIVE" : "DISCONNECTED"
                    color: imuConnected ? App.Style.statusConnected : App.Style.secondaryTextColor
                    font.pixelSize: App.Spacing.dp(13)
                    font.bold: true
                    font.family: sensorMenu.globalFont
                    font.letterSpacing: App.Spacing.dp(2)
                }
            }

            // Sensor cards grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: parent.width > App.Spacing.dp(600) ? 3 : 2
                rowSpacing: App.Spacing.dp(12)
                columnSpacing: App.Spacing.dp(12)

                // Pitch card
                SensorCard {
                    label: "PITCH"
                    value: currentPitch.toFixed(1)
                    unit: "\u00B0"
                    icon: "\u2195"
                    barValue: (currentPitch + 90) / 180
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }

                // Roll card
                SensorCard {
                    label: "ROLL"
                    value: currentRoll.toFixed(1)
                    unit: "\u00B0"
                    icon: "\u21C4"
                    barValue: (currentRoll + 90) / 180
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }

                // Heading card
                SensorCard {
                    label: "HEADING"
                    value: currentHeading.toFixed(1)
                    unit: "\u00B0 " + headingToCardinal(currentHeading)
                    icon: "\u2316"
                    barValue: currentHeading / 360
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }

                // G-Force card
                SensorCard {
                    label: "G-FORCE"
                    value: currentGForce.toFixed(2)
                    unit: "g"
                    icon: "\u2B07"
                    barValue: Math.min(currentGForce / 3.0, 1.0)
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }

                // Altitude card
                SensorCard {
                    label: "ALTITUDE"
                    value: currentAltitude.toFixed(1)
                    unit: "m"
                    icon: "\u25B2"
                    barValue: -1
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }

                // Temperature card
                SensorCard {
                    label: "TEMPERATURE"
                    value: currentBaroTemp.toFixed(1)
                    unit: "\u00B0C"
                    icon: "\u2600"
                    barValue: -1
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                }
            }

            // Bottom controls
            RowLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.dp(12)

                // Tare button
                Rectangle {
                    width: App.Spacing.dp(100)
                    height: App.Spacing.dp(36)
                    radius: App.Spacing.dp(6)
                    color: tareArea.pressed ? Qt.darker(App.Style.accent, 1.3) : App.Style.accent
                    visible: imuConnected

                    Text {
                        anchors.centerIn: parent
                        text: "ZERO"
                        color: "white"
                        font.pixelSize: App.Spacing.dp(13)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }

                    MouseArea {
                        id: tareArea
                        anchors.fill: parent
                        onClicked: berryIMU.calibrateTare()
                    }
                }

                // Reset tare button
                Rectangle {
                    width: App.Spacing.dp(100)
                    height: App.Spacing.dp(36)
                    radius: App.Spacing.dp(6)
                    color: resetArea.pressed ? Qt.darker(App.Style.secondaryTextColor, 1.3) : App.Style.headerBackgroundColor
                    border.color: App.Style.secondaryTextColor
                    border.width: 1
                    visible: imuConnected

                    Text {
                        anchors.centerIn: parent
                        text: "RESET"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.dp(13)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }

                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        onClicked: berryIMU.resetTare()
                    }
                }

                Item { Layout.fillWidth: true }

                // 3D View button — navigate to CarMenu
                Rectangle {
                    width: App.Spacing.dp(100)
                    height: App.Spacing.dp(36)
                    radius: App.Spacing.dp(6)
                    color: carMenuArea.pressed ? Qt.darker(App.Style.headerBackgroundColor, 1.3) : App.Style.headerBackgroundColor
                    border.color: App.Style.secondaryTextColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "3D View"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.dp(13)
                        font.family: sensorMenu.globalFont
                    }

                    MouseArea {
                        id: carMenuArea
                        anchors.fill: parent
                        onClicked: {
                            var page = Qt.createComponent("CarMenu.qml").createObject(stackView, {
                                stackView: sensorMenu.stackView,
                                mainWindow: sensorMenu.mainWindow
                            })
                            stackView.push(page)
                        }
                    }
                }
            }
        }
    }
}
