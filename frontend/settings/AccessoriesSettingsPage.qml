import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: accessoriesColumn.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    // Gesture action model
    property var actionOptions: ["next_track", "previous_track", "volume_up", "volume_down", "play_pause", "mute_toggle", "none"]
    property var actionLabels: {
        "next_track": "Next Track",
        "previous_track": "Previous Track",
        "volume_up": "Volume Up",
        "volume_down": "Volume Down",
        "play_pause": "Play / Pause",
        "mute_toggle": "Mute Toggle",
        "none": "Disabled"
    }
    property var gestureNames: ["RIGHT", "LEFT", "UP", "DOWN", "FORWARD", "BACKWARD", "CLOCKWISE", "COUNTER-CLOCKWISE", "WAVE"]

    ColumnLayout {
        id: accessoriesColumn
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // Port data model for Volume Knob
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

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // VOLUME KNOB
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Connection ──
        SettingsCard {
            objectName: "Volume Knob"
            cardId: "accessories_volume_knob"
            title: "Volume Knob"

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
                            onClicked: accessoriesColumn.refreshPorts()
                        }
                    }
                }

                // Port chips using Flow layout
                Flow {
                    id: portChipsFlow
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Repeater {
                        model: accessoriesColumn.portsModel

                        Item {
                            id: portChipWrapper
                            width: portChipRect.width
                            height: portChipRect.height

                            property bool isSelected: settingsManager && settingsManager.esp32VolumePort === modelData.port

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
                        visible: accessoriesColumn.portsModel.length === 0
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

                SettingDescription {
                    visible: {
                        if (!settingsManager || !settingsManager.esp32VolumePort) return false
                        for (var i = 0; i < accessoriesColumn.portsModel.length; i++) {
                            if (accessoriesColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                return true
                            }
                        }
                        return false
                    }
                    text: {
                        if (!settingsManager || !settingsManager.esp32VolumePort) return ""
                        for (var i = 0; i < accessoriesColumn.portsModel.length; i++) {
                            if (accessoriesColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                return accessoriesColumn.portsModel[i].description
                            }
                        }
                        return ""
                    }
                }
            }
        }

        // ── Configuration ──
        SettingsCard {
            objectName: "Configuration"
            cardId: "accessories_configuration"
            title: "Configuration"

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

                SettingsSlider {
                    id: vkVolumeStepSlider
                    from: 0.25
                    to: 10.0
                    stepSize: 0.25
                    value: settingsManager ? settingsManager.esp32VolumeStepSize : 1.0

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_esp32_volume_step_size(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onEsp32VolumeStepSizeChanged(size) {
                            vkVolumeStepSlider.value = size
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

        // ── LED Indicator ──
        SettingsCard {
            objectName: "LED Indicator"
            cardId: "accessories_led_indicator"
            title: "LED Indicator"
            description: "RGB LED indicator on the ESP32-S3 receiver"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: ledSleepToggle
                    Layout.fillWidth: true
                    text: "Keep LEDs on"
                    checked: settingsManager ? !settingsManager.esp32LedSleepEnabled : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_esp32_led_sleep_enabled(!checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onEsp32LedSleepEnabledChanged(enabled) {
                            ledSleepToggle.checked = !enabled
                        }
                    }
                }

                SettingDescription {
                    text: "Stay on while OCTAVE runs (off = sleep after 5s idle)"
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Color Mode"
                }

                SettingDescription {
                    text: "Album art accent colors or a fixed color"
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Item {
                        id: themeModeChipWrapper
                        width: themeModeChipRect.width
                        height: themeModeChipRect.height
                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "theme"

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
                                    text: "\u2728"
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
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Item {
                        id: staticModeChipWrapper
                        width: staticModeChipRect.width
                        height: staticModeChipRect.height
                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "static"

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
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            SettingsDivider {}

            // Static Color Picker
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.esp32LedColorMode === "static"

                SettingLabel {
                    text: "Static Color"
                }

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
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }

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

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // IMU SENSOR
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        SettingsCard {
            objectName: "IMU Sensor"
            cardId: "accessories_imu_sensor"
            title: "IMU Sensor"

            RowLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.overallSpacing

                Rectangle {
                    id: imuStatusDot
                    width: App.Spacing.dp(14)
                    height: App.Spacing.dp(14)
                    radius: App.Spacing.dpMin(7, 2)

                    property string currentStatus: (typeof berryIMU !== "undefined" && berryIMU) ? berryIMU.getConnectionStatus() : "Disconnected"
                    color: currentStatus === "Connected" ? App.Style.statusConnected : App.Style.statusDisconnected

                    Connections {
                        target: typeof berryIMU !== "undefined" ? berryIMU : null
                        function onConnectionStatusChanged(status) {
                            imuStatusDot.currentStatus = status
                            imuStatusDot.color = (status === "Connected") ? App.Style.statusConnected : App.Style.statusDisconnected
                            imuStatusText.text = status
                        }
                    }
                }

                Text {
                    id: imuStatusText
                    text: imuStatusDot.currentStatus
                    color: App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: App.Style.fontFamily
                    Layout.fillWidth: true
                }
            }

            SettingsDivider {}

            SettingsToggle {
                id: imuEnabledToggle
                Layout.fillWidth: true
                text: "IMU Sensor"
                checked: settingsManager ? settingsManager.imuEnabled : true
                activeColor: App.Style.accent
                inactiveColor: App.Style.hoverColor

                onToggled: function(checked) {
                    if (settingsManager) {
                        settingsManager.save_imu_enabled(checked)
                    }
                    if (typeof berryIMU !== "undefined" && berryIMU) {
                        berryIMU.setEnabled(checked)
                    }
                }

                Connections {
                    target: settingsManager
                    function onImuEnabledChanged(enabled) {
                        imuEnabledToggle.checked = enabled
                    }
                }
            }

            SettingDescription {
                text: "BerryIMU v3 accelerometer, gyroscope, magnetometer, and barometer on I2C bus 2"
            }
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // GESTURE SENSOR
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Connection + Enable ──
        SettingsCard {
            objectName: "Gesture Sensor"
            cardId: "accessories_gesture_sensor"
            title: "Gesture Sensor"

            RowLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.overallSpacing

                Rectangle {
                    id: gestureStatusDot
                    width: App.Spacing.dp(14)
                    height: App.Spacing.dp(14)
                    radius: App.Spacing.dpMin(7, 2)

                    property string currentStatus: (typeof gestureSensor !== "undefined" && gestureSensor) ? gestureSensor.getConnectionStatus() : "Disconnected"
                    color: currentStatus === "Connected" ? App.Style.statusConnected : App.Style.statusDisconnected

                    Connections {
                        target: typeof gestureSensor !== "undefined" ? gestureSensor : null
                        function onConnectionStatusChanged(status) {
                            gestureStatusDot.currentStatus = status
                            gestureStatusDot.color = (status === "Connected") ? App.Style.statusConnected : App.Style.statusDisconnected
                            gestureStatusText.text = status
                        }
                    }
                }

                Text {
                    id: gestureStatusText
                    text: gestureStatusDot.currentStatus
                    color: App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: App.Style.fontFamily
                    Layout.fillWidth: true
                }
            }

            SettingsDivider {}

            SettingsToggle {
                id: gestureEnabledToggle
                Layout.fillWidth: true
                text: "Gesture Sensor"
                checked: settingsManager ? settingsManager.gestureSensorEnabled : true
                activeColor: App.Style.accent
                inactiveColor: App.Style.hoverColor

                onToggled: function(checked) {
                    if (settingsManager) {
                        settingsManager.save_gesture_sensor_enabled(checked)
                    }
                    if (typeof gestureSensor !== "undefined" && gestureSensor) {
                        gestureSensor.setEnabled(checked)
                    }
                }

                Connections {
                    target: settingsManager
                    function onGestureSensorEnabledChanged(enabled) {
                        gestureEnabledToggle.checked = enabled
                    }
                }
            }

            SettingDescription {
                text: "PAJ7620U2 infrared gesture recognition on I2C bus 2"
            }
        }

        // ── Gesture Settings ──
        SettingsCard {
            objectName: "Gesture Settings"
            cardId: "accessories_gesture_settings"
            title: "Gesture Settings"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                RowLayout {
                    Layout.fillWidth: true

                    SettingLabel {
                        text: "Volume Step"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: settingsManager ? settingsManager.gestureVolumeStep + "%" : "5%"
                        color: App.Style.accent
                        font.pixelSize: App.Spacing.overallText * 1.2
                        font.family: App.Style.fontFamily
                        font.bold: true
                    }
                }

                SettingDescription {
                    text: "Volume change per gesture (up/down)"
                }

                Slider {
                    id: gsVolumeStepSlider
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    stepSize: 1
                    value: settingsManager ? settingsManager.gestureVolumeStep : 5

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_gesture_volume_step(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onGestureVolumeStepChanged(step) {
                            gsVolumeStepSlider.value = step
                        }
                    }

                    background: Rectangle {
                        x: gsVolumeStepSlider.leftPadding
                        y: gsVolumeStepSlider.topPadding + gsVolumeStepSlider.availableHeight / 2 - height / 2
                        implicitWidth: App.Spacing.dp(200)
                        implicitHeight: App.Spacing.dp(6)
                        width: gsVolumeStepSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: App.Style.hoverColor

                        Rectangle {
                            width: gsVolumeStepSlider.visualPosition * parent.width
                            height: parent.height
                            color: App.Style.accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: gsVolumeStepSlider.leftPadding + gsVolumeStepSlider.visualPosition * (gsVolumeStepSlider.availableWidth - width)
                        y: gsVolumeStepSlider.topPadding + gsVolumeStepSlider.availableHeight / 2 - height / 2
                        implicitWidth: App.Spacing.dp(20)
                        implicitHeight: App.Spacing.dp(20)
                        radius: App.Spacing.dpMin(10, 2)
                        color: gsVolumeStepSlider.pressed ? Qt.darker(App.Style.accent, 1.1) : App.Style.accent
                        border.color: "white"
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        onPressed: function(mouse) {
                            var hx = gsVolumeStepSlider.leftPadding + gsVolumeStepSlider.visualPosition * (gsVolumeStepSlider.availableWidth - gsVolumeStepSlider.handle.width)
                            var hy = gsVolumeStepSlider.topPadding + gsVolumeStepSlider.availableHeight / 2 - gsVolumeStepSlider.handle.height / 2
                            if (mouse.x >= hx && mouse.x <= hx + gsVolumeStepSlider.handle.width &&
                                mouse.y >= hy && mouse.y <= hy + gsVolumeStepSlider.handle.height) {
                                mouse.accepted = false
                            } else {
                                mouse.accepted = true
                            }
                        }
                    }
                }

                SettingsChips {
                    options: ["1%", "2%", "5%", "10%", "15%", "25%", "50%"]
                    currentValue: settingsManager ? settingsManager.gestureVolumeStep + "%" : "5%"
                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_gesture_volume_step(parseInt(value))
                        }
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                RowLayout {
                    Layout.fillWidth: true

                    SettingLabel {
                        text: "Gesture Cooldown"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: settingsManager ? settingsManager.gestureCooldown + " ms" : "300 ms"
                        color: App.Style.accent
                        font.pixelSize: App.Spacing.overallText * 1.2
                        font.family: App.Style.fontFamily
                        font.bold: true
                    }
                }

                SettingDescription {
                    text: "Minimum time between consecutive gestures"
                }

                Slider {
                    id: cooldownSlider
                    Layout.fillWidth: true
                    from: 100
                    to: 2000
                    stepSize: 50
                    value: settingsManager ? settingsManager.gestureCooldown : 300

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_gesture_cooldown(value)
                        }
                        if (typeof gestureSensor !== "undefined" && gestureSensor) {
                            gestureSensor.setCooldown(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onGestureCooldownChanged(ms) {
                            cooldownSlider.value = ms
                        }
                    }

                    background: Rectangle {
                        x: cooldownSlider.leftPadding
                        y: cooldownSlider.topPadding + cooldownSlider.availableHeight / 2 - height / 2
                        implicitWidth: App.Spacing.dp(200)
                        implicitHeight: App.Spacing.dp(6)
                        width: cooldownSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: App.Style.hoverColor

                        Rectangle {
                            width: cooldownSlider.visualPosition * parent.width
                            height: parent.height
                            color: App.Style.accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: cooldownSlider.leftPadding + cooldownSlider.visualPosition * (cooldownSlider.availableWidth - width)
                        y: cooldownSlider.topPadding + cooldownSlider.availableHeight / 2 - height / 2
                        implicitWidth: App.Spacing.dp(20)
                        implicitHeight: App.Spacing.dp(20)
                        radius: App.Spacing.dpMin(10, 2)
                        color: cooldownSlider.pressed ? Qt.darker(App.Style.accent, 1.1) : App.Style.accent
                        border.color: "white"
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        onPressed: function(mouse) {
                            var hx = cooldownSlider.leftPadding + cooldownSlider.visualPosition * (cooldownSlider.availableWidth - cooldownSlider.handle.width)
                            var hy = cooldownSlider.topPadding + cooldownSlider.availableHeight / 2 - cooldownSlider.handle.height / 2
                            if (mouse.x >= hx && mouse.x <= hx + cooldownSlider.handle.width &&
                                mouse.y >= hy && mouse.y <= hy + cooldownSlider.handle.height) {
                                mouse.accepted = false
                            } else {
                                mouse.accepted = true
                            }
                        }
                    }
                }

                SettingsChips {
                    options: ["100ms", "200ms", "300ms", "500ms", "1000ms"]
                    currentValue: settingsManager ? settingsManager.gestureCooldown + "ms" : "300ms"
                    onSelected: function(value) {
                        var ms = parseInt(value)
                        if (settingsManager) {
                            settingsManager.save_gesture_cooldown(ms)
                        }
                        if (typeof gestureSensor !== "undefined" && gestureSensor) {
                            gestureSensor.setCooldown(ms)
                        }
                    }
                }
            }
        }

        // ── Gesture Mapping ──
        SettingsCard {
            objectName: "Gesture Mapping"
            cardId: "accessories_gesture_mapping"
            title: "Gesture Mapping"

                SettingDescription {
                    text: "Choose which action each gesture triggers"
                }

                Repeater {
                    model: gestureNames

                    ColumnLayout {
                        id: gestureRow
                        Layout.fillWidth: true
                        spacing: App.Spacing.rowSpacing

                        required property string modelData
                        property string gestureName: modelData

                        property string currentAction: {
                            if (typeof gestureSensor !== "undefined" && gestureSensor) {
                                return gestureSensor.getGestureAction(gestureName)
                            }
                            return "none"
                        }

                        Connections {
                            target: settingsManager
                            function onGestureMappingChanged() {
                                if (typeof gestureSensor !== "undefined" && gestureSensor) {
                                    gestureRow.currentAction = gestureSensor.getGestureAction(gestureRow.gestureName)
                                }
                            }
                        }

                        SettingLabel {
                            text: gestureRow.gestureName
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: App.Spacing.overallSpacing

                            Repeater {
                                model: actionOptions

                                Item {
                                    id: actionChipWrapper
                                    width: actionChipRect.width
                                    height: actionChipRect.height

                                    property string actionKey: modelData
                                    property bool isSelected: gestureRow.currentAction === actionKey

                                    Rectangle {
                                        anchors.centerIn: actionChipRect
                                        width: actionChipRect.width + App.Spacing.dp(4)
                                        height: actionChipRect.height + App.Spacing.dp(4)
                                        radius: actionChipRect.radius + 2
                                        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                        visible: App.EnvironmentTheme.active.chipAccentBorder && actionChipWrapper.isSelected
                                    }

                                    Rectangle {
                                        id: actionChipRect
                                        width: actionChipText.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight * 0.8
                                        radius: App.EnvironmentTheme.active.chipRadius === -1
                                            ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                                        color: actionChipWrapper.isSelected ? App.Style.accent : App.Style.hoverColor

                                        border.width: App.EnvironmentTheme.active.chipAccentBorder
                                            ? 1
                                            : (actionChipWrapper.isSelected ? 0 : 1)
                                        border.color: App.EnvironmentTheme.active.chipAccentBorder
                                            ? (actionChipWrapper.isSelected
                                                ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.8)
                                                : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3))
                                            : Qt.rgba(App.Style.primaryTextColor.r,
                                                      App.Style.primaryTextColor.g,
                                                      App.Style.primaryTextColor.b, 0.1)

                                        Text {
                                            id: actionChipText
                                            anchors.centerIn: parent
                                            text: actionLabels[actionChipWrapper.actionKey] || actionChipWrapper.actionKey
                                            color: actionChipWrapper.isSelected ? "white" : App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.family: App.Style.fontFamily
                                        }

                                        MouseArea {
                                            id: actionChipArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (typeof gestureSensor !== "undefined" && gestureSensor) {
                                                    gestureSensor.setGestureAction(gestureRow.gestureName, actionChipWrapper.actionKey)
                                                }
                                            }
                                            onEntered: actionChipRect.scale = 1.05
                                            onExited: actionChipRect.scale = 1.0
                                        }

                                        layer.enabled: !App.EnvironmentTheme.active.chipAccentBorder && actionChipWrapper.isSelected
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

                SettingsDivider {}

                Rectangle {
                    width: resetContent.width + App.Spacing.overallSpacing * 3
                    height: App.Spacing.formElementHeight * 0.9
                    radius: App.EnvironmentTheme.active.chipRadius === -1
                        ? height / 2 : App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius, 2)

                    color: resetArea.containsMouse ? App.Style.hoverColor : "transparent"

                    border.width: 1
                    border.color: App.EnvironmentTheme.active.chipAccentBorder
                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                        : App.Style.hoverColor

                    scale: resetArea.pressed ? 0.97 : (resetArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Row {
                        id: resetContent
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(6)

                        Text {
                            text: "Reset to Defaults"
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: App.Style.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (typeof gestureSensor !== "undefined" && gestureSensor) {
                                gestureSensor.resetMappingToDefaults()
                            }
                            if (settingsManager) {
                                settingsManager.reset_gesture_mapping()
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
