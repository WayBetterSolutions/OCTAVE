import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

ColumnLayout {
    Layout.fillWidth: true
    spacing: App.Spacing.rowSpacing

    property string title: ""
    property string description: ""

    // Title row with optional HUD accent line
    RowLayout {
        Layout.fillWidth: true
        spacing: App.Spacing.overallSpacing

        SettingLabel {
            text: parent.parent.title
            font.pixelSize: App.Spacing.overallText * 1.5
            font.bold: true
            Layout.fillWidth: false
        }

        // HUD accent line extending from title to right edge (spacecraft only)
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.4)
            visible: App.EnvironmentTheme.active.sectionHeaderLines
            Layout.alignment: Qt.AlignVCenter
        }
    }

    SettingDescription {
        text: parent.description
        visible: parent.description !== ""
    }
}
