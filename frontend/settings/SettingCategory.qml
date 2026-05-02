import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

// Lightweight category card — wraps a single setting (or tightly coupled group
// of controls) with a promoted header and subtle background. Lighter chrome
// than SettingsCard: no border, brackets, or glass effects.
//
// Two content slots:
//   • categoryContent (default) — stacks vertically below the header (e.g. chips,
//     subcategories, multi-row inputs)
//   • inlineContent — sits on the right side of the title row (e.g. a single
//     toggle, or slider + value display) to keep the card condensed
Rectangle {
    id: cat

    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    default property alias categoryContent: contentLayout.data
    property alias inlineContent: inlineLayout.data
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

        // Title + flex spacer (or accent line) + inline controls — single row.
        // The flex element absorbs all slack so inline controls land on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: App.Spacing.overallSpacing
            visible: cat.title !== "" || inlineLayout.children.length > 0

            SettingLabel {
                text: cat.title
                font.pixelSize: App.Spacing.overallText * 1.5
                font.bold: true
                Layout.fillWidth: false
                visible: cat.title !== ""
            }

            // Flex element — visible accent line when no inline controls, otherwise
            // a transparent spacer that pushes the inline controls to the right edge.
            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 1
                color: inlineLayout.children.length > 0
                    ? "transparent"
                    : Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.4)
                visible: cat.title !== "" && (inlineLayout.children.length > 0
                    || App.EnvironmentTheme.active.sectionHeaderLines)
            }

            RowLayout {
                id: inlineLayout
                Layout.alignment: Qt.AlignVCenter
                spacing: App.Spacing.overallSpacing
            }
        }

        SettingDescription {
            text: cat.description
            visible: cat.description !== ""
            Layout.fillWidth: true
        }

        // Default stacked content (used when categoryContent has children)
        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: App.Spacing.rowSpacing
        }
    }
}
