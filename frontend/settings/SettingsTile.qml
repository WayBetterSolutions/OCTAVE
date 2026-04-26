import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App

Rectangle {
    id: tile

    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    property string cardId: ""
    property string title: ""
    property string icon: ""
    property color statusColor: "transparent"
    property bool statusVisible: false

    signal tileClicked(string cardId)

    color: tileMouse.pressed
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.18)
        : tileMouse.containsMouse
            ? Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.10)
            : Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.05)
    radius: dpMin(App.EnvironmentTheme.active.cardRadius, 2)

    border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
    border.color: App.EnvironmentTheme.active.accentBorder
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                  App.EnvironmentTheme.active.accentBorderOpacity) : "transparent"

    scale: tileMouse.pressed ? 0.97 : 1.0

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    // Top-edge accent highlight (spacecraft)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: dp(App.EnvironmentTheme.active.cardRadius)
        anchors.rightMargin: dp(App.EnvironmentTheme.active.cardRadius)
        height: 1
        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
        visible: App.EnvironmentTheme.active.accentBorder && !App.EnvironmentTheme.active.cardGlassEffect
    }

    App.CornerBrackets {
        bracketLength: dp(10)
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: tile.dp(10)
        spacing: tile.dp(6)

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: tile.dp(28)

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: App.Style.accent
                font.pixelSize: Math.max(tile.dp(20), parent.height * 0.55)
                font.family: App.Style.fontFamily
            }
        }

        Text {
            Layout.fillWidth: true
            text: tile.title
            color: App.Style.primaryTextColor
            font.pixelSize: App.Spacing.overallText * 0.95
            font.family: App.Style.fontFamily
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
            font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
        }
    }

    // Status dot
    Rectangle {
        visible: tile.statusVisible
        width: tile.dp(10)
        height: tile.dp(10)
        radius: width / 2
        color: tile.statusColor
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: tile.dp(8)
        anchors.rightMargin: tile.dp(8)
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.tileClicked(tile.cardId)
    }
}
