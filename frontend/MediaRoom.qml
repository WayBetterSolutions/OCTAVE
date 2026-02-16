import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Basic 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: mediaRoom
    objectName: "mediaRoom"
    property StackView stackView
    property ApplicationWindow mainWindow

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Global colors
    property color backgroundColor: "black"
    property color transparentColor: "transparent"

    //property color textColor: "white"
    property color sliderBackgroundColor: "#424242"
    property color sliderGradientStart: "#000000"
    property color sliderGradientEnd: "#a11212"
    property color sliderHandleNormal: "#808080"
    property color sliderHandlePressed: "#666666"
    property real buttonPressedOpacity: 0.7
    property real buttonNormalOpacity: 1.0

    property int duration: 0
    property int position: 0
    property bool userSeeking: false

    property color accent: "#a11212"
    
    property bool isShuffleEnabled: false

    // Spotify integration - use Spotify when user chooses it AND it's connected
    property bool useSpotify: settingsManager && settingsManager.mediaSource === "spotify" &&
                              spotifyManager && spotifyManager.is_connected()

    // Check if Spotify is available (connected) for showing toggle
    property bool spotifyAvailable: spotifyManager && spotifyManager.is_connected()

    // Spotify track info (updated directly from signals)
    property string spotifyTrackName: ""
    property string spotifyArtist: ""
    property string spotifyAlbum: ""
    property string spotifyAlbumArt: ""

    // Track info that works for both local and Spotify
    property string currentTrackName: {
        if (useSpotify && spotifyTrackName) {
            return spotifyTrackName
        }
        return currentSongText.text ? (mediaManager ? mediaManager.get_display_name(currentSongText.text) : currentSongText.text.replace('.mp3', '')) : ""
    }

    property string currentArtist: {
        if (useSpotify && spotifyArtist) {
            return spotifyArtist
        }
        return currentSongText.text ? (mediaManager ? mediaManager.get_band(currentSongText.text) : "Unknown Artist") : "Unknown Artist"
    }

    property string currentAlbum: {
        if (useSpotify && spotifyAlbum) {
            return spotifyAlbum
        }
        return currentSongText.text ? (mediaManager ? mediaManager.get_album(currentSongText.text) : "Unknown Album") : "Unknown Album"
    }

    property string currentAlbumArt: {
        if (useSpotify && spotifyAlbumArt) {
            return spotifyAlbumArt
        }
        return currentSongText.text ? (mediaManager ? mediaManager.get_album_art(currentSongText.text) || "./assets/missing_art.png" : "./assets/missing_art.png") : "./assets/missing_art.png"
    }

    // Card stack -- peek at adjacent tracks
    property int _trackChangeCounter: 0  // bumped on track change to force re-evaluation
    property int _slideDirection: 1      // 1 = next (slide from right), -1 = prev (slide from left)
    property string _previousAlbumArt: "" // cached old art for exit card during transitions

    // Resolved album art source — tracks currentAlbumArt but falls back to
    // missing_art.png if the image fails to load (e.g. corrupted extract, stale cache)
    property string _displayAlbumArt: currentAlbumArt
    onCurrentAlbumArtChanged: _displayAlbumArt = currentAlbumArt

    property string nextAlbumArt: {
        // depend on counter so bindings re-evaluate on track change
        var _dep = _trackChangeCounter
        if (useSpotify && spotifyManager) {
            var info = spotifyManager.get_next_track_info()
            if (info) {
                try { return JSON.parse(info).image || "" } catch(e) { return "" }
            }
            return ""
        }
        return mediaManager ? mediaManager.get_next_track_album_art() : ""
    }

    property string prevAlbumArt: {
        var _dep = _trackChangeCounter
        if (useSpotify && spotifyManager) {
            var info = spotifyManager.get_previous_track_info()
            if (info) {
                try { return JSON.parse(info).image || "" } catch(e) { return "" }
            }
            return ""
        }
        return mediaManager ? mediaManager.get_previous_track_album_art() : ""
    }

    function formatTime(ms) {
        var minutes = Math.floor(ms / 60000)
        var seconds = Math.floor((ms % 60000) / 1000)
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function animateTrackChange() {
        if (settingsManager && settingsManager.show3DAlbumPreview) albumArtStack.triggerSlide()
    }

    Rectangle {
        id: mainContent        
        anchors.fill: parent
        color: transparentColor

        Item { //background
            id: backgroundContainer
            anchors.fill: parent
            z: -1  

            Grid {
                id: albumArtGrid
                anchors.fill: parent
                columns: {
                    if (settingsManager) {
                        switch(settingsManager.backgroundGrid) {
                            case "Normal": return 1;
                            case "2x2": return 2;
                            case "4x4": return 4;
                            default: return 4;
                        }
                    }
                    return 4; // default fallback
                }
                spacing: 0

                // Single blur on the entire grid instead of per-cell (16x cheaper on 4x4)
                // Freeze blur texture during card animation — avoids a full-screen
                // multi-pass re-render when grid images change source mid-transition
                layer.enabled: true
                layer.live: !cardRotateAnimation.running
                layer.effect: GaussianBlur {
                    radius: settingsManager ? settingsManager.backgroundBlurRadius : 40
                    samples: Math.min(32, Math.max(1, radius))
                    deviation: radius / 2.5
                    transparentBorder: false
                }

                Repeater {
                    id: gridRepeater
                    model: {
                        if (settingsManager) {
                            switch(settingsManager.backgroundGrid) {
                                case "Normal": return 1;
                                case "2x2": return 4;
                                case "4x4": return 16;
                                default: return 16;
                            }
                        }
                        return 16; // default fallback
                    }

                    delegate: Item {
                        width: backgroundContainer.width / albumArtGrid.columns
                        height: backgroundContainer.height / albumArtGrid.columns

                        Image {
                            id: gridImage
                            anchors.fill: parent
                            source: mediaRoom._displayAlbumArt || "./assets/missing_art.png"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }
            Rectangle { // Black layer
                id: colorOverlay
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, (settingsManager ? settingsManager.backgroundOverlayOpacity : 80) / 100)
                opacity: settingsManager && settingsManager.showBackgroundOverlay ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                }
                layer.enabled: true
            }
        }


        Component.onCompleted: {
            if (useSpotify && spotifyManager) {
                mediaRoom.duration = spotifyManager.get_duration()
                mediaRoom.position = spotifyManager.get_position()
                isShuffleEnabled = spotifyManager.is_shuffled()
                // Initialize Spotify track info
                mediaRoom.spotifyTrackName = spotifyManager.get_current_track_name()
                mediaRoom.spotifyArtist = spotifyManager.get_current_artist()
                mediaRoom.spotifyAlbum = spotifyManager.get_current_album()
                mediaRoom.spotifyAlbumArt = spotifyManager.get_current_album_art()
            } else if (mediaManager) {
                mediaRoom.duration = mediaManager.get_duration()
                mediaRoom.position = mediaManager.get_position()
                var currentFile = mediaManager.get_current_file()
                if (currentFile) {
                    currentSongText.text = currentFile
                }
                isShuffleEnabled = mediaManager.is_shuffled()
            }
            // Force initial evaluation of side card art
            mediaRoom._trackChangeCounter++
            mediaRoom._previousAlbumArt = mediaRoom._displayAlbumArt
        }

        Rectangle { // Volume control at top
            id: topVolumeControl
            width: parent.width * 0.75
            height: App.Spacing.mediaRoomDurationBarHeight
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: App.Spacing.mediaRoomMargin
            }
            color: transparentColor
            
            RowLayout {
                anchors.fill: parent
                spacing: App.Spacing.dp(10)

                // Volume icon control
                Control {
                    id: volumeIconControl
                    implicitWidth: App.Spacing.bottomBarMuteButtonWidth
                    implicitHeight: App.Spacing.bottomBarMuteButtonHeight
                    Layout.alignment: Qt.AlignVCenter
                    
                    background: Rectangle { color: "transparent" }
                    
                    contentItem: Item {
                        Image {
                            id: volumeIconImage
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            source: getVolumeIconSource()
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                            mipmap: false
                            visible: false
                        }
                        
                        ColorOverlay {
                            anchors.fill: volumeIconImage
                            source: volumeIconImage
                            color: App.Style.mediaRoomSeekColor
                            
                            layer.enabled: true
                            layer.effect: DropShadow {
                                transparentBorder: true
                                horizontalOffset: 4       
                                verticalOffset: 4         
                                radius: 8.0               
                                samples: 17               
                                color: "#B0000000"        
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // If volume is 0, restore to startup volume instead of toggling mute
                            if (volumeControl.currentValue === 0 && settingsManager) {
                                var startupVol = Math.round(settingsManager.startUpVolume * 100)
                                volumeSlider.value = startupVol
                            } else {
                                mediaManager.toggle_mute()
                            }
                        }
                    }
                }
                
                // Volume slider
                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: volumeControl.currentValue
                    
                    // Increase touch area
                    implicitHeight: App.Spacing.mediaRoomProgressSliderHeight * 4
                    
                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: App.Spacing.mediaRoomProgressSliderHeight
                        radius: height / 2
                        color: App.Style.hoverColor
                        
                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: App.Style.volumeSliderColor
                        }
                    }
                    
                    // Handle styling
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: App.Spacing.mediaRoomSliderButtonWidth
                        height: App.Spacing.mediaRoomSliderButtonHeight
                        radius: App.Spacing.mediaRoomSliderButtonRadius
                        color: App.Style.accent
                        visible: true
                    }
                    
                    // Enhanced touch area
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -App.Spacing.dp(10)
                        anchors.bottomMargin: -App.Spacing.dp(10)

                        onPressed: function(mouse) {
                            var newPos = Math.max(0, Math.min(1, (mouseX - volumeSlider.leftPadding) / volumeSlider.availableWidth))
                            volumeSlider.value = volumeSlider.from + newPos * (volumeSlider.to - volumeSlider.from)
                            volumeSlider.pressed = true
                            mouse.accepted = false
                        }
                        
                        onReleased: function(mouse) {
                            volumeSlider.pressed = false
                            mouse.accepted = false
                        }
                    }
                    
                    // Volume change logic
                    onValueChanged: {
                        volumeControl.currentValue = value
                        var normalizedValue = value / 100
                        var logVolume = Math.pow(normalizedValue, 2.0)

                        // Update unified volume in settings
                        if (settingsManager) {
                            settingsManager.setCurrentVolume(Math.round(value))
                        }

                        // Apply to local media
                        if (mediaManager) {
                            mediaManager.setVolume(logVolume)

                            // Unmute if volume was raised while user is dragging the slider
                            if (volumeSlider.pressed && value > 0 && volumeControl.isMuted) {
                                mediaManager.toggle_mute()
                            }
                        }

                        // Apply to Spotify if connected
                        if (spotifyManager && spotifyManager.is_connected()) {
                            spotifyManager.set_volume(Math.round(value))
                        }

                        // Update icon
                        topVolumeControl.updateVolumeIcon()
                    }
                }
                
                // Volume percentage text
                Text {
                    id: volumePercentText
                    text: Math.round(volumeSlider.value) + "%"
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
                    font.family: mediaRoom.globalFont
                    Layout.minimumWidth: App.Spacing.dp(40)
                }
            }

            // Volume control state properties
            QtObject {
                id: volumeControl
                property int currentValue: 0
                property bool isMuted: mediaManager ? mediaManager.is_muted() : false

                Component.onCompleted: {
                    // Use the unified volume from Octave settings
                    if (settingsManager) {
                        currentValue = settingsManager.currentVolume
                    } else if (mediaManager) {
                        var volume = mediaManager.getVolume()
                        currentValue = Math.round(Math.sqrt(volume) * 100)
                    }
                    isMuted = mediaManager ? mediaManager.is_muted() : false
                    topVolumeControl.updateVolumeIcon()
                }
            }
            
            // Functions
            function getVolumeIconSource() {
                if (volumeControl.isMuted || volumeControl.currentValue === 0) {
                    return "./assets/mute_on.svg"
                }
                if (volumeControl.currentValue < 20) return "./assets/mute_off_med.svg"
                if (volumeControl.currentValue > 90) return "./assets/mute_off_low.svg"
                return "./assets/mute_off_low.svg"
            }
            
            function updateVolumeIcon() {
                volumeIconImage.source = getVolumeIconSource()
            }
            
            // Connections for volume sync
            Connections {
                target: mediaManager
                function onMuteChanged(muted) {
                    volumeControl.isMuted = muted
                    topVolumeControl.updateVolumeIcon()
                }
                
                function onVolumeChanged(volume) {
                    if (!volumeSlider.pressed) {
                        var volumePercent = Math.round(Math.sqrt(volume) * 100)
                        volumeControl.currentValue = volumePercent
                        volumeSlider.value = volumePercent
                    }
                    topVolumeControl.updateVolumeIcon()
                }
            }
        }

        Rectangle { //media controls container
            id: mediaControlsContainer
            width: App.Spacing.applicationWidth * App.Spacing.mediaRoomControlsContainerWidth
            height: App.Spacing.applicationHeight * App.Spacing.mediaRoomControlsContainerHeight
            anchors {
                top: topVolumeControl.bottom
                bottom: durationBar.top
                horizontalCenter: parent.horizontalCenter
                // Use verticalCenter to ensure it's centered between the two elements
                margins: App.Spacing.mediaRoomMargin
            }
            color: transparentColor
        

            RowLayout {
                anchors.fill: parent
                spacing: App.Spacing.mediaRoomSpacing

                // Left side - Controls and Metadata
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.5  // 50% for left side
                    Layout.maximumWidth: parent.width * 0.5
                    Layout.leftMargin: App.Spacing.dp(20)
                    spacing: App.Spacing.mediaRoomSpacing * 2

                    // Spacer to push controls toward center
                    Item { Layout.fillHeight: true }

                    // Media Controls Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: App.Spacing.mediaRoomBetweenButton

                        Control { //Previous button
                            id: previousControl
                            implicitHeight: App.Spacing.mediaRoomPreviousButtonHeight
                            implicitWidth: App.Spacing.mediaRoomPreviousButtonWidth

                            property bool _tiltEnabled: settingsManager && settingsManager.show3DButtonTilt
                            property real tiltAngle: (_tiltEnabled && prevMouseArea.pressed) ? 15 : 0
                            scale: (_tiltEnabled && prevMouseArea.pressed) ? 0.9 : 1.0
                            transform: Rotation {
                                axis { x: 1; y: 0; z: 0 }
                                angle: previousControl.tiltAngle
                                origin.x: previousControl.width / 2
                                origin.y: previousControl.height / 2
                            }
                            Behavior on tiltAngle { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                            Behavior on scale { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                            background: Rectangle {
                                color: "transparent"
                            }
                            contentItem: Item {
                                Image {
                                    id: previousButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: "./assets/previous_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: false
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: previousButtonImage
                                    source: previousButtonImage
                                    color: App.Style.mediaRoomPreviousButton
                                    opacity: prevMouseArea.pressed ? buttonPressedOpacity : buttonNormalOpacity
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        transparentBorder: true
                                        horizontalOffset: 4
                                        verticalOffset: 4
                                        radius: 8.0
                                        samples: 17
                                        color: "#B0000000"
                                    }
                                }
                            }
                            MouseArea {
                                id: prevMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    mediaRoom._slideDirection = -1
                                    if (useSpotify) {
                                        spotifyManager.previous_track()
                                    } else {
                                        mediaManager.previous_track()
                                    }
                                }
                            }
                        }

                        Control { //Play Button
                            id: playControl
                            implicitHeight: App.Spacing.mediaRoomPlayButtonHeight
                            implicitWidth: App.Spacing.mediaRoomPlayButtonWidth

                            property bool _tiltEnabled: settingsManager && settingsManager.show3DButtonTilt
                            property real tiltAngle: (_tiltEnabled && playMouseArea.pressed) ? 25 : 0
                            scale: (_tiltEnabled && playMouseArea.pressed) ? 0.85 : 1.0
                            transform: Rotation {
                                axis { x: 1; y: 0; z: 0 }
                                angle: playControl.tiltAngle
                                origin.x: playControl.width / 2
                                origin.y: playControl.height / 2
                            }
                            Behavior on tiltAngle { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                            Behavior on scale { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                            background: Rectangle {
                                color: "transparent"
                            }
                            contentItem: Item {
                                Image {
                                    id: playButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: {
                                        var isPlaying = useSpotify ?
                                            (spotifyManager && spotifyManager.is_playing()) :
                                            (mediaManager && mediaManager.is_playing())
                                        return isPlaying ? "./assets/pause_button.svg" : "./assets/play_button.svg"
                                    }
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: playButtonImage
                                    source: playButtonImage
                                    color: App.Style.mediaRoomPlayButton
                                    opacity: playMouseArea.pressed ? buttonPressedOpacity : buttonNormalOpacity
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        transparentBorder: true
                                        horizontalOffset: 4
                                        verticalOffset: 4
                                        radius: 8.0
                                        samples: 17
                                        color: "#B0000000"
                                    }
                                }
                            }
                            MouseArea {
                                id: playMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    if (useSpotify) {
                                        spotifyManager.toggle_play()
                                    } else {
                                        mediaManager.toggle_play()
                                    }
                                }
                            }
                        }
                        
                        Control { //Next Button
                            id: nextControl
                            implicitHeight: App.Spacing.mediaRoomNextButtonHeight
                            implicitWidth: App.Spacing.mediaRoomNextButtonWidth

                            property bool _tiltEnabled: settingsManager && settingsManager.show3DButtonTilt
                            property real tiltAngle: (_tiltEnabled && nextMouseArea.pressed) ? 15 : 0
                            scale: (_tiltEnabled && nextMouseArea.pressed) ? 0.9 : 1.0
                            transform: Rotation {
                                axis { x: 1; y: 0; z: 0 }
                                angle: nextControl.tiltAngle
                                origin.x: nextControl.width / 2
                                origin.y: nextControl.height / 2
                            }
                            Behavior on tiltAngle { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                            Behavior on scale { NumberAnimation { duration: settingsManager ? settingsManager.buttonTiltDuration : 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                            background: Rectangle {
                                color: "transparent"
                            }
                            contentItem: Item {
                                Image {
                                    id: nextButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: "./assets/next_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: nextButtonImage
                                    source: nextButtonImage
                                    color: App.Style.mediaRoomNextButton
                                    opacity: nextMouseArea.pressed ? buttonPressedOpacity : buttonNormalOpacity
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        transparentBorder: true
                                        horizontalOffset: 4
                                        verticalOffset: 4
                                        radius: 8.0
                                        samples: 17
                                        color: "#B0000000"
                                    }
                                }
                            }
                            MouseArea {
                                id: nextMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    mediaRoom._slideDirection = 1
                                    if (useSpotify) {
                                        spotifyManager.next_track()
                                    } else {
                                        mediaManager.next_track()
                                    }
                                }
                            }
                        }
                    }

                    // Song metadata section (below controls)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: App.Spacing.dp(4)

                        // Song title with scrolling
                        Item {
                            id: songTitleContainer
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            height: Math.ceil(App.Spacing.mediaRoomMetaDataSongText * 1.4)

                            Flickable {
                                id: songTitleFlickable
                                anchors.centerIn: parent
                                width: Math.min(songTitleText.width, parent.width)
                                height: parent.height
                                contentWidth: songTitleText.width
                                contentHeight: parent.height
                                clip: true
                                flickableDirection: Flickable.HorizontalFlick

                                Text {
                                    id: songTitleText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: currentTrackName || "No track selected"
                                    color: App.Style.metadataColor
                                    font.pixelSize: App.Spacing.mediaRoomMetaDataSongText
                                    font.bold: true
                                    font.family: mediaRoom.globalFont
                                }

                                Timer {
                                    id: songScrollTimer
                                    property real containerWidth: songTitleFlickable.parent ? songTitleFlickable.parent.width : 200
                                    interval: 3000
                                    running: songTitleText.width > containerWidth
                                    repeat: true
                                    onTriggered: {
                                        if (songTitleFlickable.contentX === 0) {
                                            songScrollAnimation.to = songTitleText.width - songTitleFlickable.width;
                                            songScrollAnimation.start();
                                        } else {
                                            songScrollAnimation.to = 0;
                                            songScrollAnimation.start();
                                        }
                                    }
                                }

                                NumberAnimation {
                                    id: songScrollAnimation
                                    target: songTitleFlickable
                                    property: "contentX"
                                    duration: settingsManager ? settingsManager.textScrollSpeed : 5000
                                    easing.type: Easing.InOutQuad
                                    onFinished: songScrollTimer.restart()
                                }
                            }
                        }

                        // Artist and album info
                        Item {
                            id: metadataContainer
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            height: Math.ceil(App.Spacing.mediaRoomMetaDataBandText * 1.4)

                            Flickable {
                                id: metadataFlickable
                                anchors.centerIn: parent
                                width: Math.min(metadataRow.width, parent.width)
                                height: parent.height
                                contentWidth: metadataRow.width
                                contentHeight: parent.height
                                clip: true
                                flickableDirection: Flickable.HorizontalFlick

                                Row {
                                    id: metadataRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: App.Spacing.dp(10)

                                    Text {
                                        text: currentArtist
                                        color: App.Style.metadataColor
                                        font.pixelSize: App.Spacing.mediaRoomMetaDataBandText
                                        font.family: mediaRoom.globalFont
                                        opacity: 0.7
                                    }
                                    Text {
                                        text: "•"
                                        color: App.Style.metadataColor
                                        font.pixelSize: App.Spacing.mediaRoomMetaDataAlbumText
                                        font.family: mediaRoom.globalFont
                                        opacity: 0.8
                                    }
                                    Text {
                                        text: currentAlbum
                                        color: App.Style.metadataColor
                                        font.pixelSize: App.Spacing.mediaRoomMetaDataAlbumText
                                        font.family: mediaRoom.globalFont
                                        opacity: 0.8
                                    }
                                }

                                Timer {
                                    id: metadataScrollTimer
                                    property real containerWidth: metadataFlickable.parent ? metadataFlickable.parent.width : 200
                                    interval: 3000
                                    running: metadataRow.width > containerWidth
                                    repeat: true
                                    onTriggered: {
                                        if (metadataFlickable.contentX === 0) {
                                            metadataScrollAnimation.to = metadataRow.width - metadataFlickable.width;
                                            metadataScrollAnimation.start();
                                        } else {
                                            metadataScrollAnimation.to = 0;
                                            metadataScrollAnimation.start();
                                        }
                                    }
                                }

                                NumberAnimation {
                                    id: metadataScrollAnimation
                                    target: metadataFlickable
                                    property: "contentX"
                                    duration: settingsManager ? settingsManager.textScrollSpeed : 5000
                                    easing.type: Easing.InOutQuad
                                    onFinished: metadataScrollTimer.restart()
                                }
                            }
                        }
                    }

                    // Spacer to push content toward center
                    Item { Layout.fillHeight: true }

                    // Hidden container for current song text (used by other components)
                    Item {
                        id: currentSongTextContainer
                        visible: false
                        Text { id: currentSongText; text: "" }
                    }

                }


                Item { // Right side - Album Art Card Stack
                    id: albumArtStack
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.5  // 50% for right side
                    Layout.maximumWidth: parent.width * 0.5
                    Layout.alignment: Qt.AlignVCenter
                    clip: false

                    property bool _previewEnabled: settingsManager && settingsManager.show3DAlbumPreview
                    property real artSize: Math.min(width * (_previewEnabled ? 0.75 : 0.85), height * (_previewEnabled ? 0.75 : 0.85))

                    property bool _roundedArt: settingsManager && settingsManager.roundedAlbumArt
                    property real _artRadius: App.Spacing.dp(settingsManager ? settingsManager.albumArtCornerRadius : 16)

                    // Shared rounded-corner mask for album art OpacityMask
                    Rectangle {
                        id: artRoundedMask
                        width: albumArtStack.artSize
                        height: width
                        radius: albumArtStack._roundedArt ? albumArtStack._artRadius : 0
                        visible: false
                        layer.enabled: true
                    }

                    // 3D coverflow — old card exits while new card enters simultaneously
                    ParallelAnimation {
                        id: cardRotateAnimation
                        property int _direction: 1
                        // Computed in triggerSlide() so they're stable for the animation's lifetime
                        property real _sideOffset: 0
                        property real _sideAngle: 0

                        // Exit card: current position → opposite side (no `from` — picks up live on interrupt)
                        NumberAnimation { target: exitCardWrapper; property: "_offset"; to: -cardRotateAnimation._sideOffset; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: exitCardWrapper; property: "_angle"; to: cardRotateAnimation._direction * cardRotateAnimation._sideAngle; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: exitCardWrapper; property: "_cardScale"; to: 0.72; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: exitCardWrapper; property: "_cardOpacity"; to: 0; duration: 250; easing.type: Easing.InCubic }

                        // Enter card: side → center (always starts fresh from the side)
                        NumberAnimation { target: albumArtContainer; property: "_rotateOffset"; from: cardRotateAnimation._sideOffset; to: 0; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: albumArtContainer; property: "_rotateAngle"; from: -cardRotateAnimation._direction * cardRotateAnimation._sideAngle; to: 0; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: albumArtContainer; property: "_rotateScale"; from: 0.72; to: 1.0; duration: 250; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: albumArtContainer; property: "opacity"; from: 0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                    }

                    function triggerSlide() {
                        cardRotateAnimation.stop()
                        // Transfer enter card's live state to exit card (seamless handoff on interrupt)
                        exitCardWrapper._offset = albumArtContainer._rotateOffset
                        exitCardWrapper._angle = albumArtContainer._rotateAngle
                        exitCardWrapper._cardScale = albumArtContainer._rotateScale
                        exitCardWrapper._cardOpacity = albumArtContainer.opacity
                        // Load old art onto exit card (fallback if cached art is empty/invalid)
                        exitArtImage.source = mediaRoom._previousAlbumArt || "./assets/missing_art.png"
                        // Snapshot direction-dependent values (avoid binding re-evaluation mid-animation)
                        cardRotateAnimation._direction = mediaRoom._slideDirection
                        cardRotateAnimation._sideOffset = mediaRoom._slideDirection * albumArtStack.artSize * 0.42
                        cardRotateAnimation._sideAngle = settingsManager ? settingsManager.sideCardAngle : 30
                        cardRotateAnimation.start()
                        // Cache resolved art for next transition (uses _displayAlbumArt which has error fallback)
                        mediaRoom._previousAlbumArt = mediaRoom._displayAlbumArt
                    }

                    // Previous card (background, tilted left)
                    Item {
                        id: prevArtWrapper
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -parent.artSize * 0.42
                        width: parent.artSize
                        height: width
                        visible: prevAlbumArt !== "" && settingsManager && settingsManager.show3DAlbumPreview
                        z: 0
                        scale: 0.72
                        opacity: settingsManager ? settingsManager.sideCardOpacity : 0.4
                        transform: Rotation {
                            axis { x: 0; y: 1; z: 0 }
                            angle: settingsManager ? settingsManager.sideCardAngle : 30
                            origin.x: prevArtWrapper.width / 2
                            origin.y: prevArtWrapper.height / 2
                        }

                        Image {
                            id: prevArtImage
                            anchors.fill: parent
                            source: prevAlbumArt
                            fillMode: Image.PreserveAspectFit
                            smooth: true; antialiasing: true; asynchronous: true
                            layer.enabled: albumArtStack._roundedArt
                            layer.effect: OpacityMask {
                                maskSource: artRoundedMask
                            }
                        }
                    }

                    // Next card (background, tilted right)
                    Item {
                        id: nextArtWrapper
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: parent.artSize * 0.42
                        width: parent.artSize
                        height: width
                        visible: nextAlbumArt !== "" && settingsManager && settingsManager.show3DAlbumPreview
                        z: 0
                        scale: 0.72
                        opacity: settingsManager ? settingsManager.sideCardOpacity : 0.4
                        transform: Rotation {
                            axis { x: 0; y: 1; z: 0 }
                            angle: -(settingsManager ? settingsManager.sideCardAngle : 30)
                            origin.x: nextArtWrapper.width / 2
                            origin.y: nextArtWrapper.height / 2
                        }

                        Image {
                            id: nextArtImage
                            anchors.fill: parent
                            source: nextAlbumArt
                            fillMode: Image.PreserveAspectFit
                            smooth: true; antialiasing: true; asynchronous: true
                            layer.enabled: albumArtStack._roundedArt
                            layer.effect: OpacityMask {
                                maskSource: artRoundedMask
                            }
                        }
                    }

                    // Exit card — shows old art sliding away during transitions
                    Item {
                        id: exitCardWrapper
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.artSize
                        height: width
                        z: 0
                        visible: cardRotateAnimation.running && exitArtImage.status === Image.Ready

                        property real _offset: 0
                        property real _angle: 0
                        property real _cardScale: 1.0
                        property real _cardOpacity: 1.0

                        scale: _cardScale
                        opacity: _cardOpacity

                        transform: [
                            Translate { x: exitCardWrapper._offset },
                            Rotation {
                                axis { x: 0; y: 1; z: 0 }
                                angle: exitCardWrapper._angle
                                origin.x: exitCardWrapper.width / 2
                                origin.y: exitCardWrapper.height / 2
                            }
                        ]

                        Image {
                            id: exitArtImage
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                            onStatusChanged: {
                                if (status === Image.Error) source = "./assets/missing_art.png"
                            }
                            layer.enabled: albumArtStack._roundedArt
                            layer.effect: OpacityMask {
                                maskSource: artRoundedMask
                            }
                        }

                        layer.enabled: exitArtImage.status === Image.Ready && settingsManager && settingsManager.showAlbumArtShadow
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 8
                            verticalOffset: 8
                            radius: 16.0
                            samples: 33
                            color: "#E0000000"
                        }
                    }

                    // Current card (front) — animated properties for 3D rotation transition
                    Item {
                        id: albumArtContainer
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.artSize
                        height: width
                        z: 1

                        // Animated transition properties (resting: 0, 0, 1.0)
                        property real _rotateOffset: 0
                        property real _rotateAngle: 0
                        property real _rotateScale: 1.0

                        scale: _rotateScale

                        // Use transform list instead of anchors.horizontalCenterOffset
                        // for the slide — transforms are purely visual and skip
                        // anchor layout recalculations on every animation frame
                        transform: [
                            Translate { x: albumArtContainer._rotateOffset },
                            Rotation {
                                axis { x: 0; y: 1; z: 0 }
                                angle: albumArtContainer._rotateAngle
                                origin.x: albumArtContainer.width / 2
                                origin.y: albumArtContainer.height / 2
                            }
                        ]

                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            source: mediaRoom._displayAlbumArt
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                            mipmap: false
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error) mediaRoom._displayAlbumArt = "./assets/missing_art.png"
                            }
                            layer.enabled: albumArtStack._roundedArt
                            layer.effect: OpacityMask {
                                maskSource: artRoundedMask
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: 2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: albumArtPopup.open()
                        }

                        layer.enabled: albumArtImage.status === Image.Ready && settingsManager && settingsManager.showAlbumArtShadow
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 8
                            verticalOffset: 8
                            radius: 16.0
                            samples: 33
                            color: "#E0000000"
                        }
                    }
                }
            }
        }

        // Waveform Visualizer
        Item {
            id: waveformContainer
            width: parent.width * 0.75
            height: App.Spacing.dp(40)
            anchors {
                bottom: durationBar.top
                horizontalCenter: parent.horizontalCenter
                bottomMargin: App.Spacing.dp(10)
            }
            visible: settingsManager && settingsManager.showWaveformVisualizer && !mediaRoom.useSpotify
            opacity: visible ? 1.0 : 0.0

            // Track playback state reactively (method calls aren't reactive in bindings)
            property bool isPlaying: false
            property string lastAnalyzedFile: ""

            // Quality-driven parameters
            property string quality: settingsManager ? settingsManager.visualizerQuality : "Medium"
            property int timerInterval: quality === "Low" ? 200 : (quality === "High" ? 60 : (quality === "Extreme" ? 33 : (quality === "Insane" ? 16 : 100)))
            property bool smoothBars: true
            property int animDuration: quality === "Insane" ? 120 : (quality === "Extreme" ? 80 : (quality === "High" ? 50 : (quality === "Medium" ? 80 : 150)))
            property int animEasing: quality === "Insane" ? Easing.InOutSine : (quality === "Extreme" ? Easing.InOutQuad : Easing.OutQuad)
            property bool fancyBars: quality === "Extreme" || quality === "Insane"

            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            // Rebuild bars when quality (and thus bar count) changes
            Connections {
                target: settingsManager
                function onVisualizerQualityChanged() {
                    waveformBars.numBars = audioAnalyzer ? audioAnalyzer.get_num_bars() : 32
                    // Re-analyze current song with new bar count
                    if (audioAnalyzer && mediaManager && !mediaRoom.useSpotify) {
                        var currentFile = mediaManager.get_current_file()
                        if (currentFile) {
                            var fullPath = mediaManager.get_full_file_path(currentFile)
                            if (fullPath) {
                                audioAnalyzer.analyze_file(fullPath)
                            }
                        }
                    }
                }
            }

            // Waveform bars
            Row {
                id: waveformBars
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                height: parent.height
                spacing: waveformContainer.quality === "Insane" ? App.Spacing.dp(1) : App.Spacing.dp(2)

                property int numBars: audioAnalyzer ? audioAnalyzer.get_num_bars() : 32

                Repeater {
                    id: waveformRepeater
                    model: waveformBars.numBars

                    Rectangle {
                        property int barLevel: 0
                        property bool fancy: waveformContainer.fancyBars

                        width: Math.max(2, (waveformContainer.width - (waveformBars.numBars - 1) * waveformBars.spacing) / waveformBars.numBars)
                        height: Math.max(2, (barLevel / 8) * waveformContainer.height)
                        anchors.bottom: parent.bottom

                        // Pill-shaped bars on Extreme/Insane
                        radius: fancy ? width * 0.4 : 0

                        // Always set color as fallback — Qt ignores color when gradient is active,
                        // but if the gradient fails to render (Windows GPU quirk) the bar stays visible
                        color: App.Style.accent

                        // Gradient glow from base on Extreme/Insane
                        gradient: fancy ? barGradient : null

                        // Breathing opacity — quiet bars fade, loud bars pop
                        opacity: fancy ? (0.4 + (barLevel / 8) * 0.6) : 0.8

                        Gradient {
                            id: barGradient
                            GradientStop { position: 0.0; color: Qt.darker(App.Style.accent, 1.4) }
                            GradientStop { position: 0.5; color: App.Style.accent }
                            GradientStop { position: 1.0; color: Qt.lighter(App.Style.accent, 1.6) }
                        }

                        Behavior on height {
                            enabled: waveformContainer.smoothBars && !cardRotateAnimation.running
                            NumberAnimation { duration: waveformContainer.animDuration; easing.type: waveformContainer.animEasing }
                        }

                        Behavior on opacity {
                            enabled: fancy && !cardRotateAnimation.running
                            NumberAnimation { duration: waveformContainer.animDuration; easing.type: waveformContainer.animEasing }
                        }
                    }
                }
            }

            // Connect to audio analyzer — update each bar's level directly
            Connections {
                target: audioAnalyzer
                enabled: waveformContainer.visible

                function onFftDataChanged(levels) {
                    for (var i = 0; i < waveformRepeater.count; i++) {
                        var item = waveformRepeater.itemAt(i)
                        if (item) {
                            item.barLevel = (levels && levels[i]) || 0
                        }
                    }
                }
            }

            // Update position periodically — interval driven by quality tier
            Timer {
                id: waveformUpdateTimer
                interval: waveformContainer.timerInterval
                running: waveformContainer.visible && waveformContainer.isPlaying
                repeat: true

                onTriggered: {
                    if (audioAnalyzer && audioAnalyzer.is_analyzed() && mediaManager) {
                        audioAnalyzer.update_position(mediaManager.get_position() / 1000.0)
                    }
                }
            }

            // Handle media manager signals
            Connections {
                target: mediaManager
                enabled: settingsManager && settingsManager.showWaveformVisualizer

                function onCurrentMediaChanged(filename) {
                    if (audioAnalyzer && filename && !mediaRoom.useSpotify) {
                        var fullPath = mediaManager.get_full_file_path(filename)
                        if (fullPath) {
                            audioAnalyzer.analyze_file(fullPath)
                            waveformContainer.lastAnalyzedFile = filename
                        }
                    }
                }

                function onPlayStateChanged(playing) {
                    waveformContainer.isPlaying = playing
                    if (audioAnalyzer) {
                        audioAnalyzer.set_active(playing)
                    }
                }
            }

            // Initialize waveform when needed
            function initializeWaveform() {
                if (audioAnalyzer && mediaManager && !mediaRoom.useSpotify) {
                    var currentFile = mediaManager.get_current_file()
                    if (currentFile) {
                        var fullPath = mediaManager.get_full_file_path(currentFile)
                        if (fullPath) {
                            audioAnalyzer.analyze_file(fullPath)
                            waveformContainer.lastAnalyzedFile = currentFile
                        }
                    }
                    // Set active state based on current playback
                    waveformContainer.isPlaying = mediaManager.is_playing()
                    audioAnalyzer.set_active(waveformContainer.isPlaying)
                }
            }

            // Re-initialize when becoming visible
            onVisibleChanged: {
                if (visible) {
                    initializeWaveform()
                }
            }

            // Also initialize on component load
            Component.onCompleted: {
                if (waveformContainer.visible) {
                    initializeWaveform()
                }
            }
        }

        Rectangle { //duration bar
            id: durationBar
            width: parent.width * 0.75
            height: App.Spacing.mediaRoomDurationBarHeight
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: App.Spacing.dp(20)
            }
            color: transparentColor

            RowLayout {
                anchors.fill: parent
                spacing: App.Spacing.dp(20)

                Text {
                    id: positionText
                    text: formatTime(mediaRoom.position)
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
                    font.family: mediaRoom.globalFont
                    Layout.minimumWidth: App.Spacing.dp(40)  // Added minimum width for consistent layout
                }

                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: mediaRoom.duration > 0 ? mediaRoom.duration : 1
                    value: mediaRoom.position
                    enabled: mediaRoom.duration > 0
                    
                    // Increase the implicit height to provide a larger touch area
                    implicitHeight: App.Spacing.mediaRoomProgressSliderHeight * 4 // Increased touch area height
                    
                    // Improved slider styling
                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: progressSlider.availableWidth
                        height: App.Spacing.mediaRoomProgressSliderHeight
                        radius: height / 2
                        color: App.Style.secondaryTextColor

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: App.Style.primaryTextColor
                        }
                    }

                    // Fixed handle visibility
                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: App.Spacing.mediaRoomSliderButtonWidth
                        height: App.Spacing.mediaRoomSliderButtonHeight
                        radius: App.Spacing.mediaRoomSliderButtonRadius
                        color: progressSlider.pressed ? sliderHandlePressed : sliderHandleNormal
                        visible: true  // Explicitly set to visible
                        
                        // Optional: Add drop shadow for better visibility
                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 1
                            verticalOffset: 1
                            radius: 3.0
                            samples: 5
                            color: "#80000000"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // Add extra padding to make it easier to touch
                        anchors.topMargin: -App.Spacing.dp(10)
                        anchors.bottomMargin: -App.Spacing.dp(10)

                        onPressed: function(mouse) {
                            // Calculate value based on mouse position
                            var newPos = Math.max(0, Math.min(1, (mouseX - progressSlider.leftPadding) / progressSlider.availableWidth))
                            progressSlider.value = progressSlider.from + newPos * (progressSlider.to - progressSlider.from)
                            progressSlider.pressed = true
                            userSeeking = true
                            mouse.accepted = false  // Allow the event to propagate to the Slider
                        }
                        onReleased: function(mouse) {
                            progressSlider.pressed = false
                            userSeeking = false
                            if (useSpotify) {
                                spotifyManager.set_position(progressSlider.value)
                            } else {
                                mediaManager.set_position(progressSlider.value)
                            }
                            mediaRoom.position = progressSlider.value
                            mouse.accepted = false
                        }
                    }

                    onPressedChanged: {
                        if (pressed) {
                            userSeeking = true
                        } else {
                            userSeeking = false
                            if (useSpotify) {
                                spotifyManager.set_position(value)
                            } else {
                                mediaManager.set_position(value)
                            }
                            mediaRoom.position = value
                        }
                    }

                    onMoved: {
                        if (userSeeking) {
                            mediaRoom.position = value
                        }
                    }
                }

                Text {
                    id: durationText
                    text: formatTime(mediaRoom.duration)
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
                    font.family: mediaRoom.globalFont
                    Layout.minimumWidth: App.Spacing.dp(40)  // Added minimum width for consistent layout
                }

                // Source toggle button (Local/Spotify)
                Control {
                    id: sourceToggleButton
                    visible: spotifyAvailable  // Only show when Spotify is connected
                    implicitWidth: App.Spacing.mediaRoomShuffleButtonWidth * 1.8
                    implicitHeight: App.Spacing.mediaRoomShuffleButtonHeight
                    background: Rectangle {
                        color: useSpotify ? "#1DB954" : App.Style.mediaRoomToggleShade
                        radius: height / 2
                        border.color: useSpotify ? "#1DB954" : App.Style.secondaryTextColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: useSpotify ? "Spotify" : "Local"
                        color: useSpotify ? "white" : App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.mediaRoomSliderDurationText * 0.9
                        font.bold: true
                        font.family: mediaRoom.globalFont
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: sourceToggleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            // Pause current source before switching
                            if (useSpotify) {
                                // Currently on Spotify, pause it before switching to local
                                if (spotifyManager && spotifyManager.is_playing()) {
                                    spotifyManager.pause()
                                }
                            } else {
                                // Currently on local, pause it before switching to Spotify
                                if (mediaManager && mediaManager.is_playing()) {
                                    mediaManager.pause()
                                }
                            }

                            // Toggle the source
                            if (settingsManager) {
                                settingsManager.toggle_media_source()
                            }
                        }
                    }
                    ToolTip.visible: sourceToggleMouseArea.containsMouse
                    ToolTip.text: useSpotify ? "Switch to local files" : "Switch to Spotify"
                    ToolTip.delay: 500
                }

                // Spotify connect button (show when credentials exist but not connected)
                Control {
                    id: spotifyConnectButton
                    visible: !spotifyAvailable && spotifyManager && spotifyManager.has_credentials()
                    implicitWidth: App.Spacing.mediaRoomShuffleButtonWidth * 1.8
                    implicitHeight: App.Spacing.mediaRoomShuffleButtonHeight
                    background: Rectangle {
                        color: spotifyConnectMouseArea.containsMouse ? "#1DB954" : "#1a1a1a"
                        radius: height / 2
                        border.color: "#1DB954"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "Connect"
                        color: spotifyConnectMouseArea.containsMouse ? "white" : "#1DB954"
                        font.pixelSize: App.Spacing.mediaRoomSliderDurationText * 0.9
                        font.bold: true
                        font.family: mediaRoom.globalFont
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea {
                        id: spotifyConnectMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (spotifyManager) {
                                spotifyManager.authenticate()
                            }
                        }
                    }
                    ToolTip.visible: spotifyConnectMouseArea.containsMouse
                    ToolTip.text: "Connect to Spotify (opens browser)"
                    ToolTip.delay: 500
                }
            }
        }

        // Shuffle Button — bottom left corner, centered between edge and duration bar
        Control {
            id: shuffleButton
            width: durationBar.height * 1.96875
            height: durationBar.height * 1.96875
            anchors.verticalCenter: durationBar.verticalCenter
            anchors.verticalCenterOffset: -App.Spacing.dp(15)
            x: (durationBar.x - width) / 2
            background: Rectangle {
                color: isShuffleEnabled ? App.Style.mediaRoomToggleShade : "transparent"
                radius: 4
            }
            contentItem: Item {
                Image {
                    id: shuffleButtonImage
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: parent.height * 0.7
                    source: "./assets/shuffle_button.svg"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    antialiasing: true
                    mipmap: true
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: shuffleButtonImage
                    source: shuffleButtonImage
                    color: isShuffleEnabled ?
                        App.Style.bottomBarActiveToggleButton :
                        App.Style.bottomBarVolumeButton
                }
            }
            MouseArea {
                id: shuffleMouseArea
                anchors.fill: parent
                onClicked: {
                    if (useSpotify) {
                        spotifyManager.toggle_shuffle()
                    } else {
                        mediaManager.toggle_shuffle()
                    }
                }
            }
        }
    }

    // Local media manager connections (only apply when not using Spotify)
    Connections {
        target: mediaManager
        enabled: !useSpotify

        function onPlayStateChanged(playing) {
            playButtonImage.source = playing ?
                "./assets/pause_button.svg" : "./assets/play_button.svg"
            if (playing) {
                mediaRoom.duration = mediaManager.get_duration()
                mediaRoom.position = mediaManager.get_position()
            }
        }

        function onDurationChanged(duration) {
            mediaRoom.duration = duration
        }

        function onPositionChanged(position) {
            if (!userSeeking) {
                mediaRoom.position = position
                progressSlider.value = position
            }
        }

        function onCurrentMediaChanged(filename) {
            playButtonImage.source = "./assets/pause_button.svg"
            mediaRoom.position = 0
            progressSlider.value = 0
            currentSongText.text = filename

            // Always refresh side card sources
            mediaRoom._trackChangeCounter++

            // 3D text flip + card slide on track change
            mediaRoom.animateTrackChange()
        }
        function onShuffleStateChanged(enabled) {
            if (!useSpotify) {
                isShuffleEnabled = enabled
                // Shuffle reorders the playlist — neighbors changed
                mediaRoom._trackChangeCounter++
            }
        }
    }

    Connections {
        target: mediaManager
        function onMuteChanged(muted) {
            volumeControl.isMuted = muted
            topVolumeControl.updateVolumeIcon()
        }

        function onVolumeChanged(volume) {
            if (!volumeSlider.pressed) {
                var volumePercent = Math.round(Math.sqrt(volume) * 100)
                volumeControl.currentValue = volumePercent
                volumeSlider.value = volumePercent
            }
            topVolumeControl.updateVolumeIcon()
        }
    }

    // Spotify playback connections (always active to receive updates)
    Connections {
        target: spotifyManager

        function onPlayStateChanged(playing) {
            // Only update UI if we're in Spotify mode
            if (useSpotify) {
                playButtonImage.source = playing ?
                    "./assets/pause_button.svg" : "./assets/play_button.svg"
            }
        }

        function onDurationChanged(duration) {
            if (useSpotify) {
                mediaRoom.duration = duration
            }
        }

        function onPositionChanged(position) {
            if (useSpotify && !userSeeking) {
                mediaRoom.position = position
                progressSlider.value = position
            }
        }

        function onCurrentTrackChanged(title, artist, album, artUrl) {
            // Always update the cached Spotify track info
            mediaRoom.spotifyTrackName = title
            mediaRoom.spotifyArtist = artist
            mediaRoom.spotifyAlbum = album
            mediaRoom.spotifyAlbumArt = artUrl

            // Only update UI elements if we're in Spotify mode
            if (useSpotify) {
                // Reset position for new track
                mediaRoom.position = 0
                progressSlider.value = 0

                // Update duration
                if (spotifyManager) {
                    mediaRoom.duration = spotifyManager.get_duration()
                }

                // Always refresh side card sources
                mediaRoom._trackChangeCounter++

                // 3D text flip + card rotation on track change
                mediaRoom.animateTrackChange()
            }
        }

        function onVolumeChanged(volume) {
            if (useSpotify && !volumeSlider.pressed) {
                volumeControl.currentValue = volume
                volumeSlider.value = volume
                topVolumeControl.updateVolumeIcon()
            }
        }
    }

    // Spotify connection state (always active to track availability)
    Connections {
        target: spotifyManager

        function onConnectionStateChanged(connected) {
            // Update spotifyAvailable when connection state changes
            mediaRoom.spotifyAvailable = connected

            // If Spotify disconnects while in Spotify mode, switch to local
            if (!connected && settingsManager && settingsManager.mediaSource === "spotify") {
                settingsManager.set_media_source("local")
            }
        }

        function onShuffleStateChanged(enabled) {
            if (useSpotify) {
                isShuffleEnabled = enabled
                // Shuffle reorders the playlist — neighbors changed
                mediaRoom._trackChangeCounter++
            }
        }
    }

    // Settings manager connection for media source changes
    Connections {
        target: settingsManager
        function onMediaSourceChanged(source) {
            var nowUseSpotify = (source === "spotify" && spotifyManager && spotifyManager.is_connected())

            // Update play button to show paused state (since we paused before switching)
            playButtonImage.source = "./assets/play_button.svg"

            // Update duration, position, and shuffle from the new source
            if (nowUseSpotify) {
                mediaRoom.duration = spotifyManager.get_duration()
                mediaRoom.position = spotifyManager.get_position()
                progressSlider.value = mediaRoom.position
                isShuffleEnabled = spotifyManager.is_shuffled()

                // Initialize Spotify track info when switching to Spotify
                mediaRoom.spotifyTrackName = spotifyManager.get_current_track_name()
                mediaRoom.spotifyArtist = spotifyManager.get_current_artist()
                mediaRoom.spotifyAlbum = spotifyManager.get_current_album()
                mediaRoom.spotifyAlbumArt = spotifyManager.get_current_album_art()
            } else if (mediaManager) {
                mediaRoom.duration = mediaManager.get_duration()
                mediaRoom.position = mediaManager.get_position()
                progressSlider.value = mediaRoom.position
                isShuffleEnabled = mediaManager.is_shuffled()

                // Also update the local song text if we have a current file
                var currentFile = mediaManager.get_current_file()
                if (currentFile) {
                    currentSongText.text = currentFile
                }
            }

            // Refresh side cards for the new source's neighbors
            mediaRoom._trackChangeCounter++

            // Volume stays unified from Octave settings - no need to change it when switching sources
            // The unified volume is already applied to both sources
            topVolumeControl.updateVolumeIcon()
        }
    }

    // Album Art Popup — Save Theme
    Popup {
        id: albumArtPopup
        anchors.centerIn: Overlay.overlay
        width: App.Spacing.dp(340)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property bool themeSaved: false

        onOpened: {
            themeSaved = false
            // Always extract fresh colors for the current song so the theme
            // matches what's playing now, not a stale previous extraction
            if (mediaManager) {
                var currentFile = mediaManager.get_current_file()
                if (currentFile) {
                    mediaManager.extract_colors_from_album_art(currentFile)
                }
            }
        }

        background: Rectangle {
            color: App.Style.backgroundColor
            radius: App.Spacing.dpMin(8, 2)
            border.color: App.Style.accent
            border.width: 1

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 4
                radius: 30.0
                samples: 31
                color: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        contentItem: ColumnLayout {
            spacing: App.Spacing.dp(16)

            // Header — album name
            Text {
                Layout.fillWidth: true
                text: mediaRoom.currentAlbum
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.dp(16)
                font.bold: true
                font.family: mediaRoom.globalFont
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Thin divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(App.Style.primaryTextColor.r,
                               App.Style.primaryTextColor.g,
                               App.Style.primaryTextColor.b, 0.15)
            }

            // Save as Theme button
            Rectangle {
                Layout.fillWidth: true
                height: App.Spacing.formElementHeight
                radius: App.Spacing.dpMin(6, 2)
                color: saveThemeMA.containsMouse ? App.Style.accent : App.Style.hoverColor
                opacity: App.Style.albumArtTheme ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: albumArtPopup.themeSaved ? "Theme Saved" : "Save as Theme"
                    color: saveThemeMA.containsMouse ? "white" : App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: mediaRoom.globalFont
                }

                MouseArea {
                    id: saveThemeMA
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: App.Style.albumArtTheme !== null && !albumArtPopup.themeSaved
                    onClicked: {
                        var themeName = mediaRoom.currentAlbum
                        if (!themeName || themeName === "Unknown Album") {
                            themeName = mediaRoom.currentTrackName || "Custom Theme"
                        }
                        var themeJson = JSON.stringify(App.Style.albumArtTheme)
                        settingsManager.save_custom_theme(themeName, themeJson, mediaRoom.currentAlbumArt)
                        albumArtPopup.themeSaved = true
                    }
                }
            }
        }
    }
}