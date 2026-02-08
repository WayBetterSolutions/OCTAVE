import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Item {
    id: control
    height: 44
    implicitHeight: 44
    Layout.fillWidth: true

    property bool checked: false
    property string text: ""
    signal toggled(bool checked)

    RowLayout {
        anchors.fill: parent
        spacing: App.Spacing.overallSpacing * 1.5

        Rectangle {
            id: checkboxRect
            width: 30
            height: 30
            radius: 4
            color: control.checked ? App.Style.accent : "transparent"
            border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
            border.width: 2

            Text {
                visible: control.checked
                text: "✓"
                font.pixelSize: 22
                color: "white"
                anchors.centerIn: parent
                font.family: App.Style.fontFamily
            }

            Rectangle {
                anchors.fill: parent
                color: "white"
                radius: 4
                opacity: checkboxArea.containsMouse ? 0.1 : 0
            }
        }

        Text {
            text: control.text
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: App.Style.fontFamily
        }
    }

    MouseArea {
        id: checkboxArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            control.checked = !control.checked
            control.toggled(control.checked)
        }
    }
}
