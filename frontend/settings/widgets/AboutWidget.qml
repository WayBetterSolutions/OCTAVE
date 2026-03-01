import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../.." as App
import ".."

Item {
    id: widgetRoot
    property int cardSpan: 1

    ColumnLayout {
        anchors.fill: parent
        spacing: App.Spacing.overallSpacing * 0.3

        Text {
            text: settingsManager ? settingsManager.get_git_commit_hash() : "unknown"
            color: App.Style.accent
            font.pixelSize: App.Spacing.overallText * 0.85
            font.bold: true
            font.family: App.Style.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        WidgetPill {
            label: "Status"
            value: {
                if (!networkManager) return "Unknown"
                switch (networkManager.updateStatus) {
                    case "checking": return "Checking..."
                    case "update-available": return "Update available"
                    case "up-to-date": return "Up to date"
                    case "error": return "Check failed"
                    default: return "Not checked"
                }
            }
            statusColor: {
                if (!networkManager) return "transparent"
                switch (networkManager.updateStatus) {
                    case "update-available": return App.Style.statusWarning
                    case "up-to-date": return App.Style.statusConnected
                    case "error": return App.Style.statusDisconnected
                    default: return "transparent"
                }
            }
        }

        SettingsButton {
            text: networkManager && networkManager.updateStatus === "checking" ? "Checking..." : "Check Updates"
            height: App.Spacing.dp(26)
            enabled: !networkManager || networkManager.updateStatus !== "checking"
            opacity: enabled ? 1.0 : 0.6
            onClicked: {
                if (networkManager)
                    networkManager.checkForUpdates()
            }
        }

        Item { Layout.fillHeight: true }
    }
}
