import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
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
    property color textColor: App.Style.primaryTextColor
    
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
                margins: 10
                bottomMargin: 70 // Space for bottom controls
            }
            columns: 3
            rowSpacing: 10
            columnSpacing: 10
            
            // Use Repeater to create parameter cards
            Repeater {
                model: allParameters
                
                Rectangle {
                    id: card
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
                    
                    color: Qt.darker(backgroundColor, 0.9)
                    radius: 6
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        
                        Text {
                            text: modelData.title
                            color: accentColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: obdPage.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: ((paramValues[modelData.id] || 0.0).toFixed(1) + " " + modelData.unit)
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
                            Layout.topMargin: 4
                            
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
                                    NumberAnimation { duration: 200 }
                                }
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
}