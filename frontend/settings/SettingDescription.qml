import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Text {
    color: App.Style.secondaryTextColor
    font.pixelSize: App.Spacing.overallText * 0.8
    font.family: App.Style.fontFamily
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
}
