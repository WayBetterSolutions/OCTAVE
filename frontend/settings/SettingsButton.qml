import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: control

    property string text: ""
    property string tooltipText: ""
    property color buttonColor: App.Style.accent
    property bool bold: true
    signal clicked()

    Layout.preferredWidth: buttonLabel.implicitWidth + App.Spacing.overallSpacing * 1.5
    Layout.minimumWidth: 70
    color: buttonArea.pressed ? Qt.darker(control.buttonColor, 1.4) :
           buttonArea.containsMouse ? Qt.darker(control.buttonColor, 1.2) : control.buttonColor
    radius: 6
    border.width: 1
    border.color: Qt.darker(control.buttonColor, 1.3)
    clip: true

    Text {
        id: buttonLabel
        anchors.centerIn: parent
        text: control.text
        color: "white"
        font.pixelSize: App.Spacing.overallText
        font.bold: control.bold
        font.family: App.Style.fontFamily
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: control.clicked()
    }

    ToolTip.visible: buttonArea.containsMouse && control.tooltipText !== ""
    ToolTip.text: control.tooltipText
    ToolTip.delay: 300
}
