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

    property string currentSection: ""

    // State: "hub" = card grid landing, "detail" = full-width settings page
    // Default "" so neither state matches initially — avoids hub flash when entering detail directly
    property string viewState: ""

    // Central page model — single source of truth for all pages
    readonly property var pageModel: [
        { name: "Device",         section: "deviceSettings",         source: "settings/DeviceSettingsPage.qml",         status: "", icon: "\u2699" },
        { name: "Media",          section: "mediaSettings",          source: "settings/MediaSettingsPage.qml",          status: "", icon: "\u266B" },
        { name: "Display",        section: "displaySettings",        source: "settings/DisplaySettingsPage.qml",        status: "", icon: "\u263C" },
        { name: "OBD",            section: "obdSettings",            source: "settings/OBDSettingsPage.qml",            status: "", icon: "\u26A1" },
        { name: "Android Auto",   section: "androidAutoSettings",    source: "settings/AndroidAutoSettingsPage.qml",    status: "", icon: "\u25B6" },
        { name: "Phone Mirror",   section: "phoneMirrorSettings",    source: "settings/PhoneMirrorSettingsPage.qml",    status: "", icon: "\u260E" },
        { name: "Volume Knob",    section: "volumeKnobSettings",     source: "settings/VolumeKnobSettingsPage.qml",     status: "", icon: "\u23F6" },
        { name: "Gesture Sensor", section: "gestureSensorSettings",  source: "settings/GestureSensorSettingsPage.qml",  status: "", icon: "\u270B" },
        { name: "About",          section: "about",                  source: "settings/AboutPage.qml",                  status: "", icon: "\u2139" }
    ]

    // Derived section order for fallback when current section is hidden
    readonly property var sectionOrder: {
        var order = []
        for (var i = 0; i < pageModel.length; i++)
            order.push(pageModel[i].section)
        return order
    }

    // Visible pages model for the hub grid
    property var hubModel: []

    // Scroll memory — stores contentY per section (ephemeral, not persisted)
    property var scrollPositions: ({})

    Component.onCompleted: {
        buildHubModel()

        // Entry behavior: resume last category if valid
        if (initialSection && initialSection !== "") {
            var page = pageForSection(initialSection)
            if (page && isVisible(initialSection)) {
                currentSection = initialSection
                viewState = "detail"
                return
            }
        }
        viewState = "hub"
    }

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

    // Look up page name by section
    function nameForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i].name
        }
        return "Settings"
    }

    // Check if a section is visible
    function isVisible(section) {
        return settingsManager ? settingsManager.is_settings_section_visible(section) : true
    }

    // Build the hub model from pageModel, respecting visibility
    function buildHubModel() {
        var model = []
        for (var i = 0; i < pageModel.length; i++) {
            var page = pageModel[i]
            if (isVisible(page.section)) {
                model.push({
                    name: page.name,
                    section: page.section,
                    icon: page.icon,
                    widgetItems: getWidgetForSection(page.section)
                })
            }
        }
        hubModel = model
    }

    // Get widget info lines for a hub card
    function getWidgetForSection(section) {
        if (!settingsManager) return []
        switch (section) {
            case "deviceSettings":
                return [
                    { label: "Name", value: settingsManager.deviceName || "OCTAVE" }
                ]
            case "mediaSettings":
                return [
                    { label: "Source", value: settingsManager.mediaSource === "spotify" ? "Spotify" : "Local" },
                    { label: "Autoplay", value: settingsManager.autoPlayOnStartup ? "On" : "Off" },
                    { label: "Visualizer", value: settingsManager.showWaveformVisualizer ? "On" : "Off" }
                ]
            case "displaySettings":
                return [
                    { label: "Theme", value: settingsManager.themeSetting },
                    { label: "Environment", value: settingsManager.environmentTheme },
                    { label: "Scale", value: Math.round(settingsManager.uiScale * 100) + "%" }
                ]
            case "obdSettings":
                return [
                    { label: "Status", value: obdManager ? obdManager.get_connection_status() : "N/A" },
                    { label: "Port", value: settingsManager.obdBluetoothPort || "Not set" },
                    { label: "Fast", value: settingsManager.obdFastMode ? "On" : "Off" }
                ]
            case "androidAutoSettings":
                return [
                    { label: "Nav Bar", value: settingsManager.androidAutoEnabled ? "Shown" : "Hidden" }
                ]
            case "phoneMirrorSettings":
                return [
                    { label: "Nav Bar", value: settingsManager.phoneMirrorEnabled ? "Shown" : "Hidden" },
                    { label: "Audio", value: settingsManager.scrcpyAudioEnabled ? "On" : "Off" }
                ]
            case "volumeKnobSettings":
                var espConnected = (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager && esp32VolumeManager.is_connected())
                return [
                    { label: "Status", value: espConnected ? "Connected" : "Disconnected" },
                    { label: "Port", value: settingsManager.esp32VolumePort || "Not set" },
                    { label: "LED", value: settingsManager.esp32LedColorMode || "Off" }
                ]
            case "gestureSensorSettings":
                return [
                    { label: "Status", value: settingsManager.gestureSensorEnabled ? "Enabled" : "Disabled" },
                    { label: "Vol Step", value: settingsManager.gestureVolumeStep + "%" },
                    { label: "Cooldown", value: settingsManager.gestureCooldown + "ms" }
                ]
            default:
                return []
        }
    }

    // Navigate to a category detail view
    function navigateToCategory(section) {
        currentSection = section
        viewState = "detail"
        if (settingsManager) {
            settingsManager.set_last_settings_section(section)
        }
    }

    // Return to hub
    function navigateToHub() {
        // Save scroll position before leaving detail
        if (contentLoader.item && typeof contentLoader.item.contentY !== "undefined") {
            var copy = ({})
            for (var key in scrollPositions) copy[key] = scrollPositions[key]
            copy[currentSection] = contentLoader.item.contentY
            scrollPositions = copy
        }
        viewState = "hub"
    }

    // When visibility changes, rebuild hub and check if we need to navigate away
    Connections {
        target: settingsManager
        function onSettingsMenuVisibilityChanged() {
            buildHubModel()
            if (viewState === "detail" && !isVisible(currentSection)) {
                navigateToHub()
            }
        }
    }

    // Live hub refresh — rebuild when device status changes (only while hub is showing)
    Connections {
        target: typeof obdManager !== "undefined" && obdManager ? obdManager : null
        enabled: viewState === "hub"
        function onConnectionStatusChanged() { buildHubModel() }
    }

    Connections {
        target: typeof esp32VolumeManager !== "undefined" && esp32VolumeManager ? esp32VolumeManager : null
        enabled: viewState === "hub"
        function onConnectionStatusChanged() { buildHubModel() }
    }

    Connections {
        target: typeof gestureManager !== "undefined" && gestureManager ? gestureManager : null
        enabled: viewState === "hub"
        function onConnectionStatusChanged() { buildHubModel() }
    }

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        // ─── Hub State ───────────────────────────────────────────────
        Item {
            id: hubView
            anchors.fill: parent
            visible: false
            opacity: 0

            Flickable {
                anchors.fill: parent
                anchors.margins: App.Spacing.settingsContentMargin
                contentHeight: hubGrid.implicitHeight + App.Spacing.bottomBarHeight
                clip: true
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 1200
                maximumFlickVelocity: 4000
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                GridLayout {
                    id: hubGrid
                    width: parent.width
                    columns: parent.width > 800 ? 3 : 2
                    columnSpacing: App.Spacing.settingsHubGridSpacing
                    rowSpacing: App.Spacing.settingsHubGridSpacing

                    Repeater {
                        model: hubModel.length

                        SettingsHubCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: App.Spacing.settingsHubCardHeight
                            categoryName: hubModel[index] ? hubModel[index].name : ""
                            section: hubModel[index] ? hubModel[index].section : ""
                            widgetItems: hubModel[index] ? hubModel[index].widgetItems : []
                            categoryIcon: hubModel[index] ? hubModel[index].icon : ""
                            radius: App.EnvironmentTheme.active.hubCardRadius

                            onCategorySelected: function(sec) {
                                settingsMenu.navigateToCategory(sec)
                            }
                        }
                    }
                }
            }
        }

        // ─── Detail State ────────────────────────────────────────────
        Item {
            id: detailView
            anchors.fill: parent
            visible: false
            opacity: 0

            Rectangle {
                anchors.fill: parent
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

                // ─── Heading bar ───
                Item {
                    id: headingBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: App.Spacing.overallSpacing * 2.4
                    z: 2

                    Row {
                        id: headingRow
                        anchors.left: parent.left
                        anchors.leftMargin: App.Spacing.settingsContentMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: App.Spacing.overallSpacing * 0.5

                        // Back arrow
                        Text {
                            text: "\u2190"
                            color: floatingLabelArea.containsMouse ? App.Style.accent : App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 1.1
                            font.family: App.Style.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Category name
                        Text {
                            id: categoryLabelText
                            text: nameForSection(currentSection)
                            color: floatingLabelArea.containsMouse ? App.Style.accent : App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText * 1.1
                            font.bold: true
                            font.family: App.Style.fontFamily
                            font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
                            font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: floatingLabelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsMenu.navigateToHub()
                    }

                    // Bottom separator line
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

                // ─── Content below heading ───
                Loader {
                    id: contentLoader
                    anchors {
                        top: headingBar.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: App.Spacing.settingsContentMargin
                        rightMargin: App.Spacing.settingsContentMargin
                        bottomMargin: App.Spacing.settingsContentMargin
                    }
                    source: viewState === "detail" ? sourceForSection(currentSection) : ""

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

        // ─── State management ────────────────────────────────────────
        states: [
            State {
                name: "hub"
                when: viewState === "hub"
                PropertyChanges { target: hubView; visible: true; opacity: 1.0 }
                PropertyChanges { target: detailView; visible: false; opacity: 0 }
            },
            State {
                name: "detail"
                when: viewState === "detail"
                PropertyChanges { target: hubView; visible: false; opacity: 0 }
                PropertyChanges { target: detailView; visible: true; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "hub"; to: "detail"
                SequentialAnimation {
                    NumberAnimation { target: hubView; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                    PropertyAction { target: hubView; property: "visible"; value: false }
                    PropertyAction { target: detailView; property: "visible"; value: true }
                    NumberAnimation { target: detailView; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.InQuad }
                }
            },
            Transition {
                from: "detail"; to: "hub"
                SequentialAnimation {
                    ScriptAction { script: settingsMenu.buildHubModel() }
                    NumberAnimation { target: detailView; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                    PropertyAction { target: detailView; property: "visible"; value: false }
                    PropertyAction { target: hubView; property: "visible"; value: true }
                    NumberAnimation { target: hubView; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.InQuad }
                }
            }
        ]
    }
}
