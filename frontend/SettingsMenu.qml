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
    // Order optimized for dashboard grid packing: span-2 cards first in each row, span-1 fills column 3
    readonly property var pageModel: [
        { name: "Display",        section: "displaySettings",        source: "settings/DisplaySettingsPage.qml",        status: "", icon: "\u263C" },
        { name: "Device",         section: "deviceSettings",         source: "settings/DeviceSettingsPage.qml",         status: "", icon: "\u2699" },
        { name: "Media",          section: "mediaSettings",          source: "settings/MediaSettingsPage.qml",          status: "", icon: "\u266B" },
        { name: "Android Auto",   section: "androidAutoSettings",    source: "settings/AndroidAutoSettingsPage.qml",    status: "", icon: "\u25B6" },
        { name: "OBD",            section: "obdSettings",            source: "settings/OBDSettingsPage.qml",            status: "", icon: "\u26A1" },
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

    // Dashboard column span — important categories get 2 columns in 3-col mode
    function getSpanForSection(section) {
        switch (section) {
            case "displaySettings":
            case "mediaSettings":
            case "obdSettings":
                return 2
            default:
                return 1
        }
    }

    // Count how many grid rows the hub model occupies (simulates GridLayout packing)
    function getRowCount(cols) {
        var col = 0
        var rows = 1
        for (var i = 0; i < hubModel.length; i++) {
            var span = hubModel[i].span
            if (cols <= 2) span = 1  // 2-col mode ignores spans
            if (col + span > cols) {
                rows++
                col = 0
            }
            col += span
            if (col >= cols) {
                if (i < hubModel.length - 1) rows++
                col = 0
            }
        }
        return Math.max(rows, 1)
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
                    widgetItems: getWidgetForSection(page.section),
                    span: getSpanForSection(page.section)
                })
            }
        }
        hubModel = model
    }

    // Get widget info lines for a hub card
    // Items with live connection state include statusColor for dot indicator
    function getWidgetForSection(section) {
        if (!settingsManager) return []
        switch (section) {
            case "deviceSettings":
                return [
                    { label: "Name", value: settingsManager.deviceName || "OCTAVE", statusColor: "" },
                    { label: "Resolution", value: settingsManager.screenWidth + " x " + settingsManager.screenHeight, statusColor: "" }
                ]
            case "mediaSettings": {
                var isSpotify = settingsManager.mediaSource === "spotify"
                var spotifyColor = ""
                if (isSpotify && typeof spotifyManager !== "undefined" && spotifyManager) {
                    spotifyColor = spotifyManager.is_connected()
                        ? App.Style.statusConnected.toString()
                        : App.Style.statusDisconnected.toString()
                }
                var mediaItems = [
                    { label: "Source", value: isSpotify ? "Spotify" : "Local", statusColor: spotifyColor },
                    { label: "Autoplay", value: settingsManager.autoPlayOnStartup ? "On" : "Off", statusColor: "" },
                    { label: "Visualizer", value: settingsManager.showWaveformVisualizer ? "On" : "Off", statusColor: "" }
                ]
                if (!isSpotify && typeof mediaManager !== "undefined" && mediaManager) {
                    var albums = mediaManager.get_album_count()
                    var artists = mediaManager.get_artist_count()
                    if (albums > 0) mediaItems.push({ label: "Albums", value: albums.toString(), statusColor: "" })
                    if (artists > 0) mediaItems.push({ label: "Artists", value: artists.toString(), statusColor: "" })
                }
                return mediaItems
            }
            case "displaySettings": {
                var fontVal = settingsManager.fontSetting || "System Default"
                if (fontVal.length > 14) fontVal = fontVal.substring(0, 14) + "\u2026"
                return [
                    { label: "Theme", value: settingsManager.themeSetting, statusColor: "" },
                    { label: "Environment", value: settingsManager.environmentTheme, statusColor: "" },
                    { label: "Scale", value: Math.round(settingsManager.uiScale * 100) + "%", statusColor: "" },
                    { label: "Font", value: fontVal, statusColor: "" }
                ]
            }
            case "obdSettings": {
                var obdStatus = obdManager ? obdManager.get_connection_status() : "N/A"
                var obdColor = App.Style.statusDisconnected.toString()
                if (obdStatus.indexOf("Connected") !== -1)
                    obdColor = App.Style.statusConnected.toString()
                else if (obdStatus.indexOf("Connecting") !== -1)
                    obdColor = App.Style.statusWarning.toString()
                var obdItems = [
                    { label: "Status", value: obdStatus, statusColor: obdColor },
                    { label: "Port", value: settingsManager.obdBluetoothPort || "Not set", statusColor: "" },
                    { label: "Fast", value: settingsManager.obdFastMode ? "On" : "Off", statusColor: "" }
                ]
                if (obdManager && obdManager.is_connected()) {
                    var v = obdManager.voltage()
                    if (v > 0) obdItems.push({ label: "Voltage", value: v.toFixed(1) + "V", statusColor: "" })
                }
                return obdItems
            }
            case "androidAutoSettings":
                return [
                    { label: "Nav Bar", value: settingsManager.androidAutoEnabled ? "Shown" : "Hidden", statusColor: "" }
                ]
            case "phoneMirrorSettings":
                return [
                    { label: "Nav Bar", value: settingsManager.phoneMirrorEnabled ? "Shown" : "Hidden", statusColor: "" },
                    { label: "Audio", value: settingsManager.scrcpyAudioEnabled ? "On" : "Off", statusColor: "" }
                ]
            case "volumeKnobSettings": {
                var espConnected = (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager && esp32VolumeManager.is_connected())
                return [
                    { label: "Status", value: espConnected ? "Connected" : "Disconnected",
                      statusColor: espConnected ? App.Style.statusConnected.toString() : App.Style.statusDisconnected.toString() },
                    { label: "Port", value: settingsManager.esp32VolumePort || "Not set", statusColor: "" },
                    { label: "LED", value: settingsManager.esp32LedColorMode || "Off", statusColor: "" }
                ]
            }
            case "gestureSensorSettings": {
                var gestureEnabled = settingsManager.gestureSensorEnabled
                return [
                    { label: "Status", value: gestureEnabled ? "Enabled" : "Disabled",
                      statusColor: gestureEnabled ? App.Style.statusConnected.toString() : App.Style.statusDisconnected.toString() },
                    { label: "Vol Step", value: settingsManager.gestureVolumeStep + "%", statusColor: "" },
                    { label: "Cooldown", value: settingsManager.gestureCooldown + "ms", statusColor: "" }
                ]
            }
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
        buildHubModel()
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

    // Live hub refresh — settings changes
    Connections {
        target: settingsManager
        enabled: viewState === "hub"
        function onThemeSettingChanged() { buildHubModel() }
        function onFontSettingChanged() { buildHubModel() }
        function onMediaSourceChanged() { buildHubModel() }
    }

    // Live hub refresh — media library counts
    Connections {
        target: typeof mediaManager !== "undefined" && mediaManager ? mediaManager : null
        enabled: viewState === "hub"
        function onAlbumCountChanged() { buildHubModel() }
        function onArtistCountChanged() { buildHubModel() }
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

            // Environment backgrounds (behind grid)
            ContentSonar {}
            ContentSolarSystem {}

            GridLayout {
                id: hubGrid
                anchors.fill: parent
                anchors.margins: App.Spacing.settingsContentMargin
                anchors.bottomMargin: App.Spacing.settingsContentMargin
                columns: width > 800 ? 3 : 2
                columnSpacing: App.Spacing.settingsHubGridSpacing
                rowSpacing: App.Spacing.settingsHubGridSpacing

                // Compute card height to fill available space
                property int rowCount: getRowCount(columns)
                property real cardHeight: (height - (rowCount - 1) * rowSpacing) / rowCount

                Repeater {
                    model: hubModel.length

                    SettingsHubCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: hubGrid.cardHeight
                        Layout.columnSpan: hubGrid.columns === 3 ? (hubModel[index] ? hubModel[index].span : 1) : 1
                        categoryName: hubModel[index] ? hubModel[index].name : ""
                        section: hubModel[index] ? hubModel[index].section : ""
                        widgetItems: hubModel[index] ? hubModel[index].widgetItems : []
                        categoryIcon: hubModel[index] ? hubModel[index].icon : ""
                        cardSpan: hubGrid.columns === 3 ? (hubModel[index] ? hubModel[index].span : 1) : 1
                        radius: App.EnvironmentTheme.active.hubCardRadius

                        onCategorySelected: function(sec) {
                            settingsMenu.navigateToCategory(sec)
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

        transitions: []
    }
}
