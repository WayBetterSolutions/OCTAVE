import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Button {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: control
    Layout.preferredHeight: App.Spacing.formElementHeight
    Layout.preferredWidth: dp(300)
    Layout.maximumWidth: dp(400)
    Layout.minimumWidth: dp(250)
    Layout.fillWidth: true
    property string displayText: ""
    property var options: []
    property var onSelected: function(value) {}

    contentItem: Item {
        anchors.fill: parent

        Text {
            id: labelText
            text: control.displayText
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText
            font.family: App.Style.fontFamily
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter

            anchors {
                left: parent.left
                leftMargin: dp(20)
                right: arrowText.left
                rightMargin: dp(15)
                verticalCenter: parent.verticalCenter
            }
        }

        Text {
            id: arrowText
            text: "▼"
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText * 0.8
            font.family: App.Style.fontFamily
            verticalAlignment: Text.AlignVCenter

            anchors {
                right: parent.right
                rightMargin: dp(20)
                verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        color: control.pressed ? Qt.darker(App.Style.hoverColor, 1.2) :
               control.hovered ? Qt.darker(App.Style.hoverColor, 1.1) : App.Style.hoverColor
        radius: dpMin(App.EnvironmentTheme.active.dropdownRadius, 2)

        // Accent border (spacecraft)
        border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
        border.color: App.EnvironmentTheme.active.accentBorder
            ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                      control.hovered ? 0.7 : 0.4)
            : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        }

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    property var dropdownPopup: Popup {
        id: popup
        width: control.width
        y: control.height
        height: Math.min(contentItem.implicitHeight, dp(300))

        background: Rectangle {
            color: App.Style.backgroundColor
            border.color: App.Style.accent
            border.width: 1
            radius: dpMin(App.EnvironmentTheme.active.dropdownRadius, 2)
        }

        contentItem: ListView {
            id: optionsList
            implicitHeight: contentHeight
            model: control.options
            clip: true

            delegate: ItemDelegate {
                required property int index
                required property var modelData

                width: parent.width
                height: dp(45)

                contentItem: Text {
                    text: modelData
                    color: App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: App.Style.fontFamily
                    leftPadding: dp(20)
                    rightPadding: dp(20)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    color: parent.hovered ? App.Style.hoverColor : "transparent"
                }

                onClicked: {
                    control.onSelected(modelData)
                    popup.close()
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 0
                active: true
                interactive: true
                opacity: 0.2
            }
        }
    }

    onClicked: {
        dropdownPopup.opened ? dropdownPopup.close() : dropdownPopup.open()
    }
}
