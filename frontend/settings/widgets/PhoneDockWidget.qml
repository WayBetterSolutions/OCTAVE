import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../.." as App
import ".."

Item {
    id: widgetRoot
    property int cardSpan: 1

    signal navigateToSubSection(string subSection)

    ColumnLayout {
        anchors.fill: parent
        spacing: App.Spacing.overallSpacing * 0.25

        SettingsToggle {
            compact: true
            text: "Android Auto"
            font.pixelSize: App.Spacing.overallText * 0.85
            checked: settingsManager ? settingsManager.androidAutoEnabled : false
            onToggled: {
                if (settingsManager)
                    settingsManager.save_android_auto_enabled(checked)
            }
        }

        SettingsToggle {
            compact: true
            text: "Phone Mirror"
            font.pixelSize: App.Spacing.overallText * 0.85
            checked: settingsManager ? settingsManager.phoneMirrorEnabled : false
            onToggled: {
                if (settingsManager)
                    settingsManager.save_phone_mirror_enabled(checked)
            }
        }

        SettingsToggle {
            compact: true
            text: "Audio Fwd"
            font.pixelSize: App.Spacing.overallText * 0.85
            checked: settingsManager ? settingsManager.scrcpyAudioEnabled : false
            onToggled: {
                if (settingsManager)
                    settingsManager.save_scrcpy_audio_enabled(checked)
            }
        }

        Item { Layout.fillHeight: true }

        // Sub-section chips
        Flow {
            Layout.fillWidth: true
            spacing: App.Spacing.overallSpacing * 0.3

            WidgetChip {
                text: "Android Auto"
                onClicked: widgetRoot.navigateToSubSection("Android Auto")
            }

            WidgetChip {
                text: "Phone Mirror"
                onClicked: widgetRoot.navigateToSubSection("Phone Mirror")
            }
        }
    }
}
