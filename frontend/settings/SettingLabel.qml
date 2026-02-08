import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Label {
    color: App.Style.primaryTextColor
    font.pixelSize: App.Spacing.overallText
    font.family: App.Style.fontFamily
    Layout.fillWidth: true
}
