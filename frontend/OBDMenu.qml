import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: obdPage
    objectName: "obdMenu"
    required property StackView stackView
    required property ApplicationWindow mainWindow

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Define background and accent colors based on screenshot
    property color backgroundColor: App.Style.obdBoxBackground
    property color accentColor: App.Style.obdBarColor
    property color textColor: App.Style.obdValueColor      // For values - calculated for OBD box background
    property color labelColor: App.Style.obdLabelColor     // For parameter labels - calculated for OBD box background
    
    // Card style setting - true for circular gauges, false for square cards
    property bool useCircularCards: settingsManager ? settingsManager.get_setting_with_default("obdCardStyleCircular", false) : false

    // OBD parameters definition - comprehensive list of all supported parameters
    property var allParameters: [
        // Original parameters
        { id: "SPEED", title: "Speed", unit: "MPH", min: 0, max: 160 },
        { id: "RPM", title: "Engine RPM", unit: "RPM", min: 0, max: 8000 },
        { id: "COOLANT_TEMP", title: "Coolant Temp", unit: "°C", min: 0, max: 120 },
        { id: "OIL_TEMP", title: "Oil Temp", unit: "°C", min: 0, max: 150 },
        { id: "COMMANDED_EQUIV_RATIO", title: "Air-Fuel Ratio", unit: ":1", min: 10, max: 18 },
        { id: "ENGINE_LOAD", title: "Engine Load", unit: "%", min: 0, max: 100 },
        { id: "THROTTLE_POS", title: "Throttle", unit: "%", min: 0, max: 100 },
        { id: "FUEL_LEVEL", title: "Fuel Level", unit: "%", min: 0, max: 100 },
        { id: "SHORT_FUEL_TRIM_1", title: "Short Fuel Trim 1", unit: "%", min: -25, max: 25 },
        { id: "LONG_FUEL_TRIM_1", title: "Long Fuel Trim 1", unit: "%", min: -25, max: 25 },
        { id: "INTAKE_TEMP", title: "Intake Temp", unit: "°C", min: 0, max: 80 },
        { id: "INTAKE_PRESSURE", title: "Intake Pressure", unit: "kPa", min: 0, max: 255 },
        { id: "MAF", title: "Mass Air Flow", unit: "g/s", min: 0, max: 100 },
        { id: "TIMING_ADVANCE", title: "Timing Advance", unit: "°", min: -35, max: 35 },
        { id: "CONTROL_MODULE_VOLTAGE", title: "System Voltage", unit: "V", min: 10, max: 15 },
        { id: "O2_B1S1", title: "O2 Bank 1 Sensor 1", unit: "V", min: 0, max: 1.0 },
        { id: "FUEL_PRESSURE", title: "Fuel Pressure", unit: "kPa", min: 0, max: 765 },
        { id: "IGNITION_TIMING", title: "Ignition Timing", unit: "°", min: -10, max: 60 },
        // Additional parameters
        { id: "RUN_TIME", title: "Run Time", unit: "sec", min: 0, max: 65535 },
        { id: "DISTANCE_W_MIL", title: "Distance w/ MIL", unit: "km", min: 0, max: 65535 },
        { id: "FUEL_RAIL_PRESSURE_VAC", title: "Fuel Rail Pressure", unit: "kPa", min: 0, max: 5177 },
        { id: "FUEL_RAIL_PRESSURE_DIRECT", title: "Fuel Rail Direct", unit: "kPa", min: 0, max: 655350 },
        { id: "BAROMETRIC_PRESSURE", title: "Barometric", unit: "kPa", min: 0, max: 255 },
        { id: "AMBIANT_AIR_TEMP", title: "Ambient Air", unit: "°C", min: -40, max: 215 },
        { id: "RELATIVE_THROTTLE_POS", title: "Rel. Throttle", unit: "%", min: 0, max: 100 },
        { id: "THROTTLE_POS_B", title: "Throttle Pos B", unit: "%", min: 0, max: 100 },
        { id: "ACCELERATOR_POS_D", title: "Accel. Pedal", unit: "%", min: 0, max: 100 },
        { id: "CATALYST_TEMP_B1S1", title: "Cat Temp B1S1", unit: "°C", min: 0, max: 6513 },
        { id: "CATALYST_TEMP_B1S2", title: "Cat Temp B1S2", unit: "°C", min: 0, max: 6513 },
        { id: "EVAP_VAPOR_PRESSURE", title: "EVAP Pressure", unit: "Pa", min: -8192, max: 8191 },
        { id: "SHORT_FUEL_TRIM_2", title: "Short Fuel Trim 2", unit: "%", min: -25, max: 25 },
        { id: "LONG_FUEL_TRIM_2", title: "Long Fuel Trim 2", unit: "%", min: -25, max: 25 },
        { id: "O2_B1S2", title: "O2 Bank 1 Sensor 2", unit: "V", min: 0, max: 1.0 },
        { id: "O2_B2S1", title: "O2 Bank 2 Sensor 1", unit: "V", min: 0, max: 1.0 },
        { id: "O2_B2S2", title: "O2 Bank 2 Sensor 2", unit: "V", min: 0, max: 1.0 },
        { id: "DISTANCE_SINCE_DTC_CLEAR", title: "Dist Since Clear", unit: "km", min: 0, max: 65535 },
        { id: "WARMUPS_SINCE_DTC_CLEAR", title: "Warmups Since Clear", unit: "", min: 0, max: 255 },
        { id: "ABSOLUTE_LOAD", title: "Absolute Load", unit: "%", min: 0, max: 25700 },
        { id: "COMMANDED_EGR", title: "Commanded EGR", unit: "%", min: 0, max: 100 },
        { id: "EGR_ERROR", title: "EGR Error", unit: "%", min: -100, max: 100 },
        { id: "ETHANOL_PERCENT", title: "Ethanol %", unit: "%", min: 0, max: 100 },
        // Batch 2 - Additional O2 sensors
        { id: "O2_B1S3", title: "O2 Bank 1 Sensor 3", unit: "V", min: 0, max: 1.0 },
        { id: "O2_B1S4", title: "O2 Bank 1 Sensor 4", unit: "V", min: 0, max: 1.0 },
        { id: "O2_B2S3", title: "O2 Bank 2 Sensor 3", unit: "V", min: 0, max: 1.0 },
        { id: "O2_B2S4", title: "O2 Bank 2 Sensor 4", unit: "V", min: 0, max: 1.0 },
        // Wide-range O2 sensors voltage
        { id: "O2_S1_WR_VOLTAGE", title: "O2 S1 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S2_WR_VOLTAGE", title: "O2 S2 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S3_WR_VOLTAGE", title: "O2 S3 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S4_WR_VOLTAGE", title: "O2 S4 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S5_WR_VOLTAGE", title: "O2 S5 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S6_WR_VOLTAGE", title: "O2 S6 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S7_WR_VOLTAGE", title: "O2 S7 WR Voltage", unit: "V", min: 0, max: 5.0 },
        { id: "O2_S8_WR_VOLTAGE", title: "O2 S8 WR Voltage", unit: "V", min: 0, max: 5.0 },
        // Wide-range O2 sensors current
        { id: "O2_S1_WR_CURRENT", title: "O2 S1 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S2_WR_CURRENT", title: "O2 S2 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S3_WR_CURRENT", title: "O2 S3 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S4_WR_CURRENT", title: "O2 S4 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S5_WR_CURRENT", title: "O2 S5 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S6_WR_CURRENT", title: "O2 S6 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S7_WR_CURRENT", title: "O2 S7 WR Current", unit: "mA", min: -128, max: 128 },
        { id: "O2_S8_WR_CURRENT", title: "O2 S8 WR Current", unit: "mA", min: -128, max: 128 },
        // Bank 2 catalyst temps
        { id: "CATALYST_TEMP_B2S1", title: "Cat Temp B2S1", unit: "°C", min: 0, max: 6513 },
        { id: "CATALYST_TEMP_B2S2", title: "Cat Temp B2S2", unit: "°C", min: 0, max: 6513 },
        // Additional throttle/accelerator
        { id: "THROTTLE_POS_C", title: "Throttle Pos C", unit: "%", min: 0, max: 100 },
        { id: "ACCELERATOR_POS_E", title: "Accel. Pos E", unit: "%", min: 0, max: 100 },
        { id: "ACCELERATOR_POS_F", title: "Accel. Pos F", unit: "%", min: 0, max: 100 },
        { id: "THROTTLE_ACTUATOR", title: "Throttle Actuator", unit: "%", min: 0, max: 100 },
        // Fuel system
        { id: "EVAPORATIVE_PURGE", title: "EVAP Purge", unit: "%", min: 0, max: 100 },
        { id: "FUEL_RAIL_PRESSURE_ABS", title: "Fuel Rail Abs", unit: "kPa", min: 0, max: 655350 },
        { id: "FUEL_INJECT_TIMING", title: "Fuel Inject Timing", unit: "°", min: -210, max: 302 },
        { id: "FUEL_RATE", title: "Fuel Rate", unit: "L/h", min: 0, max: 3212 },
        // Time-based
        { id: "RUN_TIME_MIL", title: "Run Time w/ MIL", unit: "min", min: 0, max: 65535 },
        { id: "TIME_SINCE_DTC_CLEARED", title: "Time Since Clear", unit: "min", min: 0, max: 65535 },
        // Other
        { id: "MAX_MAF", title: "Max MAF", unit: "g/s", min: 0, max: 2550 },
        { id: "FUEL_TYPE", title: "Fuel Type", unit: "", min: 0, max: 23 },
        { id: "EVAP_VAPOR_PRESSURE_ABS", title: "EVAP Pressure Abs", unit: "kPa", min: 0, max: 327 },
        { id: "EVAP_VAPOR_PRESSURE_ALT", title: "EVAP Pressure Alt", unit: "Pa", min: -32768, max: 32767 },
        { id: "SHORT_O2_TRIM_B1", title: "Short O2 Trim B1", unit: "%", min: -100, max: 100 },
        { id: "LONG_O2_TRIM_B1", title: "Long O2 Trim B1", unit: "%", min: -100, max: 100 },
        { id: "SHORT_O2_TRIM_B2", title: "Short O2 Trim B2", unit: "%", min: -100, max: 100 },
        { id: "LONG_O2_TRIM_B2", title: "Long O2 Trim B2", unit: "%", min: -100, max: 100 },
        { id: "RELATIVE_ACCEL_POS", title: "Rel. Accel Pos", unit: "%", min: 0, max: 100 },
        { id: "HYBRID_BATTERY_REMAINING", title: "Hybrid Battery", unit: "%", min: 0, max: 100 },
        { id: "ELM_VOLTAGE", title: "ELM Voltage", unit: "V", min: 0, max: 65 }
    ]
    
    // OBD values storage - use a regular object that we'll replace to trigger updates
    property var paramValues: ({})

    // Helper function to update a parameter value and trigger bindings
    function updateParamValue(paramId, value) {
        // Create a new object to trigger property change notification
        var newValues = Object.assign({}, paramValues)
        newValues[paramId] = value
        paramValues = newValues
    }

    // OBD Data Connections - Original parameters
    Connections {
        target: obdManager

        // Original parameters
        function onCoolantTempChanged(value) { updateParamValue("COOLANT_TEMP", value); }
        function onVoltageChanged(value) { updateParamValue("CONTROL_MODULE_VOLTAGE", value); }
        function onEngineLoadChanged(value) { updateParamValue("ENGINE_LOAD", value); }
        function onThrottlePositionChanged(value) { updateParamValue("THROTTLE_POS", value); }
        function onIntakeAirTempChanged(value) { updateParamValue("INTAKE_TEMP", value); }
        function onTimingAdvanceChanged(value) { updateParamValue("TIMING_ADVANCE", value); }
        function onMassAirFlowChanged(value) { updateParamValue("MAF", value); }
        function onSpeedMPHChanged(value) { updateParamValue("SPEED", value); }
        function onRpmChanged(value) { updateParamValue("RPM", value); }
        function onAirFuelRatioChanged(value) { updateParamValue("COMMANDED_EQUIV_RATIO", value); }
        function onFuelLevelChanged(value) { updateParamValue("FUEL_LEVEL", value); }
        function onIntakeManifoldPressureChanged(value) { updateParamValue("INTAKE_PRESSURE", value); }
        function onShortTermFuelTrimChanged(value) { updateParamValue("SHORT_FUEL_TRIM_1", value); }
        function onLongTermFuelTrimChanged(value) { updateParamValue("LONG_FUEL_TRIM_1", value); }
        function onOxygenSensorVoltageChanged(value) { updateParamValue("O2_B1S1", value); }
        function onFuelPressureChanged(value) { updateParamValue("FUEL_PRESSURE", value); }
        function onEngineOilTempChanged(value) { updateParamValue("OIL_TEMP", value); }
        function onIgnitionTimingChanged(value) { updateParamValue("IGNITION_TIMING", value); }

        // Additional parameters
        function onRunTimeChanged(value) { updateParamValue("RUN_TIME", value); }
        function onDistanceWithMILChanged(value) { updateParamValue("DISTANCE_W_MIL", value); }
        function onFuelRailPressureChanged(value) { updateParamValue("FUEL_RAIL_PRESSURE_VAC", value); }
        function onFuelRailPressureDirectChanged(value) { updateParamValue("FUEL_RAIL_PRESSURE_DIRECT", value); }
        function onBarometricPressureChanged(value) { updateParamValue("BAROMETRIC_PRESSURE", value); }
        function onAmbientAirTempChanged(value) { updateParamValue("AMBIANT_AIR_TEMP", value); }
        function onRelativeThrottlePosChanged(value) { updateParamValue("RELATIVE_THROTTLE_POS", value); }
        function onAbsoluteThrottlePosBChanged(value) { updateParamValue("THROTTLE_POS_B", value); }
        function onAcceleratorPosChanged(value) { updateParamValue("ACCELERATOR_POS_D", value); }
        function onCatalystTempB1S1Changed(value) { updateParamValue("CATALYST_TEMP_B1S1", value); }
        function onCatalystTempB1S2Changed(value) { updateParamValue("CATALYST_TEMP_B1S2", value); }
        function onEvapVaporPressureChanged(value) { updateParamValue("EVAP_VAPOR_PRESSURE", value); }
        function onShortFuelTrim2Changed(value) { updateParamValue("SHORT_FUEL_TRIM_2", value); }
        function onLongFuelTrim2Changed(value) { updateParamValue("LONG_FUEL_TRIM_2", value); }
        function onO2SensorB1S2Changed(value) { updateParamValue("O2_B1S2", value); }
        function onO2SensorB2S1Changed(value) { updateParamValue("O2_B2S1", value); }
        function onO2SensorB2S2Changed(value) { updateParamValue("O2_B2S2", value); }
        function onDistanceSinceCodesCleared(value) { updateParamValue("DISTANCE_SINCE_DTC_CLEAR", value); }
        function onWarmupsSinceCodesCleared(value) { updateParamValue("WARMUPS_SINCE_DTC_CLEAR", value); }
        function onAbsoluteLoadChanged(value) { updateParamValue("ABSOLUTE_LOAD", value); }
        function onCommandedEGRChanged(value) { updateParamValue("COMMANDED_EGR", value); }
        function onEgrErrorChanged(value) { updateParamValue("EGR_ERROR", value); }
        function onEthanoPercentChanged(value) { updateParamValue("ETHANOL_PERCENT", value); }

        // Batch 2 - Additional O2 sensors
        function onO2SensorB1S3Changed(value) { updateParamValue("O2_B1S3", value); }
        function onO2SensorB1S4Changed(value) { updateParamValue("O2_B1S4", value); }
        function onO2SensorB2S3Changed(value) { updateParamValue("O2_B2S3", value); }
        function onO2SensorB2S4Changed(value) { updateParamValue("O2_B2S4", value); }
        // Wide-range O2 sensors voltage
        function onO2S1WRVoltageChanged(value) { updateParamValue("O2_S1_WR_VOLTAGE", value); }
        function onO2S2WRVoltageChanged(value) { updateParamValue("O2_S2_WR_VOLTAGE", value); }
        function onO2S3WRVoltageChanged(value) { updateParamValue("O2_S3_WR_VOLTAGE", value); }
        function onO2S4WRVoltageChanged(value) { updateParamValue("O2_S4_WR_VOLTAGE", value); }
        function onO2S5WRVoltageChanged(value) { updateParamValue("O2_S5_WR_VOLTAGE", value); }
        function onO2S6WRVoltageChanged(value) { updateParamValue("O2_S6_WR_VOLTAGE", value); }
        function onO2S7WRVoltageChanged(value) { updateParamValue("O2_S7_WR_VOLTAGE", value); }
        function onO2S8WRVoltageChanged(value) { updateParamValue("O2_S8_WR_VOLTAGE", value); }
        // Wide-range O2 sensors current
        function onO2S1WRCurrentChanged(value) { updateParamValue("O2_S1_WR_CURRENT", value); }
        function onO2S2WRCurrentChanged(value) { updateParamValue("O2_S2_WR_CURRENT", value); }
        function onO2S3WRCurrentChanged(value) { updateParamValue("O2_S3_WR_CURRENT", value); }
        function onO2S4WRCurrentChanged(value) { updateParamValue("O2_S4_WR_CURRENT", value); }
        function onO2S5WRCurrentChanged(value) { updateParamValue("O2_S5_WR_CURRENT", value); }
        function onO2S6WRCurrentChanged(value) { updateParamValue("O2_S6_WR_CURRENT", value); }
        function onO2S7WRCurrentChanged(value) { updateParamValue("O2_S7_WR_CURRENT", value); }
        function onO2S8WRCurrentChanged(value) { updateParamValue("O2_S8_WR_CURRENT", value); }
        // Bank 2 catalyst temps
        function onCatalystTempB2S1Changed(value) { updateParamValue("CATALYST_TEMP_B2S1", value); }
        function onCatalystTempB2S2Changed(value) { updateParamValue("CATALYST_TEMP_B2S2", value); }
        // Additional throttle/accelerator
        function onThrottlePosCChanged(value) { updateParamValue("THROTTLE_POS_C", value); }
        function onAcceleratorPosEChanged(value) { updateParamValue("ACCELERATOR_POS_E", value); }
        function onAcceleratorPosFChanged(value) { updateParamValue("ACCELERATOR_POS_F", value); }
        function onThrottleActuatorChanged(value) { updateParamValue("THROTTLE_ACTUATOR", value); }
        // Fuel system
        function onEvaporativePurgeChanged(value) { updateParamValue("EVAPORATIVE_PURGE", value); }
        function onFuelRailPressureAbsChanged(value) { updateParamValue("FUEL_RAIL_PRESSURE_ABS", value); }
        function onFuelInjectTimingChanged(value) { updateParamValue("FUEL_INJECT_TIMING", value); }
        function onFuelRateChanged(value) { updateParamValue("FUEL_RATE", value); }
        // Time-based
        function onRunTimeMILChanged(value) { updateParamValue("RUN_TIME_MIL", value); }
        function onTimeSinceDTCClearedChanged(value) { updateParamValue("TIME_SINCE_DTC_CLEARED", value); }
        // Other
        function onMaxMAFChanged(value) { updateParamValue("MAX_MAF", value); }
        function onFuelTypeChanged(value) { updateParamValue("FUEL_TYPE", value); }
        function onEvapVaporPressureAbsChanged(value) { updateParamValue("EVAP_VAPOR_PRESSURE_ABS", value); }
        function onEvapVaporPressureAltChanged(value) { updateParamValue("EVAP_VAPOR_PRESSURE_ALT", value); }
        function onShortO2TrimB1Changed(value) { updateParamValue("SHORT_O2_TRIM_B1", value); }
        function onLongO2TrimB1Changed(value) { updateParamValue("LONG_O2_TRIM_B1", value); }
        function onShortO2TrimB2Changed(value) { updateParamValue("SHORT_O2_TRIM_B2", value); }
        function onLongO2TrimB2Changed(value) { updateParamValue("LONG_O2_TRIM_B2", value); }
        function onRelativeAccelPosChanged(value) { updateParamValue("RELATIVE_ACCEL_POS", value); }
        function onHybridBatteryRemainingChanged(value) { updateParamValue("HYBRID_BATTERY_REMAINING", value); }
        function onElmVoltageChanged(value) { updateParamValue("ELM_VOLTAGE", value); }
    }
    
    // Just update column count when parameters change
    function updateLayout() {
        // Count visible parameters
        let visibleCount = 0;
        for (let i = 0; i < allParameters.length; i++) {
            const param = allParameters[i];
            if (settingsManager && settingsManager.get_obd_parameter_enabled(param.id, true)) {
                visibleCount++;
            }
        }
        
        // Determine column count based on visible parameters
        if (visibleCount <= 4) {
            parametersGrid.columns = 2;
        } else if (visibleCount <= 9) {
            parametersGrid.columns = 3;
        } else {
            parametersGrid.columns = 4;
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: backgroundColor
        
        GridLayout {
            id: parametersGrid
            anchors {
                fill: parent
                margins: App.Spacing.dp(10)
                bottomMargin: App.Spacing.dp(70) // Space for bottom controls
            }
            columns: 3
            rowSpacing: App.Spacing.dp(10)
            columnSpacing: App.Spacing.dp(10)
            
            // Use Repeater to create parameter cards
            Repeater {
                model: allParameters
                
                Item {
                    id: cardContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: settingsManager ? settingsManager.get_obd_parameter_enabled(modelData.id, true) : true

                    // Update layout when visibility changes
                    onVisibleChanged: {
                        if (updateTimer.running) {
                            updateTimer.restart();
                        } else {
                            updateTimer.start();
                        }
                    }

                    // Only take up space when visible
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.preferredHeight: visible ? implicitHeight : 0

                    // Animated display value - fast rolling effect
                    property real targetValue: paramValues[modelData.id] || 0
                    property real displayValue: targetValue
                    Behavior on displayValue {
                        NumberAnimation {
                            duration: 50
                            easing.type: Easing.Linear
                        }
                    }

                    // Square card style (default)
                    Rectangle {
                        id: squareCard
                        anchors.fill: parent
                        visible: !obdPage.useCircularCards

                        color: squareCardMouseArea.containsMouse && modelData.id === "RPM" ?
                               Qt.lighter(Qt.darker(backgroundColor, 0.9), 1.1) : Qt.darker(backgroundColor, 0.9)
                        radius: App.Spacing.dpMin(6, 2)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: squareCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: modelData.id === "RPM"
                            cursorShape: modelData.id === "RPM" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.id === "RPM") {
                                    rpmSettingsPopup.open()
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: App.Spacing.dp(8)
                            spacing: App.Spacing.dp(4)

                            Text {
                                text: modelData.title
                                color: labelColor
                                font.pixelSize: App.Spacing.overallText
                                font.family: obdPage.globalFont
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: cardContainer.displayValue.toFixed(1) + " " + modelData.unit
                                color: textColor
                                font.pixelSize: App.Spacing.overallText
                                font.bold: true
                                font.family: obdPage.globalFont
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: App.Spacing.overallSliderHeight * .5
                                color: Qt.darker(backgroundColor, 1.1)
                                radius: 3
                                Layout.topMargin: App.Spacing.dp(4)

                                Rectangle {
                                    id: progressBar
                                    height: parent.height
                                    radius: 3
                                    color: App.Style.obdBarColor
                                    width: {
                                        const value = paramValues[modelData.id] || 0;
                                        return Math.max(6, parent.width * Math.min(1,
                                            (value - modelData.min) / (modelData.max - modelData.min)));
                                    }

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 100
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Circular gauge style
                    Rectangle {
                        id: circularCard
                        visible: obdPage.useCircularCards

                        // Make it larger - use 95% of the smaller dimension for better fill
                        property real cardSize: Math.min(parent.width, parent.height) * 0.95
                        width: cardSize
                        height: cardSize
                        anchors.centerIn: parent

                        color: circularCardMouseArea.containsMouse && modelData.id === "RPM" ?
                               Qt.lighter(Qt.darker(backgroundColor, 0.9), 1.1) : Qt.darker(backgroundColor, 0.9)
                        radius: width / 2  // Fully circular

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: circularCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: modelData.id === "RPM"
                            cursorShape: modelData.id === "RPM" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.id === "RPM") {
                                    rpmSettingsPopup.open()
                                }
                            }
                        }

                        // Circular gauge arc - using GPU-accelerated Shape
                        property real gaugeValue: {
                            const value = paramValues[modelData.id] || 0;
                            return Math.min(1, Math.max(0, (value - modelData.min) / (modelData.max - modelData.min)));
                        }

                        // Animated gauge value for smooth transitions
                        property real animatedGaugeValue: gaugeValue
                        Behavior on animatedGaugeValue {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }

                        // Gauge dimensions
                        property real arcRadius: (width / 2) - 8
                        property real arcWidth: Math.max(10, arcRadius * 0.14)
                        property real startAngle: 135  // degrees, bottom-left
                        property real sweepAngle: 270  // degrees, total arc span

                        // Background arc - GPU-accelerated Shape (no layer overhead)
                        Shape {
                            anchors.fill: parent

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Qt.darker(obdPage.backgroundColor, 1.1)
                                strokeWidth: circularCard.arcWidth
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: circularCard.width / 2
                                    centerY: circularCard.height / 2
                                    radiusX: circularCard.arcRadius
                                    radiusY: circularCard.arcRadius
                                    startAngle: circularCard.startAngle
                                    sweepAngle: circularCard.sweepAngle
                                }
                            }
                        }

                        // Value arc (on top) - GPU-accelerated Shape
                        Shape {
                            anchors.fill: parent
                            visible: circularCard.animatedGaugeValue > 0.001

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: App.Style.obdBarColor
                                strokeWidth: circularCard.arcWidth
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: circularCard.width / 2
                                    centerY: circularCard.height / 2
                                    radiusX: circularCard.arcRadius
                                    radiusY: circularCard.arcRadius
                                    startAngle: circularCard.startAngle
                                    sweepAngle: circularCard.sweepAngle * circularCard.animatedGaugeValue
                                }
                            }
                        }

                        // Center content
                        Column {
                            anchors.centerIn: parent
                            spacing: App.Spacing.dp(2)

                            Text {
                                text: modelData.title
                                color: labelColor
                                font.pixelSize: App.Spacing.overallText * 0.9
                                font.family: obdPage.globalFont
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                width: circularCard.width * 0.75
                            }

                            Text {
                                text: cardContainer.displayValue.toFixed(1)
                                color: textColor
                                font.pixelSize: App.Spacing.overallText * 1.4
                                font.bold: true
                                font.family: obdPage.globalFont
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: modelData.unit
                                color: labelColor
                                font.pixelSize: App.Spacing.overallText * 0.75
                                font.family: obdPage.globalFont
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Use a timer to delay layout updates to prevent rapid successive updates
    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: updateLayout()
    }
    
    // Listen for settings changes
    Connections {
        target: settingsManager
        function onObdParametersChanged() {
            // Use timer to debounce multiple rapid changes
            updateTimer.restart();
        }
        function onGenericSettingChanged(key) {
            // Update card style when setting changes
            if (key === "obdCardStyleCircular") {
                obdPage.useCircularCards = settingsManager.get_setting_with_default("obdCardStyleCircular", false)
            }
        }
    }
    
    // Listen for window size changes
    Connections {
        target: parent
        function onWidthChanged() { updateTimer.restart(); }
        function onHeightChanged() { updateTimer.restart(); }
    }
    
    // Initialize layout
    Component.onCompleted: {
        updateTimer.start();
    }

    // RPM Settings Popup
    Popup {
        id: rpmSettingsPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: parent.width * 0.92
        height: parent.height * 0.95
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        // RPM Settings state
        property bool shiftLightEnabled: true
        property bool showOnHomeCard: true       // Show indicator on home OBD card
        property int maxRpm: 8000
        property int selectedFlagIndex: -1  // Which flag is selected for editing (-1 = none)
        property real fullScreenFlashOpacity: 0.5

        // Shift light appearance settings
        property real shiftLightSize: 0.5        // Size as percentage of card height (0.25 - 1.0)
        property real glowSize: 0.6              // Inner glow size percentage (0.0 - 1.0)
        property real glowIntensity: 0.6         // Inner glow opacity (0.0 - 1.0)
        property int colorTransitionSpeed: 100   // Color animation duration in ms (0 - 500)
        property bool pulseEnabled: false        // Enable pulse animation when active

        // Flags list - each flag has: rpmLow, rpmHigh, color, flash, flashSpeed, fullScreenFlash, fullScreenFlashOpacity
        property var flags: []

        // Default colors for new flags
        property var defaultColors: ["#00FF00", "#FFFF00", "#FF8800", "#FF0000", "#FF00FF", "#00FFFF"]

        // Load settings when popup opens
        onOpened: {
            if (settingsManager) {
                shiftLightEnabled = settingsManager.get_setting_with_default("rpm_shift_light_enabled", true)
                showOnHomeCard = settingsManager.get_setting_with_default("rpm_show_on_home_card", true)
                maxRpm = settingsManager.get_setting_with_default("rpm_max_rpm", 8000)
                fullScreenFlashOpacity = settingsManager.get_setting_with_default("rpm_fullscreen_flash_opacity", 0.5)
                // Load appearance settings
                shiftLightSize = settingsManager.get_setting_with_default("rpm_shift_light_size", 0.5)
                glowSize = settingsManager.get_setting_with_default("rpm_glow_size", 0.6)
                glowIntensity = settingsManager.get_setting_with_default("rpm_glow_intensity", 0.6)
                colorTransitionSpeed = settingsManager.get_setting_with_default("rpm_color_transition_speed", 100)
                pulseEnabled = settingsManager.get_setting_with_default("rpm_pulse_enabled", false)
                var savedFlags = settingsManager.get_setting_with_default("rpm_flags", "[]")
                try {
                    flags = JSON.parse(savedFlags)
                    // Migrate old format (single rpm) to new format (rpmLow/rpmHigh)
                    for (var i = 0; i < flags.length; i++) {
                        if (flags[i].rpm !== undefined && flags[i].rpmLow === undefined) {
                            flags[i].rpmLow = flags[i].rpm
                            flags[i].rpmHigh = maxRpm  // Default high to max
                            delete flags[i].rpm
                        }
                    }
                } catch(e) {
                    flags = []
                }
                selectedFlagIndex = -1
            }
        }

        // Save flags to settings
        function saveFlags() {
            if (settingsManager) {
                settingsManager.save_setting("rpm_flags", JSON.stringify(flags))
            }
        }

        // Add a new flag at a default position
        function addFlag() {
            var newRpmLow = Math.round(maxRpm * 0.6 / 100) * 100  // Default to 60% of max
            var newRpmHigh = Math.round(maxRpm * 0.85 / 100) * 100  // Default to 85% of max
            var colorIndex = flags.length % defaultColors.length
            var newFlag = {
                rpmLow: newRpmLow,
                rpmHigh: newRpmHigh,
                color: defaultColors[colorIndex],
                flash: false,
                flashSpeed: 100,
                fullScreenFlash: false,
                fullScreenFlashOpacity: 0.5
            }
            var newFlags = flags.slice()  // Create a copy
            newFlags.push(newFlag)
            // Sort by low RPM
            newFlags.sort(function(a, b) { return a.rpmLow - b.rpmLow })
            flags = newFlags
            selectedFlagIndex = flags.indexOf(newFlag)
            saveFlags()
        }

        // Remove a flag
        function removeFlag(index) {
            if (index >= 0 && index < flags.length) {
                var newFlags = flags.slice()
                newFlags.splice(index, 1)
                flags = newFlags
                if (selectedFlagIndex >= flags.length) {
                    selectedFlagIndex = flags.length - 1
                }
                if (selectedFlagIndex < 0 && flags.length > 0) {
                    selectedFlagIndex = 0
                }
                saveFlags()
            }
        }

        // Update a flag property
        function updateFlag(index, property, value) {
            if (index >= 0 && index < flags.length) {
                var newFlags = flags.slice()
                newFlags[index] = Object.assign({}, newFlags[index])
                newFlags[index][property] = value
                // Ensure rpmLow <= rpmHigh
                if (property === "rpmLow" && newFlags[index].rpmLow > newFlags[index].rpmHigh) {
                    newFlags[index].rpmHigh = newFlags[index].rpmLow
                }
                if (property === "rpmHigh" && newFlags[index].rpmHigh < newFlags[index].rpmLow) {
                    newFlags[index].rpmLow = newFlags[index].rpmHigh
                }
                // Re-sort if low RPM changed
                if (property === "rpmLow") {
                    var updatedFlag = newFlags[index]
                    newFlags.sort(function(a, b) { return a.rpmLow - b.rpmLow })
                    selectedFlagIndex = newFlags.indexOf(updatedFlag)
                }
                flags = newFlags
                saveFlags()
            }
        }

        background: Rectangle {
            color: Qt.rgba(App.Style.contentColor.r, App.Style.contentColor.g, App.Style.contentColor.b, 0.95)
            radius: App.Spacing.overallMargin
            border.color: App.Style.accent
            border.width: 2

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 6
                radius: 30
                samples: 31
                color: "#90000000"
            }
        }

        contentItem: Item {
            // Header at top
            Text {
                id: rpmPopupHeader
                text: "RPM Shift Light Settings"
                font.pixelSize: App.Spacing.overallText * 1.6
                font.bold: true
                font.family: obdPage.globalFont
                color: App.Style.primaryTextColor
                anchors.top: parent.top
                anchors.topMargin: App.Spacing.overallMargin
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Close button at bottom
            Rectangle {
                id: rpmCloseBtn
                width: App.Spacing.overallText * 10
                height: App.Spacing.overallText * 3
                radius: App.Spacing.overallMargin * 0.5
                color: rpmCloseButtonMouse.pressed ? Qt.darker(App.Style.accent, 1.2) :
                       rpmCloseButtonMouse.containsMouse ? Qt.lighter(App.Style.accent, 1.1) : App.Style.accent
                anchors.bottom: parent.bottom
                anchors.bottomMargin: App.Spacing.overallMargin
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    font.pixelSize: App.Spacing.overallText * 1.4
                    font.bold: true
                    font.family: obdPage.globalFont
                    color: "white"
                }

                MouseArea {
                    id: rpmCloseButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: rpmSettingsPopup.close()
                }
            }

            // Settings content in scrollable area
            ScrollView {
                id: rpmSettingsScrollView
                anchors.top: rpmPopupHeader.bottom
                anchors.topMargin: App.Spacing.overallSpacing
                anchors.bottom: rpmCloseBtn.top
                anchors.bottomMargin: App.Spacing.overallSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: App.Spacing.overallMargin
                anchors.rightMargin: App.Spacing.overallMargin
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                Column {
                    width: rpmSettingsScrollView.width
                    spacing: App.Spacing.overallSpacing

                    // === SHIFT LIGHT ENABLE/DISABLE ===
                    Rectangle {
                        width: parent.width
                        height: App.Spacing.dp(60)
                        radius: App.Spacing.overallMargin * 0.5
                        color: shiftLightRowMouse.containsMouse ? Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3) : "transparent"

                        MouseArea {
                            id: shiftLightRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                rpmSettingsPopup.shiftLightEnabled = !rpmSettingsPopup.shiftLightEnabled
                                if (settingsManager) {
                                    settingsManager.save_setting("rpm_shift_light_enabled", rpmSettingsPopup.shiftLightEnabled)
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: App.Spacing.overallMargin
                            anchors.rightMargin: App.Spacing.overallMargin
                            spacing: App.Spacing.overallSpacing * 2

                            Text {
                                text: "Enable Shift Light"
                                font.pixelSize: App.Spacing.overallText * 1.1
                                font.family: obdPage.globalFont
                                color: App.Style.primaryTextColor
                                Layout.fillWidth: true

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        rpmSettingsPopup.shiftLightEnabled = !rpmSettingsPopup.shiftLightEnabled
                                        if (settingsManager) {
                                            settingsManager.save_setting("rpm_shift_light_enabled", rpmSettingsPopup.shiftLightEnabled)
                                        }
                                    }
                                }
                            }

                            // Toggle switch - matches SettingsMenu styling exactly
                            Item {
                                Layout.preferredWidth: App.Spacing.dp(80)
                                Layout.preferredHeight: App.Spacing.dp(40)

                                // Main track
                                Rectangle {
                                    id: shiftLightTrack
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: rpmSettingsPopup.shiftLightEnabled ?
                                        Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3) :
                                        Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)

                                    // Subtle gradient overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                                        }
                                    }

                                    // Animated highlight
                                    Rectangle {
                                        id: shiftLightHighlight
                                        width: rpmSettingsPopup.shiftLightEnabled ? parent.width : 0
                                        height: parent.height
                                        radius: parent.radius
                                        anchors.right: rpmSettingsPopup.shiftLightEnabled ? parent.right : undefined
                                        anchors.left: !rpmSettingsPopup.shiftLightEnabled ? parent.left : undefined
                                        color: App.Style.accent
                                        opacity: rpmSettingsPopup.shiftLightEnabled ? 0.5 : 0

                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    // ON/OFF text
                                    Text {
                                        anchors {
                                            left: rpmSettingsPopup.shiftLightEnabled ? undefined : parent.left
                                            right: rpmSettingsPopup.shiftLightEnabled ? parent.right : undefined
                                            margins: App.Spacing.dp(10)
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: rpmSettingsPopup.shiftLightEnabled ? "ON" : "OFF"
                                        font.pixelSize: App.Spacing.overallText * 0.8
                                        font.bold: true
                                        font.family: obdPage.globalFont
                                        color: rpmSettingsPopup.shiftLightEnabled ? App.Style.accent :
                                            Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.7)
                                        visible: width < (parent.width - shiftLightHandle.width - App.Spacing.dp(10))

                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                // Handle
                                Rectangle {
                                    id: shiftLightHandle
                                    width: App.Spacing.dp(40)
                                    height: App.Spacing.dp(40)
                                    radius: width / 2
                                    x: rpmSettingsPopup.shiftLightEnabled ? parent.width - width : 0
                                    y: 0
                                    color: "white"

                                    // Inner indicator
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.4
                                        height: width
                                        radius: width / 2
                                        color: App.Style.accent
                                        opacity: rpmSettingsPopup.shiftLightEnabled ? 1 : 0
                                        scale: rpmSettingsPopup.shiftLightEnabled ? 1 : 0.5

                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        verticalOffset: 2
                                        radius: 6.0
                                        samples: 17
                                        color: Qt.rgba(0, 0, 0, 0.2)
                                    }

                                    scale: shiftLightToggleMouse.pressed ? 0.95 : 1.0

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 0.6
                                        }
                                    }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }

                                // Interactive area with pulse animation
                                MouseArea {
                                    id: shiftLightToggleMouse
                                    anchors.fill: parent
                                    onClicked: {
                                        rpmSettingsPopup.shiftLightEnabled = !rpmSettingsPopup.shiftLightEnabled
                                        if (settingsManager) {
                                            settingsManager.save_setting("rpm_shift_light_enabled", rpmSettingsPopup.shiftLightEnabled)
                                        }
                                    }
                                    onPressed: {
                                        shiftLightPulseAnimation.start()
                                    }

                                    SequentialAnimation {
                                        id: shiftLightPulseAnimation
                                        PropertyAnimation {
                                            target: shiftLightHandle
                                            property: "scale"
                                            to: 0.9
                                            duration: 100
                                        }
                                        PropertyAnimation {
                                            target: shiftLightHandle
                                            property: "scale"
                                            to: 1.0
                                            duration: 100
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // === SHOW ON HOME CARD TOGGLE ===
                    Rectangle {
                        width: parent.width
                        height: App.Spacing.dp(60)
                        radius: App.Spacing.overallMargin * 0.5
                        color: showOnHomeCardRowMouse.containsMouse ? Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3) : "transparent"

                        MouseArea {
                            id: showOnHomeCardRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                rpmSettingsPopup.showOnHomeCard = !rpmSettingsPopup.showOnHomeCard
                                if (settingsManager) {
                                    settingsManager.save_setting("rpm_show_on_home_card", rpmSettingsPopup.showOnHomeCard)
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: App.Spacing.overallMargin
                            anchors.rightMargin: App.Spacing.overallMargin
                            spacing: App.Spacing.overallSpacing * 2

                            Text {
                                text: "Show Indicator on Home"
                                font.pixelSize: App.Spacing.overallText * 1.1
                                font.family: obdPage.globalFont
                                color: App.Style.primaryTextColor
                                Layout.fillWidth: true

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        rpmSettingsPopup.showOnHomeCard = !rpmSettingsPopup.showOnHomeCard
                                        if (settingsManager) {
                                            settingsManager.save_setting("rpm_show_on_home_card", rpmSettingsPopup.showOnHomeCard)
                                        }
                                    }
                                }
                            }

                            // Toggle switch
                            Item {
                                Layout.preferredWidth: App.Spacing.dp(80)
                                Layout.preferredHeight: App.Spacing.dp(40)

                                Rectangle {
                                    id: showOnHomeCardTrack
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: rpmSettingsPopup.showOnHomeCard ?
                                        Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3) :
                                        Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                                        }
                                    }

                                    Rectangle {
                                        width: rpmSettingsPopup.showOnHomeCard ? parent.width : 0
                                        height: parent.height
                                        radius: parent.radius
                                        anchors.right: rpmSettingsPopup.showOnHomeCard ? parent.right : undefined
                                        anchors.left: !rpmSettingsPopup.showOnHomeCard ? parent.left : undefined
                                        color: App.Style.accent
                                        opacity: rpmSettingsPopup.showOnHomeCard ? 0.5 : 0

                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Text {
                                        anchors {
                                            left: rpmSettingsPopup.showOnHomeCard ? undefined : parent.left
                                            right: rpmSettingsPopup.showOnHomeCard ? parent.right : undefined
                                            margins: App.Spacing.dp(10)
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: rpmSettingsPopup.showOnHomeCard ? "ON" : "OFF"
                                        font.pixelSize: App.Spacing.overallText * 0.8
                                        font.bold: true
                                        font.family: obdPage.globalFont
                                        color: rpmSettingsPopup.showOnHomeCard ? App.Style.accent :
                                            Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.7)
                                        visible: width < (parent.width - showOnHomeCardHandle.width - App.Spacing.dp(10))

                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                Rectangle {
                                    id: showOnHomeCardHandle
                                    width: App.Spacing.dp(40)
                                    height: App.Spacing.dp(40)
                                    radius: width / 2
                                    x: rpmSettingsPopup.showOnHomeCard ? parent.width - width : 0
                                    y: 0
                                    color: "white"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.4
                                        height: width
                                        radius: width / 2
                                        color: App.Style.accent
                                        opacity: rpmSettingsPopup.showOnHomeCard ? 1 : 0
                                        scale: rpmSettingsPopup.showOnHomeCard ? 1 : 0.5

                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        verticalOffset: 2
                                        radius: 6.0
                                        samples: 17
                                        color: Qt.rgba(0, 0, 0, 0.2)
                                    }

                                    scale: showOnHomeCardToggleMouse.pressed ? 0.95 : 1.0

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 0.6
                                        }
                                    }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: showOnHomeCardToggleMouse
                                    anchors.fill: parent
                                    onClicked: {
                                        rpmSettingsPopup.showOnHomeCard = !rpmSettingsPopup.showOnHomeCard
                                        if (settingsManager) {
                                            settingsManager.save_setting("rpm_show_on_home_card", rpmSettingsPopup.showOnHomeCard)
                                        }
                                    }
                                    onPressed: {
                                        showOnHomeCardPulseAnimation.start()
                                    }

                                    SequentialAnimation {
                                        id: showOnHomeCardPulseAnimation
                                        PropertyAnimation {
                                            target: showOnHomeCardHandle
                                            property: "scale"
                                            to: 0.9
                                            duration: 100
                                        }
                                        PropertyAnimation {
                                            target: showOnHomeCardHandle
                                            property: "scale"
                                            to: 1.0
                                            duration: 100
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // === MAX RPM SETTING ===
                    RowLayout {
                        width: parent.width
                        Layout.leftMargin: App.Spacing.overallMargin
                        Layout.rightMargin: App.Spacing.overallMargin

                        Text {
                            text: "Redline"
                            font.pixelSize: App.Spacing.overallText * 1.1
                            font.family: obdPage.globalFont
                            color: App.Style.primaryTextColor
                        }

                        Slider {
                            id: maxRpmSlider
                            Layout.fillWidth: true
                            implicitHeight: App.Spacing.overallSliderHeight * 2.5
                            from: 4000
                            to: 12000
                            stepSize: 500
                            value: rpmSettingsPopup.maxRpm
                            onMoved: {
                                rpmSettingsPopup.maxRpm = value
                                if (settingsManager) {
                                    settingsManager.save_setting("rpm_max_rpm", value)
                                }
                                // Clamp flag rpmHigh values that exceed new max
                                var needsSave = false
                                var newFlags = rpmSettingsPopup.flags.slice()
                                for (var i = 0; i < newFlags.length; i++) {
                                    if (newFlags[i].rpmHigh > value) {
                                        newFlags[i] = Object.assign({}, newFlags[i])
                                        newFlags[i].rpmHigh = value
                                        // Also clamp rpmLow if it exceeds new rpmHigh
                                        if (newFlags[i].rpmLow > value) {
                                            newFlags[i].rpmLow = value
                                        }
                                        needsSave = true
                                    }
                                }
                                if (needsSave) {
                                    rpmSettingsPopup.flags = newFlags
                                    rpmSettingsPopup.saveFlags()
                                }
                            }

                            background: Rectangle {
                                x: maxRpmSlider.leftPadding
                                y: maxRpmSlider.topPadding + maxRpmSlider.availableHeight / 2 - height / 2
                                width: maxRpmSlider.availableWidth
                                height: App.Spacing.overallSliderHeight * 0.5
                                radius: height / 2
                                color: Qt.darker(App.Style.contentColor, 1.2)

                                Rectangle {
                                    width: maxRpmSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#FF0000"
                                    radius: height / 2
                                }
                            }

                            handle: Rectangle {
                                x: maxRpmSlider.leftPadding + maxRpmSlider.visualPosition * (maxRpmSlider.availableWidth - width)
                                y: maxRpmSlider.topPadding + maxRpmSlider.availableHeight / 2 - height / 2
                                width: App.Spacing.overallSliderHeight * 1.5
                                height: width
                                radius: width / 2
                                color: maxRpmSlider.pressed ? Qt.darker("white", 1.1) : "white"
                                border.color: "#FF0000"
                                border.width: 2
                            }
                        }

                        Text {
                            text: rpmSettingsPopup.maxRpm
                            font.pixelSize: App.Spacing.overallText * 1.1
                            font.bold: true
                            font.family: obdPage.globalFont
                            color: "#FF0000"
                            Layout.preferredWidth: App.Spacing.overallText * 4
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // RPM Bar visualization with flags
                    Item {
                        width: parent.width
                        height: App.Spacing.overallText * 8

                        // The RPM bar background
                        Rectangle {
                            id: rpmBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: App.Spacing.overallMargin
                            anchors.rightMargin: App.Spacing.overallMargin
                            anchors.verticalCenter: parent.verticalCenter
                            height: App.Spacing.overallSliderHeight * 1.2
                            radius: height / 2
                            color: Qt.darker(App.Style.contentColor, 1.2)

                            // Gradient fill showing base RPM range
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(0.2, 0.2, 0.2, 1) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0.5, 0.1, 0.1, 1) }
                                }
                            }

                            // Range segments for each flag
                            Repeater {
                                model: rpmSettingsPopup.flags

                                Rectangle {
                                    id: rangeSegment
                                    property real lowPos: modelData.rpmLow / rpmSettingsPopup.maxRpm
                                    property real highPos: modelData.rpmHigh / rpmSettingsPopup.maxRpm
                                    x: lowPos * rpmBar.width
                                    width: (highPos - lowPos) * rpmBar.width
                                    height: rpmBar.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.rgba(Qt.lighter(modelData.color, 1.2).r, Qt.lighter(modelData.color, 1.2).g, Qt.lighter(modelData.color, 1.2).b, 0.5)
                                    border.color: index === rpmSettingsPopup.selectedFlagIndex ? "white" : modelData.color
                                    border.width: index === rpmSettingsPopup.selectedFlagIndex ? 3 : 2
                                    radius: rpmBar.radius

                                    // Flag number label on segment
                                    Text {
                                        anchors.centerIn: parent
                                        text: (index + 1).toString()
                                        font.pixelSize: App.Spacing.overallText * 1.1
                                        font.bold: true
                                        font.family: obdPage.globalFont
                                        color: "white"
                                        visible: parent.width > App.Spacing.overallText * 2
                                    }

                                    // Click to select flag
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            rpmSettingsPopup.selectedFlagIndex = index
                                        }
                                    }
                                }
                            }

                            // RPM scale labels
                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.bottom
                                anchors.topMargin: App.Spacing.overallSpacing * 0.5
                                text: "0"
                                font.pixelSize: App.Spacing.overallText * 0.9
                                font.family: obdPage.globalFont
                                color: Qt.darker(App.Style.primaryTextColor, 1.3)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: App.Spacing.overallSpacing * 0.5
                                text: Math.round(rpmSettingsPopup.maxRpm / 2).toString()
                                font.pixelSize: App.Spacing.overallText * 0.9
                                font.family: obdPage.globalFont
                                color: Qt.darker(App.Style.primaryTextColor, 1.3)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.top: parent.bottom
                                anchors.topMargin: App.Spacing.overallSpacing * 0.5
                                text: rpmSettingsPopup.maxRpm.toString()
                                font.pixelSize: App.Spacing.overallText * 0.9
                                font.family: obdPage.globalFont
                                color: Qt.darker(App.Style.primaryTextColor, 1.3)
                            }
                        }
                    }

                    // Add Flag Button
                    Rectangle {
                        width: App.Spacing.overallText * 12
                        height: App.Spacing.overallText * 3
                        radius: App.Spacing.overallMargin * 0.5
                        color: addFlagMouse.pressed ? Qt.darker(App.Style.accent, 1.2) :
                               addFlagMouse.containsMouse ? Qt.lighter(App.Style.accent, 1.1) : App.Style.accent
                        anchors.horizontalCenter: parent.horizontalCenter

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: App.Spacing.overallSpacing * 0.5

                            Text {
                                text: "+"
                                font.pixelSize: App.Spacing.overallText * 1.6
                                font.bold: true
                                font.family: obdPage.globalFont
                                color: "white"
                            }

                            Text {
                                text: "Add Flag"
                                font.pixelSize: App.Spacing.overallText * 1.4
                                font.bold: true
                                font.family: obdPage.globalFont
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: addFlagMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: rpmSettingsPopup.addFlag()
                        }
                    }

                    // === SECTION DIVIDER ===
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.2)
                        visible: rpmSettingsPopup.flags.length > 0
                    }

                    // === SELECTED FLAG SETTINGS ===
                    Column {
                        id: flagSettingsColumn
                        width: parent.width
                        spacing: App.Spacing.overallSpacing
                        visible: rpmSettingsPopup.selectedFlagIndex >= 0 && rpmSettingsPopup.selectedFlagIndex < rpmSettingsPopup.flags.length

                        property var currentFlag: rpmSettingsPopup.selectedFlagIndex >= 0 && rpmSettingsPopup.selectedFlagIndex < rpmSettingsPopup.flags.length ?
                                                  rpmSettingsPopup.flags[rpmSettingsPopup.selectedFlagIndex] : null

                        RowLayout {
                            width: parent.width

                            Text {
                                text: "Flag " + (rpmSettingsPopup.selectedFlagIndex + 1) + " Settings"
                                font.pixelSize: App.Spacing.overallText * 1.6
                                font.bold: true
                                font.family: obdPage.globalFont
                                color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                leftPadding: App.Spacing.overallMargin
                                Layout.fillWidth: true
                            }

                            // Delete flag button
                            Rectangle {
                                Layout.preferredWidth: App.Spacing.overallText * 8
                                Layout.preferredHeight: App.Spacing.overallText * 2.5
                                Layout.rightMargin: App.Spacing.overallMargin
                                radius: App.Spacing.overallMargin * 0.5
                                color: deleteFlagMouse.pressed ? Qt.darker("#FF4444", 1.2) :
                                       deleteFlagMouse.containsMouse ? Qt.lighter("#FF4444", 1.1) : "#FF4444"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Delete"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.bold: true
                                    font.family: obdPage.globalFont
                                    color: "white"
                                }

                                MouseArea {
                                    id: deleteFlagMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: rpmSettingsPopup.removeFlag(rpmSettingsPopup.selectedFlagIndex)
                                }
                            }
                        }

                        // RPM Low Value Slider for selected flag
                        Column {
                            width: parent.width
                            spacing: App.Spacing.overallSpacing * 0.5

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "RPM Low (Start)"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true
                                    leftPadding: App.Spacing.overallMargin
                                }

                                Text {
                                    text: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.rpmLow + " RPM" : ""
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.bold: true
                                    font.family: obdPage.globalFont
                                    color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.primaryTextColor
                                    rightPadding: App.Spacing.overallMargin
                                }
                            }

                            Slider {
                                id: flagRpmLowSlider
                                width: parent.width - App.Spacing.overallMargin * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitHeight: App.Spacing.overallSliderHeight * 2.5
                                from: 0
                                to: rpmSettingsPopup.maxRpm
                                stepSize: 100
                                value: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.rpmLow : 0
                                onMoved: {
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "rpmLow", value)
                                }

                                background: Rectangle {
                                    x: flagRpmLowSlider.leftPadding
                                    y: flagRpmLowSlider.topPadding + flagRpmLowSlider.availableHeight / 2 - height / 2
                                    width: flagRpmLowSlider.availableWidth
                                    height: App.Spacing.overallSliderHeight * 0.5
                                    radius: height / 2
                                    color: Qt.darker(App.Style.contentColor, 1.2)

                                    Rectangle {
                                        width: flagRpmLowSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                        radius: height / 2
                                    }
                                }

                                handle: Rectangle {
                                    x: flagRpmLowSlider.leftPadding + flagRpmLowSlider.visualPosition * (flagRpmLowSlider.availableWidth - width)
                                    y: flagRpmLowSlider.topPadding + flagRpmLowSlider.availableHeight / 2 - height / 2
                                    width: App.Spacing.overallSliderHeight * 1.5
                                    height: width
                                    radius: width / 2
                                    color: flagRpmLowSlider.pressed ? Qt.darker("white", 1.1) : "white"
                                    border.color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                    border.width: 2
                                }
                            }
                        }

                        // RPM High Value Slider for selected flag
                        Column {
                            width: parent.width
                            spacing: App.Spacing.overallSpacing * 0.5

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "RPM High (End)"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true
                                    leftPadding: App.Spacing.overallMargin
                                }

                                Text {
                                    text: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.rpmHigh + " RPM" : ""
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.bold: true
                                    font.family: obdPage.globalFont
                                    color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.primaryTextColor
                                    rightPadding: App.Spacing.overallMargin
                                }
                            }

                            Slider {
                                id: flagRpmHighSlider
                                width: parent.width - App.Spacing.overallMargin * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitHeight: App.Spacing.overallSliderHeight * 2.5
                                from: 0
                                to: rpmSettingsPopup.maxRpm
                                stepSize: 100
                                value: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.rpmHigh : rpmSettingsPopup.maxRpm
                                onMoved: {
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "rpmHigh", value)
                                }

                                background: Rectangle {
                                    x: flagRpmHighSlider.leftPadding
                                    y: flagRpmHighSlider.topPadding + flagRpmHighSlider.availableHeight / 2 - height / 2
                                    width: flagRpmHighSlider.availableWidth
                                    height: App.Spacing.overallSliderHeight * 0.5
                                    radius: height / 2
                                    color: Qt.darker(App.Style.contentColor, 1.2)

                                    Rectangle {
                                        width: flagRpmHighSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                        radius: height / 2
                                    }
                                }

                                handle: Rectangle {
                                    x: flagRpmHighSlider.leftPadding + flagRpmHighSlider.visualPosition * (flagRpmHighSlider.availableWidth - width)
                                    y: flagRpmHighSlider.topPadding + flagRpmHighSlider.availableHeight / 2 - height / 2
                                    width: App.Spacing.overallSliderHeight * 1.5
                                    height: width
                                    radius: width / 2
                                    color: flagRpmHighSlider.pressed ? Qt.darker("white", 1.1) : "white"
                                    border.color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                    border.width: 2
                                }
                            }
                        }

                        // Color picker for selected flag
                        Column {
                            width: parent.width
                            spacing: App.Spacing.overallSpacing * 0.5

                            Text {
                                text: "Color"
                                font.pixelSize: App.Spacing.overallText * 1.1
                                font.family: obdPage.globalFont
                                color: App.Style.primaryTextColor
                                leftPadding: App.Spacing.overallMargin
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: App.Spacing.overallSpacing

                                Repeater {
                                    model: ["#00FF00", "#FFFF00", "#FF8800", "#FF0000", "#FF00FF", "#00FFFF", "#FFFFFF", "#0088FF"]

                                    Rectangle {
                                        width: App.Spacing.overallText * 3
                                        height: width
                                        radius: width / 2
                                        color: modelData
                                        border.color: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.color === modelData ? "white" : Qt.darker(modelData, 1.3)
                                        border.width: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.color === modelData ? 3 : 2

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "color", modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Flash toggle for selected flag
                        Rectangle {
                            width: parent.width
                            height: App.Spacing.dp(60)
                            radius: App.Spacing.overallMargin * 0.5
                            color: flagFlashRowMouse.containsMouse ? Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3) : "transparent"

                            MouseArea {
                                id: flagFlashRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var currentFlash = flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.flash : false
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "flash", !currentFlash)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: App.Spacing.overallMargin
                                anchors.rightMargin: App.Spacing.overallMargin
                                spacing: App.Spacing.overallSpacing * 2

                                Text {
                                    text: "Flash when triggered"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var currentFlash = flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.flash
                                            rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "flash", !currentFlash)
                                        }
                                    }
                                }

                                // Toggle switch - matches SettingsMenu styling exactly
                                Item {
                                    id: flagFlashToggleItem
                                    Layout.preferredWidth: App.Spacing.dp(80)
                                    Layout.preferredHeight: App.Spacing.dp(40)

                                    property bool isChecked: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.flash

                                    Rectangle {
                                        id: flagFlashTrack
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: flagFlashToggleItem.isChecked ?
                                            Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3) :
                                            Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)

                                        // Subtle gradient overlay
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                                            }
                                        }

                                        // Animated highlight
                                        Rectangle {
                                            width: flagFlashToggleItem.isChecked ? parent.width : 0
                                            height: parent.height
                                            radius: parent.radius
                                            anchors.right: flagFlashToggleItem.isChecked ? parent.right : undefined
                                            anchors.left: !flagFlashToggleItem.isChecked ? parent.left : undefined
                                            color: App.Style.accent
                                            opacity: flagFlashToggleItem.isChecked ? 0.5 : 0

                                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                                            Behavior on opacity { NumberAnimation { duration: 300 } }
                                        }

                                        // ON/OFF text
                                        Text {
                                            anchors {
                                                left: flagFlashToggleItem.isChecked ? undefined : parent.left
                                                right: flagFlashToggleItem.isChecked ? parent.right : undefined
                                                margins: App.Spacing.dp(10)
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: flagFlashToggleItem.isChecked ? "ON" : "OFF"
                                            font.pixelSize: App.Spacing.overallText * 0.8
                                            font.bold: true
                                            font.family: obdPage.globalFont
                                            color: flagFlashToggleItem.isChecked ? App.Style.accent :
                                                Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.7)
                                            visible: width < (parent.width - flagFlashHandle.width - App.Spacing.dp(10))

                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }

                                    // Handle
                                    Rectangle {
                                        id: flagFlashHandle
                                        width: App.Spacing.dp(40)
                                        height: App.Spacing.dp(40)
                                        radius: width / 2
                                        x: flagFlashToggleItem.isChecked ? parent.width - width : 0
                                        y: 0
                                        color: "white"

                                        // Inner indicator
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.4
                                            height: width
                                            radius: width / 2
                                            color: App.Style.accent
                                            opacity: flagFlashToggleItem.isChecked ? 1 : 0
                                            scale: flagFlashToggleItem.isChecked ? 1 : 0.5

                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        }

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            verticalOffset: 2
                                            radius: 6.0
                                            samples: 17
                                            color: Qt.rgba(0, 0, 0, 0.2)
                                        }

                                        scale: flagFlashToggleMouse.pressed ? 0.95 : 1.0

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 0.6
                                            }
                                        }
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                    }

                                    // Interactive area with pulse animation
                                    MouseArea {
                                        id: flagFlashToggleMouse
                                        anchors.fill: parent
                                        onClicked: {
                                            rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "flash", !flagFlashToggleItem.isChecked)
                                        }
                                        onPressed: {
                                            flagFlashPulseAnimation.start()
                                        }

                                        SequentialAnimation {
                                            id: flagFlashPulseAnimation
                                            PropertyAnimation {
                                                target: flagFlashHandle
                                                property: "scale"
                                                to: 0.9
                                                duration: 100
                                            }
                                            PropertyAnimation {
                                                target: flagFlashHandle
                                                property: "scale"
                                                to: 1.0
                                                duration: 100
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Flash speed slider (only visible when flash is enabled)
                        Column {
                            width: parent.width
                            spacing: App.Spacing.overallSpacing * 0.5
                            visible: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.flash

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "Flash Speed"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true
                                    leftPadding: App.Spacing.overallMargin
                                }

                                Text {
                                    text: (flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.flashSpeed : 100) + " ms"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.bold: true
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    rightPadding: App.Spacing.overallMargin
                                }
                            }

                            Slider {
                                id: flagFlashSpeedSlider
                                width: parent.width - App.Spacing.overallMargin * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitHeight: App.Spacing.overallSliderHeight * 2.5
                                from: 50
                                to: 500
                                stepSize: 25
                                value: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.flashSpeed : 100
                                onMoved: {
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "flashSpeed", value)
                                }

                                background: Rectangle {
                                    x: flagFlashSpeedSlider.leftPadding
                                    y: flagFlashSpeedSlider.topPadding + flagFlashSpeedSlider.availableHeight / 2 - height / 2
                                    width: flagFlashSpeedSlider.availableWidth
                                    height: App.Spacing.overallSliderHeight * 0.5
                                    radius: height / 2
                                    color: Qt.darker(App.Style.contentColor, 1.2)

                                    Rectangle {
                                        width: flagFlashSpeedSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: App.Style.accent
                                        radius: height / 2
                                    }
                                }

                                handle: Rectangle {
                                    x: flagFlashSpeedSlider.leftPadding + flagFlashSpeedSlider.visualPosition * (flagFlashSpeedSlider.availableWidth - width)
                                    y: flagFlashSpeedSlider.topPadding + flagFlashSpeedSlider.availableHeight / 2 - height / 2
                                    width: App.Spacing.overallSliderHeight * 1.5
                                    height: width
                                    radius: width / 2
                                    color: flagFlashSpeedSlider.pressed ? Qt.darker("white", 1.1) : "white"
                                    border.color: App.Style.accent
                                    border.width: 2
                                }
                            }

                            RowLayout {
                                width: parent.width - App.Spacing.overallMargin * 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "Fast"
                                    font.pixelSize: App.Spacing.overallText * 0.9
                                    font.family: obdPage.globalFont
                                    color: Qt.darker(App.Style.primaryTextColor, 1.3)
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "Slow"
                                    font.pixelSize: App.Spacing.overallText * 0.9
                                    font.family: obdPage.globalFont
                                    color: Qt.darker(App.Style.primaryTextColor, 1.3)
                                }
                            }
                        }

                        // Full screen overlay toggle for this flag
                        Rectangle {
                            width: parent.width
                            height: App.Spacing.dp(60)
                            radius: App.Spacing.overallMargin * 0.5
                            color: fullScreenRowMouse.containsMouse ? Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3) : "transparent"

                            MouseArea {
                                id: fullScreenRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var currentFullScreen = flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.fullScreenFlash : false
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "fullScreenFlash", !currentFullScreen)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: App.Spacing.overallMargin
                                anchors.rightMargin: App.Spacing.overallMargin
                                spacing: App.Spacing.overallSpacing * 2

                                Text {
                                    text: "Full screen overlay"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var currentFullScreen = flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.fullScreenFlash : false
                                            rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "fullScreenFlash", !currentFullScreen)
                                        }
                                    }
                                }

                                // Toggle switch - matches SettingsMenu styling exactly
                                Item {
                                    id: fullScreenToggleItem
                                    Layout.preferredWidth: App.Spacing.dp(80)
                                    Layout.preferredHeight: App.Spacing.dp(40)

                                    property bool isChecked: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.fullScreenFlash

                                    Rectangle {
                                        id: fullScreenTrack
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: fullScreenToggleItem.isChecked ?
                                            Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3) :
                                            Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)

                                        // Subtle gradient overlay
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                                            }
                                        }

                                        // Animated highlight
                                        Rectangle {
                                            width: fullScreenToggleItem.isChecked ? parent.width : 0
                                            height: parent.height
                                            radius: parent.radius
                                            anchors.right: fullScreenToggleItem.isChecked ? parent.right : undefined
                                            anchors.left: !fullScreenToggleItem.isChecked ? parent.left : undefined
                                            color: App.Style.accent
                                            opacity: fullScreenToggleItem.isChecked ? 0.5 : 0

                                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                                            Behavior on opacity { NumberAnimation { duration: 300 } }
                                        }

                                        // ON/OFF text
                                        Text {
                                            anchors {
                                                left: fullScreenToggleItem.isChecked ? undefined : parent.left
                                                right: fullScreenToggleItem.isChecked ? parent.right : undefined
                                                margins: App.Spacing.dp(10)
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: fullScreenToggleItem.isChecked ? "ON" : "OFF"
                                            font.pixelSize: App.Spacing.overallText * 0.8
                                            font.bold: true
                                            font.family: obdPage.globalFont
                                            color: fullScreenToggleItem.isChecked ? App.Style.accent :
                                                Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.7)
                                            visible: width < (parent.width - fullScreenHandle.width - App.Spacing.dp(10))

                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }

                                    // Handle
                                    Rectangle {
                                        id: fullScreenHandle
                                        width: App.Spacing.dp(40)
                                        height: App.Spacing.dp(40)
                                        radius: width / 2
                                        x: fullScreenToggleItem.isChecked ? parent.width - width : 0
                                        y: 0
                                        color: "white"

                                        // Inner indicator
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.4
                                            height: width
                                            radius: width / 2
                                            color: App.Style.accent
                                            opacity: fullScreenToggleItem.isChecked ? 1 : 0
                                            scale: fullScreenToggleItem.isChecked ? 1 : 0.5

                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                        }

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            verticalOffset: 2
                                            radius: 6.0
                                            samples: 17
                                            color: Qt.rgba(0, 0, 0, 0.2)
                                        }

                                        scale: fullScreenFlashFlagToggleMouse.pressed ? 0.95 : 1.0

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 0.6
                                            }
                                        }
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                    }

                                    // Interactive area with pulse animation
                                    MouseArea {
                                        id: fullScreenFlashFlagToggleMouse
                                        anchors.fill: parent
                                        onClicked: {
                                            rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "fullScreenFlash", !fullScreenToggleItem.isChecked)
                                        }
                                        onPressed: {
                                            fullScreenPulseAnimation.start()
                                        }

                                        SequentialAnimation {
                                            id: fullScreenPulseAnimation
                                            PropertyAnimation {
                                                target: fullScreenHandle
                                                property: "scale"
                                                to: 0.9
                                                duration: 100
                                            }
                                            PropertyAnimation {
                                                target: fullScreenHandle
                                                property: "scale"
                                                to: 1.0
                                                duration: 100
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Overlay opacity slider (only visible when full screen overlay is enabled for this flag)
                        Column {
                            width: parent.width
                            spacing: App.Spacing.overallSpacing * 0.5
                            visible: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.fullScreenFlash

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "Overlay Opacity"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    Layout.fillWidth: true
                                    leftPadding: App.Spacing.overallMargin
                                }

                                Text {
                                    text: Math.round((flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.fullScreenFlashOpacity !== undefined ? flagSettingsColumn.currentFlag.fullScreenFlashOpacity : 0.5) * 100) + "%"
                                    font.pixelSize: App.Spacing.overallText * 1.1
                                    font.bold: true
                                    font.family: obdPage.globalFont
                                    color: App.Style.primaryTextColor
                                    rightPadding: App.Spacing.overallMargin
                                }
                            }

                            Slider {
                                id: flagOpacitySlider
                                width: parent.width - App.Spacing.overallMargin * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitHeight: App.Spacing.overallSliderHeight * 2.5
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.fullScreenFlashOpacity !== undefined ? flagSettingsColumn.currentFlag.fullScreenFlashOpacity : 0.5
                                onMoved: {
                                    rpmSettingsPopup.updateFlag(rpmSettingsPopup.selectedFlagIndex, "fullScreenFlashOpacity", value)
                                }

                                background: Rectangle {
                                    x: flagOpacitySlider.leftPadding
                                    y: flagOpacitySlider.topPadding + flagOpacitySlider.availableHeight / 2 - height / 2
                                    width: flagOpacitySlider.availableWidth
                                    height: App.Spacing.overallSliderHeight * 0.5
                                    radius: height / 2
                                    color: Qt.darker(App.Style.contentColor, 1.2)

                                    // Filled portion shows actual opacity preview
                                    Rectangle {
                                        width: flagOpacitySlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: height / 2
                                        color: {
                                            var flagColor = flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                            var opacityVal = flagSettingsColumn.currentFlag && flagSettingsColumn.currentFlag.fullScreenFlashOpacity !== undefined ? flagSettingsColumn.currentFlag.fullScreenFlashOpacity : 0.5
                                            return Qt.rgba(Qt.lighter(flagColor, 1).r, Qt.lighter(flagColor, 1).g, Qt.lighter(flagColor, 1).b, opacityVal)
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    x: flagOpacitySlider.leftPadding + flagOpacitySlider.visualPosition * (flagOpacitySlider.availableWidth - width)
                                    y: flagOpacitySlider.topPadding + flagOpacitySlider.availableHeight / 2 - height / 2
                                    width: App.Spacing.overallSliderHeight * 1.5
                                    height: width
                                    radius: width / 2
                                    color: flagOpacitySlider.pressed ? Qt.darker("white", 1.1) : "white"
                                    border.color: flagSettingsColumn.currentFlag ? flagSettingsColumn.currentFlag.color : App.Style.accent
                                    border.width: 2
                                }
                            }
                        }
                    }

                    // Empty state message
                    Text {
                        width: parent.width
                        text: "No flags added yet. Click \"Add Flag\" to create your first shift light trigger point."
                        font.pixelSize: App.Spacing.overallText * 1.1
                        font.family: obdPage.globalFont
                        color: Qt.darker(App.Style.primaryTextColor, 1.3)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: rpmSettingsPopup.flags.length === 0
                        topPadding: App.Spacing.overallSpacing
                        bottomPadding: App.Spacing.overallSpacing
                    }

                    // Bottom padding
                    Item {
                        width: parent.width
                        height: App.Spacing.overallSpacing
                    }
                }
            }
        }
    }
}