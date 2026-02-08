import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

TextField {
    id: control
    Layout.preferredHeight: App.Spacing.formElementHeight
    Layout.preferredWidth: 500
    Layout.maximumWidth: 800
    color: App.Style.primaryTextColor
    font.pixelSize: App.Spacing.overallText
    placeholderTextColor: App.Style.secondaryTextColor
    leftPadding: 20
    rightPadding: 20
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        color: App.Style.hoverColor
        radius: 4
        border.color: control.activeFocus ? App.Style.accent : "transparent"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        Behavior on border.color { ColorAnimation { duration: 200 } }
    }
}
