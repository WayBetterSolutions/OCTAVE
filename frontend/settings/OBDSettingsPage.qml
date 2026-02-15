import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // ── Card 1: Connection ──────────────────────────────────
        SettingsCard {

            SettingsSectionHeader { title: "Connection" }

            // OBD Connection Status
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Connection Status"
                }

                Rectangle {
                    id: connectionStatusRect
                    Layout.fillWidth: true
                    Layout.preferredHeight: App.Spacing.dp(40)

                    // Use more diverse status colors
                    property var statusColors: {
                        "Connected": App.Style.accent,
                        "Connecting": App.Style.statusWarning,
                        "Device Not Found": App.Style.statusError,
                        "Error": App.Style.statusError,
                        "Disconnected": App.Style.statusDisconnected,
                        "Device Lost": App.Style.statusWarning,
                        "No Vehicle": App.Style.statusInfo
                    }

                    // Default to error color if status not in our map
                    color: obdManager ?
                        (statusColors[obdManager.get_connection_status()] || App.Style.statusError) :
                        App.Style.statusError
                    radius: 4

                    // Properties for animations
                    property bool connecting: obdManager ?
                        (obdManager.get_connection_status() === "Connecting") : false
                    property real pulseOpacity: 0.7
                    property real connectionProgress: obdManager ?
                        (obdManager._connectionProgress || 0) : 0

                    // Progress indicator
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * (connectionStatusRect.connectionProgress / 100)
                        color: Qt.rgba(1, 1, 1, 0.2)
                        radius: parent.radius
                        visible: connectionStatusRect.connecting
                    }

                    // Pulse animation
                    SequentialAnimation {
                        id: pulseAnimation
                        running: connectionStatusRect.connecting
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: connectionStatusRect
                            property: "pulseOpacity"
                            from: 0.7
                            to: 1.0
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            target: connectionStatusRect
                            property: "pulseOpacity"
                            from: 1.0
                            to: 0.7
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // Click animation
                    SequentialAnimation {
                        id: clickAnimation

                        NumberAnimation {
                            target: connectionStatusRect
                            property: "scale"
                            from: 1.0
                            to: 0.95
                            duration: 100
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            target: connectionStatusRect
                            property: "scale"
                            from: 0.95
                            to: 1.0
                            duration: 100
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // Text and spinner layout
                    Column {
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(2)

                        // Main status row
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: App.Spacing.dp(10)

                            // Simple spinner using Rectangle animation
                            Rectangle {
                                id: spinner
                                width: App.Spacing.dp(20)
                                height: App.Spacing.dp(20)
                                radius: App.Spacing.dpMin(10, 2)
                                color: "transparent"
                                border.width: 2
                                border.color: "white"
                                visible: connectionStatusRect.connecting

                                // Spinner dot that rotates around
                                Rectangle {
                                    id: spinnerDot
                                    width: App.Spacing.dp(6)
                                    height: App.Spacing.dp(6)
                                    radius: 3
                                    color: "white"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: -3

                                    // Animation
                                    RotationAnimation {
                                        target: spinner
                                        property: "rotation"
                                        from: 0
                                        to: 360
                                        duration: 1200
                                        loops: Animation.Infinite
                                        running: connectionStatusRect.connecting
                                    }
                                }
                            }

                            // Status text
                            Text {
                                id: statusText
                                anchors.verticalCenter: parent.verticalCenter
                                text: obdManager ? obdManager.get_connection_status() : "Not Connected"
                                color: "white"
                                font.pixelSize: App.Spacing.overallText
                                font.family: App.Style.fontFamily
                                font.bold: true
                                opacity: connectionStatusRect.connecting ? connectionStatusRect.pulseOpacity : 1.0
                            }
                        }

                        // Detailed status text - only shown when available
                        Text {
                            id: detailText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: obdManager && obdManager._connectionDetail ?
                                obdManager._connectionDetail : ""
                            color: "white"
                            font.pixelSize: App.Spacing.overallText * 0.7
                            font.family: App.Style.fontFamily
                            visible: text !== ""
                            opacity: 0.9
                        }
                    }

                    // Click handling
                    MouseArea {
                        id: connectionClickArea
                        anchors.fill: parent
                        hoverEnabled: true

                        // Change cursor on hover
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (obdManager) {
                                // Pop up the connection menu
                                connectionMenu.popup()
                            }
                        }
                    }

                    // Connection menu with options
                    Menu {
                        id: connectionMenu

                        MenuItem {
                            text: "Reset Connection"
                            onTriggered: {
                                if (obdManager) {
                                    clickAnimation.start()
                                    obdManager.reset_connection()
                                }
                            }
                        }
                    }

                    // Connections to OBD manager
                    Connections {
                        target: obdManager

                        function onConnectionStatusChanged(status) {
                            connectionStatusRect.connecting = (status === "Connecting")
                        }

                        function onConnectionProgressChanged(progress) {
                            connectionStatusRect.connectionProgress = progress
                        }

                        function onDevicePresenceChanged(present) {
                            if (!present) {
                                deviceNotFoundNotification.open()
                            }
                        }
                    }
                }

                // Add notification popups
                Popup {
                    id: deviceNotFoundNotification
                    x: (parent.width - width) / 2
                    y: parent.height - height - App.Spacing.dp(20)
                    width: App.Spacing.dp(300)
                    height: App.Spacing.dp(60)
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    background: Rectangle {
                        color: App.Style.statusError
                        radius: 4
                    }

                    contentItem: Text {
                        text: "OBD device not found. Check connections."
                        color: "white"
                        wrapMode: Text.WordWrap
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                    }

                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                    }

                    Timer {
                        interval: 3000
                        running: deviceNotFoundNotification.visible
                        onTriggered: deviceNotFoundNotification.close()
                    }
                }

                SettingDescription {
                    text: "Tap status bar to reconnect"
                }
            }

            SettingsDivider {}

            // Bluetooth Device Path
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Bluetooth Device"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsTextField {
                        id: bluetoothPortField
                        Layout.fillWidth: true
                        text: settingsManager ? settingsManager.obdBluetoothPort : "/dev/rfcomm0"

                        onEditingFinished: {
                            if (settingsManager && text.trim() !== "") {
                                settingsManager.save_obd_bluetooth_port(text)
                            }
                        }
                    }

                    Text {
                        text: "e.g. /dev/rfcomm0"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText * 0.8
                        font.family: App.Style.fontFamily
                    }
                }

                SettingDescription {
                    text: "Serial port for your Bluetooth OBD adapter"
                }
            }

            SettingsDivider {}

            // Fast Mode Toggle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    text: "Fast mode"
                    Layout.fillWidth: true
                    checked: settingsManager ? settingsManager.obdFastMode : true

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_obd_fast_mode(checked)
                        }
                    }
                }

                SettingDescription {
                    text: "Faster polling, may not work with all vehicles"
                }
            }

            SettingsDivider {}

            // Auto-Reconnect Attempts
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Reconnect Retries"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsSlider {
                        id: autoReconnectSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 10
                        stepSize: 1
                        value: settingsManager ? settingsManager.obdAutoReconnectAttempts : 0

                        valueDisplay: value === 0 ? "Off" : value.toString()

                        onMoved: {
                            if (settingsManager) {
                                settingsManager.save_obd_auto_reconnect_attempts(Math.round(value))
                            }
                        }
                    }

                    Text {
                        text: autoReconnectSlider.value === 0 ? "Off" : autoReconnectSlider.value.toString()
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                        font.bold: true
                        Layout.preferredWidth: App.Spacing.dp(30)
                        horizontalAlignment: Text.AlignRight
                    }
                }

                SettingDescription {
                    text: "Retry attempts after disconnect (0 = off)"
                }
            }

            SettingsDivider {}

            // OBD Card Style
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: obdCardStyleToggle
                    Layout.fillWidth: true
                    text: "Circular gauges"
                    checked: settingsManager ? settingsManager.get_setting_with_default("obdCardStyleCircular", false) : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_setting("obdCardStyleCircular", checked)
                        }
                    }
                }

                SettingDescription {
                    text: "Square cards or circular gauges (OBD page only)"
                }
            }
        }

        // ── Card 2: Vehicle Scan ────────────────────────────────
        SettingsCard {

            SettingsSectionHeader { title: "Vehicle Scan" }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingDescription {
                    text: "Detect which parameters your vehicle supports"
                }

                // Scan button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Button {
                        id: vehicleScanButton
                        property bool isScanning: false
                        text: isScanning ? "Scanning..." : "Scan Vehicle"
                        enabled: obdManager && obdManager.is_connected() && !isScanning
                        implicitHeight: App.Spacing.overallSpacing * 2.5
                        implicitWidth: vehicleScanButtonText.implicitWidth + App.Spacing.overallSpacing * 2

                        scale: vehicleScanMouseArea.pressed ? 0.95 : 1.0
                        opacity: enabled ? (vehicleScanMouseArea.pressed ? 0.8 : 1.0) : 0.5

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutBack }
                        }

                        background: Rectangle {
                            color: vehicleScanButton.enabled ? App.Style.statusSuccess : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                            radius: 4
                        }

                        contentItem: Text {
                            id: vehicleScanButtonText
                            text: vehicleScanButton.text
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: App.Style.fontFamily
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: vehicleScanMouseArea
                            anchors.fill: parent
                            enabled: parent.enabled
                            onClicked: {
                                if (obdManager) {
                                    vehicleScanTerminal.clear()
                                    vehicleScanButton.isScanning = true
                                    obdManager.scan_vehicle()
                                }
                            }
                        }

                        // Listen for scan completion
                        Connections {
                            target: obdManager
                            function onScanCompleteChanged(supportedList) {
                                vehicleScanButton.isScanning = false
                            }
                        }
                    }

                    Text {
                        text: obdManager && obdManager.is_connected() ? "OBD Connected" : "Connect OBD first"
                        color: obdManager && obdManager.is_connected() ? App.Style.statusSuccess : App.Style.statusError
                        font.pixelSize: App.Spacing.smallText
                        font.family: App.Style.fontFamily
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Terminal output for scan progress
                App.TerminalFeedback {
                    id: vehicleScanTerminal
                    Layout.fillWidth: true
                    Layout.preferredHeight: App.Spacing.dp(300)
                    Layout.topMargin: App.Spacing.rowSpacing
                    title: "Vehicle Scan Output"
                    maxLines: 100

                    // Connect to obdManager scan output signal
                    Connections {
                        target: obdManager
                        function onScanOutputChanged(message) {
                            vehicleScanTerminal.appendLine(message)
                        }
                    }
                }
            }
        }

        // ── Card 3: Parameters ──────────────────────────────────
        SettingsCard {

            SettingsCollapsibleSection {
                title: "Parameters"
                expanded: false
                Layout.fillWidth: true

                ColumnLayout {
                    id: parameterSelectionLayout
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    // Full parameter list for all operations
                    property var allOBDParameters: [
                        // Original parameters
                        "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE", "ENGINE_LOAD",
                        "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                        "MAF", "SPEED", "RPM", "COMMANDED_EQUIV_RATIO",
                        "FUEL_LEVEL", "INTAKE_PRESSURE", "SHORT_FUEL_TRIM_1",
                        "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                        "OIL_TEMP", "IGNITION_TIMING",
                        // Additional parameters
                        "RUN_TIME", "DISTANCE_W_MIL", "FUEL_RAIL_PRESSURE_VAC",
                        "FUEL_RAIL_PRESSURE_DIRECT", "BAROMETRIC_PRESSURE", "AMBIANT_AIR_TEMP",
                        "RELATIVE_THROTTLE_POS", "THROTTLE_POS_B", "ACCELERATOR_POS_D",
                        "CATALYST_TEMP_B1S1", "CATALYST_TEMP_B1S2", "EVAP_VAPOR_PRESSURE",
                        "SHORT_FUEL_TRIM_2", "LONG_FUEL_TRIM_2", "O2_B1S2",
                        "O2_B2S1", "O2_B2S2", "DISTANCE_SINCE_DTC_CLEAR",
                        "WARMUPS_SINCE_DTC_CLEAR", "ABSOLUTE_LOAD", "COMMANDED_EGR",
                        "EGR_ERROR", "ETHANOL_PERCENT",
                        // Batch 2 - Additional O2 sensors
                        "O2_B1S3", "O2_B1S4", "O2_B2S3", "O2_B2S4",
                        // Wide-range O2 sensors voltage
                        "O2_S1_WR_VOLTAGE", "O2_S2_WR_VOLTAGE", "O2_S3_WR_VOLTAGE", "O2_S4_WR_VOLTAGE",
                        "O2_S5_WR_VOLTAGE", "O2_S6_WR_VOLTAGE", "O2_S7_WR_VOLTAGE", "O2_S8_WR_VOLTAGE",
                        // Wide-range O2 sensors current
                        "O2_S1_WR_CURRENT", "O2_S2_WR_CURRENT", "O2_S3_WR_CURRENT", "O2_S4_WR_CURRENT",
                        "O2_S5_WR_CURRENT", "O2_S6_WR_CURRENT", "O2_S7_WR_CURRENT", "O2_S8_WR_CURRENT",
                        // Bank 2 catalyst temps
                        "CATALYST_TEMP_B2S1", "CATALYST_TEMP_B2S2",
                        // Additional throttle/accelerator
                        "THROTTLE_POS_C", "ACCELERATOR_POS_E", "ACCELERATOR_POS_F", "THROTTLE_ACTUATOR",
                        // Fuel system
                        "EVAPORATIVE_PURGE", "FUEL_RAIL_PRESSURE_ABS", "FUEL_INJECT_TIMING", "FUEL_RATE",
                        // Time-based
                        "RUN_TIME_MIL", "TIME_SINCE_DTC_CLEARED",
                        // Other
                        "MAX_MAF", "FUEL_TYPE", "EVAP_VAPOR_PRESSURE_ABS", "EVAP_VAPOR_PRESSURE_ALT",
                        "SHORT_O2_TRIM_B1", "LONG_O2_TRIM_B1", "SHORT_O2_TRIM_B2", "LONG_O2_TRIM_B2",
                        "RELATIVE_ACCEL_POS", "HYBRID_BATTERY_REMAINING", "ELM_VOLTAGE"
                    ]

                    // Scan vehicle state
                    property bool isScanning: false
                    property string scanStatus: ""
                    property int scanProgress: 0
                    property var supportedCommands: []

                    // Controls row (Select All and Deselect All buttons)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: App.Spacing.dp(10)

                        // Select All button
                        Button {
                            id: selectAllButton
                            text: "Select All"
                            implicitHeight: App.Spacing.overallSpacing * 2
                            implicitWidth: selectAllButtonText.implicitWidth + App.Spacing.overallSpacing * 1.5

                            // Add click animation
                            scale: selectAllMouseArea.pressed ? 0.95 : 1.0
                            opacity: selectAllMouseArea.pressed ? 0.8 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutBack
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }

                            background: Rectangle {
                                color: App.Style.accent
                                radius: 4
                                clip: true
                            }

                            contentItem: Text {
                                id: selectAllButtonText
                                text: selectAllButton.text
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.overallText
                                font.family: App.Style.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: selectAllMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    if (settingsManager) {
                                        parameterChipsFlow.visibleCommandsList.forEach(function(param) {
                                            settingsManager.save_obd_parameter_enabled(param, true);
                                        });
                                    }
                                }
                            }
                        }

                        // Deselect All button
                        Button {
                            id: deselectAllButton
                            text: "Deselect All"
                            implicitHeight: App.Spacing.overallSpacing * 2
                            implicitWidth: deselectAllButtonText.implicitWidth + App.Spacing.overallSpacing * 1.5

                            // Add click animation
                            scale: deselectAllMouseArea.pressed ? 0.95 : 1.0
                            opacity: deselectAllMouseArea.pressed ? 0.8 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutBack
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }

                            background: Rectangle {
                                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                                radius: 4
                                clip: true
                            }

                            contentItem: Text {
                                id: deselectAllButtonText
                                text: deselectAllButton.text
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.overallText
                                font.family: App.Style.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: deselectAllMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    if (settingsManager) {
                                        parameterChipsFlow.visibleCommandsList.forEach(function(param) {
                                            settingsManager.save_obd_parameter_enabled(param, false);
                                        });
                                    }
                                }
                            }
                        }

                        // Spacer
                        Item { Layout.fillWidth: true }

                        // Parameter counter
                        Text {
                            id: enabledCount
                            text: "0 of 0 enabled"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: App.Style.fontFamily

                            // Count enabled parameters (scoped to visible set)
                            function updateEnabledCount() {
                                if (!settingsManager) return;

                                var visible = parameterChipsFlow.visibleCommandsList;
                                let count = 0;
                                visible.forEach(function(param) {
                                    var isOriginal = parameterChipsFlow.isOriginalParameter(param);
                                    if (settingsManager.get_obd_parameter_enabled(param, isOriginal)) {
                                        count++;
                                    }
                                });

                                enabledCount.text = count + " of " + visible.length + " enabled";
                            }

                            Component.onCompleted: {
                                updateEnabledCount();
                            }
                        }
                    }

                    // Scan progress indicator (shown during scan)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: parameterSelectionLayout.isScanning || parameterSelectionLayout.scanStatus !== ""
                        spacing: App.Spacing.dp(10)

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.2)
                            radius: 3

                            Rectangle {
                                width: parent.width * (parameterSelectionLayout.scanProgress / 100)
                                height: parent.height
                                color: App.Style.statusSuccess
                                radius: 3

                                Behavior on width {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }

                        Text {
                            text: parameterSelectionLayout.scanStatus
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.9
                            font.family: App.Style.fontFamily
                        }
                    }

                    // OBD scan connections
                    Connections {
                        target: obdManager

                        function onScanProgressChanged(progress, message) {
                            parameterSelectionLayout.scanProgress = progress;
                            parameterSelectionLayout.scanStatus = message;
                            parameterSelectionLayout.isScanning = progress < 100;
                        }

                        function onScanCompleteChanged(supportedParams) {
                            parameterSelectionLayout.supportedCommands = supportedParams;
                            parameterSelectionLayout.isScanning = false;

                            // Auto-enable all supported parameters
                            if (supportedParams.length > 0 && settingsManager) {
                                supportedParams.forEach(function(param) {
                                    settingsManager.save_obd_parameter_enabled(param, true);
                                });
                            }
                        }
                    }

                    // Debounce timer for counter updates
                    Timer {
                        id: updateCountTimer
                        interval: 10
                        running: false
                        repeat: false
                        onTriggered: {
                            enabledCount.updateEnabledCount();
                        }
                    }

                    // Track settings changes
                    Connections {
                        target: settingsManager
                        function onObdParametersChanged() {
                            updateCountTimer.restart();
                        }
                        function onSupportedOBDParametersChanged() {
                            parameterChipsFlow.supportedParamsVersion++;
                            updateCountTimer.restart();
                        }
                    }

                    // IMPROVED PARAMETER CHIPS AREA
                    Flow {
                        id: parameterChipsFlow
                        Layout.fillWidth: true
                        spacing: App.Spacing.dp(12)
                        Layout.preferredHeight: childrenRect.height

                        // Parameter chips model - all supported parameters
                        property var parametersModel: [
                            // Original parameters (enabled by default)
                            { name: "Vehicle Speed", command: "SPEED" },
                            { name: "Engine RPM", command: "RPM" },
                            { name: "Coolant Temperature", command: "COOLANT_TEMP" },
                            { name: "System Voltage", command: "CONTROL_MODULE_VOLTAGE" },
                            { name: "Engine Load", command: "ENGINE_LOAD" },
                            { name: "Throttle Position", command: "THROTTLE_POS" },
                            { name: "Intake Temperature", command: "INTAKE_TEMP" },
                            { name: "Timing Advance", command: "TIMING_ADVANCE" },
                            { name: "Mass Air Flow", command: "MAF" },
                            { name: "Air-Fuel Ratio", command: "COMMANDED_EQUIV_RATIO" },
                            { name: "Fuel Level", command: "FUEL_LEVEL" },
                            { name: "Intake Manifold Pressure", command: "INTAKE_PRESSURE" },
                            { name: "Short Term Fuel Trim 1", command: "SHORT_FUEL_TRIM_1" },
                            { name: "Long Term Fuel Trim 1", command: "LONG_FUEL_TRIM_1" },
                            { name: "O2 Bank 1 Sensor 1", command: "O2_B1S1" },
                            { name: "Fuel Pressure", command: "FUEL_PRESSURE" },
                            { name: "Oil Temperature", command: "OIL_TEMP" },
                            { name: "Ignition Timing", command: "IGNITION_TIMING" },
                            // Additional parameters (disabled by default, enable via scan)
                            { name: "Run Time", command: "RUN_TIME" },
                            { name: "Distance w/ MIL", command: "DISTANCE_W_MIL" },
                            { name: "Fuel Rail Pressure", command: "FUEL_RAIL_PRESSURE_VAC" },
                            { name: "Fuel Rail Direct", command: "FUEL_RAIL_PRESSURE_DIRECT" },
                            { name: "Barometric Pressure", command: "BAROMETRIC_PRESSURE" },
                            { name: "Ambient Air Temp", command: "AMBIANT_AIR_TEMP" },
                            { name: "Relative Throttle", command: "RELATIVE_THROTTLE_POS" },
                            { name: "Throttle Position B", command: "THROTTLE_POS_B" },
                            { name: "Accelerator Pedal", command: "ACCELERATOR_POS_D" },
                            { name: "Catalyst Temp B1S1", command: "CATALYST_TEMP_B1S1" },
                            { name: "Catalyst Temp B1S2", command: "CATALYST_TEMP_B1S2" },
                            { name: "EVAP Vapor Pressure", command: "EVAP_VAPOR_PRESSURE" },
                            { name: "Short Term Fuel Trim 2", command: "SHORT_FUEL_TRIM_2" },
                            { name: "Long Term Fuel Trim 2", command: "LONG_FUEL_TRIM_2" },
                            { name: "O2 Bank 1 Sensor 2", command: "O2_B1S2" },
                            { name: "O2 Bank 2 Sensor 1", command: "O2_B2S1" },
                            { name: "O2 Bank 2 Sensor 2", command: "O2_B2S2" },
                            { name: "Distance Since Clear", command: "DISTANCE_SINCE_DTC_CLEAR" },
                            { name: "Warmups Since Clear", command: "WARMUPS_SINCE_DTC_CLEAR" },
                            { name: "Absolute Load", command: "ABSOLUTE_LOAD" },
                            { name: "Commanded EGR", command: "COMMANDED_EGR" },
                            { name: "EGR Error", command: "EGR_ERROR" },
                            { name: "Ethanol Percent", command: "ETHANOL_PERCENT" },
                            // Batch 2 - Additional O2 sensors
                            { name: "O2 Bank 1 Sensor 3", command: "O2_B1S3" },
                            { name: "O2 Bank 1 Sensor 4", command: "O2_B1S4" },
                            { name: "O2 Bank 2 Sensor 3", command: "O2_B2S3" },
                            { name: "O2 Bank 2 Sensor 4", command: "O2_B2S4" },
                            // Wide-range O2 sensors voltage
                            { name: "O2 S1 WR Voltage", command: "O2_S1_WR_VOLTAGE" },
                            { name: "O2 S2 WR Voltage", command: "O2_S2_WR_VOLTAGE" },
                            { name: "O2 S3 WR Voltage", command: "O2_S3_WR_VOLTAGE" },
                            { name: "O2 S4 WR Voltage", command: "O2_S4_WR_VOLTAGE" },
                            { name: "O2 S5 WR Voltage", command: "O2_S5_WR_VOLTAGE" },
                            { name: "O2 S6 WR Voltage", command: "O2_S6_WR_VOLTAGE" },
                            { name: "O2 S7 WR Voltage", command: "O2_S7_WR_VOLTAGE" },
                            { name: "O2 S8 WR Voltage", command: "O2_S8_WR_VOLTAGE" },
                            // Wide-range O2 sensors current
                            { name: "O2 S1 WR Current", command: "O2_S1_WR_CURRENT" },
                            { name: "O2 S2 WR Current", command: "O2_S2_WR_CURRENT" },
                            { name: "O2 S3 WR Current", command: "O2_S3_WR_CURRENT" },
                            { name: "O2 S4 WR Current", command: "O2_S4_WR_CURRENT" },
                            { name: "O2 S5 WR Current", command: "O2_S5_WR_CURRENT" },
                            { name: "O2 S6 WR Current", command: "O2_S6_WR_CURRENT" },
                            { name: "O2 S7 WR Current", command: "O2_S7_WR_CURRENT" },
                            { name: "O2 S8 WR Current", command: "O2_S8_WR_CURRENT" },
                            // Bank 2 catalyst temps
                            { name: "Catalyst Temp B2S1", command: "CATALYST_TEMP_B2S1" },
                            { name: "Catalyst Temp B2S2", command: "CATALYST_TEMP_B2S2" },
                            // Additional throttle/accelerator
                            { name: "Throttle Position C", command: "THROTTLE_POS_C" },
                            { name: "Accelerator Pos E", command: "ACCELERATOR_POS_E" },
                            { name: "Accelerator Pos F", command: "ACCELERATOR_POS_F" },
                            { name: "Throttle Actuator", command: "THROTTLE_ACTUATOR" },
                            // Fuel system
                            { name: "EVAP Purge", command: "EVAPORATIVE_PURGE" },
                            { name: "Fuel Rail Abs", command: "FUEL_RAIL_PRESSURE_ABS" },
                            { name: "Fuel Inject Timing", command: "FUEL_INJECT_TIMING" },
                            { name: "Fuel Rate", command: "FUEL_RATE" },
                            // Time-based
                            { name: "Run Time w/ MIL", command: "RUN_TIME_MIL" },
                            { name: "Time Since Clear", command: "TIME_SINCE_DTC_CLEARED" },
                            // Other
                            { name: "Max MAF", command: "MAX_MAF" },
                            { name: "Fuel Type", command: "FUEL_TYPE" },
                            { name: "EVAP Pressure Abs", command: "EVAP_VAPOR_PRESSURE_ABS" },
                            { name: "EVAP Pressure Alt", command: "EVAP_VAPOR_PRESSURE_ALT" },
                            { name: "Short O2 Trim B1", command: "SHORT_O2_TRIM_B1" },
                            { name: "Long O2 Trim B1", command: "LONG_O2_TRIM_B1" },
                            { name: "Short O2 Trim B2", command: "SHORT_O2_TRIM_B2" },
                            { name: "Long O2 Trim B2", command: "LONG_O2_TRIM_B2" },
                            { name: "Rel. Accel Position", command: "RELATIVE_ACCEL_POS" },
                            { name: "Hybrid Battery", command: "HYBRID_BATTERY_REMAINING" },
                            { name: "ELM Voltage", command: "ELM_VOLTAGE" }
                        ]

                        // Original parameters that are enabled by default
                        property var originalParameters: [
                            "SPEED", "RPM", "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE",
                            "ENGINE_LOAD", "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                            "MAF", "COMMANDED_EQUIV_RATIO", "FUEL_LEVEL", "INTAKE_PRESSURE",
                            "SHORT_FUEL_TRIM_1", "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                            "OIL_TEMP", "IGNITION_TIMING"
                        ]

                        // Version counter to force re-evaluation when scan results change
                        property int supportedParamsVersion: 0

                        // Filtered model: core 18 before scan, vehicle-supported after scan
                        property var visibleParameters: {
                            var _v = supportedParamsVersion;
                            if (!settingsManager) return parametersModel;
                            var supported = settingsManager.get_supported_obd_parameters();
                            if (supported.length > 0) {
                                return parametersModel.filter(function(p) {
                                    return supported.indexOf(p.command) !== -1;
                                });
                            } else {
                                return parametersModel.filter(function(p) {
                                    return originalParameters.indexOf(p.command) !== -1;
                                });
                            }
                        }

                        // Flat list of visible command strings for Select All / Deselect All / counter
                        property var visibleCommandsList: {
                            return visibleParameters.map(function(p) { return p.command; });
                        }

                        // Helper function to get the default enabled state for a parameter
                        function isOriginalParameter(command) {
                            return originalParameters.indexOf(command) !== -1;
                        }

                        Repeater {
                            model: parameterChipsFlow.visibleParameters

                            delegate: Rectangle {
                                id: paramChip
                                width: Math.min(parameterChipsFlow.width * 0.3, App.Spacing.dp(400))
                                height: App.Spacing.settingsButtonHeight*.8
                                radius: App.Spacing.dpMin(12, 2)

                                // Check if this is an original parameter (enabled by default)
                                property bool isOriginal: parameterChipsFlow.isOriginalParameter(modelData.command)

                                // Bind the color directly to the parameter's enabled state
                                property bool isEnabled: settingsManager ?
                                    settingsManager.get_obd_parameter_enabled(modelData.command, isOriginal) : isOriginal

                                // Track if this parameter is on the home screen
                                property bool isOnHomeScreen: {
                                    if (!settingsManager) return false;
                                    let homeParams = settingsManager.get_home_obd_parameters();
                                    return homeParams.indexOf(modelData.command) !== -1;
                                }

                                // Use a darker background for disabled chips to improve contrast
                                color: isEnabled ?
                                    Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) :
                                    Qt.rgba(App.Style.backgroundColor.r, App.Style.backgroundColor.g, App.Style.backgroundColor.b, 0.5)

                                border.width: 1
                                border.color: isEnabled ?
                                    App.Style.accent :
                                    Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.3)

                                // Add click animation
                                scale: chipMouseArea.pressed ? 0.97 : 1.0
                                opacity: chipMouseArea.pressed ? 0.9 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 100 }
                                }

                                // Update enabled state when settings change
                                Connections {
                                    target: settingsManager
                                    function onObdParametersChanged() {
                                        if (settingsManager) {
                                            paramChip.isEnabled = settingsManager.get_obd_parameter_enabled(modelData.command, paramChip.isOriginal);
                                        }
                                    }

                                    function onHomeOBDParametersChanged() {
                                        if (settingsManager) {
                                            let homeParams = settingsManager.get_home_obd_parameters();
                                            paramChip.isOnHomeScreen = homeParams.indexOf(modelData.command) !== -1;
                                            homeButton.updateHomeStatus();
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        margins: App.Spacing.dp(12)
                                    }
                                    spacing: App.Spacing.dp(8)

                                    // Parameter name - always make the text visible regardless of enabled state
                                    Text {
                                        text: modelData.name
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: App.Style.fontFamily
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Add home button
                                    HomeScreenButton {
                                        id: homeButton
                                        isActive: paramChip.isOnHomeScreen

                                        function updateHomeStatus() {
                                            if (settingsManager) {
                                                let homeParams = settingsManager.get_home_obd_parameters();
                                                isActive = homeParams.indexOf(modelData.command) !== -1;
                                            }
                                        }

                                        Component.onCompleted: {
                                            updateHomeStatus();
                                        }

                                        onClicked: {
                                            if (settingsManager) {
                                                let homeParams = settingsManager.get_home_obd_parameters();

                                                if (isActive) {
                                                    // Remove from home screen
                                                    let index = homeParams.indexOf(modelData.command);
                                                    if (index !== -1) {
                                                        homeParams.splice(index, 1);
                                                        settingsManager.save_home_obd_parameters(homeParams);
                                                    }
                                                } else {
                                                    // Add to home screen if space available (max 8)
                                                    if (homeParams.length < 8) {
                                                        homeParams.push(modelData.command);
                                                        settingsManager.save_home_obd_parameters(homeParams);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Simple click area with animation
                                MouseArea {
                                    id: chipMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: App.Spacing.dp(64) // Leave space for home button
                                    onClicked: {
                                        if (settingsManager) {
                                            // Toggle the enabled state
                                            let newState = !paramChip.isEnabled;
                                            settingsManager.save_obd_parameter_enabled(modelData.command, newState);
                                            updateCountTimer.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hint text showing scan status
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: App.Spacing.dp(8)
                        text: {
                            var _v = parameterChipsFlow.supportedParamsVersion;
                            var supported = settingsManager ? settingsManager.get_supported_obd_parameters() : [];
                            if (supported.length === 0) {
                                return "Showing core parameters. Scan your vehicle to discover additional supported parameters.";
                            } else {
                                return "Showing " + supported.length + " vehicle-supported parameters from last scan.";
                            }
                        }
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.smallText
                        font.family: App.Style.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    // Initialize counter on load
                    Component.onCompleted: {
                        Qt.callLater(function() {
                            if (enabledCount) {
                                enabledCount.updateEnabledCount();
                            }
                        });
                    }
                }
            }
        }

        // Bottom spacer
        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }

        function updateHomeDisplay() {
            // Force refresh of home parameters display
            homeParametersRepeater.model = [];
            Qt.callLater(function() {
                if (settingsManager) {
                    homeParametersRepeater.model = settingsManager.get_home_obd_parameters();
                    homeParametersEmptyRepeater.model = Math.max(0, 8 - (settingsManager ? settingsManager.get_home_obd_parameters().length : 0));

                    // Also update all home buttons in the parameter list
                    for (let i = 0; i < parameterListView.count; i++) {
                        let item = parameterListView.itemAtIndex(i);
                        if (item && item.homeButton) {
                            item.homeButton.updateHomeStatus();
                        }
                    }
                }
            });
        }
    }
}
