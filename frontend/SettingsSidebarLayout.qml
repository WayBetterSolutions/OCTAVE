import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings"
import "settings/ScrollMemory.js" as ScrollMemory

Item {
    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    id: sidebarLayout

    // Required from orchestrator
    property var settingsMenu: null
    property var hubModel: []

    // Look up the QML source for a given section
    function sourceForSection(section) {
        if (!settingsMenu) return ""
        for (var i = 0; i < settingsMenu.pageModel.length; i++) {
            if (settingsMenu.pageModel[i].section === section)
                return settingsMenu.pageModel[i].source
        }
        return settingsMenu.pageModel[0].source
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle { // Left Navigation Panel
            id: sidebarPanel
            Layout.preferredWidth: App.Spacing.settingsNavWidth
            Layout.fillHeight: true
            color: App.Style.sidebarColor

            // Sidebar lighting gradient (subtle overhead light simulation)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.04) }
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.06) }
                }
            }

            // Lit edge highlight along the top
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Soft shadow on the right edge
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.right
                }
                width: 10
                z: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                    GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: App.Spacing.settingsNavMargin
                }
                spacing: 0

                ListView {
                    id: navListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    interactive: true
                    clip: true

                    model: hubModel.length

                    delegate: Item {
                        id: delegateRoot
                        property var entry: hubModel[index] || {}
                        property string itemSection: entry.section || ""
                        property string itemName: entry.name || ""

                        width: navListView.width
                        height: App.Spacing.settingsButtonHeight

                        // Elevation shadow - outer
                        Rectangle {
                            x: navBackground.x - 2
                            y: navBackground.y + 4
                            width: navBackground.width + 4
                            height: navBackground.height + 2
                            radius: navBackground.radius + 3
                            color: Qt.rgba(0, 0, 0, 0.06)
                            opacity: settingsMenu && settingsMenu.currentSection === parent.itemSection ? 1.0
                                : (navMouseArea.containsMouse ? 0.6 : 0)

                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Elevation shadow - inner
                        Rectangle {
                            x: navBackground.x - 1
                            y: navBackground.y + 2
                            width: navBackground.width + 2
                            height: navBackground.height + 1
                            radius: navBackground.radius + 1
                            color: Qt.rgba(0, 0, 0, 0.12)
                            opacity: settingsMenu && settingsMenu.currentSection === parent.itemSection
                                ? (navMouseArea.pressed ? 0.4 : 1.0)
                                : (navMouseArea.containsMouse ? 0.5 : 0)

                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Background - rounded selection
                        Rectangle {
                            id: navBackground
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                                leftMargin: 8
                                rightMargin: 8
                                topMargin: 3
                                bottomMargin: 3
                            }
                            radius: App.EnvironmentTheme.active.navItemRadius
                            color: settingsMenu && settingsMenu.currentSection === parent.itemSection
                                ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                : "transparent"
                            scale: navMouseArea.pressed ? 0.97 : 1.0

                            // Accent border (spacecraft)
                            border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
                            border.color: settingsMenu && settingsMenu.currentSection === delegateRoot.itemSection
                                ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                                : (navMouseArea.containsMouse
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                                    : "transparent")

                            // Top lit edge on selected/hovered item
                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: 2
                                    rightMargin: 2
                                }
                                height: 1
                                radius: 0.5
                                color: Qt.rgba(255, 255, 255, 0.1)
                                opacity: settingsMenu && settingsMenu.currentSection === delegateRoot.entry.section ? 1.0
                                    : (navMouseArea.containsMouse ? 0.5 : 0)

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                        }

                        // Pulsing glow behind accent bar (spacecraft)
                        Rectangle {
                            anchors.centerIn: accentBar
                            width: accentBar.width + 6
                            height: accentBar.height + 6
                            radius: accentBar.radius + 3
                            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, accentBarPulse)
                            visible: App.EnvironmentTheme.active.pulsingElements && settingsMenu && settingsMenu.currentSection === parent.itemSection

                            property real accentBarPulse: 0.15
                            SequentialAnimation on accentBarPulse {
                                running: App.EnvironmentTheme.active.pulsingElements && settingsMenu && settingsMenu.currentSection === delegateRoot.entry.section
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 1500; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.15; duration: 1500; easing.type: Easing.InOutSine }
                            }
                        }

                        // Left accent bar for selected item
                        Rectangle {
                            id: accentBar
                            anchors {
                                left: parent.left
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                            width: App.EnvironmentTheme.active.navAccentBarWidth
                            height: settingsMenu && settingsMenu.currentSection === parent.itemSection
                                ? (App.EnvironmentTheme.active.navAccentBarFullHeight
                                    ? parent.height * 0.8 : parent.height * 0.5)
                                : 0
                            radius: App.EnvironmentTheme.active.navAccentBarWidth / 2
                            color: App.Style.accent

                            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        }

                        // Hover effect - rounded
                        Rectangle {
                            id: navHoverRectangle
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                                leftMargin: 8
                                rightMargin: 8
                                topMargin: 3
                                bottomMargin: 3
                            }
                            radius: App.EnvironmentTheme.active.navItemRadius
                            color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)
                            opacity: 0

                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Text
                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 24
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            text: parent.itemName
                            color: settingsMenu && settingsMenu.currentSection === parent.itemSection ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 1.6
                            font.bold: settingsMenu && settingsMenu.currentSection === parent.itemSection
                            font.family: App.Style.fontFamily
                            elide: Text.ElideRight
                        }

                        // Update notification dot
                        Rectangle {
                            width: dp(7)
                            height: dp(7)
                            radius: width / 2
                            color: "#FF9800"
                            z: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: delegateRoot.itemSection === "about"
                                     && settingsMenu && settingsMenu.updateAvailable

                            SequentialAnimation on opacity {
                                running: delegateRoot.itemSection === "about"
                                         && settingsMenu && settingsMenu.updateAvailable
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.3; duration: 1200 }
                                NumberAnimation { from: 0.3; to: 1.0; duration: 1200 }
                            }
                        }

                        // Entire area clickable
                        MouseArea {
                            id: navMouseArea
                            anchors.fill: parent
                            onClicked: {
                                // Save scroll position of current page before switching
                                if (contentLoader.item && typeof contentLoader.item.contentY !== "undefined" && settingsMenu) {
                                    ScrollMemory.positions[settingsMenu.currentSection] = contentLoader.item.contentY
                                }

                                if (settingsMenu) {
                                    settingsMenu.currentSection = parent.itemSection
                                    if (settingsManager)
                                        settingsManager.set_last_settings_section(parent.itemSection)
                                }
                            }
                            hoverEnabled: true

                            onEntered: {
                                if (settingsMenu && settingsMenu.currentSection !== delegateRoot.itemSection) {
                                    navHoverRectangle.opacity = 1
                                }
                            }
                            onExited: {
                                navHoverRectangle.opacity = 0
                            }
                        }
                    }
                }
            }
        }

        Rectangle { // Right Content Area
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: App.Style.contentColor

            // HUD lines (spacecraft)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: App.Spacing.settingsContentMargin
                anchors.rightMargin: App.Spacing.settingsContentMargin
                height: 1
                z: 1
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
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                visible: App.EnvironmentTheme.active.contentHudLines
            }

            ContentSonar {}
            ContentSolarSystem {}

            Loader {
                id: contentLoader
                anchors {
                    fill: parent
                    margins: App.Spacing.settingsContentMargin
                }
                source: settingsMenu ? sourceForSection(settingsMenu.currentSection) : ""

                // Track previous section for scroll save
                property string previousSection: ""

                onSourceChanged: {
                    // Save scroll position of previous page
                    if (previousSection && item && typeof item.contentY !== "undefined") {
                        ScrollMemory.positions[previousSection] = item.contentY
                    }
                    previousSection = settingsMenu ? settingsMenu.currentSection : ""
                }

                onLoaded: {
                    // Bind optional properties if the page declares them
                    if (item && typeof item.mainWindow !== "undefined" && settingsMenu)
                        item.mainWindow = settingsMenu.mainWindow
                    if (item && typeof item.stackView !== "undefined" && settingsMenu)
                        item.stackView = settingsMenu.stackView
                    if (item && typeof item.currentSection !== "undefined" && settingsMenu)
                        item.currentSection = Qt.binding(function() { return settingsMenu ? settingsMenu.currentSection : "" })

                    // Restore scroll position (use timer to wait for content to layout)
                    if (settingsMenu && settingsMenu.currentSection !== "") {
                        var savedY = ScrollMemory.positions[settingsMenu.currentSection]
                        if (item && typeof item.contentY !== "undefined" && savedY !== undefined && savedY > 0) {
                            scrollRestoreTimer.savedY = savedY
                            scrollRestoreTimer.restart()
                        }
                    }
                }

                // Save scroll position continuously as user scrolls
                Connections {
                    target: contentLoader.item
                    function onContentYChanged() {
                        if (contentLoader.item && settingsMenu && settingsMenu.currentSection !== "")
                            ScrollMemory.positions[settingsMenu.currentSection] = contentLoader.item.contentY
                    }
                }

                // Polls until the Flickable has valid dimensions, then restores scroll
                Timer {
                    id: scrollRestoreTimer
                    interval: 16
                    repeat: true
                    property real savedY: -1
                    onTriggered: {
                        var fl = contentLoader.item
                        if (fl && fl.contentHeight > 0 && fl.height > 0 && savedY >= 0) {
                            fl.contentY = Math.min(savedY, Math.max(0, fl.contentHeight - fl.height))
                            savedY = -1
                            stop()
                        }
                    }
                }
            }
        }
    }
}
