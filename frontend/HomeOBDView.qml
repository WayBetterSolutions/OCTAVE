// HomeOBDView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: homeOBDView

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Full screen flash settings (opacity is global, but enabled is per-flag)
    property real fullScreenFlashOpacity: settingsManager ? settingsManager.get_setting_with_default("rpm_fullscreen_flash_opacity", 0.5) : 0.5

    // Track if any shift light is active and flashing (will be set by the RPM card)
    property var activeShiftFlag: null
    property bool shiftLightFlashVisible: true

    // Properties - expanded to include all possible OBD parameters
    property var parameterInfo: {
        "SPEED": {title: "Speed", unit: "MPH", minValue: 0, maxValue: 160},
        "RPM": {title: "RPM", unit: "RPM", minValue: 0, maxValue: 8000},
        "COOLANT_TEMP": {title: "Temp", unit: "°C", minValue: 0, maxValue: 120},
        "CONTROL_MODULE_VOLTAGE": {title: "Voltage", unit: "V", minValue: 10, maxValue: 15},
        "ENGINE_LOAD": {title: "Load", unit: "%", minValue: 0, maxValue: 100},
        "THROTTLE_POS": {title: "Throttle", unit: "%", minValue: 0, maxValue: 100},
        "INTAKE_TEMP": {title: "Intake", unit: "°C", minValue: 0, maxValue: 80},
        "TIMING_ADVANCE": {title: "Timing", unit: "°", minValue: -35, maxValue: 35},
        "MAF": {title: "MAF", unit: "g/s", minValue: 0, maxValue: 100},
        "COMMANDED_EQUIV_RATIO": {title: "AFR", unit: ":1", minValue: 10, maxValue: 18},
        "FUEL_LEVEL": {title: "Fuel", unit: "%", minValue: 0, maxValue: 100},
        "INTAKE_PRESSURE": {title: "MAP", unit: "kPa", minValue: 0, maxValue: 255},
        "SHORT_FUEL_TRIM_1": {title: "STFT", unit: "%", minValue: -25, maxValue: 25},
        "LONG_FUEL_TRIM_1": {title: "LTFT", unit: "%", minValue: -25, maxValue: 25},
        "O2_B1S1": {title: "O2", unit: "V", minValue: 0, maxValue: 1.0},
        "FUEL_PRESSURE": {title: "FP", unit: "kPa", minValue: 0, maxValue: 765},
        "OIL_TEMP": {title: "Oil", unit: "°C", minValue: 0, maxValue: 150},
        "IGNITION_TIMING": {title: "Ign", unit: "°", minValue: -10, maxValue: 60}
    }
    
    // Refreshes all OBD values in the display
    function refreshOBDValues() {
        if (obdManager) {
            const repeaterCount = obdRepeater.count;
            for (let i = 0; i < repeaterCount; i++) {
                const item = obdRepeater.itemAt(i);
                if (item) {
                    const param = item.param;
                    
                    // Map of parameter names to their getter functions in obdManager
                    const getterMap = {
                        "SPEED": "speedMPH",
                        "RPM": "rpm",
                        "COOLANT_TEMP": "coolantTemp",
                        "CONTROL_MODULE_VOLTAGE": "voltage",
                        "ENGINE_LOAD": "engineLoad",
                        "THROTTLE_POS": "throttlePosition",
                        "INTAKE_TEMP": "intakeTemp",
                        "TIMING_ADVANCE": "timingAdvance",
                        "MAF": "massAirFlow",
                        "COMMANDED_EQUIV_RATIO": "airFuelRatio",
                        "FUEL_LEVEL": "fuelLevel",
                        "INTAKE_PRESSURE": "intakeManifoldPressure",
                        "SHORT_FUEL_TRIM_1": "shortTermFuelTrim",
                        "LONG_FUEL_TRIM_1": "longTermFuelTrim",
                        "O2_B1S1": "oxygenSensorVoltage",
                        "FUEL_PRESSURE": "fuelPressure",
                        "OIL_TEMP": "engineOilTemp",
                        "IGNITION_TIMING": "ignitionTiming"
                    };
                    
                    // Get the getter function name for this parameter
                    const getterName = getterMap[param];
                    
                    // If we have a matching getter, call it and update the value
                    if (getterName && obdManager[getterName]) {
                        const value = obdManager[getterName]();
                        if (value !== undefined) {
                            item.value = value;
                        }
                    }
                }
            }
        }
    }
    
    // Timer for delayed refresh after model changes
    Timer {
        id: refreshTimer
        interval: 50  // Short delay
        repeat: false
        onTriggered: {
            refreshOBDValues();
        }
    }
    
    // Smart grid layout - 1 column for up to 5 cards, 2 columns for 6-8 cards
    property int cardCount: obdRepeater.count
    property int columnCount: cardCount <= 5 ? 1 : 2

    GridLayout {
        id: gridLayout
        anchors.fill: parent
        anchors.margins: 10
        columnSpacing: 10
        rowSpacing: 10
        columns: homeOBDView.columnCount

        // Dynamically create displays (max 8)
        Repeater {
            id: obdRepeater
            model: {
                // Use the settings if available, or default to 4 standard params
                let params;
                if (settingsManager && settingsManager.get_home_obd_parameters) {
                    params = settingsManager.get_home_obd_parameters()
                } else {
                    params = ["SPEED", "RPM", "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE"]
                }
                // Limit to maximum 8 cards
                return params.slice(0, 8)
            }
            
            delegate: Rectangle {
                id: display
                property string param: modelData
                property var info: homeOBDView.parameterInfo[param] || 
                                {title: param, unit: "", minValue: 0, maxValue: 100}
                property real value: 0
                
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: App.Style.backgroundColor
                border.color: App.Style.accent
                border.width: 1
                radius: 3
                
                // Dynamic signal connection based on parameter type
                Component.onCompleted: {
                    if (obdManager) {
                        // Map of parameter names to their signal names in obdManager
                        const signalMap = {
                            "SPEED": "speedMPHChanged",
                            "RPM": "rpmChanged",
                            "COOLANT_TEMP": "coolantTempChanged",
                            "CONTROL_MODULE_VOLTAGE": "voltageChanged",
                            "ENGINE_LOAD": "engineLoadChanged",
                            "THROTTLE_POS": "throttlePositionChanged",
                            "INTAKE_TEMP": "intakeAirTempChanged",
                            "TIMING_ADVANCE": "timingAdvanceChanged",
                            "MAF": "massAirFlowChanged",
                            "COMMANDED_EQUIV_RATIO": "airFuelRatioChanged",
                            "FUEL_LEVEL": "fuelLevelChanged",
                            "INTAKE_PRESSURE": "intakeManifoldPressureChanged",
                            "SHORT_FUEL_TRIM_1": "shortTermFuelTrimChanged",
                            "LONG_FUEL_TRIM_1": "longTermFuelTrimChanged",
                            "O2_B1S1": "oxygenSensorVoltageChanged",
                            "FUEL_PRESSURE": "fuelPressureChanged",
                            "OIL_TEMP": "engineOilTempChanged",
                            "IGNITION_TIMING": "ignitionTimingChanged"
                        };
                        
                        // Get the signal name for this parameter
                        const signalName = signalMap[param];
                        
                        // If we have a matching signal, connect to it
                        if (signalName && obdManager[signalName]) {
                            obdManager[signalName].connect(function(val) { 
                                display.value = val; 
                            });
                        }
                    }
                }
                
                // Shift light - positioned on right middle of RPM card
                // Uses flag-based settings from settingsManager
                Rectangle {
                    id: shiftLight
                    visible: param === "RPM" && shiftLightEnabled && showOnHomeCard
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 15
                    width: parent.height * shiftLightSize
                    height: width
                    radius: width / 2

                    // Load shift light settings
                    property bool shiftLightEnabled: settingsManager ? settingsManager.get_setting_with_default("rpm_shift_light_enabled", true) : true
                    property bool showOnHomeCard: settingsManager ? settingsManager.get_setting_with_default("rpm_show_on_home_card", true) : true
                    property var flags: {
                        if (settingsManager) {
                            try {
                                var savedFlags = settingsManager.get_setting_with_default("rpm_flags", "[]")
                                return JSON.parse(savedFlags)
                            } catch(e) {
                                return []
                            }
                        }
                        return []
                    }

                    // Appearance settings
                    property real shiftLightSize: settingsManager ? settingsManager.get_setting_with_default("rpm_shift_light_size", 0.5) : 0.5
                    property real glowSize: settingsManager ? settingsManager.get_setting_with_default("rpm_glow_size", 0.6) : 0.6
                    property real glowIntensity: settingsManager ? settingsManager.get_setting_with_default("rpm_glow_intensity", 0.6) : 0.6
                    property int colorTransitionSpeed: settingsManager ? settingsManager.get_setting_with_default("rpm_color_transition_speed", 100) : 100
                    property bool pulseEnabled: settingsManager ? settingsManager.get_setting_with_default("rpm_pulse_enabled", false) : false

                    // Find the active flag based on current RPM value (range-based)
                    property var activeFlag: {
                        if (!flags || flags.length === 0) return null
                        // Find the flag whose range contains the current RPM
                        // Check from highest priority (last) to lowest (first)
                        var active = null
                        for (var i = flags.length - 1; i >= 0; i--) {
                            var flag = flags[i]
                            // Support both old format (rpm) and new format (rpmLow/rpmHigh)
                            var low = flag.rpmLow !== undefined ? flag.rpmLow : flag.rpm
                            var high = flag.rpmHigh !== undefined ? flag.rpmHigh : 99999
                            if (value >= low && value <= high) {
                                active = flag
                                break
                            }
                        }
                        return active
                    }

                    property bool isActive: activeFlag !== null

                    // Flash timer for flashing flags
                    property bool flashVisible: true
                    Timer {
                        id: flashTimer
                        interval: shiftLight.activeFlag ? shiftLight.activeFlag.flashSpeed : 100
                        running: shiftLight.activeFlag && shiftLight.activeFlag.flash
                        repeat: true
                        onTriggered: {
                            shiftLight.flashVisible = !shiftLight.flashVisible
                            // Update parent for full screen flash
                            homeOBDView.shiftLightFlashVisible = shiftLight.flashVisible
                        }
                    }

                    // Pulse animation timer
                    Timer {
                        id: pulseTimer
                        interval: 800
                        running: shiftLight.isActive && shiftLight.pulseEnabled && shiftLight.flashVisible
                        repeat: true
                        onTriggered: {
                            pulseAnimation.start()
                        }
                    }

                    SequentialAnimation {
                        id: pulseAnimation
                        PropertyAnimation {
                            target: shiftLight
                            property: "scale"
                            to: 1.15
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                        PropertyAnimation {
                            target: shiftLight
                            property: "scale"
                            to: 1.0
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // Reset flash visibility when flag changes or flash stops
                    onActiveFlagChanged: {
                        flashVisible = true
                        homeOBDView.shiftLightFlashVisible = true
                    }

                    // Update parent with active flag for full screen flash
                    onIsActiveChanged: {
                        if (isActive && shiftLightEnabled) {
                            homeOBDView.activeShiftFlag = activeFlag
                        } else {
                            homeOBDView.activeShiftFlag = null
                        }
                    }

                    // Clear active flag when shift light is disabled
                    onShiftLightEnabledChanged: {
                        if (!shiftLightEnabled) {
                            homeOBDView.activeShiftFlag = null
                        } else if (isActive) {
                            homeOBDView.activeShiftFlag = activeFlag
                        }
                    }

                    color: {
                        if (activeFlag) {
                            // If flashing and flash is off, show dark
                            if (activeFlag.flash && !flashVisible) {
                                return "#1a1a1a"
                            }
                            return activeFlag.color
                        }
                        return "#1a1a1a"  // Dark silhouette when off
                    }
                    border.color: isActive ? Qt.darker(color, 1.3) : "#333333"
                    border.width: 2

                    // Glow effect for shift light (only when active)
                    Rectangle {
                        id: shiftLightGlow
                        anchors.centerIn: parent
                        width: parent.width * shiftLight.glowSize
                        height: width
                        radius: width / 2
                        color: Qt.lighter(parent.color, 1.5)
                        opacity: shiftLight.glowIntensity
                        visible: shiftLight.isActive && shiftLight.flashVisible && shiftLight.glowSize > 0
                    }

                    Behavior on color { ColorAnimation { duration: shiftLight.colorTransitionSpeed } }

                    // Reload settings when they change
                    Connections {
                        target: settingsManager
                        function onGenericSettingChanged(key) {
                            // Only reload if RPM-related settings changed
                            if (key.startsWith("rpm_")) {
                                shiftLight.shiftLightEnabled = settingsManager.get_setting_with_default("rpm_shift_light_enabled", true)
                                shiftLight.showOnHomeCard = settingsManager.get_setting_with_default("rpm_show_on_home_card", true)
                                shiftLight.shiftLightSize = settingsManager.get_setting_with_default("rpm_shift_light_size", 0.5)
                                shiftLight.glowSize = settingsManager.get_setting_with_default("rpm_glow_size", 0.6)
                                shiftLight.glowIntensity = settingsManager.get_setting_with_default("rpm_glow_intensity", 0.6)
                                shiftLight.colorTransitionSpeed = settingsManager.get_setting_with_default("rpm_color_transition_speed", 100)
                                shiftLight.pulseEnabled = settingsManager.get_setting_with_default("rpm_pulse_enabled", false)
                                try {
                                    var savedFlags = settingsManager.get_setting_with_default("rpm_flags", "[]")
                                    shiftLight.flags = JSON.parse(savedFlags)
                                } catch(e) {
                                    shiftLight.flags = []
                                }
                                // Also reload full screen flash opacity at the view level
                                homeOBDView.fullScreenFlashOpacity = settingsManager.get_setting_with_default("rpm_fullscreen_flash_opacity", 0.5)
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5

                    Text {
                        text: info.title.toUpperCase()
                        font.pixelSize: App.Spacing.mainMenuOBDTextSize
                        font.family: homeOBDView.globalFont
                        color: App.Style.secondaryTextColor
                        Layout.alignment: Qt.AlignLeft
                    }

                    Text {
                        text: value.toFixed(1) + " " + info.unit
                        font.pixelSize: App.Spacing.mainMenuOBDDataSize
                        font.bold: true
                        font.family: homeOBDView.globalFont
                        color: App.Style.primaryTextColor
                        Layout.alignment: Qt.AlignLeft
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 8
                        color: App.Style.backgroundColor
                        radius: 4
                        Layout.topMargin: 2

                        Rectangle {
                            width: Math.max(4, parent.width * Math.min(1, (value - info.minValue) / (info.maxValue - info.minValue)))
                            height: parent.height
                            color: App.Style.accent
                            radius: 4
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }
        }
    }
    
    // Single connection to settings changes
    Connections {
        target: settingsManager
        function onHomeOBDParametersChanged() {
            // Force refresh of the repeater
            let currentParams = settingsManager.get_home_obd_parameters();
            
            // First set model to empty array to force re-creation of all delegates
            obdRepeater.model = [];
            
            // Then delay setting the new model to ensure clean refresh
            Qt.callLater(function() {
                obdRepeater.model = currentParams;
                
                // Wait for the repeater to create items, then refresh values
                refreshTimer.start();
            });
        }
    }
    
    // Refresh on component completion
    Component.onCompleted: {
        refreshOBDValues();
    }
}