import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

ScrollView {
    contentWidth: parent.width
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
    clip: true

    ColumnLayout {
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        SettingsCard {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    text: "Show clock"
                    Layout.fillWidth: true
                    checked: settingsManager ? settingsManager.showClock : true

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_clock(checked)
                        }
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Time Format"
                }

                SettingsSegmentedControl {
                    id: timeFormatControl
                    Layout.fillWidth: true
                    options: ["24-hour", "12-hour (AM/PM)"]
                    currentValue: settingsManager ?
                                (settingsManager.clockFormat24Hour ? "24-hour" : "12-hour (AM/PM)") :
                                "24-hour"

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_clock_format(value === "24-hour")
                        }
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Clock Size"
                }

                SettingsSlider {
                    id: clockSizeSlider
                    from: 10
                    to: 85
                    stepSize: 1
                    value: settingsManager ? settingsManager.clockSize : 18

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_clock_size(value)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    ValueDisplay {
                        text: clockSizeSlider.value.toFixed(0) + " pixels"
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
