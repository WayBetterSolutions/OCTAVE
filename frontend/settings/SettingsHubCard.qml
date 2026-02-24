import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".." as App
import "ScrollMemory.js" as ScrollMemory

Rectangle {
    id: hubCard

    property string categoryName: ""
    property string section: ""
    property string categoryIcon: ""
    property string groupName: ""
    property string pageSource: ""
    property bool isCenter: false

    // Passed through from SettingsMenu so loaded pages can access them
    property var settingsMenu: null

    color: "transparent"
    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.cardRadius, 2)
    clip: true

    // Accent border (spacecraft)
    border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
    border.color: App.EnvironmentTheme.active.accentBorder
        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                  App.EnvironmentTheme.active.accentBorderOpacity) : "transparent"

    // Card background — elevated surface
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: {
            var base = App.Style.contentColor
            return Qt.rgba(base.r, base.g, base.b, 0.92)
        }
    }

    // Subtle white lift
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.05)
    }

    // Frosted highlight gradient
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top edge highlight line
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    App.CornerBrackets {
        visible: App.EnvironmentTheme.active.cornerBrackets
    }

    // Bottom accent line
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: App.Style.accent }
            GradientStop { position: 0.7; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: 0.6
    }


    // ─── Card content: settings page fills entire card ───
    Item {
        id: cardContent
        anchors.fill: parent
        anchors.leftMargin: App.Spacing.overallSpacing * 0.3
        anchors.rightMargin: App.Spacing.overallSpacing * 0.3
        anchors.topMargin: App.Spacing.dp(2)
        anchors.bottomMargin: App.Spacing.dp(2)

        Loader {
            id: pageLoader
            anchors.fill: parent
            source: hubCard.pageSource ? ("../" + hubCard.pageSource) : ""
            active: hubCard.isCenter

            onLoaded: {
                if (item) {
                    if (typeof item.mainWindow !== "undefined")
                        item.mainWindow = hubCard.settingsMenu ? hubCard.settingsMenu.mainWindow : null
                    if (typeof item.stackView !== "undefined")
                        item.stackView = hubCard.settingsMenu ? hubCard.settingsMenu.stackView : null
                    if (typeof item.currentSection !== "undefined")
                        item.currentSection = Qt.binding(function() { return hubCard.section })
                }

                // Restore saved scroll position
                if (hubCard.section !== "") {
                    var savedY = ScrollMemory.positions[hubCard.section]
                    if (item && typeof item.contentY !== "undefined" && savedY !== undefined && savedY > 0) {
                        scrollRestoreTimer.savedY = savedY
                        scrollRestoreTimer.restart()
                    }
                }
            }
        }

        // Polls until the Flickable has valid dimensions, then restores scroll
        Timer {
            id: scrollRestoreTimer
            interval: 16
            repeat: true
            property real savedY: -1
            onTriggered: {
                var fl = pageLoader.item
                if (fl && fl.contentHeight > 0 && fl.height > 0 && savedY >= 0) {
                    fl.contentY = Math.min(savedY, Math.max(0, fl.contentHeight - fl.height))
                    savedY = -1
                    stop()
                }
            }
        }

        // Save scroll position continuously as the user scrolls
        Connections {
            target: pageLoader.item
            function onContentYChanged() {
                if (pageLoader.item && hubCard.section !== "")
                    ScrollMemory.positions[hubCard.section] = pageLoader.item.contentY
            }
        }
    }

}
