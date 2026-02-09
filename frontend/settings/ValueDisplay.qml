import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Item {
    id: root
    property alias text: displayText.text
    property string displayValue: App.EnvironmentTheme.active.valueDisplayBrackets
        ? "[ " + displayText.text + " ]" : displayText.text

    Layout.topMargin: 2
    Layout.fillWidth: true
    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    // Hidden text to hold the raw value from callers
    Text {
        id: displayText
        visible: false
    }

    // Visible label with optional bracket wrapping
    Text {
        id: label
        text: root.displayValue
        color: App.EnvironmentTheme.active.valueAccentColor ? App.Style.accent : App.Style.secondaryTextColor
        font.pixelSize: App.Spacing.overallText
        font.family: App.Style.fontFamily
        font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
    }
}
