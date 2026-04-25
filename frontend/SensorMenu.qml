import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings" as Settings

Item {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: sensorMenu
    objectName: "sensorMenu"
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
    property real currentLateralG: 0
    property real currentLongitudinalG: 0
    property real currentBaroTemp: 0
    property bool imuConnected: false

    // Display settings
    property int decimalPlaces: 1
    property bool useFahrenheit: true
    property bool useImperial: false
    property int emitRate: 60
    property bool showPitch: true
    property bool showRoll: true
    property bool showHeading: true
    property bool showGForce: true
    property bool showAltitude: true
    property bool showTemperature: true

    function headingToCardinal(h) {
        var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var idx = Math.round(h / 45) % 8
        return dirs[idx]
    }

    function tempDisplay(celsius) {
        if (useFahrenheit)
            return (celsius * 9 / 5 + 32).toFixed(decimalPlaces)
        return celsius.toFixed(decimalPlaces)
    }

    function altDisplay(meters) {
        if (useImperial)
            return (meters * 3.28084).toFixed(decimalPlaces)
        return meters.toFixed(decimalPlaces)
    }

    Component.onCompleted: {
        imuConnected = berryIMU.connected
        decimalPlaces = settingsManager.get_setting_with_default("sensorDecimalPlaces", 1)
        useFahrenheit = settingsManager.get_setting_with_default("sensorTempUnit", "F") === "F"
        useImperial = settingsManager.get_setting_with_default("sensorAltitudeUnit", "m") === "ft"
        emitRate = settingsManager.get_setting_with_default("sensorEmitRate", 60)
        showPitch = settingsManager.get_setting_with_default("sensorShowPitch", true)
        showRoll = settingsManager.get_setting_with_default("sensorShowRoll", true)
        showHeading = settingsManager.get_setting_with_default("sensorShowHeading", true)
        showGForce = settingsManager.get_setting_with_default("sensorShowGForce", true)
        showAltitude = settingsManager.get_setting_with_default("sensorShowAltitude", true)
        showTemperature = settingsManager.get_setting_with_default("sensorShowTemperature", true)
        berryIMU.setEmitRate(emitRate)
    }

    Connections {
        target: berryIMU
        function onPitchChanged(val) { currentPitch = val }
        function onRollChanged(val) { currentRoll = val }
        function onHeadingChanged(val) { currentHeading = val }
        function onAltitudeChanged(val) { currentAltitude = val }
        function onAccelMagnitudeChanged(val) { currentGForce = val }
        function onLateralGChanged(val) { currentLateralG = val }
        function onLongitudinalGChanged(val) { currentLongitudinalG = val }
        function onBaroTempChanged(val) { currentBaroTemp = val }
        function onConnectionStatusChanged(status) { imuConnected = (status === "Connected") }
    }

    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: App.Spacing.overallMargin
            spacing: dp(16)

            // Header — heading, temperature, and gear
            RowLayout {
                Layout.fillWidth: true
                spacing: dp(16)

                // Heading readout
                RowLayout {
                    spacing: dp(4)
                    visible: showHeading

                    Text {
                        text: "\u25c9"
                        color: App.Style.accent
                        font.pixelSize: dp(16)
                    }
                    Text {
                        text: imuConnected
                              ? currentHeading.toFixed(decimalPlaces) + "\u00B0 " + headingToCardinal(currentHeading)
                              : "--"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(16)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }
                }

                // Temperature readout
                RowLayout {
                    spacing: dp(4)
                    visible: showTemperature && (berryIMU.hasTemperature !== false)

                    Text {
                        text: "\u2600"
                        color: App.Style.accent
                        font.pixelSize: dp(16)
                    }
                    Text {
                        text: imuConnected
                              ? tempDisplay(currentBaroTemp) + (useFahrenheit ? "\u00B0F" : "\u00B0C")
                              : "--"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(16)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }
                }

                Item { Layout.fillWidth: true }

                // Settings gear button
                Rectangle {
                    width: dp(34)
                    height: dp(34)
                    radius: dp(6)
                    color: gearArea.containsMouse ? App.Style.hoverColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\u22ef"
                        font.pixelSize: dp(24)
                        color: App.Style.secondaryTextColor
                    }

                    MouseArea {
                        id: gearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: sensorSettingsPopup.open()
                    }
                }
            }

            // Sensor cards — 2x2 grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: dp(12)
                columnSpacing: dp(12)

                SensorCard {
                    label: "PITCH"
                    value: currentPitch.toFixed(decimalPlaces)
                    unit: "\u00B0"
                    icon: "\u2195"
                    barValue: (currentPitch + 90) / 180
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                    visible: showPitch
                }

                SensorCard {
                    label: "ROLL"
                    value: currentRoll.toFixed(decimalPlaces)
                    unit: "\u00B0"
                    icon: "\u21C4"
                    barValue: (currentRoll + 90) / 180
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                    visible: showRoll
                }

                GForceDisplay {
                    lateralG: currentLateralG
                    longitudinalG: currentLongitudinalG
                    magnitude: currentGForce
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                    decimalPlaces: sensorMenu.decimalPlaces
                    visible: showGForce
                }

                SensorCard {
                    label: "ALTITUDE"
                    value: altDisplay(currentAltitude)
                    unit: useImperial ? "ft" : "m"
                    icon: "\u25B2"
                    barValue: -1
                    globalFont: sensorMenu.globalFont
                    connected: imuConnected
                    visible: showAltitude
                }
            }

            // Bottom controls
            RowLayout {
                Layout.fillWidth: true
                spacing: dp(12)

                // Tare button
                Rectangle {
                    width: dp(100)
                    height: dp(36)
                    radius: dp(6)
                    color: tareArea.pressed ? Qt.darker(App.Style.accent, 1.3) : App.Style.accent
                    visible: imuConnected

                    Text {
                        anchors.centerIn: parent
                        text: "ZERO"
                        color: "white"
                        font.pixelSize: dp(13)
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
                    width: dp(100)
                    height: dp(36)
                    radius: dp(6)
                    color: resetArea.pressed ? Qt.darker(App.Style.secondaryTextColor, 1.3) : App.Style.headerBackgroundColor
                    border.color: App.Style.secondaryTextColor
                    border.width: 1
                    visible: imuConnected

                    Text {
                        anchors.centerIn: parent
                        text: "RESET"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(13)
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

                // 3D View button
                Rectangle {
                    width: dp(100)
                    height: dp(36)
                    radius: dp(6)
                    color: carMenuArea.pressed ? Qt.darker(App.Style.headerBackgroundColor, 1.3) : App.Style.headerBackgroundColor
                    border.color: App.Style.secondaryTextColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "3D View"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(13)
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

    // ==================== Settings Popup ====================

    Popup {
        id: sensorSettingsPopup
        anchors.centerIn: Overlay.overlay
        modal: true
        width: dp(380)
        height: Math.min(popupFlickable.contentHeight + dp(32), sensorMenu.height * 0.85)
        padding: dp(16)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: App.Style.backgroundColor
            border.color: App.Style.accent
            border.width: 1
            radius: dp(12)
        }

        contentItem: Flickable {
            id: popupFlickable
            clip: true
            contentHeight: popupContent.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

            ColumnLayout {
                id: popupContent
                width: popupFlickable.width - dp(12)
                spacing: dp(10)

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: dp(8)

                    Text {
                        text: "Sensor Settings"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(20)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: dp(28)
                        height: dp(28)
                        radius: dp(6)
                        color: closeArea.containsMouse ? App.Style.hoverColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            font.pixelSize: dp(14)
                            color: App.Style.secondaryTextColor
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: sensorSettingsPopup.close()
                        }
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(App.Style.secondaryTextColor.r, App.Style.secondaryTextColor.g,
                                   App.Style.secondaryTextColor.b, 0.2)
                }

                // ── DISPLAY section ──
                Text {
                    text: "DISPLAY"
                    color: App.Style.secondaryTextColor
                    font.pixelSize: dp(11)
                    font.bold: true
                    font.family: sensorMenu.globalFont
                    font.letterSpacing: dp(1.5)
                }

                // Decimal Places
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Decimal Places"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(14)
                        font.family: sensorMenu.globalFont
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: decimalPlaces
                        color: App.Style.accent
                        font.pixelSize: dp(14)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }
                }

                Settings.SettingsSlider {
                    from: 0; to: 4; stepSize: 1
                    value: decimalPlaces
                    onMoved: {
                        decimalPlaces = value
                        settingsManager.save_setting("sensorDecimalPlaces", value)
                    }
                }

                // Temperature unit
                Settings.SettingsToggle {
                    text: "Temperature in \u00B0F"
                    checked: useFahrenheit
                    compact: true
                    onToggled: function(checked) {
                        useFahrenheit = checked
                        settingsManager.save_setting("sensorTempUnit", checked ? "F" : "C")
                    }
                }

                // Altitude unit
                Settings.SettingsToggle {
                    text: "Altitude in Feet"
                    checked: useImperial
                    compact: true
                    onToggled: function(checked) {
                        useImperial = checked
                        settingsManager.save_setting("sensorAltitudeUnit", checked ? "ft" : "m")
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(App.Style.secondaryTextColor.r, App.Style.secondaryTextColor.g,
                                   App.Style.secondaryTextColor.b, 0.2)
                }

                // ── PERFORMANCE section ──
                Text {
                    text: "PERFORMANCE"
                    color: App.Style.secondaryTextColor
                    font.pixelSize: dp(11)
                    font.bold: true
                    font.family: sensorMenu.globalFont
                    font.letterSpacing: dp(1.5)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Update Rate"
                        color: App.Style.primaryTextColor
                        font.pixelSize: dp(14)
                        font.family: sensorMenu.globalFont
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: emitRate + " Hz"
                        color: App.Style.accent
                        font.pixelSize: dp(14)
                        font.bold: true
                        font.family: sensorMenu.globalFont
                    }
                }

                Settings.SettingsSlider {
                    from: 10; to: 120; stepSize: 5
                    value: emitRate
                    onMoved: {
                        emitRate = value
                        emitRateTimer.restart()
                    }
                }

                Timer {
                    id: emitRateTimer
                    interval: 200
                    onTriggered: {
                        settingsManager.save_setting("sensorEmitRate", emitRate)
                        berryIMU.setEmitRate(emitRate)
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(App.Style.secondaryTextColor.r, App.Style.secondaryTextColor.g,
                                   App.Style.secondaryTextColor.b, 0.2)
                }

                // ── VISIBLE CARDS section ──
                Text {
                    text: "VISIBLE CARDS"
                    color: App.Style.secondaryTextColor
                    font.pixelSize: dp(11)
                    font.bold: true
                    font.family: sensorMenu.globalFont
                    font.letterSpacing: dp(1.5)
                }

                Settings.SettingsToggle {
                    text: "Pitch"
                    checked: showPitch
                    compact: true
                    onToggled: function(checked) {
                        showPitch = checked
                        settingsManager.save_setting("sensorShowPitch", checked)
                    }
                }

                Settings.SettingsToggle {
                    text: "Roll"
                    checked: showRoll
                    compact: true
                    onToggled: function(checked) {
                        showRoll = checked
                        settingsManager.save_setting("sensorShowRoll", checked)
                    }
                }

                Settings.SettingsToggle {
                    text: "Heading"
                    checked: showHeading
                    compact: true
                    onToggled: function(checked) {
                        showHeading = checked
                        settingsManager.save_setting("sensorShowHeading", checked)
                    }
                }

                Settings.SettingsToggle {
                    text: "G-Force"
                    checked: showGForce
                    compact: true
                    onToggled: function(checked) {
                        showGForce = checked
                        settingsManager.save_setting("sensorShowGForce", checked)
                    }
                }

                Settings.SettingsToggle {
                    text: "Altitude"
                    checked: showAltitude
                    compact: true
                    onToggled: function(checked) {
                        showAltitude = checked
                        settingsManager.save_setting("sensorShowAltitude", checked)
                    }
                }

                Settings.SettingsToggle {
                    text: "Temperature"
                    checked: showTemperature
                    compact: true
                    onToggled: function(checked) {
                        showTemperature = checked
                        settingsManager.save_setting("sensorShowTemperature", checked)
                    }
                }

                // Bottom spacer
                Item { height: dp(4) }
            }
        }
    }
}
