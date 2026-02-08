import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

ColumnLayout {
    Layout.fillWidth: true
    spacing: App.Spacing.rowSpacing

    property string title: ""
    property string description: ""

    SettingLabel {
        text: parent.title
        font.pixelSize: App.Spacing.overallText * 1.5
        font.bold: true
    }

    SettingDescription {
        text: parent.description
        visible: parent.description !== ""
    }
}
