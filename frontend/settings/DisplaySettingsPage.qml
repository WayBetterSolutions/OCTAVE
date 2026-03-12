import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Flickable {
    property var stackView: null
    property var mainWindow: null
    property string currentSection: ""

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

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // ── Card 1: Layout ──────────────────────────────────────────────
        SettingsCard {
            objectName: "Layout"
            cardId: "display_layout"
            title: "Layout"

            ColumnLayout { // UI Scaling slider
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "UI Scaling"
                }

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

                SettingDescription {
                    text: "Adjusts the overall size of UI elements. 100% = default."
                }
            }

            SettingsDivider {}

            ColumnLayout { //nav bar orientation
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Nav Bar Position"
                }

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

                SettingDescription {
                    text: "Bottom or side placement"
                }
            }

            SettingsDivider {}

            ColumnLayout { // Nav Bar Media Controls
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: bottomBarMediaControlsToggle
                    Layout.fillWidth: true
                    text: "Nav bar media controls"
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

        // ── Card 2: Window ──────────────────────────────────────────────
        SettingsCard {
            objectName: "Window"
            cardId: "display_window"
            title: "Window"

            ColumnLayout { // Screen Dimensions
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Screen Dimensions"
                }

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
                        Layout.preferredWidth: App.Spacing.dp(120)
                        text: mainWindow ? mainWindow.width : ""
                        horizontalAlignment: TextInput.AlignHCenter
                        validator: IntValidator {
                            bottom: 400
                            top: 3840
                        }

                        function applyWidth() {
                            if (text && settingsManager) {
                                const width = parseInt(text)
                                settingsManager.save_screen_width(width)
                                mainWindow.width = width
                                App.Spacing.updateDimensions(width, mainWindow.height)
                            }
                        }

                        onEditingFinished: applyWidth()
                        onActiveFocusChanged: if (!activeFocus) applyWidth()

                        Connections {
                            target: mainWindow
                            function onWidthChanged() {
                                if (!screenWidth.activeFocus) {
                                    screenWidth.text = mainWindow.width
                                    if (settingsManager) {
                                        settingsManager.save_screen_width(mainWindow.width)
                                    }
                                    App.Spacing.updateDimensions(mainWindow.width, mainWindow.height)
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
                        Layout.preferredWidth: App.Spacing.dp(120)
                        text: mainWindow ? mainWindow.height : ""
                        horizontalAlignment: TextInput.AlignHCenter
                        validator: IntValidator {
                            bottom: 300
                            top: 2160
                        }

                        function applyHeight() {
                            if (text && settingsManager) {
                                const height = parseInt(text)
                                settingsManager.save_screen_height(height)
                                mainWindow.height = height
                                App.Spacing.updateDimensions(mainWindow.width, height)
                            }
                        }

                        onEditingFinished: applyHeight()
                        onActiveFocusChanged: if (!activeFocus) applyHeight()

                        Connections {
                            target: mainWindow
                            function onHeightChanged() {
                                if (!screenHeight.activeFocus) {
                                    screenHeight.text = mainWindow.height
                                    if (settingsManager) {
                                        settingsManager.save_screen_height(mainWindow.height)
                                    }
                                    App.Spacing.updateDimensions(mainWindow.width, mainWindow.height)
                                }
                            }
                        }
                    }

                    SettingsButton {
                        text: mainWindow && mainWindow.visibility === Window.FullScreen ? "Exit Fullscreen" : "Fullscreen"
                        Layout.preferredHeight: screenHeight.height
                        Layout.minimumWidth: App.Spacing.dp(80)
                        tooltipText: mainWindow && mainWindow.visibility === Window.FullScreen ? "Exit fullscreen mode" : "Enter fullscreen mode"
                        onClicked: {
                            if (!mainWindow) return
                            if (mainWindow.visibility === Window.FullScreen) {
                                mainWindow.visibility = Window.Windowed
                                if (settingsManager) settingsManager.save_window_state("windowed")
                            } else {
                                mainWindow.visibility = Window.FullScreen
                                if (settingsManager) settingsManager.save_window_state("fullscreen")
                            }
                        }
                    }

                    SettingsButton {
                        text: "Maximize"
                        Layout.preferredHeight: screenHeight.height
                        Layout.minimumWidth: App.Spacing.dp(80)
                        tooltipText: "Maximize window to fill screen"
                        onClicked: {
                            if (!mainWindow) return
                            mainWindow.visibility = Window.Maximized
                            if (settingsManager) settingsManager.save_window_state("maximized")
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer
                }
            }
        }

        // ── Card 3: Appearance ──────────────────────────────────────────
        SettingsCard {
            objectName: "Appearance"
            cardId: "display_appearance"
            title: "Appearance"

            ColumnLayout { // Theme Selection
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Theme"
                }

                // Update theme options when themes change
                Connections {
                    target: App.Style
                    function onCustomThemesUpdated() {
                        // Force refresh of theme options, chip colors, images, and deletable items
                        themeButton.options = App.Style.getAllThemeNames()
                        themeButton.chipColors = buildThemeChipColors()
                        themeButton.chipImages = buildThemeChipImages()
                        themeButton.deletableItems = settingsManager ? settingsManager.customThemes : []
                    }
                }

                // Theme selection chips
                SettingsChips {
                    id: themeButton
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.themeSetting : "Light"
                    options: App.Style.getAllThemeNames()
                    chipColors: buildThemeChipColors()
                    chipImages: buildThemeChipImages()
                    deletableItems: settingsManager ? settingsManager.customThemes : []

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_theme_setting(value)
                            App.Style.setTheme(value)
                        }
                    }

                    onItemDeleted: function(value) {
                        if (settingsManager) {
                            // If deleting the active theme, switch to default first
                            if (settingsManager.themeSetting === value) {
                                settingsManager.save_theme_setting("CosmicVoyager")
                                App.Style.setTheme("CosmicVoyager")
                            }
                            settingsManager.delete_custom_theme(value)
                        }
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout { // Environment Selection
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Environment"
                }

                SettingsChips {
                    id: environmentChips
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.environmentTheme : "Standard"
                    options: App.EnvironmentTheme.getAllEnvironmentNames()

                    onSelected: function(value) {
                        App.EnvironmentTheme.setEnvironment(value)
                        if (settingsManager) {
                            settingsManager.save_environment_theme(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onEnvironmentThemeChanged() {
                            environmentChips.currentValue = settingsManager.environmentTheme
                            App.EnvironmentTheme.setEnvironment(settingsManager.environmentTheme)
                        }
                    }
                }

                SettingDescription {
                    text: "Switch between visual styles for the settings page."
                }
            }

            SettingsDivider {}

            ColumnLayout { // Font Selection
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Font"
                }

                SettingDescription {
                    text: "Drop .ttf/.otf files in the fonts folder"
                }

                // Update font options when fonts change
                Connections {
                    target: App.Style
                    function onFontsUpdated() {
                        fontButton.options = App.Style.availableFonts
                    }
                }

                // Font selection chips
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

            SettingsDivider {}

            ColumnLayout { // Color Transition Speed
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Theme Transition Speed"
                }

                SettingsSlider {
                    id: colorTransitionSlider
                    from: 0
                    to: 2000
                    stepSize: 50
                    value: settingsManager ? settingsManager.colorTransitionMs : 1000

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

                SettingDescription {
                    text: "How long colors fade when switching themes or album art changes. 0 = instant."
                }

                SettingsToggle {
                    id: songLengthTransitionToggle
                    Layout.fillWidth: true
                    text: "Match song length"
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

                SettingDescription {
                    text: "Colors transition over the full length of the current song."
                }
            }
        }

        // ── Card 4: Clock ─────────────────────────────────────────────────
        SettingsCard {
            objectName: "Clock"
            cardId: "display_clock"
            title: "Clock"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    text: "Show clock"
                    Layout.fillWidth: true
                    checked: settingsManager ? settingsManager.showClock : true

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_clock(checked)
                        }
                    }
                }
            }

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Time Format"
                }

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

            SettingsDivider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Clock Size"
                }

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

        // Bottom spacer
        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
