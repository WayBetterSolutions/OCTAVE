import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: gestureSettingsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
        id: gestureSettingsColumn
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // ── Card 1: Connection ────────────────────────────────────────
        SettingsCard {
            SettingsSectionHeader { title: "Connection" }

            // Connection Status Row
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

            // Enable/Disable Toggle
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

        // ── Card 2: Settings ──────────────────────────────────────────
        SettingsCard {
            SettingsSectionHeader { title: "Settings" }

            // Volume Step Size
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
                    id: volumeStepSlider
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
                            volumeStepSlider.value = step
                        }
                    }

                    background: Rectangle {
                        x: volumeStepSlider.leftPadding
                        y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                        implicitWidth: App.Spacing.dp(200)
                        implicitHeight: App.Spacing.dp(6)
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
                        implicitWidth: App.Spacing.dp(20)
                        implicitHeight: App.Spacing.dp(20)
                        radius: App.Spacing.dpMin(10, 2)
                        color: volumeStepSlider.pressed ? Qt.darker(App.Style.accent, 1.1) : App.Style.accent
                        border.color: "white"
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: 100 } }
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

            // Gesture Cooldown
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

        // ── Card 3: Gesture Mapping ───────────────────────────────────
        SettingsCard {
            SettingsCollapsibleSection {
                title: "Gesture Mapping"

                SettingDescription {
                    text: "Choose which action each gesture triggers"
                }

                // Gesture mapping rows
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

                                    // Glow behind selected chip (spacecraft)
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

                // Reset to Defaults Button
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
        }

        // Bottom spacer
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
