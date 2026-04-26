import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

// Lightweight category card — wraps a single setting (or tightly coupled group
// of controls) with a promoted header and subtle background. Lighter chrome
// than SettingsCard: no border, brackets, or glass effects.
Rectangle {
    id: cat

    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    default property alias categoryContent: contentLayout.data
    property string title: ""
    property string description: ""

    Layout.fillWidth: true
    color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.05)
    radius: dpMin(App.EnvironmentTheme.active.cardRadius, 2)
    implicitHeight: mainLayout.implicitHeight + App.Spacing.overallSpacing * 2

    ColumnLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: App.Spacing.overallSpacing
        }
        spacing: App.Spacing.rowSpacing

        // Promoted header — title + HUD accent line (matches SettingsSectionHeader)
        RowLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.overallSpacing
            visible: cat.title !== ""

            SettingLabel {
                text: cat.title
                font.pixelSize: App.Spacing.overallText * 1.5
                font.bold: true
                Layout.fillWidth: false
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.4)
                visible: App.EnvironmentTheme.active.sectionHeaderLines
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Description slot — sits directly under the title, above all content
        SettingDescription {
            text: cat.description
            visible: cat.description !== ""
            Layout.fillWidth: true
        }

        // Default content area
        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: App.Spacing.rowSpacing
        }
    }
}
