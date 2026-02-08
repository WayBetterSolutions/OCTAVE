import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.1)
    Layout.topMargin: App.Spacing.overallSpacing
    Layout.bottomMargin: App.Spacing.overallSpacing
}
