import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        SettingsCard {
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
