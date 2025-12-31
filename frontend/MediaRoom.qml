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
        return currentSongText.text ? currentSongText.text.replace('.mp3', '') : ""
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

    function formatTime(ms) {
        var minutes = Math.floor(ms / 60000)
        var seconds = Math.floor((ms % 60000) / 1000)
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
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
                            anchors.fill: parent
                            source: albumArtImage.source
                            fillMode: Image.PreserveAspectCrop
                            
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
            
                            opacity: 1
                            layer.enabled: true
                            layer.effect: GaussianBlur {
                                radius: settingsManager ? settingsManager.backgroundBlurRadius : 40
                                samples: Math.min(32, Math.max(1, radius))  // Adjust samples based on radius
                                deviation: radius / 2.5
                                transparentBorder: false
                            }
                        }
                    }
                }
            }
            Rectangle { // Black layer
                id: colorOverlay
                anchors.fill: parent
                color: "#D0000000"
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
                spacing: 10
                
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
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        
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
                    Layout.minimumWidth: 40
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
                    Layout.leftMargin: 20
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
                                    if (useSpotify) {
                                        spotifyManager.previous_track()
                                    } else {
                                        mediaManager.previous_track()
                                    }
                                }
                            }
                        }

                        Control { //Play Button
                            implicitHeight: App.Spacing.mediaRoomPlayButtonHeight
                            implicitWidth: App.Spacing.mediaRoomPlayButtonWidth
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
                        spacing: 4

                        // Song title with scrolling
                        Item {
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
                                    duration: 5000
                                    easing.type: Easing.InOutQuad
                                    onFinished: songScrollTimer.restart()
                                }
                            }
                        }

                        // Artist and album info
                        Item {
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
                                    spacing: 10

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
                                    duration: 5000
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


                Item { // Right side - Album Art
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.5  // 50% for right side
                    Layout.maximumWidth: parent.width * 0.5
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: albumArtImage
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.85, parent.height * 0.85)
                        height: width
                        source: currentAlbumArt
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                        mipmap: false

                        layer.enabled: true
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

        Rectangle { //duration bar
            id: durationBar
            width: parent.width * 0.75
            height: App.Spacing.mediaRoomDurationBarHeight
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: 20
            }
            color: transparentColor
            
            RowLayout {
                anchors.fill: parent
                spacing: 20

                Control { // Shuffle Button
                    id: shuffleButton  // Added ID to match the reference in ColorOverlay
                    implicitWidth: App.Spacing.mediaRoomShuffleButtonWidth
                    implicitHeight: App.Spacing.mediaRoomShuffleButtonHeight
                    background: Rectangle {
                        color: isShuffleEnabled ? App.Style.mediaRoomToggleShade : "transparent"
                        radius: width / 2
                    }
                    contentItem: Item {
                        Image {
                            id: shuffleButtonImage
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            source: "./assets/shuffle_button.svg"
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                            mipmap: true
                            visible: false  // Changed to false since we're using ColorOverlay
                        }
                        ColorOverlay {
                            anchors.fill: shuffleButtonImage
                            source: shuffleButtonImage
                            color: isShuffleEnabled ? 
                                App.Style.bottomBarActiveToggleButton : 
                                App.Style.bottomBarVolumeButton
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

                Text {
                    id: positionText
                    text: formatTime(mediaRoom.position)
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
                    font.family: mediaRoom.globalFont
                    Layout.minimumWidth: 40  // Added minimum width for consistent layout
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
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        
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
                    Layout.minimumWidth: 40  // Added minimum width for consistent layout
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
        }
        function onShuffleStateChanged(enabled) {
            if (!useSpotify) {
                isShuffleEnabled = enabled
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

            // Volume stays unified from Octave settings - no need to change it when switching sources
            // The unified volume is already applied to both sources
            topVolumeControl.updateVolumeIcon()
        }
    }
}