import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import ".." as App

Item {
    id: control
    height: 60
    Layout.preferredHeight: 60
    Layout.fillWidth: true

    property bool checked: false
    property string text: ""
    property color activeColor: App.Style.accent
    property color inactiveColor: App.Style.hoverColor
    signal toggled(bool checked)

    RowLayout {
        anchors.fill: parent
        spacing: App.Spacing.overallSpacing * 2

        Text {
            text: control.text
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText * 1.1
            font.family: App.Style.fontFamily
            Layout.preferredWidth: control.width * 0.55

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    control.checked = !control.checked
                    control.toggled(control.checked)
                }
            }
        }

        Item {
            width: 96
            height: 48

            Rectangle {
                id: track
                anchors.fill: parent
                radius: height / 2
                color: control.checked ? Qt.rgba(control.activeColor.r, control.activeColor.g, control.activeColor.b, 0.3) :
                                    Qt.rgba(control.inactiveColor.r, control.inactiveColor.g, control.inactiveColor.b, 0.3)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                    }
                }

                Rectangle {
                    id: highlightTrack
                    width: control.checked ? parent.width : 0
                    height: parent.height
                    radius: parent.radius
                    anchors.right: control.checked ? parent.right : undefined
                    anchors.left: !control.checked ? parent.left : undefined
                    color: control.activeColor
                    opacity: control.checked ? 0.5 : 0

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

            Rectangle {
                id: handle
                width: 48
                height: 48
                radius: width / 2
                x: control.checked ? parent.width - width : 0
                y: 0
                color: "white"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.4
                    height: width
                    radius: width / 2
                    color: control.activeColor
                    opacity: control.checked ? 1 : 0
                    scale: control.checked ? 1 : 0.5

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                }

                layer.enabled: true
                layer.effect: DropShadow {
                    verticalOffset: 2
                    radius: 6.0
                    samples: 17
                    color: Qt.rgba(0, 0, 0, 0.2)
                }

                scale: controlMouseArea.pressed ? 0.95 : 1.0

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.6
                    }
                }
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: controlMouseArea
                anchors.fill: parent
                onClicked: {
                    control.checked = !control.checked
                    control.toggled(control.checked)
                }

                onPressed: {
                    pulseAnimation.start()
                }

                SequentialAnimation {
                    id: pulseAnimation
                    PropertyAnimation {
                        target: handle
                        property: "scale"
                        to: 0.9
                        duration: 100
                    }
                    PropertyAnimation {
                        target: handle
                        property: "scale"
                        to: 1.0
                        duration: 100
                    }
                }
            }
        }
    }
}
