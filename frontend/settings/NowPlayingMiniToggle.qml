import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

// Standard horizontal toggle row: label on the LEFT, toggle on the RIGHT.
// Keeps every setting in the Now Playing studio aligned to the same x —
// labels stack down a column on the left, controls stack down a column on
// the right, so scanning is a pure vertical eye-track.
RowLayout {
    id: root
    function dp(s) { return Math.round(s * (App.Spacing.effectiveScale || 1.0)) }

    property string label: ""
    property bool checked: false
    signal toggled(bool checked)

    Layout.fillWidth: true
    spacing: root.dp(8)

    Label {
        text: root.label
        color: App.Style.primaryTextColor
        font.pixelSize: App.Spacing.overallText
        font.family: App.Style.fontFamily
        font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    SettingsToggle {
        id: tog
        compact: true
        // Fix the toggle's outer width so the inner switch indicator lands
        // at the same x in every row regardless of whether the label reads
        // "On" (narrow) or "Off" (wide). Sized to comfortably fit "Off" at
        // any reasonable UI scale without clipping the trailing 'f'.
        Layout.preferredWidth: root.dp(104)
        Layout.minimumWidth: root.dp(104)
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        text: checked ? "On" : "Off"
        checked: root.checked
        activeColor: App.Style.accent
        inactiveColor: App.Style.hoverColor
        onToggled: function(c) { root.toggled(c) }
    }

    onCheckedChanged: tog.checked = root.checked
}
