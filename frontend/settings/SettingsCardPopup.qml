import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: popup

    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }

    property string title: ""
    property var contentComponent: null
    // Inner-content opacity — driven by the hero morph so header/body fade in
    // as the popup expands out of the originating tile.
    property real contentOpacity: 1.0

    signal backRequested()

    color: App.Style.contentColor
    clip: true

    // HUD lines (spacecraft)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: App.Spacing.settingsContentMargin
        anchors.rightMargin: App.Spacing.settingsContentMargin
        height: 1
        z: 1
        opacity: popup.contentOpacity
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
        visible: App.EnvironmentTheme.active.contentHudLines
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: App.Spacing.settingsContentMargin
        anchors.rightMargin: App.Spacing.settingsContentMargin
        height: 1
        z: 1
        opacity: popup.contentOpacity
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
        visible: App.EnvironmentTheme.active.contentHudLines
    }

    // Header bar with back button — matches sidebar nav delegate sizing
    Item {
        id: header
        opacity: popup.contentOpacity
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: App.Spacing.settingsButtonHeight
        z: 2

        Row {
            anchors.left: parent.left
            anchors.leftMargin: App.Spacing.settingsContentMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: App.Spacing.overallSpacing * 0.5

            Text {
                text: "→"
                color: backArea.containsMouse ? App.Style.accent : App.Style.secondaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.6
                font.family: App.Style.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                text: popup.title
                color: backArea.containsMouse ? App.Style.accent : App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.6
                font.bold: true
                font.family: App.Style.fontFamily
                font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
                font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.backRequested()
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: App.Style.accent }
                GradientStop { position: 0.6; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Content body — scrollable for tall cards
    Flickable {
        id: bodyFlick
        opacity: popup.contentOpacity
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: App.Spacing.settingsContentMargin
            rightMargin: App.Spacing.settingsContentMargin
            bottomMargin: App.Spacing.settingsContentMargin
        }
        contentWidth: width
        contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
        flickableDirection: Flickable.VerticalFlick
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickDeceleration: 1200
        maximumFlickVelocity: 4000
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Loader {
            id: contentLoader
            width: bodyFlick.width
            height: item ? item.implicitHeight : 0
            sourceComponent: popup.contentComponent
        }
    }
}
