import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings"

Item {
    id: settingsMenu
    objectName: "settingsMenu"
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: initialSection

    // Central page model — single source of truth for all pages
    readonly property var pageModel: [
        { name: "Device",         section: "deviceSettings",         source: "settings/DeviceSettingsPage.qml" },
        { name: "Media",          section: "mediaSettings",          source: "settings/MediaSettingsPage.qml" },
        { name: "Display",        section: "displaySettings",        source: "settings/DisplaySettingsPage.qml" },
        { name: "OBD",            section: "obdSettings",            source: "settings/OBDSettingsPage.qml" },
        { name: "Android Auto",   section: "androidAutoSettings",    source: "settings/AndroidAutoSettingsPage.qml" },
        { name: "Phone Mirror",   section: "phoneMirrorSettings",    source: "settings/PhoneMirrorSettingsPage.qml" },
        { name: "Volume Knob",    section: "volumeKnobSettings",     source: "settings/VolumeKnobSettingsPage.qml" },
        { name: "Gesture Sensor", section: "gestureSensorSettings",  source: "settings/GestureSensorSettingsPage.qml" },
        { name: "About",          section: "about",                  source: "settings/AboutPage.qml" }
    ]

    // Derived section order for fallback when current section is hidden
    readonly property var sectionOrder: {
        var order = []
        for (var i = 0; i < pageModel.length; i++)
            order.push(pageModel[i].section)
        return order
    }

    // Scroll memory — stores contentY per section (ephemeral, not persisted)
    property var scrollPositions: ({})

    // Sidebar model: flat list of visible pages
    property var sidebarModel: []

    Component.onCompleted: buildSidebarModel()

    // Look up the QML source for a given section
    function sourceForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i].source
        }
        return pageModel[0].source
    }

    // Look up page info by section
    function pageForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i]
        }
        return null
    }

    // Build the sidebar model from pageModel, respecting visibility
    function buildSidebarModel() {
        var model = []
        for (var i = 0; i < pageModel.length; i++) {
            var page = pageModel[i]
            var visible = settingsManager ? settingsManager.is_settings_section_visible(page.section) : true
            if (visible)
                model.push({ name: page.name, section: page.section })
        }
        sidebarModel = model
    }

    // When a section's visibility changes, rebuild sidebar and check if we need to switch away
    Connections {
        target: settingsManager
        function onSettingsMenuVisibilityChanged() {
            buildSidebarModel()
            if (settingsManager && !settingsManager.is_settings_section_visible(currentSection)) {
                for (var i = 0; i < sectionOrder.length; i++) {
                    if (settingsManager.is_settings_section_visible(sectionOrder[i])) {
                        currentSection = sectionOrder[i]
                        if (settingsManager) {
                            settingsManager.set_last_settings_section(sectionOrder[i])
                        }
                        return
                    }
                }
            }
        }
    }

    // Save scroll position before section change
    onCurrentSectionChanged: {
        // Save previous page's scroll position
        if (contentLoader.item && typeof contentLoader.item.contentY !== "undefined") {
            var copy = ({})
            for (var key in scrollPositions) copy[key] = scrollPositions[key]
            // We don't know the "previous" section here easily, so we save on Loader swap instead
            scrollPositions = copy
        }
    }

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

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

                SidebarDotGrid {}
                SidebarBubbles {}

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

                // Soft shadow on the right edge (replaces hard separator)
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

                        model: sidebarModel.length

                        delegate: Item {
                            id: delegateRoot
                            property var entry: sidebarModel[index] || {}
                            property string itemSection: entry.section || ""
                            property string itemName: entry.name || ""

                            width: navListView.width
                            height: App.Spacing.settingsButtonHeight

                                // Elevation shadow - outer (soft, wide spread)
                                Rectangle {
                                    x: navBackground.x - 2
                                    y: navBackground.y + 4
                                    width: navBackground.width + 4
                                    height: navBackground.height + 2
                                    radius: navBackground.radius + 3
                                    color: Qt.rgba(0, 0, 0, 0.06)
                                    opacity: currentSection === parent.itemSection ? 1.0
                                        : (navMouseArea.containsMouse ? 0.6 : 0)

                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                // Elevation shadow - inner (sharper, tighter)
                                Rectangle {
                                    x: navBackground.x - 1
                                    y: navBackground.y + 2
                                    width: navBackground.width + 2
                                    height: navBackground.height + 1
                                    radius: navBackground.radius + 1
                                    color: Qt.rgba(0, 0, 0, 0.12)
                                    opacity: currentSection === parent.itemSection
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
                                    color: currentSection === parent.itemSection
                                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                        : "transparent"
                                    scale: navMouseArea.pressed ? 0.97 : 1.0

                                    // Accent border (spacecraft)
                                    border.width: App.EnvironmentTheme.active.accentBorder ? 1 : 0
                                    border.color: currentSection === delegateRoot.itemSection
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
                                        opacity: currentSection === delegateRoot.entry.section ? 1.0
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
                                    visible: App.EnvironmentTheme.active.pulsingElements && currentSection === parent.itemSection

                                    property real accentBarPulse: 0.15
                                    SequentialAnimation on accentBarPulse {
                                        running: App.EnvironmentTheme.active.pulsingElements && currentSection === delegateRoot.entry.section
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
                                    height: currentSection === parent.itemSection
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
                                    color: currentSection === parent.itemSection ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                                    font.pixelSize: App.Spacing.overallText * 1.6
                                    font.bold: currentSection === parent.itemSection
                                    font.family: App.Style.fontFamily
                                    elide: Text.ElideRight
                                }

                                // Entire area clickable
                                MouseArea {
                                    id: navMouseArea
                                    anchors.fill: parent
                                    onClicked: {
                                        // Save scroll position of current page before switching
                                        if (contentLoader.item && typeof contentLoader.item.contentY !== "undefined") {
                                            var copy = ({})
                                            for (var key in scrollPositions) copy[key] = scrollPositions[key]
                                            copy[currentSection] = contentLoader.item.contentY
                                            scrollPositions = copy
                                        }

                                        currentSection = parent.itemSection
                                        mainWindow.lastSettingsSection = parent.itemSection
                                        // Persist to settings
                                        if (settingsManager) {
                                            settingsManager.set_last_settings_section(parent.itemSection)
                                        }
                                    }
                                    hoverEnabled: true

                                    onEntered: {
                                        if (currentSection !== delegateRoot.itemSection) {
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

                // Top HUD line (spacecraft)
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

                // Bottom HUD line (spacecraft)
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

                // Top-left corner bracket (spacecraft)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Top-right corner bracket (spacecraft)
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Bottom-left corner bracket (spacecraft)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }

                // Bottom-right corner bracket (spacecraft)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 10; height: 1; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                    visible: App.EnvironmentTheme.active.contentHudLines
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: App.Spacing.settingsContentMargin - 5
                    width: 1; height: 10; z: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
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
                    source: sourceForSection(currentSection)

                    // Track previous section for scroll save
                    property string previousSection: ""

                    onSourceChanged: {
                        // Save scroll position of previous page
                        if (previousSection && item && typeof item.contentY !== "undefined") {
                            var copy = ({})
                            for (var key in scrollPositions) copy[key] = scrollPositions[key]
                            copy[previousSection] = item.contentY
                            scrollPositions = copy
                        }
                        previousSection = currentSection
                    }

                    onLoaded: {
                        // Bind optional properties if the page declares them
                        if (item && typeof item.mainWindow !== "undefined")
                            item.mainWindow = settingsMenu.mainWindow
                        if (item && typeof item.stackView !== "undefined")
                            item.stackView = settingsMenu.stackView
                        if (item && typeof item.currentSection !== "undefined")
                            item.currentSection = Qt.binding(function() { return settingsMenu.currentSection })

                        // Restore scroll position
                        if (item && typeof item.contentY !== "undefined" && scrollPositions[currentSection] !== undefined) {
                            item.contentY = scrollPositions[currentSection]
                        }
                    }
                }
            }
        }
    }
}
