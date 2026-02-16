import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    FileDialog {
        id: scrcpyFileDialog
        title: "Select scrcpy executable"
        nameFilters: ["Executable files (*.exe)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///")) {
                path = path.substring(8)
            }
            path = path.replace(/\//g, "\\")

            scrcpyPathField.text = path
            if (settingsManager) {
                settingsManager.save_scrcpy_path(path)
                if (phoneMirrorManager) {
                    phoneMirrorManager.setScrcpyPath(path)
                }
            }
        }
    }

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // ── Android Auto ────────────────────────────────────────────
        SettingsCard {
            objectName: "Android Auto"

            SettingsSectionHeader { title: "Android Auto" }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: androidAutoEnabledToggle
                    Layout.fillWidth: true
                    text: "Show in nav bar"
                    checked: settingsManager ? settingsManager.androidAutoEnabled : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_android_auto_enabled(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onAndroidAutoEnabledChanged() {
                            androidAutoEnabledToggle.checked = settingsManager.androidAutoEnabled
                        }
                    }
                }

                SettingDescription {
                    text: "Requires Android Auto app and Developer Mode on your phone."
                }
            }
        }

        // ── Phone Mirror ────────────────────────────────────────────
        SettingsCard {
            objectName: "Phone Mirror"

            SettingsSectionHeader {
                title: "Phone Mirror"
                description: "Mirror your phone screen via scrcpy"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: phoneMirrorEnabledToggle
                    Layout.fillWidth: true
                    text: "Show in nav bar"
                    checked: settingsManager ? settingsManager.phoneMirrorEnabled : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_phone_mirror_enabled(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onPhoneMirrorEnabledChanged() {
                            phoneMirrorEnabledToggle.checked = settingsManager.phoneMirrorEnabled
                        }
                    }
                }

                SettingDescription {
                    text: "Requires scrcpy and USB debugging enabled."
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Scrcpy Path"
                }

                SettingDescription {
                    text: "Leave empty to auto-detect from PATH"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.dp(10)

                    SettingsTextField {
                        id: scrcpyPathField
                        Layout.fillWidth: true
                        text: settingsManager ? settingsManager.scrcpyPath : ""
                        placeholderText: "Auto-detect"

                        onEditingFinished: {
                            if (settingsManager) {
                                settingsManager.save_scrcpy_path(text)
                                if (phoneMirrorManager) {
                                    phoneMirrorManager.setScrcpyPath(text)
                                }
                            }
                        }
                    }

                    SettingsButton {
                        text: "Browse"
                        Layout.preferredHeight: scrcpyPathField.height
                        tooltipText: "Browse for scrcpy executable"
                        onClicked: scrcpyFileDialog.open()
                    }
                }

                Connections {
                    target: settingsManager
                    function onScrcpyPathChanged() {
                        scrcpyPathField.text = settingsManager.scrcpyPath
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Audio Forwarding"
                }

                SettingsToggle {
                    id: scrcpyAudioEnabledToggle
                    Layout.fillWidth: true
                    text: "Forward phone audio"
                    checked: settingsManager ? settingsManager.scrcpyAudioEnabled : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_scrcpy_audio_enabled(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onScrcpyAudioEnabledChanged() {
                            scrcpyAudioEnabledToggle.checked = settingsManager.scrcpyAudioEnabled
                        }
                    }
                }

                SettingDescription {
                    text: "Requires scrcpy 2.0+ and Android 11+"
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Status"
                }

                SettingDescription {
                    text: phoneMirrorManager && phoneMirrorManager.isScrcpyInstalled
                        ? "scrcpy found: " + phoneMirrorManager.scrcpyPath
                        : "scrcpy not found. Set the path above or download from github.com/Genymobile/scrcpy"
                    color: phoneMirrorManager && phoneMirrorManager.isScrcpyInstalled
                        ? App.Style.statusConnected
                        : App.Style.statusError
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
