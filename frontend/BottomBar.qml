import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Basic 2.15
import Qt5Compat.GraphicalEffects
import "." as App

Rectangle {
    id: bottomBar
    property bool isVertical: settingsManager && settingsManager.bottomBarOrientation === "side"

    // Spotify integration - use Spotify when user chooses it AND it's connected
    property bool useSpotify: settingsManager && settingsManager.mediaSource === "spotify" &&
                              spotifyManager && spotifyManager.is_connected()
    
    
    Component.onCompleted: {
        updateLayout()
    }
    
    function updateLayout() {
        if (isVertical) {
            // Release anchors first to prevent binding loops
            anchors.bottom = undefined
            anchors.right = undefined
            
            // Set anchors for vertical layout
            anchors.left = parent.left
            anchors.top = parent.top
            
            // Explicitly set width and height as percentages
            width = parent.width * 0.1
            height = parent.height
        } else {
            // Release anchors first
            anchors.top = undefined
            anchors.right = undefined
            
            // Set anchors for horizontal layout
            anchors.left = parent.left
            anchors.bottom = parent.bottom
            
            // Explicitly set width and height
            width = parent.width
            height = parent.height * App.Spacing.bottomBarHeightPercent
        }
    }
    
    // Watch for settings changes
    Connections {
        target: settingsManager
        function onBottomBarOrientationChanged() {
            updateLayout()
        }
    }
    
    // Watch for isVertical changes
    onIsVerticalChanged: {
        updateLayout()
    }
    
    // Explicitly handle parent size changes
    Connections {
        target: parent
        function onWidthChanged() {
            if (isVertical) {
                width = parent.width * 0.1
            } else {
                width = parent.width
            }
        }
        function onHeightChanged() {
            if (isVertical) {
                height = parent.height
            } else {
                height = parent.height * App.Spacing.bottomBarHeightPercent
            }
        }
    }
    
    gradient: Gradient {
        orientation: isVertical ? Gradient.Horizontal : Gradient.Vertical
        GradientStop { position: 1.5; color: App.Style.bottomBarGradientStart }
        GradientStop { position: 0.0; color: App.Style.bottomBarGradientEnd }
    }

    signal clicked()
    
    MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) {
            bottomBar.clicked()
            mouse.accepted = false // Allow clicks to pass through
        }
        z: -1 // Put behind other controls
    }

    layer.enabled: true
    layer.effect: DropShadow {
        color: "#40000000"
        radius: 8
        samples: 16
        verticalOffset: -4
    }

    required property StackView stackView
    required property Window mainWindow

    Loader {
        anchors.fill: parent
        sourceComponent: isVertical ? verticalLayoutComponent : horizontalLayoutComponent

        Component { //horizontal 
            id: horizontalLayoutComponent

            RowLayout { // Main layout that divides the bar into three sections with equal spacing
                anchors.fill: parent
                spacing: 0 // We'll handle spacing within each section
                

                Item { // SECTION 1: Left section - Media Controls
                    Layout.preferredWidth: parent.width * 0.4 // Allocate 40% of space 
                    Layout.fillHeight: true
                    
                    RowLayout { 
                        id: mediaControls
                        anchors {
                            left: parent.left
                            leftMargin: App.Spacing.overallMargin
                            right: parent.right
                            rightMargin: App.Spacing.overallMargin
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: App.Spacing.bottomBarBetweenButtonMargin

                        // Previous button
                        Control {
                            id: previousButtonControl
                            implicitWidth: App.Spacing.bottomBarPreviousButtonWidth
                            implicitHeight: App.Spacing.bottomBarPreviousButtonHeight
                            Layout.alignment: Qt.AlignVCenter
                            
                            scale: mouseAreaPrev.pressed ? 0.8 : 1.0
                            opacity: mouseAreaPrev.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle { color: "transparent" }
                            
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
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    id: colorOverlay
                                    anchors.fill: previousButtonImage
                                    source: previousButtonImage
                                    color: App.Style.bottomBarPreviousButton
                                }
                            }
                            Item {
                                id: previousButtonClickArea
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 2.5   

                                MouseArea {
                                    id: mouseAreaPrev
                                    anchors.fill: parent
                                    onClicked: mediaManager.previous_track()
                                }
                            }
                        }

                        // Play/Pause button
                        Control {
                            id: playButtonControl
                            implicitWidth: App.Spacing.bottomBarPlayButtonWidth
                            implicitHeight: App.Spacing.bottomBarPlayButtonHeight
                            Layout.alignment: Qt.AlignVCenter

                            scale: mouseAreaPlay.pressed ? 0.8 : 1.0
                            opacity: mouseAreaPlay.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle { color: "transparent" }
                            
                            contentItem: Item {
                                Image {
                                    id: playButtonImage
                                    anchors.centerIn: parent
                                    width: parent.height
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
                                    color: App.Style.bottomBarPlayButton
                                }
                            }
                            Item {
                                id: playButtonClickArea
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 2.5   

                                MouseArea {
                                    id: mouseAreaPlay
                                    anchors.fill: parent
                                    onClicked: mediaManager.toggle_play()
                                }
                            }
                        }

                        // Next button
                        Control {
                            id: nextButtonControl
                            implicitWidth: App.Spacing.bottomBarNextButtonWidth
                            implicitHeight: App.Spacing.bottomBarNextButtonHeight
                            Layout.alignment: Qt.AlignVCenter

                            scale: mouseAreaNext.pressed ? 0.8 : 1.0
                            opacity: mouseAreaNext.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle { color: "transparent" }
                            
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
                                    color: App.Style.bottomBarNextButton
                                }
                            }
                            Item {
                                id: nextButtonClickArea
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 2.5
                            
                                MouseArea {
                                    id: mouseAreaNext
                                    anchors.fill: parent
                                    onClicked: mediaManager.next_track()
                                }
                            }
                        }

                        // Shuffle button
                        Control {
                            id: shuffleButton
                            property bool isShuffleEnabled: useSpotify ?
                                (spotifyManager ? spotifyManager.is_shuffled() : false) :
                                (mediaManager ? mediaManager.is_shuffled() : false)
                            implicitWidth: App.Spacing.bottomBarShuffleButtonWidth
                            implicitHeight: App.Spacing.bottomBarShuffleButtonHeight
                            Layout.alignment: Qt.AlignVCenter

                            scale: mouseAreaShuffle.pressed ? 0.8 : 1.0
                            opacity: mouseAreaShuffle.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle {
                                color: shuffleButton.isShuffleEnabled ? App.Style.bottomBarToggleShade : "transparent"
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
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: shuffleButtonImage
                                    source: shuffleButtonImage
                                    color: shuffleButton.isShuffleEnabled ? 
                                        App.Style.bottomBarActiveToggleButton : 
                                        App.Style.bottomBarVolumeButton
                                }
                            }

                            Item {
                                id: shuffleButtonClickArea
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 2.5

                                MouseArea {
                                    id: mouseAreaShuffle
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

                        // Mute button
                        Control {
                            id: muteButton
                            property bool isMuted: false
                            implicitWidth: App.Spacing.bottomBarMuteButtonWidth
                            implicitHeight: App.Spacing.bottomBarMuteButtonHeight
                            Layout.alignment: Qt.AlignVCenter

                            scale: mouseAreaMute.pressed ? 0.8 : 1.0
                            opacity: mouseAreaMute.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle { color: "transparent" }
                            
                            contentItem: Item {
                                Image {
                                    id: muteButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width  
                                    height: parent.height
                                    source: getUpdatedMuteSource()
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: muteButtonImage
                                    source: muteButtonImage
                                    color: App.Style.bottomBarVolumeButton
                                }
                            }
                            Item {
                                id: muteButtonClickArea
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 2.5
                            
                                MouseArea {
                                    id: mouseAreaMute
                                    anchors.fill: parent 
                                    onClicked: {
                                        muteButton.isMuted = !muteButton.isMuted
                                        mediaManager.toggle_mute()
                                    }
                                }
                            }
                        }

                        // Volume Control
                        Control {
                            id: volumeControl
                            implicitWidth: App.Spacing.bottomBarVolumeSliderWidth
                            implicitHeight: App.Spacing.bottomBarVolumeSliderHeight
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                id: volumeText
                                anchors {
                                    left: parent.left
                                    leftMargin: App.Spacing.overallMargin
                                    verticalCenter: parent.verticalCenter
                                }
                                text: volumeControl.currentValue + "%"
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.bottomBarVolumeText
                                font.bold: true
                            }
                            
                            property int currentValue: 0
                            
                            Component.onCompleted: {
                                if (settingsManager) {
                                    var volumeValue = settingsManager.startUpVolume
                                    currentValue = Math.round(Math.sqrt(volumeValue) * 100)
                                    mediaManager.setVolume(volumeValue)
                                } else {
                                    currentValue = 10
                                    mediaManager.setVolume(0.1)
                                }
                                
                                updateMuteButtonImage()

                                if (mediaManager) {
                                    shuffleButton.isShuffleEnabled = mediaManager.is_shuffled()
                                }
                            }
                            Item {
                                anchors.centerIn: parent
                                width: parent.width * 1.5
                                height: parent.height * 3.5

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: popupSlider.open()
                                }
                            }

                            Popup {
                                id: popupSlider
                                width: parent.Window.width
                                height: 140
                                anchors.centerIn: Overlay.overlay
                                modal: true
                                focus: true
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                
                                // Simple background
                                background: Rectangle {
                                    color: App.Style.backgroundColor
                                    radius: 8
                                    border.color: App.Style.accent
                                    border.width: 1
                                }
                                
                                // Content with centered slider
                                contentItem: Item {
                                    anchors.fill: parent
                                    
                                    // Larger percentage display
                                    Label {
                                        id: percentLabel
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 15
                                        text: Math.round(volumeSlider.value) + "%"
                                        color: App.Style.accent
                                        font.pixelSize: 32
                                        font.bold: true
                                    }
                                    
                                    // Container for the slider - centered in the popup
                                    Item {
                                        id: sliderContainer
                                        anchors.top: percentLabel.bottom
                                        anchors.topMargin: 15
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 15
                                        
                                        // Simplified slider
                                        Slider {
                                            id: volumeSlider
                                            anchors.centerIn: parent
                                            width: parent.width * 0.95
                                            height: 50
                                            from: 0
                                            to: 100
                                            stepSize: 1
                                            value: volumeControl.currentValue
                                            
                                            // Simple slider background
                                            background: Rectangle {
                                                x: volumeSlider.leftPadding
                                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                                width: volumeSlider.availableWidth
                                                height: 16
                                                radius: 8
                                                color: App.Style.hoverColor
                                                
                                                // Filled portion
                                                Rectangle {
                                                    width: volumeSlider.visualPosition * parent.width
                                                    height: parent.height
                                                    color: App.Style.volumeSliderColor
                                                    radius: 8
                                                }
                                            }
                                            
                                            // Larger handle for better touch
                                            handle: Rectangle {
                                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                                width: 40
                                                height: 40
                                                radius: 20  // Circular handle
                                                color: App.Style.accent
                                            }
                                            
                                            // The core functionality
                                            onValueChanged: {
                                                volumeControl.currentValue = value
                                                var normalizedValue = value / 100
                                                var logVolume = Math.pow(normalizedValue, 2.0)
                                                mediaManager.setVolume(logVolume)
                                                
                                                if (value > 0 && muteButton.isMuted) {
                                                    muteButton.isMuted = false
                                                    mediaManager.toggle_mute()
                                                }
                                                updateMuteButtonImage()
                                            }
                                        }
                                        
                                        // Circular touch area
                                        Item {
                                            id: touchAreaContainer
                                            anchors.centerIn: sliderContainer
                                            width: sliderContainer.width
                                            height: sliderContainer.height
                                            
                                            // Create multiple circular touch areas along the slider track
                                            Repeater {
                                                model: 9  // Create 9 touch areas along the slider
                                                
                                                // Each touch area is a circular MouseArea
                                                MouseArea {
                                                    id: circularTouchArea
                                                    // Position touch areas evenly along the slider
                                                    x: (index * (volumeSlider.width / 8)) - width/2 + volumeSlider.x
                                                    y: volumeSlider.y + volumeSlider.height/2 - height/2
                                                    width: 80  // Large circular area
                                                    height: 80
                                                    
                                                    // Make the touch area visually circular (only for debugging)
                                                    // Rectangle {
                                                    //     anchors.fill: parent
                                                    //     radius: width/2
                                                    //     color: "transparent"
                                                    //     border.width: 1
                                                    //     border.color: "red"
                                                    //     opacity: 0.3
                                                    // }
                                                    
                                                    // Handle touch interactions
                                                    onMouseXChanged: {
                                                        if (pressed) {
                                                            // Calculate global position relative to the slider
                                                            var globalX = mapToItem(volumeSlider, mouseX, mouseY).x
                                                            var newPosition = Math.max(0, Math.min(1, 
                                                                (globalX - volumeSlider.leftPadding) / volumeSlider.availableWidth))
                                                            volumeSlider.value = newPosition * 100
                                                        }
                                                    }
                                                    
                                                    // Allow slider to receive events too
                                                    preventStealing: false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Item { // SECTION 2: Center section - Navigation Buttons
                    Layout.preferredWidth: parent.width * 0.4 // Allocate 40% of space
                    Layout.fillHeight: true
                    
                    RowLayout {
                        id: navigationBar
                        anchors.centerIn: parent
                        spacing: App.Spacing.bottomBarBetweenButtonMargin * 8
                        
                        // Home Button (Main Menu)
                        Control {
                            id: homeButton
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            
                            // Add scale and opacity animations
                            scale: mouseAreaHome.pressed ? 0.8 : 1.0
                            opacity: mouseAreaHome.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: homeButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/home_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: homeButtonImage
                                    source: homeButtonImage
                                    color: App.Style.bottomBarHomeButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaHome
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    // Pop to root/main menu
                                    while (stackView.depth > 1) {
                                        stackView.pop();
                                    }
                                }
                            }
                        }
                        
                        // OBD Button
                        Control {
                            id: obdButton
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            
                            // Add scale and opacity animations
                            scale: mouseAreaOBD.pressed ? 0.8 : 1.0
                            opacity: mouseAreaOBD.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: obdButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/obd_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: obdButtonImage
                                    source: obdButtonImage
                                    color: App.Style.bottomBarOBDButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaOBD
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var component = Qt.createComponent("OBDMenu.qml")
                                    if (component.status === Component.Ready) {
                                        var page = component.createObject(stackView, {
                                            stackView: bottomBar.stackView,
                                            mainWindow: stackView.parent.Window.window
                                        })
                                        if (page) {
                                            stackView.push(page)
                                        }
                                    }
                                }
                            }
                        }

                        // Media Button
                        Control {
                            id: mediaButton
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            
                            // Add scale and opacity animations
                            scale: mouseAreaMedia.pressed ? 0.8 : 1.0
                            opacity: mouseAreaMedia.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: mediaButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/media_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: mediaButtonImage
                                    source: mediaButtonImage
                                    color: App.Style.bottomBarMediaButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaMedia
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    // Check if current page is MediaRoom, if so go to MediaPlayer
                                    var currentItem = stackView.currentItem
                                    if (currentItem && currentItem.objectName === "mediaRoom") {
                                        var component = Qt.createComponent("MediaPlayer.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView,
                                                mainWindow: stackView.parent.Window.window
                                            })
                                            stackView.push(page)
                                        }
                                    } else if (currentItem && currentItem.objectName === "mediaPlayer") {
                                        // If on MediaPlayer, go back to MediaRoom
                                        var component = Qt.createComponent("MediaRoom.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView
                                            })
                                            stackView.push(page)
                                        }
                                    } else {
                                        // Otherwise, go to MediaRoom
                                        var component = Qt.createComponent("MediaRoom.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView
                                            })
                                            stackView.push(page)
                                        }
                                    }
                                }
                            }
                        }

                        // Settings Button
                        Control {
                            id: settingsButton
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            
                            // Add scale and opacity animations
                            scale: mouseAreaSettings.pressed ? 0.8 : 1.0
                            opacity: mouseAreaSettings.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: settingsButtonImage
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/settings_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: settingsButtonImage
                                    source: settingsButtonImage
                                    color: App.Style.bottomBarSettingsButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaSettings
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var page = Qt.createComponent("SettingsMenu.qml").createObject(stackView, {
                                        stackView: bottomBar.stackView,
                                        mainWindow: stackView.parent.Window.window,
                                        initialSection: lastSettingsSection
                                    })
                                    stackView.push(page)
                                }
                            }
                        }
                    }
                }
                
                Item { // SECTION 3: Right section - Clock and other controls
                    Layout.preferredWidth: parent.width * 0.2 // Allocate 20% of space
                    Layout.fillHeight: true
                    
                    RowLayout {
                        id: rightControls
                        anchors {
                            right: parent.right
                            rightMargin: App.Spacing.overallMargin
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: App.Spacing.bottomBarBetweenButtonMargin
                        

                        Item {
                            id: clockContainer
                            Layout.preferredWidth: clockText.implicitWidth + 20 // Add some padding
                            Layout.preferredHeight: clockText.implicitHeight + 10
                            
                            Rectangle {
                                anchors.fill: parent
                                color: mouseAreaClock.pressed ? App.Style.hoverColor : "transparent"
                                radius: 4
                            }
                            
                            Text {
                                id: clockText
                                anchors.centerIn: parent
                                visible: settingsManager ? settingsManager.showClock : true
                                font.pixelSize: settingsManager ? settingsManager.clockSize : 18
                                color: App.Style.clockTextColor
                            }
                            
                            MouseArea {
                                id: mouseAreaClock
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var page = Qt.createComponent("CarMenu.qml").createObject(stackView, {
                                        stackView: bottomBar.stackView,
                                        mainWindow: bottomBar.mainWindow
                                    })
                                    stackView.push(page)
                                }
                            }
                        }
                    }
                }

                // Connections and Signal handlers
                Connections {
                    target: clock
                    function onTimeChanged(time) {
                        clockText.text = time
                    }
                }

                Connections {
                    target: mediaManager
                    function onPlayStateChanged(playing) {
                        playButtonImage.source = playing ? 
                            "./assets/pause_button.svg" : "./assets/play_button.svg"
                    }
                    function onMuteChanged(muted) {
                        updateMuteButtonImage()
                    }
                    function onVolumeChanged(volume) {
                        // Only update if not being changed by the slider itself
                        if (!volumeSlider.pressed) {
                            // Convert from raw volume to percentage (0-100)
                            var volumePercentage = Math.round(Math.sqrt(volume) * 100)
                            volumeControl.currentValue = volumePercentage
                            volumeSlider.value = volumePercentage
                        }
                        updateMuteButtonImage()
                    }
                    function onShuffleStateChanged(enabled) {
                        if (!useSpotify) {
                            shuffleButton.isShuffleEnabled = enabled
                        }
                    }
                }

                // Spotify shuffle state connection
                Connections {
                    target: spotifyManager
                    enabled: useSpotify
                    function onShuffleStateChanged(enabled) {
                        shuffleButton.isShuffleEnabled = enabled
                    }
                }

                // Update shuffle state when media source changes
                Connections {
                    target: settingsManager
                    function onMediaSourceChanged(source) {
                        var nowUseSpotify = (source === "spotify" && spotifyManager && spotifyManager.is_connected())
                        if (nowUseSpotify) {
                            shuffleButton.isShuffleEnabled = spotifyManager.is_shuffled()
                        } else if (mediaManager) {
                            shuffleButton.isShuffleEnabled = mediaManager.is_shuffled()
                        }
                    }
                }

                Connections {
                    target: svgManager
                    function onSvgUpdated() {
                        var timestamp = new Date().getTime()
                        previousButtonImage.source = ""
                        playButtonImage.source = ""
                        nextButtonImage.source = ""
                        muteButtonImage.source = ""
                        shuffleButtonImage.source = ""
                        
                        previousButtonImage.source = `./assets/previous_button.svg?t=${timestamp}`
                        playButtonImage.source = mediaManager && mediaManager.is_playing() ? 
                            `./assets/pause_button.svg?t=${timestamp}` : 
                            `./assets/play_button.svg?t=${timestamp}`
                        nextButtonImage.source = `./assets/next_button.svg?t=${timestamp}`
                        muteButtonImage.source = getUpdatedMuteSource() + `?t=${timestamp}`
                        shuffleButtonImage.source = `./assets/shuffle_button.svg?t=${timestamp}`
                    }
                }
                // Helper functions
                function getUpdatedMuteSource() {
                    if (mediaManager.is_muted() || muteButton.isMuted || volumeSlider.value === 0) {
                        return "./assets/mute_on.svg"
                    }
                    const volume = volumeSlider.value
                    if (volumeControl.currentValue < 20) return "./assets/mute_off_med.svg"
                    if (volumeControl.currentValue > 90) return "./assets/mute_off_low.svg"
                    return "./assets/mute_off_low.svg"
                }

                function updateMuteButtonImage() {
                    muteButtonImage.source = getUpdatedMuteSource()
                }
            }
        }

        Component { //Vertical
            id: verticalLayoutComponent

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // SECTION 1: Media Controls (Top section when vertical)
                Item {
                    Layout.preferredHeight: parent.height * 0.4
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.bottomBarBetweenButtonMargin * 4
                        
                        // ROW 1: Previous and Next buttons
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: App.Spacing.bottomBarBetweenButtonMargin * 2

                            Item {
                                Layout.fillWidth: true
                            }
                            
                            // Previous button
                            Control {
                                id: previousButtonControlVertical
                                Layout.preferredWidth: App.Spacing.bottomBarPreviousButtonWidth
                                Layout.preferredHeight: App.Spacing.bottomBarPreviousButtonHeight
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                
                                scale: mouseAreaPrevVertical.pressed ? 0.8 : 1.0
                                opacity: mouseAreaPrevVertical.pressed ? 0.7 : 1.0
                                
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutBack  
                                        easing.overshoot: 1.1
                                    }
                                }
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }

                                background: Rectangle { color: "transparent" }
                                
                                contentItem: Item {
                                    Image {
                                        id: previousButtonImageVertical
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: parent.height
                                        source: "./assets/previous_button.svg"
                                        sourceSize: Qt.size(width * 2, height * 2)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                        mipmap: true
                                        visible: false
                                    }
                                    
                                    ColorOverlay {
                                        anchors.fill: previousButtonImageVertical
                                        source: previousButtonImageVertical
                                        color: App.Style.bottomBarPreviousButton
                                    }
                                }
                                
                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width 
                                    height: parent.height * 2

                                    MouseArea {
                                        id: mouseAreaPrevVertical
                                        anchors.fill: parent
                                        onClicked: mediaManager.previous_track()
                                    }
                                }
                            }
                            
                            // Next button
                            Control {
                                id: nextButtonControlVertical
                                Layout.preferredWidth: App.Spacing.bottomBarNextButtonWidth
                                Layout.preferredHeight: App.Spacing.bottomBarNextButtonHeight
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                                scale: mouseAreaNextVertical.pressed ? 0.8 : 1.0
                                opacity: mouseAreaNextVertical.pressed ? 0.7 : 1.0
                                
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutBack  
                                        easing.overshoot: 1.1
                                    }
                                }
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                                
                                background: Rectangle { color: "transparent" }
                                
                                contentItem: Item {
                                    Image {
                                        id: nextButtonImageVertical
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
                                        anchors.fill: nextButtonImageVertical
                                        source: nextButtonImageVertical
                                        color: App.Style.bottomBarNextButton
                                    }
                                }
                                
                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height * 2
                                
                                    MouseArea {
                                        id: mouseAreaNextVertical
                                        anchors.fill: parent
                                        onClicked: mediaManager.next_track()
                                    }
                                }
                            }
                            
                            Item {
                                Layout.fillWidth: true
                            }
                        }
                        
                        // Play/Pause button
                        Control {
                            id: playButtonControlVertical
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: App.Spacing.bottomBarPlayButtonWidth
                            Layout.preferredHeight: App.Spacing.bottomBarPlayButtonHeight

                            scale: mouseAreaPlayVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaPlayVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle { color: "transparent" }
                            
                            contentItem: Item {
                                Image {
                                    id: playButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.height
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
                                    anchors.fill: playButtonImageVertical
                                    source: playButtonImageVertical
                                    color: App.Style.bottomBarPlayButton
                                }
                            }
                            
                            Item {
                                anchors.centerIn: parent
                                width: parent.width * 3
                                height: parent.height 

                                MouseArea {
                                    id: mouseAreaPlayVertical
                                    anchors.fill: parent
                                    onClicked: mediaManager.toggle_play()
                                }
                            }
                        }
                        
                        // Shuffle button
                        Control {
                            id: shuffleButtonVertical
                            property bool isShuffleEnabled: useSpotify ?
                                (spotifyManager ? spotifyManager.is_shuffled() : false) :
                                (mediaManager ? mediaManager.is_shuffled() : false)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: App.Spacing.bottomBarShuffleButtonWidth
                            Layout.preferredHeight: App.Spacing.bottomBarShuffleButtonHeight

                            scale: mouseAreaShuffleVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaShuffleVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle {
                                color: shuffleButtonVertical.isShuffleEnabled ? App.Style.bottomBarToggleShade : "transparent"
                                radius: width / 2
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: shuffleButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: "./assets/shuffle_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: shuffleButtonImageVertical
                                    source: shuffleButtonImageVertical
                                    color: shuffleButtonVertical.isShuffleEnabled ? 
                                        App.Style.bottomBarActiveToggleButton : 
                                        App.Style.bottomBarVolumeButton
                                }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: parent.width * 3
                                height: parent.height

                                MouseArea {
                                    id: mouseAreaShuffleVertical
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
                        
                        // Mute button
                        Control {
                            id: muteButtonVertical
                            property bool isMuted: false
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: App.Spacing.bottomBarMuteButtonWidth
                            Layout.preferredHeight: App.Spacing.bottomBarMuteButtonHeight
                            
                            scale: mouseAreaMuteVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaMuteVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            background: Rectangle { color: "transparent" }
                            
                            contentItem: Item {
                                Image {
                                    id: muteButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width  
                                    height: parent.height
                                    source: getUpdatedMuteSourceVertical()
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: muteButtonImageVertical
                                    source: muteButtonImageVertical
                                    color: App.Style.bottomBarVolumeButton
                                }
                            }
                            
                            Item {
                                anchors.centerIn: parent
                                width: parent.width * 3
                                height: parent.height 
                            
                                MouseArea {
                                    id: mouseAreaMuteVertical
                                    anchors.fill: parent 
                                    onClicked: {
                                        muteButtonVertical.isMuted = !muteButtonVertical.isMuted
                                        mediaManager.toggle_mute()
                                    }
                                }
                            }
                        }
                        
                        // Volume control with better alignment
                        Control {
                            id: volumeControlVertical
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: App.Spacing.bottomBarVolumeSliderWidth * 0.8
                            Layout.preferredHeight: App.Spacing.bottomBarVolumeSliderHeight
                            
                            property int currentValue: 0
                            
                            Text {
                                id: volumeTextVertical
                                anchors.centerIn: parent
                                text: volumeControlVertical.currentValue + "%"
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.bottomBarVolumeText
                                font.bold: true
                                anchors.horizontalCenterOffset: -2  // Further adjust text position
                            }
                            
                            Component.onCompleted: {
                                if (settingsManager) {
                                    var volumeValue = settingsManager.startUpVolume
                                    currentValue = Math.round(Math.sqrt(volumeValue) * 100)
                                    mediaManager.setVolume(volumeValue)
                                } else {
                                    currentValue = 10
                                    mediaManager.setVolume(0.1)
                                }
                                
                                updateMuteButtonImageVertical()

                                if (mediaManager) {
                                    shuffleButtonVertical.isShuffleEnabled = mediaManager.is_shuffled()
                                }
                            }
                            Item {
                                anchors.centerIn: parent
                                width: parent.width*3 
                                height: parent.height*2

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: popupSliderVertical.open()
                                }
                            }

                            Popup {
                                id: popupSliderVertical
                                width: parent.Window.width
                                height: 140
                                anchors.centerIn: Overlay.overlay
                                modal: true
                                focus: true
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                
                                // Simple background
                                background: Rectangle {
                                    color: App.Style.backgroundColor
                                    radius: 8
                                    border.color: App.Style.accent
                                    border.width: 1
                                }
                                
                                // Content with centered slider
                                contentItem: Item {
                                    anchors.fill: parent
                                    
                                    // Larger percentage display
                                    Label {
                                        id: percentLabelVertical
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 15
                                        text: Math.round(volumeSliderVertical.value) + "%"
                                        color: App.Style.accent
                                        font.pixelSize: 32
                                        font.bold: true
                                    }
                                    
                                    // Container for the slider - centered in the popup
                                    Item {
                                        id: sliderContainerVertical
                                        anchors.top: percentLabelVertical.bottom
                                        anchors.topMargin: 15
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 15
                                        
                                        // Simplified slider
                                        Slider {
                                            id: volumeSliderVertical
                                            anchors.centerIn: parent
                                            width: parent.width * 0.95
                                            height: 50
                                            from: 0
                                            to: 100
                                            stepSize: 1
                                            value: volumeControlVertical.currentValue
                                            
                                            // Simple slider background
                                            background: Rectangle {
                                                x: volumeSliderVertical.leftPadding
                                                y: volumeSliderVertical.topPadding + volumeSliderVertical.availableHeight / 2 - height / 2
                                                width: volumeSliderVertical.availableWidth
                                                height: 16
                                                radius: 8
                                                color: App.Style.hoverColor
                                                
                                                // Filled portion
                                                Rectangle {
                                                    width: volumeSliderVertical.visualPosition * parent.width
                                                    height: parent.height
                                                    color: App.Style.volumeSliderColor
                                                    radius: 8
                                                }
                                            }
                                            
                                            // Larger handle for better touch
                                            handle: Rectangle {
                                                x: volumeSliderVertical.leftPadding + volumeSliderVertical.visualPosition * (volumeSliderVertical.availableWidth - width)
                                                y: volumeSliderVertical.topPadding + volumeSliderVertical.availableHeight / 2 - height / 2
                                                width: 40
                                                height: 40
                                                radius: 20  // Circular handle
                                                color: App.Style.accent
                                            }
                                            
                                            // The core functionality
                                            onValueChanged: {
                                                volumeControlVertical.currentValue = value
                                                var normalizedValue = value / 100
                                                var logVolume = Math.pow(normalizedValue, 2.0)
                                                mediaManager.setVolume(logVolume)
                                                
                                                if (value > 0 && muteButtonVertical.isMuted) {
                                                    muteButtonVertical.isMuted = false
                                                    mediaManager.toggle_mute()
                                                }
                                                updateMuteButtonImageVertical()
                                            }
                                        }
                                        
                                        // Circular touch area
                                        Item {
                                            id: touchAreaContainerVertical
                                            anchors.centerIn: sliderContainerVertical
                                            width: sliderContainerVertical.width
                                            height: sliderContainerVertical.height
                                            
                                            // Create multiple circular touch areas along the slider track
                                            Repeater {
                                                model: 9  // Create 9 touch areas along the slider
                                                
                                                // Each touch area is a circular MouseArea
                                                MouseArea {
                                                    // Position touch areas evenly along the slider
                                                    x: (index * (volumeSliderVertical.width / 8)) - width/2 + volumeSliderVertical.x
                                                    y: volumeSliderVertical.y + volumeSliderVertical.height/2 - height/2
                                                    width: 80  // Large circular area
                                                    height: 80
                                                    
                                                    // Handle touch interactions
                                                    onMouseXChanged: {
                                                        if (pressed) {
                                                            // Calculate global position relative to the slider
                                                            var globalX = mapToItem(volumeSliderVertical, mouseX, mouseY).x
                                                            var newPosition = Math.max(0, Math.min(1, 
                                                                (globalX - volumeSliderVertical.leftPadding) / volumeSliderVertical.availableWidth))
                                                            volumeSliderVertical.value = newPosition * 100
                                                        }
                                                    }
                                                    
                                                    // Allow slider to receive events too
                                                    preventStealing: false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // SECTION 2: Navigation (Middle section when vertical)
                Item {
                    Layout.preferredHeight: parent.height * 0.5
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.bottomBarBetweenButtonMargin * 3

                        // Home Button
                        Control {
                            id: homeButtonVertical
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth*1.5
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            Layout.alignment: Qt.AlignHCenter
                            
                            scale: mouseAreaHomeVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaHomeVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: homeButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/home_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: homeButtonImageVertical
                                    source: homeButtonImageVertical
                                    color: App.Style.bottomBarHomeButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaHomeVertical
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    while (stackView.depth > 1) {
                                        stackView.pop();
                                    }
                                }
                            }
                        }
                        // OBD Button
                        Control {
                            id: obdButtonVertical
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth*1.5
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            Layout.alignment: Qt.AlignHCenter
                            
                            scale: mouseAreaOBDVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaOBDVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: obdButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/obd_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: obdButtonImageVertical
                                    source: obdButtonImageVertical
                                    color: App.Style.bottomBarOBDButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaOBDVertical
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var component = Qt.createComponent("OBDMenu.qml")
                                    if (component.status === Component.Ready) {
                                        var page = component.createObject(stackView, {
                                            stackView: bottomBar.stackView,
                                            mainWindow: stackView.parent.Window.window
                                        })
                                        if (page) {
                                            stackView.push(page)
                                        }
                                    }
                                }
                            }
                        }

                        // Media Button
                        Control {
                            id: mediaButtonVertical
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth*1.5
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            Layout.alignment: Qt.AlignHCenter
                            
                            scale: mouseAreaMediaVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaMediaVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: mediaButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/media_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: mediaButtonImageVertical
                                    source: mediaButtonImageVertical
                                    color: App.Style.bottomBarMediaButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaMediaVertical
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    // Check if current page is MediaRoom, if so go to MediaPlayer
                                    var currentItem = stackView.currentItem
                                    if (currentItem && currentItem.objectName === "mediaRoom") {
                                        var component = Qt.createComponent("MediaPlayer.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView,
                                                mainWindow: stackView.parent.Window.window
                                            })
                                            stackView.push(page)
                                        }
                                    } else if (currentItem && currentItem.objectName === "mediaPlayer") {
                                        // If on MediaPlayer, go back to MediaRoom
                                        var component = Qt.createComponent("MediaRoom.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView
                                            })
                                            stackView.push(page)
                                        }
                                    } else {
                                        // Otherwise, go to MediaRoom
                                        var component = Qt.createComponent("MediaRoom.qml")
                                        if (component.status === Component.Ready) {
                                            var page = component.createObject(stackView, {
                                                stackView: bottomBar.stackView
                                            })
                                            stackView.push(page)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Settings Button
                        Control {
                            id: settingsButtonVertical
                            implicitWidth: App.Spacing.bottomBarNavButtonWidth*1.5
                            implicitHeight: App.Spacing.bottomBarNavButtonHeight
                            Layout.alignment: Qt.AlignHCenter
                            
                            scale: mouseAreaSettingsVertical.pressed ? 0.8 : 1.0
                            opacity: mouseAreaSettingsVertical.pressed ? 0.7 : 1.0
                            
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack  
                                    easing.overshoot: 1.1
                                }
                            }
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                                radius: 8
                                border.color: App.Style.accent
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Image {
                                    id: settingsButtonImageVertical
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    source: "./assets/settings_button.svg"
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    mipmap: true
                                    visible: false
                                }
                                
                                ColorOverlay {
                                    anchors.fill: settingsButtonImageVertical
                                    source: settingsButtonImageVertical
                                    color: App.Style.bottomBarSettingsButton
                                }
                            }
                            
                            MouseArea {
                                id: mouseAreaSettingsVertical
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var page = Qt.createComponent("SettingsMenu.qml").createObject(stackView, {
                                        stackView: bottomBar.stackView,
                                        mainWindow: stackView.parent.Window.window,
                                        initialSection: lastSettingsSection
                                    })
                                    stackView.push(page)
                                }
                            }
                        }
                    }
                }
                
                // SECTION 3: Clock (Bottom section when vertical)
                Item {
                    Layout.preferredHeight: parent.height * 0.1
                    Layout.fillWidth: true
                    
                    Item {
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: App.Spacing.overallMargin
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: parent.width
                        height: clockTextVertical.implicitHeight + 20
                        
                        Item {
                            id: clockContainerVertical
                            anchors.centerIn: parent
                            width: clockTextVertical.implicitWidth + 20
                            height: parent.height
                            
                            Rectangle {
                                anchors.fill: parent
                                color: mouseAreaClockVertical.pressed ? App.Style.hoverColor : "transparent"
                                radius: 4
                            }
                            
                            Text {
                                id: clockTextVertical
                                anchors.centerIn: parent
                                visible: settingsManager ? settingsManager.showClock : true
                                font.pixelSize: settingsManager ? settingsManager.clockSize : 18
                                color: App.Style.clockTextColor
                                text: clockTextVertical.text  // Get the time from the horizontal layout
                            }
                            
                            MouseArea {
                                id: mouseAreaClockVertical
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var page = Qt.createComponent("CarMenu.qml").createObject(stackView, {
                                        stackView: bottomBar.stackView,
                                        mainWindow: bottomBar.mainWindow
                                    })
                                    stackView.push(page)
                                }
                            }
                        }
                    }
                }
                
                // Helper functions for vertical layout
                function updateMuteButtonImageVertical() {
                    muteButtonImageVertical.source = getUpdatedMuteSourceVertical()
                }
                
                function getUpdatedMuteSourceVertical() {
                    if (mediaManager.is_muted() || muteButtonVertical.isMuted || volumeControlVertical.currentValue === 0) {
                        return "./assets/mute_on.svg"
                    }
                    const volume = volumeControlVertical.currentValue
                    if (volume < 33) {
                        return "./assets/mute_off_low.svg"
                    } else if (volume < 66) {
                        return "./assets/mute_off_med.svg"
                    } else {
                        return "./assets/mute_off_high.svg"
                    }
                }
                
                // Connections for vertical layout
                Connections {
                    target: clock
                    function onTimeChanged(time) {
                        clockTextVertical.text = time
                    }
                }

                Connections {
                    target: mediaManager
                    function onPlayStateChanged(playing) {
                        playButtonImageVertical.source = playing ? 
                            "./assets/pause_button.svg" : "./assets/play_button.svg"
                    }
                    function onMuteChanged(muted) {
                        muteButtonVertical.isMuted = muted
                        updateMuteButtonImageVertical()
                    }
                    function onVolumeChanged(volume) {
                        // Update volume text in vertical layout
                        var volumePercentage = Math.round(Math.sqrt(volume) * 100)
                        volumeControlVertical.currentValue = volumePercentage
                        updateMuteButtonImageVertical()
                    }
                    function onShuffleStateChanged(enabled) {
                        if (!useSpotify) {
                            shuffleButtonVertical.isShuffleEnabled = enabled
                        }
                    }
                }

                // Spotify shuffle state connection for vertical layout
                Connections {
                    target: spotifyManager
                    enabled: useSpotify
                    function onShuffleStateChanged(enabled) {
                        shuffleButtonVertical.isShuffleEnabled = enabled
                    }
                }

                // Update shuffle state when media source changes (vertical)
                Connections {
                    target: settingsManager
                    function onMediaSourceChanged(source) {
                        var nowUseSpotify = (source === "spotify" && spotifyManager && spotifyManager.is_connected())
                        if (nowUseSpotify) {
                            shuffleButtonVertical.isShuffleEnabled = spotifyManager.is_shuffled()
                        } else if (mediaManager) {
                            shuffleButtonVertical.isShuffleEnabled = mediaManager.is_shuffled()
                        }
                    }
                }

                // SVG update connection for vertical layout
                Connections {
                    target: svgManager
                    function onSvgUpdated() {
                        var timestamp = new Date().getTime()
                        previousButtonImageVertical.source = `./assets/previous_button.svg?t=${timestamp}`
                        playButtonImageVertical.source = mediaManager && mediaManager.is_playing() ? 
                            `./assets/pause_button.svg?t=${timestamp}` : 
                            `./assets/play_button.svg?t=${timestamp}`
                        nextButtonImageVertical.source = `./assets/next_button.svg?t=${timestamp}`
                        muteButtonImageVertical.source = getUpdatedMuteSourceVertical() + `?t=${timestamp}`
                        shuffleButtonImageVertical.source = `./assets/shuffle_button.svg?t=${timestamp}`
                        homeButtonImageVertical.source = `./assets/home_button.svg?t=${timestamp}`
                        obdButtonImageVertical.source = `./assets/obd_button.svg?t=${timestamp}`
                        mediaButtonImageVertical.source = `./assets/media_button.svg?t=${timestamp}`
                        settingsButtonImageVertical.source = `./assets/settings_button.svg?t=${timestamp}`
                    }
                }
            }
        }
    }
}