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

        // Connection Status Row
        RowLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.overallSpacing

            Rectangle {
                id: esp32StatusDot
                width: 14
                height: 14
                radius: 7
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
                    radius: height / 2
                    color: refreshChipArea.containsMouse ? App.Style.hoverColor : "transparent"
                    border.width: 1
                    border.color: App.Style.hoverColor

                    Text {
                        id: refreshChipText
                        text: "⟳ Refresh"
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

                    Rectangle {
                        id: portChip
                        width: portChipContent.width + App.Spacing.overallSpacing * 3
                        height: App.Spacing.formElementHeight * 0.9
                        radius: height / 2

                        property bool isSelected: settingsManager && settingsManager.esp32VolumePort === modelData.port

                        color: isSelected ? App.Style.accent : App.Style.hoverColor
                        border.width: isSelected ? 0 : 1
                        border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                            App.Style.primaryTextColor.g,
                                            App.Style.primaryTextColor.b, 0.1)

                        scale: portChipArea.pressed ? 0.97 : (portChipArea.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        layer.enabled: isSelected
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 2
                            radius: 4.0
                            samples: 9
                            color: "#40000000"
                        }

                        Row {
                            id: portChipContent
                            anchors.centerIn: parent
                            spacing: 6

                            // Star indicator for ESP32-S3
                            Text {
                                visible: modelData.isEsp32S3
                                text: "★"
                                color: portChip.isSelected ? "white" : App.Style.accent
                                font.pixelSize: App.Spacing.overallText * 0.9
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.port
                                color: portChip.isSelected ? "white" : App.Style.primaryTextColor
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
                        }
                    }
                }

                // "No ports" message chip
                Rectangle {
                    visible: volumeKnobSettingsColumn.portsModel.length === 0
                    width: noPortsText.width + App.Spacing.overallSpacing * 3
                    height: App.Spacing.formElementHeight * 0.9
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(App.Style.primaryTextColor.r,
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
            Text {
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
                color: App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.overallText * 0.9
                font.family: App.Style.fontFamily
                Layout.fillWidth: true
                Layout.topMargin: 4
            }
        }

        SettingsDivider {}

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

                Text {
                    text: settingsManager ? settingsManager.esp32VolumeStepSize.toFixed(2) + "%" : "1.00%"
                    color: App.Style.accent
                    font.pixelSize: App.Spacing.overallText * 1.2
                    font.family: App.Style.fontFamily
                    font.bold: true
                }
            }

            SettingDescription {
                text: "Volume change per encoder tick"
            }

            // Slider
            Slider {
                id: volumeStepSlider
                Layout.fillWidth: true
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

                background: Rectangle {
                    x: volumeStepSlider.leftPadding
                    y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 6
                    width: volumeStepSlider.availableWidth
                    height: implicitHeight
                    radius: 3
                    color: App.Style.hoverColor

                    Rectangle {
                        width: volumeStepSlider.visualPosition * parent.width
                        height: parent.height
                        color: App.Style.accent
                        radius: 3
                    }
                }

                handle: Rectangle {
                    x: volumeStepSlider.leftPadding + volumeStepSlider.visualPosition * (volumeStepSlider.availableWidth - width)
                    y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 10
                    color: volumeStepSlider.pressed ? Qt.darker(App.Style.accent, 1.1) : App.Style.accent
                    border.color: "white"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            // Quick preset chips
            Flow {
                Layout.fillWidth: true
                spacing: App.Spacing.overallSpacing * 0.8

                Repeater {
                    model: [0.25, 0.5, 1.0, 2.0, 5.0]

                    Rectangle {
                        width: presetText.width + App.Spacing.overallSpacing * 2
                        height: App.Spacing.formElementHeight * 0.7
                        radius: height / 2

                        property bool isSelected: settingsManager && Math.abs(settingsManager.esp32VolumeStepSize - modelData) < 0.01

                        color: isSelected ? App.Style.accent : "transparent"
                        border.width: 1
                        border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                        scale: presetArea.pressed ? 0.95 : (presetArea.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            id: presetText
                            anchors.centerIn: parent
                            text: modelData + "%"
                            color: parent.isSelected ? "white" : App.Style.secondaryTextColor
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
                        }
                    }
                }
            }
        }

        SettingsDivider {}

        // LED Settings Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.rowSpacing

            SettingLabel {
                text: "LED Indicator"
                font.pixelSize: App.Spacing.overallText * 1.2
                font.bold: true
            }

            SettingDescription {
                text: "RGB LED indicator on the ESP32-S3 receiver"
            }
        }

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

                Rectangle {
                    width: themeModeContent.width + App.Spacing.overallSpacing * 3
                    height: App.Spacing.formElementHeight * 0.9
                    radius: height / 2

                    property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "theme"

                    color: isSelected ? App.Style.accent : "transparent"
                    border.width: 1
                    border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                    scale: themeModeArea.pressed ? 0.97 : (themeModeArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        id: themeModeContent
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "🎨"
                            font.pixelSize: App.Spacing.overallText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Theme Colors"
                            color: parent.parent.isSelected ? "white" : App.Style.primaryTextColor
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
                    }
                }

                Rectangle {
                    width: staticModeContent.width + App.Spacing.overallSpacing * 3
                    height: App.Spacing.formElementHeight * 0.9
                    radius: height / 2

                    property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "static"

                    color: isSelected ? App.Style.accent : "transparent"
                    border.width: 1
                    border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                    scale: staticModeArea.pressed ? 0.97 : (staticModeArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        id: staticModeContent
                        anchors.centerIn: parent
                        spacing: 6

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
                            color: parent.parent.isSelected ? "white" : App.Style.primaryTextColor
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
                    }
                }
            }
        }

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

                    Rectangle {
                        width: colorChipRow.width + App.Spacing.overallSpacing * 2
                        height: App.Spacing.formElementHeight * 0.8
                        radius: height / 2

                        property bool isSelected: settingsManager && settingsManager.esp32LedStaticColor.toUpperCase() === modelData.color

                        color: isSelected ? modelData.color : "transparent"
                        border.width: 2
                        border.color: modelData.color

                        scale: colorChipArea.pressed ? 0.95 : (colorChipArea.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            id: colorChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData.color
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.2)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.parent.isSelected
                            }

                            Text {
                                text: modelData.name
                                color: parent.parent.isSelected ?
                                       (modelData.color === "#FFFFFF" || modelData.color === "#FFFF00" || modelData.color === "#00FF00" ? "#000000" : "#FFFFFF") :
                                       App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.overallText * 0.9
                                font.family: App.Style.fontFamily
                                font.bold: parent.parent.isSelected
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
                    width: 32
                    height: 32
                    radius: 4
                    color: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                    border.width: 2
                    border.color: App.Style.hoverColor
                }

                TextField {
                    id: customColorField
                    Layout.preferredWidth: 100
                    text: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                    placeholderText: "#RRGGBB"
                    font.pixelSize: App.Spacing.overallText
                    font.family: App.Style.fontFamily

                    background: Rectangle {
                        color: App.Style.hoverColor
                        radius: 4
                        border.width: customColorField.activeFocus ? 2 : 0
                        border.color: App.Style.accent
                    }

                    color: App.Style.primaryTextColor

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

        SettingsDivider {}

        // Bottom spacer
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
