import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

ScrollView {
    contentWidth: parent.width
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
    clip: true

    required property var mainWindow

    ColumnLayout {
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        SettingsCard {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Device Name"
                }

                SettingsTextField {
                    id: deviceName
                    Layout.fillWidth: true
                    text: settingsManager ? settingsManager.deviceName : ""

                    onEditingFinished: {
                        if (text.trim() !== "" && settingsManager) {
                            mainWindow.updateDeviceName(text)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
