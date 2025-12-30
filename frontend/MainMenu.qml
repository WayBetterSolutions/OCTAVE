import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Basic 2.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: mainMenu
    property StackView stackView
    property ApplicationWindow mainWindow
    property real windowWidth
    property real windowHeight
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Media content properties
    property string currentFile: ""
    property string currentArt: ""
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentAlbum: ""

    function formatTime(ms) {
        var minutes = Math.floor(ms / 60000)
        var seconds = Math.floor((ms % 60000) / 1000)
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    // Dark background with subtle gradient
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(App.Style.backgroundColor, 1.2) }
            GradientStop { position: 1.0; color: App.Style.backgroundColor }
        }
    }

    // Main content area - Horizontal layout: Media on left (1/3), OBD on right (2/3)
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ========== LEFT SECTION: Media Controls (1/3 of width) ==========
        Rectangle {
            id: mediaSection
            Layout.preferredWidth: parent.width * 0.33
            Layout.fillHeight: true
            color: "transparent"
            radius: 8
            clip: true

            // Album art blur background (like MediaRoom)
            Item {
                id: backgroundContainer
                anchors.fill: parent
                z: -1

                Image {
                    id: backgroundArtImage
                    anchors.fill: parent
                    source: mainMenu.currentArt || "./assets/missing_art.png"
                    fillMode: Image.PreserveAspectCrop
                    opacity: 1
                    layer.enabled: true
                    layer.effect: GaussianBlur {
                        radius: settingsManager ? settingsManager.backgroundBlurRadius : 40
                        samples: Math.min(32, Math.max(1, radius))
                        deviation: radius / 2.5
                        transparentBorder: false
                    }
                }

                // Dark overlay for readability
                Rectangle {
                    id: colorOverlay
                    anchors.fill: parent
                    color: "#C0000000"
                    opacity: 1.0
                }
            }

            // Border overlay (on top of blur)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: App.Style.accent
                border.width: 2
                radius: 8
                z: 10
            }

            // Media content - vertical layout for narrow panel
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // Album Art (top, centered)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.width - 30
                    Layout.alignment: Qt.AlignHCenter

                    Image {
                        id: albumArtImage
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        source: mainMenu.currentArt || "./assets/missing_art.png"
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true

                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 4
                            verticalOffset: 4
                            radius: 12.0
                            samples: 25
                            color: "#A0000000"
                        }
                    }
                }

                // Song title with scrolling (like MediaRoom)
                Item {
                    id: songTitleContainer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    height: Math.ceil(App.Spacing.mainMenuSongTextSize * 1.4)

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
                            text: mainMenu.currentTitle || "No track playing"
                            color: App.Style.metadataColor
                            font.pixelSize: App.Spacing.mainMenuSongTextSize
                            font.bold: true
                            font.family: mainMenu.globalFont
                        }

                        Timer {
                            id: songScrollTimer
                            interval: 3000
                            running: songTitleText.width > songTitleContainer.width
                            repeat: true
                            onTriggered: {
                                if (songTitleFlickable.contentX === 0) {
                                    songScrollAnimation.to = songTitleText.width - songTitleFlickable.width
                                    songScrollAnimation.start()
                                } else {
                                    songScrollAnimation.to = 0
                                    songScrollAnimation.start()
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

                // Artist & Album with scrolling (like MediaRoom)
                Item {
                    id: metadataContainer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    height: Math.ceil(App.Spacing.mainMenuArtistTextSize * 1.4)

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
                            spacing: 8

                            Text {
                                text: mainMenu.currentFile ? mainMenu.currentArtist : "Select a song"
                                color: App.Style.metadataColor
                                font.pixelSize: App.Spacing.mainMenuArtistTextSize
                                font.family: mainMenu.globalFont
                                opacity: 0.7
                            }
                            Text {
                                text: mainMenu.currentFile ? "•" : ""
                                color: App.Style.metadataColor
                                font.pixelSize: App.Spacing.mainMenuArtistTextSize
                                font.family: mainMenu.globalFont
                                opacity: 0.8
                            }
                            Text {
                                text: mainMenu.currentFile ? mainMenu.currentAlbum : ""
                                color: App.Style.metadataColor
                                font.pixelSize: App.Spacing.mainMenuArtistTextSize
                                font.family: mainMenu.globalFont
                                opacity: 0.8
                            }
                        }

                        Timer {
                            id: metadataScrollTimer
                            interval: 3000
                            running: metadataRow.width > metadataContainer.width
                            repeat: true
                            onTriggered: {
                                if (metadataFlickable.contentX === 0) {
                                    metadataScrollAnimation.to = metadataRow.width - metadataFlickable.width
                                    metadataScrollAnimation.start()
                                } else {
                                    metadataScrollAnimation.to = 0
                                    metadataScrollAnimation.start()
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

                // Spacer
                Item { Layout.fillHeight: true }

                // Media Controls Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: App.Spacing.mainMenuNavButtonSize * 0.5

                    // Previous Button
                    Control {
                        implicitHeight: App.Spacing.mainMenuNavButtonSize
                        implicitWidth: App.Spacing.mainMenuNavButtonSize
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
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: previousButtonImage
                                source: previousButtonImage
                                color: App.Style.mediaRoomPreviousButton
                                opacity: prevMouseArea.pressed ? 0.7 : 1.0
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    horizontalOffset: 2
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: "#80000000"
                                }
                            }
                        }
                        MouseArea {
                            id: prevMouseArea
                            anchors.fill: parent
                            onClicked: mediaManager.previous_track()
                        }
                    }

                    // Play/Pause Button
                    Control {
                        implicitHeight: App.Spacing.mainMenuPlayButtonSize
                        implicitWidth: App.Spacing.mainMenuPlayButtonSize
                        background: Rectangle { color: "transparent" }
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
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: playButtonImage
                                source: playButtonImage
                                color: App.Style.mediaRoomPlayButton
                                opacity: playMouseArea.pressed ? 0.7 : 1.0
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    horizontalOffset: 2
                                    verticalOffset: 2
                                    radius: 6.0
                                    samples: 13
                                    color: "#80000000"
                                }
                            }
                        }
                        MouseArea {
                            id: playMouseArea
                            anchors.fill: parent
                            onClicked: mediaManager.toggle_play()
                        }
                    }

                    // Next Button
                    Control {
                        implicitHeight: App.Spacing.mainMenuNavButtonSize
                        implicitWidth: App.Spacing.mainMenuNavButtonSize
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
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: nextButtonImage
                                source: nextButtonImage
                                color: App.Style.mediaRoomNextButton
                                opacity: nextMouseArea.pressed ? 0.7 : 1.0
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    horizontalOffset: 2
                                    verticalOffset: 2
                                    radius: 4.0
                                    samples: 9
                                    color: "#80000000"
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

                // Progress Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        id: positionText
                        text: "0:00"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mainMenuTimeTextSize
                        font.family: mainMenu.globalFont
                        Layout.minimumWidth: App.Spacing.mainMenuTimeTextSize * 2.5
                    }

                    Slider {
                        id: progressSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: 0
                        enabled: mediaManager && mediaManager.get_duration() > 0

                        property bool userSeeking: false

                        background: Rectangle {
                            x: progressSlider.leftPadding
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            width: progressSlider.availableWidth
                            height: App.Spacing.mainMenuSliderHeight
                            radius: height / 2
                            color: App.Style.secondaryTextColor

                            Rectangle {
                                width: progressSlider.visualPosition * parent.width
                                height: parent.height
                                radius: height / 2
                                color: App.Style.accent
                            }
                        }

                        handle: Rectangle {
                            x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            width: App.Spacing.mainMenuSliderHandleSize
                            height: App.Spacing.mainMenuSliderHandleSize
                            radius: width / 2
                            color: progressSlider.pressed ? App.Style.accent : App.Style.primaryTextColor
                            visible: true
                        }

                        onPressedChanged: {
                            if (pressed) {
                                userSeeking = true
                            } else {
                                userSeeking = false
                                if (mediaManager) {
                                    mediaManager.set_position(value)
                                }
                            }
                        }
                    }

                    Text {
                        id: durationText
                        text: "0:00"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mainMenuTimeTextSize
                        font.family: mainMenu.globalFont
                        Layout.minimumWidth: App.Spacing.mainMenuTimeTextSize * 2.5
                    }
                }
            }

            // Click to open MediaRoom/MediaPlayer based on setting
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {
                    var defaultPage = settingsManager ? settingsManager.musicButtonDefaultPage : "mediaRoom"
                    var targetPage = defaultPage === "mediaPlayer" ? "MediaPlayer.qml" : "MediaRoom.qml"
                    var props = { stackView: mainMenu.stackView }
                    if (defaultPage === "mediaPlayer") {
                        props.mainWindow = mainWindow
                    }
                    stackView.push(targetPage, props)
                }
            }
        }

        // ========== RIGHT SECTION: OBD (2/3 of width) ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.color: App.Style.accent
            border.width: 2
            radius: 8

            // Use the HomeOBDView component (stacked vertically)
            HomeOBDView {
                anchors.fill: parent
                anchors.margins: 5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    stackView.push("OBDMenu.qml", {
                        stackView: stackView,
                        mainWindow: mainWindow
                    })
                }
            }
        }
    }

    // Timer for initial delayed loading of media data
    Timer {
        id: initialLoadTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: {
            updateMedia()
        }
    }

    // Function to update media information
    function updateMedia() {
        if (mediaManager) {
            var filename = mediaManager.get_current_file()
            if (filename) {
                mainMenu.currentFile = filename
                mainMenu.currentTitle = filename.replace('.mp3', '')
                mainMenu.currentArtist = mediaManager.get_band(filename)
                mainMenu.currentAlbum = mediaManager.get_album(filename)
                mainMenu.currentArt = mediaManager.get_album_art(filename)
            }
        }
    }

    Component.onCompleted: {
        initialLoadTimer.start()
        if (obdManager && obdManager.refresh_values) {
            obdManager.refresh_values()
        }
    }

    // Media Connections
    Connections {
        target: mediaManager

        function onMetadataChanged(title, artist, album) {
            updateMedia()
            mainMenu.currentTitle = title
            mainMenu.currentArtist = artist
            mainMenu.currentAlbum = album
        }

        function onPositionChanged(position) {
            if (!progressSlider.userSeeking) {
                progressSlider.value = position
                positionText.text = formatTime(position)
            }
        }

        function onDurationChanged(duration) {
            progressSlider.to = duration > 0 ? duration : 1
            durationText.text = formatTime(duration)
        }

        function onCurrentMediaChanged(filename) {
            if (mediaManager) {
                var duration = mediaManager.get_duration()
                durationText.text = formatTime(duration)
                positionText.text = "0:00"
            }
        }

        function onPlayStateChanged(playing) {
            playButtonImage.source = playing ?
                "./assets/pause_button.svg" : "./assets/play_button.svg"
        }
    }

    // OBD Settings connection
    Connections {
        target: settingsManager
        function onHomeOBDParametersChanged() {
            if (obdManager && obdManager.refresh_values) {
                obdManager.refresh_values()
            }
        }
    }
}
