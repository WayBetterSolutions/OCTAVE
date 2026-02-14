import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: volumeKnobSettingsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: volumeKnobSettingsColumn
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // Port data model
        property var portsModel: []

        function refreshPorts() {
            if (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager) {
                try {
                    var jsonStr = esp32VolumeManager.get_ports_with_descriptions()
                    portsModel = JSON.parse(jsonStr)
                } catch (e) {
                    portsModel = []
                }
            }
        }

        Component.onCompleted: refreshPorts()

        // ── Card 1: Connection ──
        SettingsCard {
            SettingsSectionHeader { title: "Connection" }

            // Connection Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.overallSpacing

                Rectangle {
                    id: esp32StatusDot
                    width: App.Spacing.dp(14)
                    height: App.Spacing.dp(14)
                    radius: App.Spacing.dpMin(7, 2)
                    color: (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager && esp32VolumeManager.is_connected()) ? App.Style.statusConnected : App.Style.statusDisconnected

                    Connections {
                        target: typeof esp32VolumeManager !== "undefined" ? esp32VolumeManager : null
                        function onConnectionStatusChanged(status) {
                            esp32StatusDot.color = esp32VolumeManager.is_connected() ? App.Style.statusConnected : App.Style.statusDisconnected
                        }
                    }
                }

                Text {
                    id: esp32StatusText
                    text: (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager) ? esp32VolumeManager.get_connection_detail() : "Not initialized"
                    color: App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: App.Style.fontFamily
                    Layout.fillWidth: true

                    Connections {
                        target: typeof esp32VolumeManager !== "undefined" ? esp32VolumeManager : null
                        function onConnectionDetailChanged(detail) {
                            esp32StatusText.text = esp32VolumeManager.get_connection_detail()
                        }
                    }
                }
            }

            SettingsDivider {}

            // Serial Port Selection with chips
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingLabel {
                        text: "USB Serial Port"
                        Layout.fillWidth: true
                    }

                    // Refresh button chip
                    Rectangle {
                        width: refreshChipText.width + App.Spacing.overallSpacing * 2
                        height: App.Spacing.formElementHeight * 0.7
                        radius: App.EnvironmentTheme.active.chipRadius === -1
                            ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)
                        color: refreshChipArea.containsMouse ? App.Style.hoverColor : "transparent"
                        border.width: 1
                        border.color: App.EnvironmentTheme.active.chipAccentBorder
                            ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                            : App.Style.hoverColor

                        scale: refreshChipArea.pressed ? 0.97 : (refreshChipArea.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Text {
                            id: refreshChipText
                            text: "\u27F3 Refresh"
                            anchors.centerIn: parent
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.9
                            font.family: App.Style.fontFamily
                        }

                        MouseArea {
                            id: refreshChipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: volumeKnobSettingsColumn.refreshPorts()
                        }
                    }
                }

                // Port chips using Flow layout
                Flow {
                    id: portChipsFlow
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Repeater {
                        model: volumeKnobSettingsColumn.portsModel

                        Item {
                            id: portChipWrapper
                            width: portChipRect.width
                            height: portChipRect.height

                            property bool isSelected: settingsManager && settingsManager.esp32VolumePort === modelData.port

                            // Glow behind selected chip (spacecraft)
                            Rectangle {
                                anchors.centerIn: portChipRect
                                width: portChipRect.width + 4
                                height: portChipRect.height + 4
                                radius: portChipRect.radius + 2
                                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                visible: App.EnvironmentTheme.active.chipAccentBorder && portChipWrapper.isSelected
                            }

                            Rectangle {
                                id: portChipRect
                                width: portChipContent.width + App.Spacing.overallSpacing * 3
                                height: App.Spacing.formElementHeight * 0.9
                                radius: App.EnvironmentTheme.active.chipRadius === -1
                                    ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                                color: portChipWrapper.isSelected ? App.Style.accent : App.Style.hoverColor

                                border.width: App.EnvironmentTheme.active.chipAccentBorder
                                    ? 1
                                    : (portChipWrapper.isSelected ? 0 : 1)
                                border.color: App.EnvironmentTheme.active.chipAccentBorder
                                    ? (portChipWrapper.isSelected
                                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                        : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                                    : Qt.rgba(App.Style.primaryTextColor.r,
                                              App.Style.primaryTextColor.g,
                                              App.Style.primaryTextColor.b, 0.1)

                                Row {
                                    id: portChipContent
                                    anchors.centerIn: parent
                                    spacing: App.Spacing.dp(6)

                                    // Star indicator for ESP32-S3
                                    Text {
                                        visible: modelData.isEsp32S3
                                        text: "\u2605"
                                        color: portChipWrapper.isSelected ? "white" : App.Style.accent
                                        font.pixelSize: App.Spacing.overallText * 0.9
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.port
                                        color: portChipWrapper.isSelected ? "white" : App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: App.Style.fontFamily
                                        font.bold: modelData.isEsp32S3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: portChipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (settingsManager) {
                                            settingsManager.save_esp32_volume_port(modelData.port)
                                            // Auto-enable and connect when port selected
                                            if (!settingsManager.esp32VolumeEnabled) {
                                                settingsManager.save_esp32_volume_enabled(true)
                                            }
                                            if (esp32VolumeManager) {
                                                esp32VolumeManager.reset_reconnect_attempts()
                                                esp32VolumeManager.connect_device()
                                            }
                                        }
                                    }
                                    onEntered: portChipRect.scale = 1.03
                                    onExited: portChipRect.scale = 1.0
                                }

                                layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && portChipWrapper.isSelected
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }

                    // "No ports" message chip
                    Rectangle {
                        visible: volumeKnobSettingsColumn.portsModel.length === 0
                        width: noPortsText.width + App.Spacing.overallSpacing * 3
                        height: App.Spacing.formElementHeight * 0.9
                        radius: App.EnvironmentTheme.active.chipRadius === -1
                            ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)
                        color: "transparent"
                        border.width: 1
                        border.color: App.EnvironmentTheme.active.chipAccentBorder
                            ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                            : Qt.rgba(App.Style.primaryTextColor.r,
                                      App.Style.primaryTextColor.g,
                                      App.Style.primaryTextColor.b, 0.2)

                        Text {
                            id: noPortsText
                            text: "No ports found - click Refresh"
                            anchors.centerIn: parent
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: App.Style.fontFamily
                        }
                    }
                }

                // Port description (shown for selected port)
                SettingDescription {
                    visible: {
                        if (!settingsManager || !settingsManager.esp32VolumePort) return false
                        for (var i = 0; i < volumeKnobSettingsColumn.portsModel.length; i++) {
                            if (volumeKnobSettingsColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                return true
                            }
                        }
                        return false
                    }
                    text: {
                        if (!settingsManager || !settingsManager.esp32VolumePort) return ""
                        for (var i = 0; i < volumeKnobSettingsColumn.portsModel.length; i++) {
                            if (volumeKnobSettingsColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                return volumeKnobSettingsColumn.portsModel[i].description
                            }
                        }
                        return ""
                    }
                }
            }
        }

        // ── Card 2: Configuration ──
        SettingsCard {
            SettingsSectionHeader { title: "Configuration" }

            // Volume Step Size Slider
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                RowLayout {
                    Layout.fillWidth: true

                    SettingLabel {
                        text: "Volume Step Size"
                        Layout.fillWidth: true
                    }

                    ValueDisplay {
                        text: settingsManager ? settingsManager.esp32VolumeStepSize.toFixed(2) + "%" : "1.00%"
                    }
                }

                SettingDescription {
                    text: "Volume change per encoder tick"
                }

                // Slider
                SettingsSlider {
                    id: volumeStepSlider
                    from: 0.25
                    to: 10.0
                    stepSize: 0.25
                    value: settingsManager ? settingsManager.esp32VolumeStepSize : 1.0

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_esp32_volume_step_size(value)
                        }
                    }

                    // Update slider when setting changes externally
                    Connections {
                        target: settingsManager
                        function onEsp32VolumeStepSizeChanged(size) {
                            volumeStepSlider.value = size
                        }
                    }
                }

                // Quick preset chips
                Flow {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing * 0.8

                    Repeater {
                        model: [0.25, 0.5, 1.0, 2.0, 5.0]

                        Item {
                            id: presetChipWrapper
                            width: presetChipRect.width
                            height: presetChipRect.height

                            property bool isSelected: settingsManager && Math.abs(settingsManager.esp32VolumeStepSize - modelData) < 0.01

                            // Glow behind selected chip (spacecraft)
                            Rectangle {
                                anchors.centerIn: presetChipRect
                                width: presetChipRect.width + 4
                                height: presetChipRect.height + 4
                                radius: presetChipRect.radius + 2
                                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                visible: App.EnvironmentTheme.active.chipAccentBorder && presetChipWrapper.isSelected
                            }

                            Rectangle {
                                id: presetChipRect
                                width: presetText.width + App.Spacing.overallSpacing * 2
                                height: App.Spacing.formElementHeight * 0.7
                                radius: App.EnvironmentTheme.active.chipRadius === -1
                                    ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                                color: presetChipWrapper.isSelected ? App.Style.accent : App.Style.hoverColor

                                border.width: App.EnvironmentTheme.active.chipAccentBorder
                                    ? 1
                                    : (presetChipWrapper.isSelected ? 0 : 1)
                                border.color: App.EnvironmentTheme.active.chipAccentBorder
                                    ? (presetChipWrapper.isSelected
                                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                        : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                                    : Qt.rgba(App.Style.primaryTextColor.r,
                                              App.Style.primaryTextColor.g,
                                              App.Style.primaryTextColor.b, 0.1)

                                Text {
                                    id: presetText
                                    anchors.centerIn: parent
                                    text: modelData + "%"
                                    color: presetChipWrapper.isSelected ? "white" : App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText * 0.9
                                    font.family: App.Style.fontFamily
                                }

                                MouseArea {
                                    id: presetArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (settingsManager) {
                                            settingsManager.save_esp32_volume_step_size(modelData)
                                        }
                                    }
                                    onEntered: presetChipRect.scale = 1.05
                                    onExited: presetChipRect.scale = 1.0
                                }

                                layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && presetChipWrapper.isSelected
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Card 3: LED Indicator ──
        SettingsCard {
            SettingsSectionHeader { title: "LED Indicator"; description: "RGB LED indicator on the ESP32-S3 receiver" }

            // LED Keep Alive Toggle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: ledSleepToggle
                    Layout.fillWidth: true
                    text: "Keep LEDs on"
                    // Inverted: sleep enabled = keep alive OFF, sleep disabled = keep alive ON
                    checked: settingsManager ? !settingsManager.esp32LedSleepEnabled : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            // Inverted: switch ON = sleep disabled, switch OFF = sleep enabled
                            settingsManager.save_esp32_led_sleep_enabled(!checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onEsp32LedSleepEnabledChanged(enabled) {
                            // Inverted display
                            ledSleepToggle.checked = !enabled
                        }
                    }
                }

                SettingDescription {
                    text: "Stay on while OCTAVE runs (off = sleep after 5s idle)"
                }
            }

            SettingsDivider {}

            // LED Color Mode
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Color Mode"
                }

                SettingDescription {
                    text: "Album art accent colors or a fixed color"
                }

                // Color mode chips
                Flow {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Item {
                        id: themeModeChipWrapper
                        width: themeModeChipRect.width
                        height: themeModeChipRect.height

                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "theme"

                        // Glow behind selected chip (spacecraft)
                        Rectangle {
                            anchors.centerIn: themeModeChipRect
                            width: themeModeChipRect.width + 4
                            height: themeModeChipRect.height + 4
                            radius: themeModeChipRect.radius + 2
                            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                            visible: App.EnvironmentTheme.active.chipAccentBorder && themeModeChipWrapper.isSelected
                        }

                        Rectangle {
                            id: themeModeChipRect
                            width: themeModeContent.width + App.Spacing.overallSpacing * 3
                            height: App.Spacing.formElementHeight * 0.9
                            radius: App.EnvironmentTheme.active.chipRadius === -1
                                ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                            color: themeModeChipWrapper.isSelected ? App.Style.accent : App.Style.hoverColor

                            border.width: App.EnvironmentTheme.active.chipAccentBorder
                                ? 1
                                : (themeModeChipWrapper.isSelected ? 0 : 1)
                            border.color: App.EnvironmentTheme.active.chipAccentBorder
                                ? (themeModeChipWrapper.isSelected
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                    : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                                : Qt.rgba(App.Style.primaryTextColor.r,
                                          App.Style.primaryTextColor.g,
                                          App.Style.primaryTextColor.b, 0.1)

                            Row {
                                id: themeModeContent
                                anchors.centerIn: parent
                                spacing: App.Spacing.dp(6)

                                Text {
                                    text: "\uD83C\uDFA8"
                                    font.pixelSize: App.Spacing.overallText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Theme Colors"
                                    color: themeModeChipWrapper.isSelected ? "white" : App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: App.Style.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: themeModeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (settingsManager) {
                                        settingsManager.save_esp32_led_color_mode("theme")
                                    }
                                }
                                onEntered: themeModeChipRect.scale = 1.03
                                onExited: themeModeChipRect.scale = 1.0
                            }

                            layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && themeModeChipWrapper.isSelected
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 2
                                radius: 4.0
                                samples: 9
                                color: Qt.rgba(0, 0, 0, 0.2)
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Item {
                        id: staticModeChipWrapper
                        width: staticModeChipRect.width
                        height: staticModeChipRect.height

                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "static"

                        // Glow behind selected chip (spacecraft)
                        Rectangle {
                            anchors.centerIn: staticModeChipRect
                            width: staticModeChipRect.width + 4
                            height: staticModeChipRect.height + 4
                            radius: staticModeChipRect.radius + 2
                            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                            visible: App.EnvironmentTheme.active.chipAccentBorder && staticModeChipWrapper.isSelected
                        }

                        Rectangle {
                            id: staticModeChipRect
                            width: staticModeContent.width + App.Spacing.overallSpacing * 3
                            height: App.Spacing.formElementHeight * 0.9
                            radius: App.EnvironmentTheme.active.chipRadius === -1
                                ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                            color: staticModeChipWrapper.isSelected ? App.Style.accent : App.Style.hoverColor

                            border.width: App.EnvironmentTheme.active.chipAccentBorder
                                ? 1
                                : (staticModeChipWrapper.isSelected ? 0 : 1)
                            border.color: App.EnvironmentTheme.active.chipAccentBorder
                                ? (staticModeChipWrapper.isSelected
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                    : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                                : Qt.rgba(App.Style.primaryTextColor.r,
                                          App.Style.primaryTextColor.g,
                                          App.Style.primaryTextColor.b, 0.1)

                            Row {
                                id: staticModeContent
                                anchors.centerIn: parent
                                spacing: App.Spacing.dp(6)

                                Rectangle {
                                    width: App.Spacing.overallText
                                    height: App.Spacing.overallText
                                    radius: width / 2
                                    color: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.3)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Static Color"
                                    color: staticModeChipWrapper.isSelected ? "white" : App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: App.Style.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: staticModeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (settingsManager) {
                                        settingsManager.save_esp32_led_color_mode("static")
                                    }
                                }
                                onEntered: staticModeChipRect.scale = 1.03
                                onExited: staticModeChipRect.scale = 1.0
                            }

                            layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && staticModeChipWrapper.isSelected
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 2
                                radius: 4.0
                                samples: 9
                                color: Qt.rgba(0, 0, 0, 0.2)
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }

            SettingsDivider {}

            // Static Color Picker (only shown when static mode is selected)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.esp32LedColorMode === "static"

                SettingLabel {
                    text: "Static Color"
                }

                // Color preset chips
                Flow {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing * 0.8

                    Repeater {
                        model: [
                            { color: "#00FFFF", name: "Cyan" },
                            { color: "#FF0080", name: "Pink" },
                            { color: "#00FF00", name: "Green" },
                            { color: "#FF8000", name: "Orange" },
                            { color: "#8000FF", name: "Purple" },
                            { color: "#FFFF00", name: "Yellow" },
                            { color: "#0080FF", name: "Blue" },
                            { color: "#FF0000", name: "Red" },
                            { color: "#FFFFFF", name: "White" }
                        ]

                        Item {
                            id: colorChipWrapper
                            width: colorChipRect.width
                            height: colorChipRect.height

                            property bool isSelected: settingsManager && settingsManager.esp32LedStaticColor.toUpperCase() === modelData.color

                            // Glow behind selected chip
                            Rectangle {
                                anchors.centerIn: colorChipRect
                                width: colorChipRect.width + 4
                                height: colorChipRect.height + 4
                                radius: colorChipRect.radius + 2
                                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                visible: App.EnvironmentTheme.active.chipAccentBorder && colorChipWrapper.isSelected
                            }

                            Rectangle {
                                id: colorChipRect
                                width: colorChipRow.width + App.Spacing.overallSpacing * 2
                                height: App.Spacing.formElementHeight * 0.8
                                radius: App.EnvironmentTheme.active.chipRadius === -1
                                    ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                                color: colorChipWrapper.isSelected ? modelData.color : App.Style.hoverColor
                                border.width: App.EnvironmentTheme.active.chipAccentBorder ? 1 : 2
                                border.color: App.EnvironmentTheme.active.chipAccentBorder
                                    ? (colorChipWrapper.isSelected
                                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                        : modelData.color)
                                    : modelData.color

                                Row {
                                    id: colorChipRow
                                    anchors.centerIn: parent
                                    spacing: App.Spacing.dp(6)

                                    Rectangle {
                                        width: App.Spacing.dp(12)
                                        height: App.Spacing.dp(12)
                                        radius: App.Spacing.dpMin(6, 2)
                                        color: modelData.color
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !colorChipWrapper.isSelected
                                    }

                                    Text {
                                        text: modelData.name
                                        color: colorChipWrapper.isSelected ?
                                               (modelData.color === "#FFFFFF" || modelData.color === "#FFFF00" || modelData.color === "#00FF00" ? "#000000" : "#FFFFFF") :
                                               App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText * 0.9
                                        font.family: App.Style.fontFamily
                                        font.bold: colorChipWrapper.isSelected
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: colorChipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (settingsManager) {
                                            settingsManager.save_esp32_led_static_color(modelData.color)
                                        }
                                    }
                                    onEntered: colorChipRect.scale = 1.05
                                    onExited: colorChipRect.scale = 1.0
                                }

                                layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && colorChipWrapper.isSelected
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }

                // Custom color input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Text {
                        text: "Custom:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                    }

                    Rectangle {
                        width: App.Spacing.dp(32)
                        height: App.Spacing.dp(32)
                        radius: App.Spacing.dpMin(App.EnvironmentTheme.active.textFieldRadius, 2)
                        color: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                        border.width: 2
                        border.color: App.Style.hoverColor
                    }

                    SettingsTextField {
                        id: customColorField
                        Layout.preferredWidth: App.Spacing.dp(120)
                        text: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                        placeholderText: "#RRGGBB"

                        onEditingFinished: {
                            if (settingsManager && /^#[0-9A-Fa-f]{6}$/.test(text)) {
                                settingsManager.save_esp32_led_static_color(text.toUpperCase())
                            }
                        }

                        Connections {
                            target: settingsManager
                            function onEsp32LedStaticColorChanged(color) {
                                customColorField.text = color
                            }
                        }
                    }
                }
            }
        }

        // Bottom spacer
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
