import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import ".." as App

Flickable {
    id: pageRoot

    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    property var stackView: null
    property var mainWindow: null
    property string currentSection: ""

    // Tile model — consumed by SettingsSidebarLayout (grid + slide-in popup).
    // Each entry: { cardId, title, icon, component }. Other layouts ignore this
    // and use the Repeater rendering below.
    property var tileModel: [
        { cardId: "display_layout",     title: "Layout",     icon: "▦", component: layoutContent },
        { cardId: "display_window",     title: "Window",     icon: "▣", component: windowContent },
        { cardId: "display_appearance", title: "Appearance", icon: "❖", component: appearanceContent },
        { cardId: "display_clock",      title: "Clock",      icon: "⏱", component: clockContent }
    ]

    function buildThemeChipColors() {
        var colors = {}
        var customNames = settingsManager ? settingsManager.customThemes : []
        for (var i = 0; i < customNames.length; i++) {
            var theme = App.Style.customThemes[customNames[i]]
            if (theme && theme.accent) {
                colors[customNames[i]] = theme.accent
            }
        }
        return colors
    }

    function buildThemeChipImages() {
        var images = {}
        var customNames = settingsManager ? settingsManager.customThemes : []
        for (var i = 0; i < customNames.length; i++) {
            var theme = App.Style.customThemes[customNames[i]]
            if (theme && theme.albumArt) {
                images[customNames[i]] = theme.albumArt
            }
        }
        return images
    }

    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    // ── Card body components — shared between the Flickable rendering (below)
    //    and the SettingsCardPopup in the Sidebar layout.

    Component {
        id: layoutContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "UI Scaling"
                description: "Adjusts the overall size of UI elements. 100% = default."

                SettingsSlider {
                    id: uiScaleSlider
                    from: 0.5
                    to: 2.0
                    stepSize: 0.05
                    value: App.Spacing.globalScale

                    Timer {
                        id: scaleUpdateTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_ui_scale(uiScaleSlider.value)
                                App.Spacing.globalScale = uiScaleSlider.value
                            }
                        }
                    }

                    onMoved: scaleUpdateTimer.restart()
                }

                ValueDisplay {
                    text: (uiScaleSlider.value * 100).toFixed(0) + "%"
                }
            }

            SettingCategory {
                title: "Nav Bar Position"
                description: "Bottom or side placement"

                SettingsSegmentedControl {
                    id: bottomBarOrientation
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.bottomBarOrientation : "bottom"
                    options: ["bottom", "side"]

                    onSelected: function(value) {
                        if (settingsManager)
                            settingsManager.save_bottom_bar_orientation(value)
                    }
                }
            }

            SettingCategory {
                title: "Nav Bar Media Controls"

                SettingsToggle {
                    id: bottomBarMediaControlsToggle
                    compact: true
                    Layout.fillWidth: true
                    text: ""
                    checked: settingsManager ? settingsManager.showBottomBarMediaControls : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_bottom_bar_media_controls(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShowBottomBarMediaControlsChanged() {
                            bottomBarMediaControlsToggle.checked = settingsManager.showBottomBarMediaControls
                        }
                    }
                }
            }
        }
    }

    Component {
        id: windowContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Screen Dimensions"

                RowLayout {
                    spacing: App.Spacing.overallSpacing
                    Layout.fillWidth: true

                    Text {
                        text: "Width:"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                    }

                    SettingsTextField {
                        id: screenWidth
                        Layout.preferredWidth: pageRoot.dp(120)
                        text: pageRoot.mainWindow ? pageRoot.mainWindow.width : ""
                        horizontalAlignment: TextInput.AlignHCenter
                        validator: IntValidator {
                            bottom: 400
                            top: 3840
                        }

                        function applyWidth() {
                            if (text && settingsManager) {
                                const width = parseInt(text)
                                settingsManager.save_screen_width(width)
                                pageRoot.mainWindow.width = width
                                App.Spacing.updateDimensions(width, pageRoot.mainWindow.height)
                            }
                        }

                        onEditingFinished: applyWidth()
                        onActiveFocusChanged: if (!activeFocus) applyWidth()

                        Connections {
                            target: pageRoot.mainWindow
                            function onWidthChanged() {
                                if (!screenWidth.activeFocus) {
                                    screenWidth.text = pageRoot.mainWindow.width
                                    if (settingsManager) {
                                        settingsManager.save_screen_width(pageRoot.mainWindow.width)
                                    }
                                    App.Spacing.updateDimensions(pageRoot.mainWindow.width, pageRoot.mainWindow.height)
                                }
                            }
                        }
                    }

                    Text {
                        text: "Height:"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                    }

                    SettingsTextField {
                        id: screenHeight
                        Layout.preferredWidth: pageRoot.dp(120)
                        text: pageRoot.mainWindow ? pageRoot.mainWindow.height : ""
                        horizontalAlignment: TextInput.AlignHCenter
                        validator: IntValidator {
                            bottom: 300
                            top: 2160
                        }

                        function applyHeight() {
                            if (text && settingsManager) {
                                const height = parseInt(text)
                                settingsManager.save_screen_height(height)
                                pageRoot.mainWindow.height = height
                                App.Spacing.updateDimensions(pageRoot.mainWindow.width, height)
                            }
                        }

                        onEditingFinished: applyHeight()
                        onActiveFocusChanged: if (!activeFocus) applyHeight()

                        Connections {
                            target: pageRoot.mainWindow
                            function onHeightChanged() {
                                if (!screenHeight.activeFocus) {
                                    screenHeight.text = pageRoot.mainWindow.height
                                    if (settingsManager) {
                                        settingsManager.save_screen_height(pageRoot.mainWindow.height)
                                    }
                                    App.Spacing.updateDimensions(pageRoot.mainWindow.width, pageRoot.mainWindow.height)
                                }
                            }
                        }
                    }

                    SettingsButton {
                        text: pageRoot.mainWindow && pageRoot.mainWindow.visibility === Window.FullScreen ? "Exit Fullscreen" : "Fullscreen"
                        Layout.preferredHeight: screenHeight.height
                        Layout.minimumWidth: pageRoot.dp(80)
                        tooltipText: pageRoot.mainWindow && pageRoot.mainWindow.visibility === Window.FullScreen ? "Exit fullscreen mode" : "Enter fullscreen mode"
                        onClicked: {
                            if (!pageRoot.mainWindow) return
                            if (pageRoot.mainWindow.visibility === Window.FullScreen) {
                                pageRoot.mainWindow.visibility = Window.Windowed
                                if (settingsManager) settingsManager.save_window_state("windowed")
                            } else {
                                pageRoot.mainWindow.visibility = Window.FullScreen
                                if (settingsManager) settingsManager.save_window_state("fullscreen")
                            }
                        }
                    }

                    SettingsButton {
                        text: "Maximize"
                        Layout.preferredHeight: screenHeight.height
                        Layout.minimumWidth: pageRoot.dp(80)
                        tooltipText: "Maximize window to fill screen"
                        onClicked: {
                            if (!pageRoot.mainWindow) return
                            pageRoot.mainWindow.visibility = Window.Maximized
                            if (settingsManager) settingsManager.save_window_state("maximized")
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer
                }
            }
        }
    }

    Component {
        id: appearanceContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Theme"

                Connections {
                    target: App.Style
                    function onCustomThemesUpdated() {
                        themeButton.options = App.Style.getAllThemeNames()
                        themeButton.chipColors = pageRoot.buildThemeChipColors()
                        themeButton.chipImages = pageRoot.buildThemeChipImages()
                        themeButton.deletableItems = settingsManager ? settingsManager.customThemes : []
                    }
                }

                SettingsChips {
                    id: themeButton
                    Layout.fillWidth: true
                    // While Album Art Capture is on, show the underlying static
                    // theme as the selected chip so users see what's "behind"
                    // the album-art override.
                    currentValue: {
                        if (!settingsManager) return "Light"
                        if (settingsManager.themeSetting === "Album Art Capture")
                            return App.Style.lastStaticTheme || "CosmicVoyager"
                        return settingsManager.themeSetting
                    }
                    options: App.Style.getAllThemeNames()
                    chipColors: pageRoot.buildThemeChipColors()
                    chipImages: pageRoot.buildThemeChipImages()
                    deletableItems: settingsManager ? settingsManager.customThemes : []

                    onSelected: function(value) {
                        if (settingsManager) {
                            // Picking a chip turns Album Art Capture off — the
                            // user is choosing a static theme.
                            settingsManager.save_theme_setting(value)
                            App.Style.setTheme(value)
                        }
                    }

                    onItemDeleted: function(value) {
                        if (settingsManager) {
                            if (settingsManager.themeSetting === value) {
                                settingsManager.save_theme_setting("CosmicVoyager")
                                App.Style.setTheme("CosmicVoyager")
                            }
                            settingsManager.delete_custom_theme(value)
                        }
                    }
                }

                SettingSubcategory {
                    id: albumArtCard
                    Layout.fillWidth: true
                    Layout.topMargin: App.Spacing.rowSpacing
                    title: "Album Art Capture"
                    description: "Pull a live color palette from the current song's album art."
                    togglable: true
                    checked: settingsManager && settingsManager.themeSetting === "Album Art Capture"

                    onToggled: function(on) {
                        if (!settingsManager) return
                        if (on) {
                            if (settingsManager.themeSetting !== "Album Art Capture")
                                App.Style.lastStaticTheme = settingsManager.themeSetting
                            settingsManager.save_theme_setting("Album Art Capture")
                            App.Style.setTheme("Album Art Capture")
                            if (typeof mediaManager !== "undefined" && mediaManager) {
                                var f = mediaManager.get_current_file()
                                if (f) mediaManager.extract_colors_from_album_art(f)
                            }
                        } else {
                            var fallback = App.Style.lastStaticTheme || "CosmicVoyager"
                            settingsManager.save_theme_setting(fallback)
                            App.Style.setTheme(fallback)
                        }
                    }

                    SettingLabel {
                        text: "Transition Speed"
                    }

                    SettingDescription {
                        text: "How long album art colors fade when the song changes. 0 = instant."
                    }

                    SettingsSlider {
                        id: colorTransitionSlider
                        from: 0
                        to: 2000
                        stepSize: 50
                        value: settingsManager ? settingsManager.colorTransitionMs : 1000
                        Layout.preferredHeight: App.Spacing.overallSliderHeight * 1.6

                        Connections {
                            target: settingsManager
                            function onColorTransitionMsChanged() {
                                colorTransitionSlider.value = settingsManager.colorTransitionMs
                            }
                        }

                        Timer {
                            id: colorTransitionUpdateTimer
                            interval: 100
                            running: false
                            repeat: false
                            onTriggered: {
                                if (settingsManager) {
                                    settingsManager.save_color_transition_ms(Math.round(colorTransitionSlider.value))
                                    App.Style.colorTransitionMs = Math.round(colorTransitionSlider.value)
                                }
                            }
                        }

                        onMoved: colorTransitionUpdateTimer.restart()
                    }

                    ValueDisplay {
                        text: Math.round(colorTransitionSlider.value) + "ms"
                    }

                    SettingLabel {
                        text: "Match Song Length"
                        Layout.topMargin: App.Spacing.rowSpacing * 1.5
                    }

                    SettingDescription {
                        text: "Colors transition over the full length of the current song."
                    }

                    SettingsToggle {
                        id: songLengthTransitionToggle
                        compact: true
                        Layout.fillWidth: true
                        text: ""
                        checked: settingsManager ? settingsManager.songLengthTransition : false
                        activeColor: App.Style.accent
                        inactiveColor: App.Style.hoverColor

                        onToggled: function(checked) {
                            if (settingsManager) {
                                settingsManager.save_song_length_transition(checked)
                            }
                        }

                        Connections {
                            target: settingsManager
                            function onSongLengthTransitionChanged() {
                                songLengthTransitionToggle.checked = settingsManager.songLengthTransition
                            }
                        }
                    }
                }
            }

            SettingCategory {
                title: "Font"
                description: "Drop .ttf/.otf files in the fonts folder"

                Connections {
                    target: App.Style
                    function onFontsUpdated() {
                        fontButton.options = App.Style.availableFonts
                    }
                }

                SettingsChips {
                    id: fontButton
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.fontSetting : "System Default"
                    options: App.Style.availableFonts

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_font_setting(value)
                            App.Style.setFont(value)
                        }
                    }
                }
            }

        }
    }

    Component {
        id: clockContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Show Clock"

                SettingsToggle {
                    compact: true
                    text: ""
                    Layout.fillWidth: true
                    checked: settingsManager ? settingsManager.showClock : true

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_clock(checked)
                        }
                    }
                }
            }

            SettingCategory {
                title: "Time Format"

                SettingsSegmentedControl {
                    id: timeFormatControl
                    Layout.fillWidth: true
                    options: ["24-hour", "12-hour (AM/PM)"]
                    currentValue: settingsManager ?
                                (settingsManager.clockFormat24Hour ? "24-hour" : "12-hour (AM/PM)") :
                                "24-hour"

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_clock_format(value === "24-hour")
                        }
                    }
                }
            }

            SettingCategory {
                title: "Clock Size"

                SettingsSlider {
                    id: clockSizeSlider
                    from: 10
                    to: 85
                    stepSize: 1
                    value: settingsManager ? settingsManager.clockSize : 18

                    onMoved: {
                        if (settingsManager) {
                            settingsManager.save_clock_size(value)
                        }
                    }
                }

                ValueDisplay {
                    text: clockSizeSlider.value.toFixed(0) + " px"
                }
            }
        }
    }

    // ── Default rendering: stacked SettingsCards (Carousel/Hub/Dashboard layouts).
    //    Sidebar layout sets pageRoot.visible = false and renders the tile grid + popup instead.
    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        Repeater {
            model: pageRoot.tileModel

            SettingsCard {
                Layout.fillWidth: true
                objectName: modelData.title
                cardId: modelData.cardId
                title: modelData.title

                Loader {
                    Layout.fillWidth: true
                    sourceComponent: modelData.component
                }
            }
        }

        // Bottom spacer
        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
