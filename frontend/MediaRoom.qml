import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Basic 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: mediaRoom
    property StackView stackView
    property ApplicationWindow mainWindow

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
            if (mediaManager) {
                mediaRoom.duration = mediaManager.get_duration()
                mediaRoom.position = mediaManager.get_position()
                var currentFile = mediaManager.get_current_file()
                if (currentFile) {
                    currentSongText.text = currentFile
                }
                isShuffleEnabled = mediaManager.is_shuffled()
            }
        }     

        Button { //mediaplayer button
            id: mediaPlayerButton
            implicitHeight: App.Spacing.mediaRoomMediaPlayerButtonHeight
            implicitWidth: App.Spacing.mediaRoomMediaPlayerButtonWidth
            background: null
            anchors {
                left: parent.left
                top: parent.top
                margins: 0
            }

            contentItem: Item {
                Image {
                    id: leftArrowImage
                    anchors.centerIn: parent
                    source: "./assets/left_arrow.svg"
                    fillMode: Image.PreserveAspectFit
                    width: parent.width
                    height: parent.height
                    smooth: true
                    antialiasing: true
                    sourceSize: Qt.size(width * 2, height * 2)
                    mipmap: true
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: leftArrowImage
                    source: leftArrowImage
                    color: App.Style.mediaRoomLeftButton
                }
            }


            onClicked: {
                var component = Qt.createComponent("MediaPlayer.qml")

                function createAndPushPage() {
                    var page = component.createObject(stackView, {
                        stackView: mediaRoom.stackView,
                        mainWindow: stackView.parent.Window.window
                    })
                    if (page) {
                        stackView.push(page)
                    } else {
                        console.error("Error creating MediaPlayer page")
                    }
                }

                if (component.status === Component.Error) {
                    console.error("Error loading MediaPlayer:", component.errorString())
                } else if (component.status === Component.Ready) {
                    createAndPushPage()
                } else {
                    component.statusChanged.connect(function() {
                        if (component.status === Component.Ready) {
                            createAndPushPage()
                        }
                    })
                }
            }
        }

        Button { //equalizerbutton
            id: equalizerControlButton
            implicitHeight: App.Spacing.mediaRoomEqualizerButtonHeight
            implicitWidth: App.Spacing.mediaRoomEqualizerButtonWidth
            background: null
            anchors {
                right: parent.right
                top: parent.top
                margins: 0
            }

            contentItem: Item {
                Image {
                    id: rightArrowImage
                    anchors.centerIn: parent
                    source: "./assets/right_arrow.svg"
                    fillMode: Image.PreserveAspectFit
                    width: parent.width 
                    height: parent.height 
                    smooth: true
                    antialiasing: true
                    sourceSize: Qt.size(width * 2, height * 2)
                    mipmap: true
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: rightArrowImage
                    source: rightArrowImage
                    color: App.Style.mediaRoomRightButton
                }
            }

            onClicked: {
                var component = Qt.createComponent("EqualizerControl.qml")

                function createAndPushPage() {
                    var page = component.createObject(stackView, {
                        stackView: mediaRoom.stackView,
                        mediaManager: mediaManager
                    })
                    if (page) {
                        stackView.push(page)
                    } else {
                        console.error("Error creating EqualizerControl page")
                    }
                }

                if (component.status === Component.Error) {
                    console.error("Error loading EqualizerControl:", component.errorString())
                } else if (component.status === Component.Ready) {
                    createAndPushPage()
                } else {
                    component.statusChanged.connect(function() {
                        if (component.status === Component.Ready) {
                            createAndPushPage()
                        }
                    })
                }
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
                            mediaManager.toggle_mute()
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
                        
                        if (mediaManager) {
                            var normalizedValue = value / 100
                            var logVolume = Math.pow(normalizedValue, 2.0)
                            mediaManager.setVolume(logVolume)
                            
                            // Unmute if volume was raised from zero
                            if (value > 0 && volumeControl.isMuted) {
                                volumeControl.isMuted = false
                                mediaManager.toggle_mute()
                            }
                            
                            // Update icon
                            topVolumeControl.updateVolumeIcon()
                        }
                    }
                }
                
                // Volume percentage text
                Text {
                    id: volumePercentText
                    text: Math.round(volumeSlider.value) + "%"
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
                    Layout.minimumWidth: 40
                }
            }
            
            // Volume control state properties
            QtObject {
                id: volumeControl
                property int currentValue: 0
                property bool isMuted: mediaManager ? mediaManager.is_muted() : false
                
                Component.onCompleted: {
                    if (mediaManager) {
                        var volume = mediaManager.getVolume()
                        currentValue = Math.round(Math.sqrt(volume) * 100)
                        isMuted = mediaManager.is_muted()
                        topVolumeControl.updateVolumeIcon()
                    }
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
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.7  // Allocate 70% to metadata
                    Layout.leftMargin: 20
                    spacing: App.Spacing.mediaRoomSpacing

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
                                onClicked: mediaManager.previous_track()
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
                                    source: mediaManager && mediaManager.is_playing() ? 
                                        "./assets/pause_button.svg" : "./assets/play_button.svg"
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
                                onClicked: mediaManager.toggle_play()
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
                                onClicked: mediaManager.next_track()
                            }
                        }
                    }

                    // Hidden container for current song text (used by other components)
                    Item {
                        id: currentSongTextContainer
                        visible: false
                        Text { id: currentSongText; text: "" }
                    }
                }


                Rectangle { // Right side - Album Art
                    implicitHeight: App.Spacing.mediaRoomAlbumArtHeight
                    implicitWidth: App.Spacing.mediaRoomAlbumArtWidth
                    Layout.preferredWidth: parent.width * 0.80  // Increased to 80%
                    Layout.maximumWidth: parent.width * 0.80
                    Layout.minimumWidth: parent.width * 0.80
                    color: transparentColor
                    clip: false

                    Item {
                        id: albumArtContainer
                        anchors.fill: parent

                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            source: currentSongText.text ?
                                (mediaManager ? mediaManager.get_album_art(currentSongText.text) || "./assets/missing_art.png" : "./assets/missing_art.png") :
                                "./assets/missing_art.png"
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
        }

        // Centered metadata above duration bar
        ColumnLayout {
            id: centeredMetadata
            width: parent.width * 0.75
            anchors {
                bottom: durationBar.top
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 10
            }
            spacing: 4

            // Song title with scrolling
            Item {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                height: App.Spacing.mediaRoomMetaDataSongText

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
                        y: (parent.height - height) / 2
                        text: currentSongText.text ? currentSongText.text.replace('.mp3', '') : "No track selected"
                        color: App.Style.metadataColor
                        font.pixelSize: App.Spacing.mediaRoomMetaDataSongText
                        font.bold: true
                    }

                    Timer {
                        id: songScrollTimer
                        interval: 3000
                        running: songTitleText.width > centeredMetadata.width
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
                height: App.Spacing.mediaRoomMetaDataBandText + 6

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
                        y: (parent.height - height) / 2
                        spacing: 10

                        Text {
                            text: currentSongText.text ?
                                (mediaManager ? mediaManager.get_band(currentSongText.text) : "Unknown Artist") :
                                "Unknown Artist"
                            color: App.Style.metadataColor
                            font.pixelSize: App.Spacing.mediaRoomMetaDataBandText
                            opacity: 0.7
                        }
                        Text {
                            text: "•"
                            color: App.Style.metadataColor
                            font.pixelSize: App.Spacing.mediaRoomMetaDataAlbumText
                            opacity: 0.8
                        }
                        Text {
                            text: currentSongText.text ?
                                (mediaManager ? mediaManager.get_album(currentSongText.text) : "Unknown Album") :
                                "Unknown Album"
                            color: App.Style.metadataColor
                            font.pixelSize: App.Spacing.mediaRoomMetaDataAlbumText
                            opacity: 0.8
                        }
                    }

                    Timer {
                        id: metadataScrollTimer
                        interval: 3000
                        running: metadataRow.width > centeredMetadata.width
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
                        onClicked: mediaManager.toggle_shuffle()
                    }
                }

                Text {
                    id: positionText
                    text: formatTime(mediaRoom.position)
                    color: App.Style.mediaRoomSeekColor
                    font.pixelSize: App.Spacing.mediaRoomSliderDurationText
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
                            mediaManager.set_position(progressSlider.value)
                            mediaRoom.position = progressSlider.value
                            mouse.accepted = false
                        }
                    }

                    onPressedChanged: {
                        if (pressed) {
                            userSeeking = true
                        } else {
                            userSeeking = false
                            mediaManager.set_position(value)
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
                    Layout.minimumWidth: 40  // Added minimum width for consistent layout
                }
            }
        }
    }

    Connections {
        target: mediaManager
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
            isShuffleEnabled = enabled
        }
    }
    
    Connections {
        target: mediaManager
        function onMuteChanged(muted) {
            volumeControl.isMuted = muted
            // Fix: use the proper object path
            topVolumeControl.updateVolumeIcon()
        }
        
        function onVolumeChanged(volume) {
            // Only update if not being changed by user
            if (!volumeSlider.pressed) {
                var volumePercent = Math.round(Math.sqrt(volume) * 100)
                volumeControl.currentValue = volumePercent
                volumeSlider.value = volumePercent
            }
            // Fix: use the proper object path
            topVolumeControl.updateVolumeIcon()
        }
    }
}