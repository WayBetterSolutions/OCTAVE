import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    default property alias cardContent: cardLayout.data

    Layout.fillWidth: true
    color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.15)
    radius: 12
    implicitHeight: cardLayout.implicitHeight + App.Spacing.overallSpacing * 3

    ColumnLayout {
        id: cardLayout
        anchors {
            fill: parent
            margins: App.Spacing.overallSpacing * 1.5
        }
        spacing: App.Spacing.rowSpacing
    }
}
