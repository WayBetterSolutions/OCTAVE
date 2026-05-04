import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import ".." as App

Flickable {
    id: pageRoot

    // Local dp/dpMin wrappers — work around Qt Android singleton-function bug.
    function dp(size) { return Math.round(size * (App.Spacing.effectiveScale || 1.0)) }
    function dpMin(size, floor) { return Math.max(floor, Math.round(size * (App.Spacing.effectiveScale || 1.0))) }

    property var stackView: null
    property var mainWindow: null
    property string currentSection: ""

    // Reactive property for Spotify devices
    property var spotifyDevicesList: []

    // Tile model — consumed by SettingsSidebarLayout (grid + slide-in popup).
    property var tileModel: [
        { cardId: "media_library",     title: "Library",     icon: "♪", component: libraryContent },
        { cardId: "media_playback",    title: "Playback",    icon: "▶", component: playbackContent },
        { cardId: "media_now_playing", title: "Now Playing", icon: "❒", component: nowPlayingContent },
        { cardId: "media_spotify",     title: "Spotify",     icon: "♫", component: spotifyContent }
    ]

    // Refresh Spotify devices when navigating to media settings
    onCurrentSectionChanged: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
    }

    Component.onCompleted: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
        if (spotifyManager && spotifyManager.is_connected()) {
            spotifyDevicesList = spotifyManager.get_devices()
        }
    }

    Connections {
        target: spotifyManager
        function onDevicesChanged(devices) {
            pageRoot.spotifyDevicesList = devices
        }
        function onConnectionStateChanged(connected) {
            if (connected) {
                spotifyManager.refresh_devices()
            } else {
                pageRoot.spotifyDevicesList = []
            }
        }
    }

    // Folder dialog for selecting music library folder.
    // On Android, this opens Storage Access Framework — the selectedFolder is
    // a content:// tree URI, not a filesystem path. We decode the SAF URI for
    // external primary storage back to a /storage/emulated/0/... path.
    FolderDialog {
        id: folderDialog
        title: "Select Music Library Folder"
        onAccepted: {
            var path = selectedFolder.toString()

            if (path.startsWith("content://")) {
                var treeIdx = path.indexOf("/tree/")
                if (treeIdx >= 0) {
                    var encoded = path.substring(treeIdx + 6)
                    var decoded = decodeURIComponent(encoded)
                    if (decoded.indexOf("primary:") === 0) {
                        path = "/storage/emulated/0/" + decoded.substring(8)
                    } else {
                        path = decoded
                    }
                }
            } else if (path.startsWith("file:///")) {
                var afterScheme = path.substring(8)
                if (afterScheme.length > 1 && afterScheme.charAt(1) === ':') {
                    path = afterScheme
                } else {
                    path = path.substring(7)
                }
            }

            if (settingsManager) {
                settingsManager.save_media_folder(path)
            }
        }
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

    // ─────────────────────────────────────────── Library
    Component {
        id: libraryContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Library Folder"
                description: "Subfolders become playlists. Root MP3s go to 'Unsorted'."

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

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
                                if (mediaManager) mediaManager.scan_library()
                            }
                        }

                        SettingsButton {
                            text: "Strip"
                            Layout.preferredHeight: mediaFolderField.height
                            onClicked: {
                                if (mediaManager) mediaManager.strip_filenames()
                            }
                        }
                    }

                    App.TerminalFeedback {
                        id: scanTerminal
                        Layout.fillWidth: true
                        Layout.preferredHeight: pageRoot.dp(300)
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
        }
    }

    // ─────────────────────────────────────────── Playback
    Component {
        id: playbackContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Startup Volume"
                description: "Volume level applied when the app launches."

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsSlider {
                        id: volumeSlider
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: settingsManager ? settingsManager.startUpVolume : 0.5
                        visualValue: Math.round(Math.sqrt(value) * 100)
                        valueDisplay: visualValue + "%"
                        activeColor: App.Style.volumeSliderColor
                        Layout.fillWidth: true

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
                        Layout.fillWidth: false
                    }
                }
            }

            SettingCategory {
                title: "Autoplay on Startup"
                description: "Resume the last track automatically when the app launches."

                SettingsToggle {
                    id: autoPlayToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.autoPlayOnStartup : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_auto_play_on_startup(checked)
                    }

                    Connections {
                        target: settingsManager
                        function onAutoPlayOnStartupChanged() {
                            autoPlayToggle.checked = settingsManager.autoPlayOnStartup
                        }
                    }
                }
            }

            SettingCategory {
                title: "Remember Shuffle State"
                description: "Persist shuffle on/off across app restarts."

                SettingsToggle {
                    id: persistShuffleToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.persistShuffleState : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_persist_shuffle_state(checked)
                    }

                    Connections {
                        target: settingsManager
                        function onPersistShuffleStateChanged() {
                            persistShuffleToggle.checked = settingsManager.persistShuffleState
                        }
                    }
                }
            }

            SettingCategory {
                title: "Default to Library View"
                description: "When opening Music, show the library list instead of the now-playing screen."

                SettingsToggle {
                    id: musicButtonDefaultPageToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
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

            SettingCategory {
                title: "Return to Library After Playing"
                description: "Bounce back to the library list once a track has been queued from it."

                SettingsToggle {
                    id: returnToLibraryToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.returnToLibraryAfterSelection : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_return_to_library_after_selection(checked)
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
    }

    // ─────────────────────────────────────────── Now Playing
    Component {
        id: nowPlayingContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Rounded Corners"
                description: "Apply rounded corners to album art in the media room."

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    SettingsToggle {
                        id: roundedAlbumArtToggle
                        compact: true
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignLeft
                        text: checked ? "On" : "Off"
                        checked: settingsManager ? settingsManager.roundedAlbumArt : true
                        activeColor: App.Style.accent
                        inactiveColor: App.Style.hoverColor

                        onToggled: function(checked) {
                            if (settingsManager) settingsManager.save_rounded_album_art(checked)
                        }

                        Connections {
                            target: settingsManager
                            function onRoundedAlbumArtChanged() {
                                roundedAlbumArtToggle.checked = settingsManager.roundedAlbumArt
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing
                        visible: settingsManager && settingsManager.roundedAlbumArt

                        SettingsSlider {
                            id: cornerRadiusSlider
                            from: 2
                            to: 32
                            stepSize: 1
                            value: settingsManager ? settingsManager.albumArtCornerRadius : 16
                            activeColor: App.Style.accent
                            Layout.fillWidth: true

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
                            Layout.fillWidth: false
                        }
                    }
                }
            }

            SettingCategory {
                title: "Drop Shadow"
                description: "Shadow behind the album art card for depth."

                SettingsToggle {
                    id: albumArtShadowToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.showAlbumArtShadow : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_show_album_art_shadow(checked)
                    }

                    Connections {
                        target: settingsManager
                        function onShowAlbumArtShadowChanged() {
                            albumArtShadowToggle.checked = settingsManager.showAlbumArtShadow
                        }
                    }
                }
            }

            SettingCategory {
                title: "Track Transition"
                description: "Animation style when switching between tracks."

                SettingsSegmentedControl {
                    id: albumArtTransitionControl
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.albumArtTransition : "Crossfade"
                    options: ["Crossfade", "Slide", "Vinyl Lift", "Dissolve", "Flip"]

                    onSelected: function(value) {
                        if (settingsManager) settingsManager.save_album_art_transition(value)
                    }

                    Connections {
                        target: settingsManager
                        function onAlbumArtTransitionChanged() {
                            albumArtTransitionControl.currentValue = settingsManager.albumArtTransition
                        }
                    }
                }
            }

            SettingCategory {
                title: "Vinyl Record Mode"
                description: "Turn album art into a spinning vinyl record during playback."

                SettingsToggle {
                    id: vinylRecordToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.vinylRecordMode : false
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_vinyl_record_mode(checked)
                    }

                    Connections {
                        target: settingsManager
                        function onVinylRecordModeChanged() {
                            vinylRecordToggle.checked = settingsManager.vinylRecordMode
                        }
                    }
                }
            }

            SettingCategory {
                title: "3D Album Preview"
                description: "Coverflow-style card stack showing next and previous album art with 3D rotation."

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    SettingsToggle {
                        id: albumPreviewToggle
                        compact: true
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignLeft
                        text: checked ? "On" : "Off"
                        checked: settingsManager ? settingsManager.show3DAlbumPreview : false
                        activeColor: App.Style.accent
                        inactiveColor: App.Style.hoverColor

                        onToggled: function(checked) {
                            if (settingsManager) settingsManager.save_show_3d_album_preview(checked)
                        }

                        Connections {
                            target: settingsManager
                            function onShow3DAlbumPreviewChanged() {
                                albumPreviewToggle.checked = settingsManager.show3DAlbumPreview
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.rowSpacing
                        visible: settingsManager && settingsManager.show3DAlbumPreview

                        SettingLabel { text: "3D Preview Transition" }

                        SettingsSegmentedControl {
                            id: albumArt3DTransitionControl
                            Layout.fillWidth: true
                            currentValue: settingsManager ? settingsManager.albumArt3DTransition : "Coverflow"
                            options: ["Coverflow", "Conveyor", "Stack", "Depth", "Swing"]

                            onSelected: function(value) {
                                if (settingsManager) settingsManager.save_album_art_3d_transition(value)
                            }

                            Connections {
                                target: settingsManager
                                function onAlbumArt3DTransitionChanged() {
                                    albumArt3DTransitionControl.currentValue = settingsManager.albumArt3DTransition
                                }
                            }
                        }

                        SettingLabel { text: "Side Card Opacity"; Layout.topMargin: App.Spacing.rowSpacing }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: App.Spacing.overallSpacing

                            SettingsSlider {
                                id: sideCardOpacitySlider
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: settingsManager ? settingsManager.sideCardOpacity : 0.4
                                activeColor: App.Style.accent
                                Layout.fillWidth: true

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
                                Layout.fillWidth: false
                            }
                        }

                        SettingLabel { text: "Side Card Angle"; Layout.topMargin: App.Spacing.rowSpacing }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: App.Spacing.overallSpacing

                            SettingsSlider {
                                id: sideCardAngleSlider
                                from: 5
                                to: 60
                                stepSize: 1
                                value: settingsManager ? settingsManager.sideCardAngle : 30
                                activeColor: App.Style.accent
                                Layout.fillWidth: true

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
                                Layout.fillWidth: false
                            }
                        }
                    }
                }
            }

            SettingCategory {
                title: "Text Scroll Speed"
                description: "Duration for scrolling long song titles and metadata. Lower is faster."

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsSlider {
                        id: textScrollSpeedSlider
                        from: 1000
                        to: 10000
                        stepSize: 500
                        value: settingsManager ? settingsManager.textScrollSpeed : 5000
                        activeColor: App.Style.accent
                        Layout.fillWidth: true

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
                        Layout.fillWidth: false
                    }
                }
            }

            SettingCategory {
                title: "Waveform Visualizer"
                description: "Animated waveform in Now Playing, themed to match."

                SettingsToggle {
                    id: waveformVisualizerToggle
                    compact: true
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    text: checked ? "On" : "Off"
                    checked: settingsManager ? settingsManager.showWaveformVisualizer : true
                    activeColor: App.Style.accent
                    inactiveColor: App.Style.hoverColor

                    onToggled: function(checked) {
                        if (settingsManager) settingsManager.save_show_waveform_visualizer(checked)
                    }

                    Connections {
                        target: settingsManager
                        function onShowWaveformVisualizerChanged() {
                            waveformVisualizerToggle.checked = settingsManager.showWaveformVisualizer
                        }
                    }
                }
            }

            SettingCategory {
                title: "3D Button Tilt"
                description: "3D tilt and scale effect when pressing playback buttons."

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    SettingsToggle {
                        id: buttonTiltToggle
                        compact: true
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignLeft
                        text: checked ? "On" : "Off"
                        checked: settingsManager ? settingsManager.show3DButtonTilt : false
                        activeColor: App.Style.accent
                        inactiveColor: App.Style.hoverColor

                        onToggled: function(checked) {
                            if (settingsManager) settingsManager.save_show_3d_button_tilt(checked)
                        }

                        Connections {
                            target: settingsManager
                            function onShow3DButtonTiltChanged() {
                                buttonTiltToggle.checked = settingsManager.show3DButtonTilt
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.rowSpacing
                        visible: settingsManager && settingsManager.show3DButtonTilt

                        SettingLabel { text: "Tilt Duration" }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: App.Spacing.overallSpacing

                            SettingsSlider {
                                id: buttonTiltDurationSlider
                                from: 50
                                to: 500
                                stepSize: 10
                                value: settingsManager ? settingsManager.buttonTiltDuration : 200
                                activeColor: App.Style.accent
                                Layout.fillWidth: true

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
                                Layout.fillWidth: false
                            }
                        }
                    }
                }
            }

            SettingCategory {
                title: "Background Layout"
                description: "Grid layout for the album art tiled across the background."

                SettingsSegmentedControl {
                    id: backgroundGridButton
                    Layout.fillWidth: true
                    currentValue: settingsManager ? settingsManager.backgroundGrid : "4x4"
                    options: ["Normal", "2x2", "4x4"]

                    onSelected: function(value) {
                        if (settingsManager) settingsManager.save_background_grid(value)
                    }
                }
            }

            SettingCategory {
                title: "Background Blur"
                description: "Gaussian blur intensity on the background album art grid."

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    SettingsSlider {
                        id: blurRadiusSlider
                        from: 0
                        to: 100
                        stepSize: 1
                        value: settingsManager ? settingsManager.backgroundBlurRadius : 40
                        activeColor: App.Style.accent
                        Layout.fillWidth: true

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
                        Layout.fillWidth: false
                    }
                }
            }

            SettingCategory {
                title: "Background Dark Overlay"
                description: "Semi-transparent dark layer over the background for readability."

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    SettingsToggle {
                        id: backgroundOverlayToggle
                        compact: true
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignLeft
                        text: checked ? "On" : "Off"
                        checked: settingsManager ? settingsManager.showBackgroundOverlay : true
                        activeColor: App.Style.accent
                        inactiveColor: App.Style.hoverColor

                        onToggled: function(checked) {
                            if (settingsManager) settingsManager.save_show_background_overlay(checked)
                        }

                        Connections {
                            target: settingsManager
                            function onShowBackgroundOverlayChanged() {
                                backgroundOverlayToggle.checked = settingsManager.showBackgroundOverlay
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.rowSpacing
                        visible: settingsManager && settingsManager.showBackgroundOverlay

                        SettingLabel { text: "Overlay Opacity" }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: App.Spacing.overallSpacing

                            SettingsSlider {
                                id: overlayOpacitySlider
                                from: 0
                                to: 100
                                stepSize: 1
                                value: settingsManager ? settingsManager.backgroundOverlayOpacity : 80
                                activeColor: App.Style.accent
                                Layout.fillWidth: true

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
                                Layout.fillWidth: false
                            }
                        }
                    }
                }
            }

        }
    }

    // ─────────────────────────────────────────── Spotify
    Component {
        id: spotifyContent
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: App.Spacing.sectionSpacing

            SettingCategory {
                title: "Spotify Connect"
                description: "Get credentials from developer.spotify.com"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.rowSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: pageRoot.dp(4)

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

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: pageRoot.dp(4)

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
                            Layout.minimumWidth: pageRoot.dp(90)
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

                    App.TerminalFeedback {
                        id: spotifyTerminal
                        Layout.fillWidth: true
                        Layout.preferredHeight: pageRoot.dp(300)
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
                            onClicked: Qt.openUrlExternally(spotifyAuthUrlText.text)
                        }
                    }
                }
            }

            SettingCategory {
                title: "Available Devices"
                description: "Tap a device to make it the active Spotify Connect target."
                visible: spotifyManager && spotifyManager.is_connected()

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    Flow {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing

                        Repeater {
                            id: spotifyDevicesRepeater
                            model: pageRoot.spotifyDevicesList

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

                                Behavior on scale { NumberAnimation { duration: 100 } }

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

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
