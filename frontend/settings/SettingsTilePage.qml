import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Item {
    id: tilePage

    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }

    property var tileModel: []

    signal tileSelected(string cardId)

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: App.Spacing.settingsHubGridSpacing
        columnSpacing: App.Spacing.settingsHubGridSpacing
        rowSpacing: App.Spacing.settingsHubGridSpacing

        // Target tile width ~140dp; auto-fit columns to pane width.
        columns: Math.max(2, Math.floor(width / tilePage.dp(140)))

        Repeater {
            model: tilePage.tileModel

            SettingsTile {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(tilePage.dp(100),
                                                 Math.min(width * 1.0, tilePage.dp(160)))
                cardId: modelData && modelData.cardId !== undefined ? modelData.cardId : ""
                title: modelData && modelData.title !== undefined ? modelData.title : ""
                icon: modelData && modelData.icon !== undefined ? modelData.icon : ""
                statusColor: modelData && modelData.statusColor !== undefined
                    ? modelData.statusColor : "transparent"
                statusVisible: modelData && modelData.statusVisible === true
                onTileClicked: function(id) { tilePage.tileSelected(id) }
            }
        }
    }
}
