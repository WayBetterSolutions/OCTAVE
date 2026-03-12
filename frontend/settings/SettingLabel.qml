import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Text {
    color: App.Style.primaryTextColor
    font.pixelSize: App.Spacing.overallText
    font.family: App.Style.fontFamily
    font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
    Layout.fillWidth: true
}
