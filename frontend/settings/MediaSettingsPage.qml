import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import ".." as App

Flickable {
    id: mediaSettingsRoot
    contentWidth: width
    contentHeight: mediaSettingsContent.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    property string currentSection: ""

    // Reactive property for Spotify devices
    property var spotifyDevicesList: []

    // Refresh Spotify devices when navigating to media settings
    onCurrentSectionChanged: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
    }

    // Refresh devices on initial load if starting on media settings
    Component.onCompleted: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
        if (spotifyManager && spotifyManager.is_connected()) {
            spotifyDevicesList = spotifyManager.get_devices()
        }
    }

    // Top-level Spotify connections
    Connections {
        target: spotifyManager
        function onDevicesChanged(devices) {
            mediaSettingsRoot.spotifyDevicesList = devices
        }
        function onConnectionStateChanged(connected) {
            if (connected) {
                spotifyManager.refresh_devices()
            } else {
                mediaSettingsRoot.spotifyDevicesList = []
            }
        }
    }

    // Folder dialog for selecting music library folder
    FolderDialog {
        id: folderDialog
        title: "Select Music Library Folder"
        onAccepted: {
            var path = selectedFolder.toString()
            if (path.startsWith("file:///")) {
                var afterScheme = path.substring(8)
                if (afterScheme.length > 1 && afterScheme.charAt(1) === ':') {
                    path = afterScheme
                } else {
                    path = path.substring(7)
                }
            }
            mediaFolderField.text = path
            if (settingsManager) {
                settingsManager.save_media_folder(path)
            }
        }
    }

    ColumnLayout {
        id: mediaSettingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        // ── Card 1: Library ──
        SettingsCard {
            objectName: "Library"
            cardId: "media_library"
            title: "Library"

            // Music Library Folder
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Library Folder"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    SettingsTextField {
                        id: mediaFolderField
                        Layout.fillWidth: true
                        text: settingsManager ? settingsManager.mediaFolder : ""

                        Connections {
                            target: settingsManager
                            function onMediaFolderChanged() {
                                mediaFolderField.text = settingsManager.mediaFolder
                            }
                        }

                        onEditingFinished: {
                            if (text.trim() !== "" && settingsManager) {
                                settingsManager.save_media_folder(text)
                            }
                        }
                    }

                    SettingsButton {
                        text: "Browse"
                        Layout.preferredHeight: mediaFolderField.height
                        onClicked: folderDialog.open()
                    }

                    SettingsButton {
                        text: "Scan"
                        Layout.preferredHeight: mediaFolderField.height
                        onClicked: {
                            if (mediaManager) {
                                mediaManager.scan_library()
                            }
                        }
                    }

                    SettingsButton {
                        text: "Strip"
                        Layout.preferredHeight: mediaFolderField.height
                        onClicked: {
                            if (mediaManager) {
                                mediaManager.strip_filenames()
                            }
                        }
                    }
                }

                SettingDescription {
                    text: "Subfolders become playlists. Root MP3s go to 'Unsorted'."
                }

                // Terminal feedback for scan progress
                App.TerminalFeedback {
                    id: scanTerminal
                    Layout.fillWidth: true
                    Layout.preferredHeight: App.Spacing.dp(300)
                    Layout.topMargin: App.Spacing.rowSpacing
                    title: "Library Scan Terminal Output"

                    Connections {
                        target: mediaManager
                        function onScanProgress(message) {
                            scanTerminal.appendLine(message)
                        }
                    }
                }
            }
        }

        // ── Card 2: Playback ──
        SettingsCard {
            objectName: "Playback"
            cardId: "media_playback"
            title: "Playback"

            // Startup Volume
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Startup volume"
                }

                SettingsSlider {
                    id: volumeSlider
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: settingsManager ? settingsManager.startUpVolume : 0.5
                    visualValue: Math.round(Math.sqrt(value) * 100)
                    valueDisplay: visualValue + "%"
                    activeColor: App.Style.volumeSliderColor

                    Timer {
                        id: volumeUpdateTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_start_volume(volumeSlider.value)
                            }
                        }
                    }

                    onMoved: volumeUpdateTimer.restart()
                }

                ValueDisplay {
                    text: volumeSlider.valueDisplay
                }
            }

            SettingsDivider {}

            // Auto-Play on Startup
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: autoPlayToggle
                    Layout.fillWidth: true
                    text: "Autoplay on startup"
                    checked: settingsManager ? settingsManager.autoPlayOnStartup : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_auto_play_on_startup(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onAutoPlayOnStartupChanged() {
                            autoPlayToggle.checked = settingsManager.autoPlayOnStartup
                        }
                    }
                }
            }

            SettingsDivider {}

            // Music Button Default Page
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: musicButtonDefaultPageToggle
                    Layout.fillWidth: true
                    text: "Default to library view"
                    checked: settingsManager ? settingsManager.musicButtonDefaultPage === "mediaPlayer" : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_music_button_default_page(checked ? "mediaPlayer" : "mediaRoom")
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onMusicButtonDefaultPageChanged() {
                            musicButtonDefaultPageToggle.checked = settingsManager.musicButtonDefaultPage === "mediaPlayer"
                        }
                    }
                }
            }

            SettingsDivider {}

            // Return to Library After Selection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: returnToLibraryToggle
                    Layout.fillWidth: true
                    text: "Return to library after playing"
                    checked: settingsManager ? settingsManager.returnToLibraryAfterSelection : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_return_to_library_after_selection(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onReturnToLibraryAfterSelectionChanged() {
                            returnToLibraryToggle.checked = settingsManager.returnToLibraryAfterSelection
                        }
                    }
                }
            }
        }

        // ── Card 3: Album Art ──
        SettingsCard {
            objectName: "Album Art"
            cardId: "media_album_art"
            title: "Album Art"

            // Rounded Album Art
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: roundedAlbumArtToggle
                    Layout.fillWidth: true
                    text: "Rounded Corners"
                    checked: settingsManager ? settingsManager.roundedAlbumArt : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_rounded_album_art(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onRoundedAlbumArtChanged() {
                            roundedAlbumArtToggle.checked = settingsManager.roundedAlbumArt
                        }
                    }
                }

                SettingDescription {
                    text: "Apply rounded corners to album art in the media room."
                }
            }

            // Corner Radius (conditional on Rounded Corners)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.roundedAlbumArt

                SettingLabel {
                    text: "Corner Radius"
                }

                SettingsSlider {
                    id: cornerRadiusSlider
                    from: 2
                    to: 32
                    stepSize: 1
                    value: settingsManager ? settingsManager.albumArtCornerRadius : 16
                    activeColor: App.Style.accent

                    Timer {
                        id: cornerRadiusTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_album_art_corner_radius(cornerRadiusSlider.value)
                            }
                        }
                    }

                    onMoved: cornerRadiusTimer.restart()

                    Connections {
                        target: settingsManager
                        function onAlbumArtCornerRadiusChanged() {
                            cornerRadiusSlider.value = settingsManager.albumArtCornerRadius
                        }
                    }
                }

                ValueDisplay {
                    text: cornerRadiusSlider.value.toFixed(0) + " dp"
                }
            }

            SettingsDivider {}

            // Drop Shadow
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: albumArtShadowToggle
                    Layout.fillWidth: true
                    text: "Drop Shadow"
                    checked: settingsManager ? settingsManager.showAlbumArtShadow : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_album_art_shadow(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShowAlbumArtShadowChanged() {
                            albumArtShadowToggle.checked = settingsManager.showAlbumArtShadow
                        }
                    }
                }

                SettingDescription {
                    text: "Shadow behind the album art card for depth."
                }
            }

            SettingsDivider {}

            // Vinyl Record Mode
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: vinylRecordToggle
                    Layout.fillWidth: true
                    text: "Vinyl Record Mode"
                    checked: settingsManager ? settingsManager.vinylRecordMode : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_vinyl_record_mode(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onVinylRecordModeChanged() {
                            vinylRecordToggle.checked = settingsManager.vinylRecordMode
                        }
                    }
                }

                SettingDescription {
                    text: "Turn album art into a spinning vinyl record during playback."
                }
            }

            SettingsDivider {}

            // Album Art Transition
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Track Transition"
                }

                SettingsSegmentedControl {
                    id: albumArtTransitionControl
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.albumArtTransition : "Crossfade"
                    options: ["Crossfade", "Slide", "Vinyl Lift", "Dissolve", "Flip"]

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_album_art_transition(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onAlbumArtTransitionChanged() {
                            albumArtTransitionControl.currentValue = settingsManager.albumArtTransition
                        }
                    }
                }

                SettingDescription {
                    text: "Animation style when switching between tracks."
                }
            }

            SettingsDivider {}

            // 3D Album Preview
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: albumPreviewToggle
                    Layout.fillWidth: true
                    text: "3D Album Preview"
                    checked: settingsManager ? settingsManager.show3DAlbumPreview : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_3d_album_preview(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShow3DAlbumPreviewChanged() {
                            albumPreviewToggle.checked = settingsManager.show3DAlbumPreview
                        }
                    }
                }

                SettingDescription {
                    text: "Coverflow-style card stack showing next and previous album art with 3D rotation transitions."
                }
            }

            // 3D Preview Transition (conditional on 3D Album Preview)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.show3DAlbumPreview

                SettingLabel {
                    text: "3D Preview Transition"
                }

                SettingsSegmentedControl {
                    id: albumArt3DTransitionControl
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.albumArt3DTransition : "Coverflow"
                    options: ["Coverflow", "Conveyor", "Stack", "Depth", "Swing"]

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_album_art_3d_transition(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onAlbumArt3DTransitionChanged() {
                            albumArt3DTransitionControl.currentValue = settingsManager.albumArt3DTransition
                        }
                    }
                }

                SettingDescription {
                    text: "Animation style for the 3D album art card stack."
                }
            }

            // Side Card Opacity (conditional on 3D Album Preview)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.show3DAlbumPreview

                SettingLabel {
                    text: "Side Card Opacity"
                }

                SettingsSlider {
                    id: sideCardOpacitySlider
                    from: 0.1
                    to: 1.0
                    stepSize: 0.05
                    value: settingsManager ? settingsManager.sideCardOpacity : 0.4
                    activeColor: App.Style.accent

                    Timer {
                        id: sideCardOpacityTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_side_card_opacity(sideCardOpacitySlider.value)
                            }
                        }
                    }

                    onMoved: sideCardOpacityTimer.restart()

                    Connections {
                        target: settingsManager
                        function onSideCardOpacityChanged() {
                            sideCardOpacitySlider.value = settingsManager.sideCardOpacity
                        }
                    }
                }

                ValueDisplay {
                    text: Math.round(sideCardOpacitySlider.value * 100) + "%"
                }
            }

            // Side Card Angle (conditional on 3D Album Preview)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.show3DAlbumPreview

                SettingLabel {
                    text: "Side Card Angle"
                }

                SettingsSlider {
                    id: sideCardAngleSlider
                    from: 5
                    to: 60
                    stepSize: 1
                    value: settingsManager ? settingsManager.sideCardAngle : 30
                    activeColor: App.Style.accent

                    Timer {
                        id: sideCardAngleTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_side_card_angle(sideCardAngleSlider.value)
                            }
                        }
                    }

                    onMoved: sideCardAngleTimer.restart()

                    Connections {
                        target: settingsManager
                        function onSideCardAngleChanged() {
                            sideCardAngleSlider.value = settingsManager.sideCardAngle
                        }
                    }
                }

                ValueDisplay {
                    text: sideCardAngleSlider.value.toFixed(0) + "°"
                }
            }

            SettingsDivider {}

            // Album Art Layout
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Background Layout"
                }

                SettingsSegmentedControl {
                    id: backgroundGridButton
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.backgroundGrid : "4x4"
                    options: ["Normal", "2x2", "4x4"]

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_background_grid(value)
                        }
                    }
                }

                SettingDescription {
                    text: "Grid layout for the album art background behind the player."
                }
            }
        }

        // ── Card 4: Background ──
        SettingsCard {
            objectName: "Background"
            cardId: "media_background"
            title: "Background"

            // Album Art Blur
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Album Art Blur"
                }

                SettingsSlider {
                    id: blurRadiusSlider
                    from: 0
                    to: 100
                    stepSize: 1
                    value: settingsManager ? settingsManager.backgroundBlurRadius : 40
                    activeColor: App.Style.accent

                    Timer {
                        id: blurUpdateTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_background_blur_radius(blurRadiusSlider.value)
                            }
                        }
                    }

                    onMoved: blurUpdateTimer.restart()
                }

                ValueDisplay {
                    text: blurRadiusSlider.value.toFixed(0)
                }

                SettingDescription {
                    text: "Gaussian blur intensity on the background album art grid."
                }
            }

            SettingsDivider {}

            // Dark Overlay
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: backgroundOverlayToggle
                    Layout.fillWidth: true
                    text: "Dark Overlay"
                    checked: settingsManager ? settingsManager.showBackgroundOverlay : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_background_overlay(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShowBackgroundOverlayChanged() {
                            backgroundOverlayToggle.checked = settingsManager.showBackgroundOverlay
                        }
                    }
                }

                SettingDescription {
                    text: "Semi-transparent dark layer over the background for readability."
                }
            }

            // Overlay Opacity (conditional on Dark Overlay)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.showBackgroundOverlay

                SettingLabel {
                    text: "Overlay Opacity"
                }

                SettingsSlider {
                    id: overlayOpacitySlider
                    from: 0
                    to: 100
                    stepSize: 1
                    value: settingsManager ? settingsManager.backgroundOverlayOpacity : 80
                    activeColor: App.Style.accent

                    Timer {
                        id: overlayOpacityTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_background_overlay_opacity(overlayOpacitySlider.value)
                            }
                        }
                    }

                    onMoved: overlayOpacityTimer.restart()

                    Connections {
                        target: settingsManager
                        function onBackgroundOverlayOpacityChanged() {
                            overlayOpacitySlider.value = settingsManager.backgroundOverlayOpacity
                        }
                    }
                }

                ValueDisplay {
                    text: overlayOpacitySlider.value.toFixed(0) + "%"
                }
            }
        }

        // ── Card 5: Effects ──
        SettingsCard {
            objectName: "Effects"
            cardId: "media_effects"
            title: "Effects"

            // Waveform Visualizer
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: waveformVisualizerToggle
                    Layout.fillWidth: true
                    text: "Waveform Visualizer"
                    checked: settingsManager ? settingsManager.showWaveformVisualizer : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_waveform_visualizer(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShowWaveformVisualizerChanged() {
                            waveformVisualizerToggle.checked = settingsManager.showWaveformVisualizer
                        }
                    }
                }

                SettingDescription {
                    text: "Animated waveform in Now Playing, themed to match."
                }
            }

            // Visualizer Quality (conditional on Waveform Visualizer)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.showWaveformVisualizer

                SettingLabel {
                    text: "Visualizer Quality"
                }

                SettingsSegmentedControl {
                    id: visualizerQualityControl
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.visualizerQuality : "Medium"
                    options: ["Low", "Medium", "High", "Extreme", "Insane"]

                    onSelected: function(value) {
                        if (settingsManager) {
                            settingsManager.save_visualizer_quality(value)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onVisualizerQualityChanged() {
                            visualizerQualityControl.currentValue = settingsManager.visualizerQuality
                        }
                    }
                }

                SettingDescription {
                    text: {
                        var q = settingsManager ? settingsManager.visualizerQuality : "Medium"
                        if (q === "Low") return "16 bars, lowest CPU usage."
                        if (q === "High") return "48 bars with smooth animation. Higher CPU usage."
                        if (q === "Extreme") return "64 bars at 30 FPS with smooth animation. Will eat your CPU alive."
                        if (q === "Insane") return "96 bars at 60 FPS. God help your CPU."
                        return "32 bars, balanced performance."
                    }
                }
            }

            SettingsDivider {}

            // 3D Button Tilt
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsToggle {
                    id: buttonTiltToggle
                    Layout.fillWidth: true
                    text: "3D Button Tilt"
                    checked: settingsManager ? settingsManager.show3DButtonTilt : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) {
                            settingsManager.save_show_3d_button_tilt(checked)
                        }
                    }

                    Connections {
                        target: settingsManager
                        function onShow3DButtonTiltChanged() {
                            buttonTiltToggle.checked = settingsManager.show3DButtonTilt
                        }
                    }
                }

                SettingDescription {
                    text: "3D tilt and scale effect when pressing playback buttons."
                }
            }

            // Tilt Duration (conditional on 3D Button Tilt)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing
                visible: settingsManager && settingsManager.show3DButtonTilt

                SettingLabel {
                    text: "Tilt Duration"
                }

                SettingsSlider {
                    id: buttonTiltDurationSlider
                    from: 50
                    to: 500
                    stepSize: 10
                    value: settingsManager ? settingsManager.buttonTiltDuration : 200
                    activeColor: App.Style.accent

                    Timer {
                        id: buttonTiltDurationTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_button_tilt_duration(buttonTiltDurationSlider.value)
                            }
                        }
                    }

                    onMoved: buttonTiltDurationTimer.restart()

                    Connections {
                        target: settingsManager
                        function onButtonTiltDurationChanged() {
                            buttonTiltDurationSlider.value = settingsManager.buttonTiltDuration
                        }
                    }
                }

                ValueDisplay {
                    text: buttonTiltDurationSlider.value.toFixed(0) + " ms"
                }
            }

            SettingsDivider {}

            // Text Scroll Speed (always visible)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Text Scroll Speed"
                }

                SettingsSlider {
                    id: textScrollSpeedSlider
                    from: 1000
                    to: 10000
                    stepSize: 500
                    value: settingsManager ? settingsManager.textScrollSpeed : 5000
                    activeColor: App.Style.accent

                    Timer {
                        id: textScrollSpeedTimer
                        interval: 100
                        running: false
                        repeat: false
                        onTriggered: {
                            if (settingsManager) {
                                settingsManager.save_text_scroll_speed(textScrollSpeedSlider.value)
                            }
                        }
                    }

                    onMoved: textScrollSpeedTimer.restart()

                    Connections {
                        target: settingsManager
                        function onTextScrollSpeedChanged() {
                            textScrollSpeedSlider.value = settingsManager.textScrollSpeed
                        }
                    }
                }

                ValueDisplay {
                    text: (textScrollSpeedSlider.value / 1000).toFixed(1) + " s"
                }

                SettingDescription {
                    text: "Duration for scrolling long song titles and metadata. Lower is faster."
                }
            }
        }

        // ── Card 6: Spotify ──
        SettingsCard {
            objectName: "Spotify"
            cardId: "media_spotify"
            title: "Spotify"

            // Spotify Connect Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingLabel {
                    text: "Spotify Connect"
                }

                SettingDescription {
                    text: "Get credentials from developer.spotify.com"
                }

                // Credentials row with Client ID and Secret
                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    // Client ID field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.dp(4)

                        Text {
                            text: "Client ID"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText - 2
                            font.family: App.Style.fontFamily
                        }

                        SettingsTextField {
                            id: spotifyClientIdField
                            Layout.fillWidth: true
                            text: settingsManager ? settingsManager.get_spotify_client_id() : ""

                            onEditingFinished: {
                                if (settingsManager && text.trim() !== "") {
                                    settingsManager.save_spotify_credentials(
                                        text.trim(),
                                        spotifyClientSecretField.text.trim()
                                    )
                                }
                            }

                            Connections {
                                target: settingsManager
                                function onSpotifyCredentialsChanged() {
                                    spotifyClientIdField.text = settingsManager.get_spotify_client_id()
                                }
                            }
                        }
                    }

                    // Client Secret field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.dp(4)

                        Text {
                            text: "Client Secret"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText - 2
                            font.family: App.Style.fontFamily
                        }

                        SettingsTextField {
                            id: spotifyClientSecretField
                            Layout.fillWidth: true
                            text: settingsManager ? settingsManager.get_spotify_client_secret() : ""
                            echoMode: TextInput.Password

                            onEditingFinished: {
                                if (settingsManager && text.trim() !== "") {
                                    settingsManager.save_spotify_credentials(
                                        spotifyClientIdField.text.trim(),
                                        text.trim()
                                    )
                                }
                            }

                            Connections {
                                target: settingsManager
                                function onSpotifyCredentialsChanged() {
                                    spotifyClientSecretField.text = settingsManager.get_spotify_client_secret()
                                }
                            }
                        }
                    }
                }

                // Action buttons row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsButton {
                        text: "Connect"
                        Layout.preferredHeight: spotifyClientIdField.height
                        visible: spotifyManager && !spotifyManager.is_connected()
                        tooltipText: "Connect to Spotify"
                        onClicked: {
                            if (spotifyManager) spotifyManager.authenticate()
                        }
                    }

                    SettingsButton {
                        text: "Disconnect"
                        Layout.preferredHeight: spotifyClientIdField.height
                        Layout.minimumWidth: App.Spacing.dp(90)
                        visible: spotifyManager && spotifyManager.is_connected()
                        buttonColor: App.Style.statusDanger
                        tooltipText: "Disconnect from Spotify"
                        onClicked: {
                            if (spotifyManager) spotifyManager.disconnect()
                        }
                    }

                    SettingsButton {
                        text: "Refresh"
                        Layout.preferredHeight: spotifyClientIdField.height
                        visible: spotifyManager && spotifyManager.is_connected()
                        tooltipText: "Refresh available devices"
                        onClicked: {
                            if (spotifyManager) spotifyManager.refresh_devices()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Terminal feedback for Spotify connection
                App.TerminalFeedback {
                    id: spotifyTerminal
                    Layout.fillWidth: true
                    Layout.preferredHeight: App.Spacing.dp(300)
                    title: "Spotify Connection Terminal Output"

                    Connections {
                        target: spotifyManager
                        function onStatusProgress(message) {
                            spotifyTerminal.appendLine(message)
                        }
                        function onAuthUrlReady(url) {
                            spotifyTerminal.appendLine("[INFO] Auth URL ready - opening browser...")
                            spotifyAuthUrlText.text = url
                            spotifyAuthUrlText.visible = true
                        }
                        function onConnectionStateChanged(connected) {
                            spotifyAuthUrlText.visible = false
                            if (connected && spotifyManager) {
                                spotifyManager.refresh_devices()
                            }
                        }
                    }
                }

                // Clickable auth URL (fallback if browser doesn't open)
                Text {
                    id: spotifyAuthUrlText
                    Layout.fillWidth: true
                    visible: false
                    color: App.Style.accent
                    font.pixelSize: App.Spacing.overallText - 2
                    font.underline: true
                    font.family: App.Style.fontFamily
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideMiddle
                    maximumLineCount: 2

                    ToolTip.visible: authUrlMouseArea.containsMouse
                    ToolTip.text: "Click to open in browser"
                    ToolTip.delay: 300

                    MouseArea {
                        id: authUrlMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Qt.openUrlExternally(spotifyAuthUrlText.text)
                        }
                    }
                }

                // Available devices list (when connected)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: spotifyManager && spotifyManager.is_connected()
                    spacing: App.Spacing.overallSpacing

                    Text {
                        text: "Available Devices"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                    }

                    // Chip-style device selector
                    Flow {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing

                        Repeater {
                            id: spotifyDevicesRepeater
                            model: mediaSettingsRoot.spotifyDevicesList

                            Rectangle {
                                id: deviceChip
                                width: deviceChipText.width + App.Spacing.overallSpacing * 3
                                height: App.Spacing.formElementHeight * 0.8
                                radius: height / 2
                                color: modelData.is_active ? App.Style.accent : App.Style.hoverColor
                                border.width: modelData.is_active ? 0 : 1
                                border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                    App.Style.primaryTextColor.g,
                                                    App.Style.primaryTextColor.b, 0.1)

                                Text {
                                    id: deviceChipText
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: modelData.is_active ? "white" : App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: App.Style.fontFamily
                                }

                                MouseArea {
                                    id: deviceChipMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (spotifyManager && !modelData.is_active) {
                                            spotifyManager.set_active_device(modelData.id)
                                        }
                                    }
                                    onEntered: deviceChip.scale = 1.05
                                    onExited: deviceChip.scale = 1.0
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                layer.enabled: modelData.is_active
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                }
                            }
                        }
                    }

                    Text {
                        visible: spotifyDevicesRepeater.count === 0
                        text: "No devices found. Open Spotify on a device first."
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: App.Style.fontFamily
                        font.italic: true
                    }
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
