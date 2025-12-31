import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: obdPage
    required property StackView stackView
    required property ApplicationWindow mainWindow

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Define background and accent colors based on screenshot
    property color backgroundColor: App.Style.obdBoxBackground 
    property color accentColor: App.Style.obdBarColor
    property color textColor: App.Style.primaryTextColor
    
    // OBD parameters definition
    property var allParameters: [
        { id: "SPEED", title: "Speed", unit: "MPH", min: 0, max: 160 },
        { id: "RPM", title: "Engine RPM", unit: "RPM", min: 0, max: 8000 },
        { id: "COOLANT_TEMP", title: "Temperature", unit: "°C", min: 0, max: 120 },
        { id: "OIL_TEMP", title: "Oil Temp", unit: "°C", min: 0, max: 150 },
        { id: "COMMANDED_EQUIV_RATIO", title: "Air-Fuel Ratio", unit: ":1", min: 10, max: 18 },
        { id: "ENGINE_LOAD", title: "Engine Load", unit: "%", min: 0, max: 100 },
        { id: "THROTTLE_POS", title: "Throttle", unit: "%", min: 0, max: 100 },
        { id: "FUEL_LEVEL", title: "Fuel Level", unit: "%", min: 0, max: 100 },
        { id: "SHORT_FUEL_TRIM_1", title: "Short Fuel Trim", unit: "%", min: -25, max: 25 },
        { id: "LONG_FUEL_TRIM_1", title: "Long Fuel Trim", unit: "%", min: -25, max: 25 },
        { id: "INTAKE_TEMP", title: "Intake Temp", unit: "°C", min: 0, max: 80 },
        { id: "INTAKE_PRESSURE", title: "Intake Pressure", unit: "kPa", min: 0, max: 255 },
        { id: "MAF", title: "Mass Air Flow", unit: "g/s", min: 0, max: 100 },
        { id: "TIMING_ADVANCE", title: "Timing Advance", unit: "°", min: -35, max: 35 },
        { id: "CONTROL_MODULE_VOLTAGE", title: "System Voltage", unit: "V", min: 10, max: 15 },
        { id: "O2_B1S1", title: "O2 Sensor", unit: "V", min: 0, max: 1.0 },
        { id: "FUEL_PRESSURE", title: "Fuel Pressure", unit: "kPa", min: 0, max: 765 },
        { id: "IGNITION_TIMING", title: "Timing", unit: "°", min: -10, max: 60 }
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

    // OBD Data Connections
    Connections {
        target: obdManager

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
                                    NumberAnimation { duration: 10 }
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