import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: mediaPlayer
    objectName: "mediaPlayer"
    required property StackView stackView
    required property ApplicationWindow mainWindow

    // Core properties
    property var mediaFiles: []
    property string lastPlayedSong: ""
    property real listViewPosition: 0
    property bool isPaused: false
    
    // Playlist properties
    property var playlistNames: []
    property string currentPlaylistName: ""

    // Sorting properties
    property bool sortByTitleAscending: true
    property bool sortByAlbumAscending: true
    property bool sortByArtistAscending: true
    property string currentSortColumn: "title" // Can be "title", "album", "artist", or "none"

    // Sort media files based on current sort column and direction
    function sortMediaFiles() {
        if (mediaManager) {
            // Call backend to perform the sorting
            let ascending = currentSortColumn === "title" ? sortByTitleAscending : 
                            currentSortColumn === "album" ? sortByAlbumAscending : 
                            sortByArtistAscending
            
            mediaFiles = mediaManager.sort_media_files(currentSortColumn, ascending)
            updateTimer.restart()
        }
    }

    // Initialize component
    Component.onCompleted: {
        if (mediaManager) {
            // Load playlist names
            playlistNames = mediaManager.get_playlist_names()
            currentPlaylistName = mediaManager.get_current_playlist_name()

            mediaManager.get_media_files()
            var currentFile = mediaManager.get_current_file()
            if (currentFile) {
                lastPlayedSong = currentFile
                isPaused = !mediaManager.is_playing()
            }
            updateTimer.restart()
        }
    }

    // Update timer for model changes
    Timer {
        id: updateTimer
        interval: 50
        repeat: false
        onTriggered: {
            listViewPosition = mediaListView.contentY
            mediaListView.model = []
            mediaListView.model = mediaFiles
            mediaListView.contentY = listViewPosition
        }
    }

    // Main content
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        // Title bar at the top
        Rectangle {
            id: titleBar
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: App.Spacing.mediaPlayerStatsBarHeight * 1.5
            color: App.Style.headerBackgroundColor
            z: 2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: App.Spacing.overallMargin * 4
                anchors.rightMargin: App.Spacing.overallMargin * 4
                spacing: App.Spacing.overallMargin * 4

                // Spacer to push dropdown to the right
                Item {
                    Layout.fillWidth: true
                }

                // Custom playlist dropdown (avoids native style issues)
                Item {
                    id: playlistDropdownContainer
                    Layout.preferredWidth: Math.min(300, parent.width * 0.4)
                    Layout.preferredHeight: App.Spacing.formElementHeight

                    Rectangle {
                        id: playlistDropdown
                        anchors.fill: parent
                        color: dropdownMouseArea.containsMouse ? Qt.lighter(App.Style.hoverColor, 1.1) : App.Style.hoverColor
                        radius: 6
                        border.width: 1
                        border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                              App.Style.primaryTextColor.g,
                                              App.Style.primaryTextColor.b, 0.2)

                        // Display text
                        Text {
                            id: dropdownText
                            anchors.left: parent.left
                            anchors.right: dropdownArrow.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: App.Spacing.overallMargin * 2
                            text: currentPlaylistName || "Select Playlist"
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.3
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        // Dropdown arrow
                        Text {
                            id: dropdownArrow
                            anchors.right: parent.right
                            anchors.rightMargin: App.Spacing.overallMargin * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: playlistPopup.visible ? "\u25B2" : "\u25BC"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.8
                        }

                        MouseArea {
                            id: dropdownMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (playlistPopup.visible) {
                                    playlistPopup.close()
                                } else {
                                    playlistPopup.open()
                                }
                            }
                        }
                    }

                    // Popup menu - outside the Rectangle for proper layering
                    Popup {
                        id: playlistPopup
                        parent: playlistDropdownContainer
                        y: playlistDropdown.height + 2
                        width: playlistDropdown.width
                        height: Math.min(playlistColumn.implicitHeight + 16, 300)
                        padding: 8
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        background: Rectangle {
                            color: App.Style.backgroundColor
                            border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                  App.Style.primaryTextColor.g,
                                                  App.Style.primaryTextColor.b, 0.3)
                            border.width: 1
                            radius: 6
                        }

                        contentItem: Flickable {
                            clip: true
                            contentHeight: playlistColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: playlistColumn
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: playlistNames

                                    Rectangle {
                                        width: playlistColumn.width
                                        height: App.Spacing.formElementHeight
                                        color: itemMouseArea.containsMouse ? App.Style.accent : "transparent"
                                        radius: 4

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: App.Spacing.overallMargin
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData
                                            color: itemMouseArea.containsMouse ? "white" : App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.bold: modelData === currentPlaylistName
                                        }

                                        MouseArea {
                                            id: itemMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (mediaManager && modelData) {
                                                    mediaManager.select_playlist(modelData)
                                                }
                                                playlistPopup.close()
                                            }
                                        }
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: true
                                policy: ScrollBar.AsNeeded
                            }
                        }
                    }
                }
            }
        }

        // Stats bar below title bar
        Rectangle {
            id: statsBar
            anchors {
                left: parent.left
                right: parent.right
                top: titleBar.bottom
            }
            height: App.Spacing.mediaPlayerStatsBarHeight * 1.2
            color: App.Style.headerBackgroundColor
            z: 1

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: App.Spacing.overallMargin * 4
                    rightMargin: App.Spacing.overallMargin * 4
                }
                spacing: App.Spacing.overallMargin * 4

                // Total Songs
                RowLayout {
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Songs:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                    }
                    Text {
                        text: mediaFiles.length
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                    }
                }

                // Number of Albums
                RowLayout {
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Albums:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                    }
                    Text {
                        id: albumCountText
                        text: mediaManager ? mediaManager.get_album_count() : "-"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                    }
                }

                // Number of Artists
                RowLayout {
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Artists:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                    }
                    Text {
                        id: artistCountText
                        text: mediaManager ? mediaManager.get_artist_count() : "-"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                    }
                }

                // Total Duration
                RowLayout {
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Total:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                    }
                    Text {
                        id: totalDurationText
                        text: mediaManager ? mediaManager.get_total_duration() : "--:--:--"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                    }
                }
                
                // Spacer
                Item {
                    Layout.fillWidth: true
                }
                
            }
        }

        // Main content area
        Rectangle {
            id: mainContent
            anchors {
                fill: parent
                margins: App.Spacing.overallMargin
                topMargin: titleBar.height + statsBar.height + App.Spacing.overallMargin
            }
            color: App.Style.backgroundColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Table header
                Rectangle {
                    Layout.fillWidth: true
                    height: App.Spacing.mediaPlayerHeaderHeight * 1.3
                    color: App.Style.headerBackgroundColor
                    
                    Rectangle {
                        width: parent.width
                        height: 2
                        color: App.Style.accent
                        anchors.top: parent.top
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: App.Spacing.overallMargin * 2
                        anchors.rightMargin: App.Spacing.overallMargin * 2
                        spacing: 0

                        // Title header with sort functionality
                        Item {
                            Layout.preferredWidth: parent.width * 0.4
                            Layout.fillHeight: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (currentSortColumn === "title") {
                                        sortByTitleAscending = !sortByTitleAscending
                                    } else {
                                        currentSortColumn = "title"
                                        sortByTitleAscending = true
                                    }
                                    sortMediaFiles()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TITLE " + (currentSortColumn === "title" ? 
                                    (sortByTitleAscending ? "↑" : "↓") : "")
                                color: App.Style.headerTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.2
                                font.bold: true
                            }
                        }

                        // Artist header with sort functionality
                        Item {
                            Layout.preferredWidth: parent.width * 0.3
                            Layout.fillHeight: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (currentSortColumn === "artist") {
                                        sortByArtistAscending = !sortByArtistAscending
                                    } else {
                                        currentSortColumn = "artist"
                                        sortByArtistAscending = true
                                    }
                                    sortMediaFiles()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ARTIST " + (currentSortColumn === "artist" ? 
                                    (sortByArtistAscending ? "↑" : "↓") : "")
                                color: App.Style.headerTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.2
                                font.bold: true
                            }
                        }

                        // Album header with sort functionality
                        Item {
                            Layout.preferredWidth: parent.width * 0.3
                            Layout.fillHeight: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (currentSortColumn === "album") {
                                        sortByAlbumAscending = !sortByAlbumAscending
                                    } else {
                                        currentSortColumn = "album"
                                        sortByAlbumAscending = true
                                    }
                                    sortMediaFiles()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ALBUM " + (currentSortColumn === "album" ? 
                                    (sortByAlbumAscending ? "↑" : "↓") : "")
                                color: App.Style.headerTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.2
                                font.bold: true
                            }
                        }
                    }
                }

                // Media list
                ListView {
                    id: mediaListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: mediaFiles
                    cacheBuffer: height * 0.5
                    displayMarginBeginning: 40
                    displayMarginEnd: 40
                    reuseItems: true
                    
                    // Add spacing between items
                    spacing: 6

                    // List item delegate
                    delegate: Item {
                        id: delegate
                        width: ListView.view.width
                        height: App.Spacing.mediaPlayerRowHeight * 1.4
                        visible: y >= mediaListView.contentY - height && 
                                y <= mediaListView.contentY + mediaListView.height
                                
                        // Active song properties
                        property bool isCurrentSong: lastPlayedSong === modelData
                        property bool isPlaying: isCurrentSong && mediaManager && mediaManager.is_playing()
                        
                        // Properties for album art
                        property var albumArtSource: visible ? 
                            (mediaManager ? 
                                mediaManager.get_album_art(modelData) || 
                                "./assets/missing_art.jpg" : 
                                "./assets/missing_art.jpg") : 
                            ""
                        
                        // Generate consistent value based on song name
                        property real randomValue: {
                            var hash = 0;
                            for (var i = 0; i < modelData.length; i++) {
                                hash = ((hash << 5) - hash) + modelData.charCodeAt(i);
                                hash = hash & hash;
                            }
                            return Math.abs(hash) / 2147483647;
                        }
                                                
                        // Modern glass-style card with theme awareness
                        Rectangle {
                            id: glassCard
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                                                        
                            // Glass background - adapts to app theme colors
                            color: {
                                // Extract theme primary colors
                                var baseColor = App.Style.backgroundColor;
                                
                                // Adjust opacity based on whether this is the current song
                                var alpha = delegate.isCurrentSong ? 0.4 : 0.25;
                                
                                // Create a glass effect by using semi-transparent theme color
                                return Qt.rgba(
                                    baseColor.r * 0.9, 
                                    baseColor.g * 0.9, 
                                    baseColor.b * 0.9, 
                                    alpha
                                );
                            }
                            
                            // Inner border for glass effect
                            border.width: 1
                            border.color: {
                                var baseColor = App.Style.accent;
                                return Qt.rgba(
                                    baseColor.r, 
                                    baseColor.g, 
                                    baseColor.b, 
                                    delegate.isCurrentSong ? 0.7 : 0.1
                                );
                            }
                            
                            // Create art-based accent layer as a strip on the left side
                            Rectangle {
                                id: accentStrip
                                width: delegate.isCurrentSong ? parent.width : 4
                                height: parent.height
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                radius: parent.radius
                                
                                // Clip to only show left part
                                clip: true
                                
                                // Gradient based on album art
                                gradient: Gradient {
                                    orientation: delegate.isCurrentSong ? 
                                        Gradient.Horizontal : Gradient.Vertical
                                        
                                    GradientStop {
                                        position: 0.0
                                        color: {
                                            // Create an accent color from app accent color
                                            var accentBase = App.Style.accent;
                                            
                                            // Adjust transparency based on if it's the current song
                                            var alpha = delegate.isCurrentSong ? 0.25 : 0.35;
                                            
                                            return Qt.rgba(
                                                accentBase.r, 
                                                accentBase.g, 
                                                accentBase.b, 
                                                alpha
                                            );
                                        }
                                    }
                                    
                                    GradientStop {
                                        position: 1.0
                                        color: "transparent"
                                    }
                                }
                                
                                // Album art as texture overlay with varying opacity
                                Image {
                                    anchors.fill: parent
                                    source: delegate.albumArtSource
                                    fillMode: Image.PreserveAspectCrop
                                    opacity: 0.3
                                    visible: delegate.isCurrentSong
                                    
                                    // Create a small random offset for visual interest
                                    transform: Translate {
                                        x: -10 + (delegate.randomValue * 20)
                                        y: -10 + ((1 - delegate.randomValue) * 20)
                                    }
                                }
                            }
                            
                            // Active song indicator - glowing accent bar
                            Rectangle {
                                visible: delegate.isCurrentSong
                                width: 6
                                height: parent.height
                                radius: width / 2
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: App.Style.accent
                                opacity: pulseAnimation.opacity
                                
                                // Pulse animation
                                SequentialAnimation {
                                    id: pulseAnimation
                                    running: delegate.isPlaying
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true
                                    property real opacity: 1.0
                                    
                                    NumberAnimation {
                                        target: pulseAnimation
                                        property: "opacity"
                                        from: 0.7
                                        to: 1.0
                                        duration: 800
                                        easing.type: Easing.InOutQuad
                                    }
                                    NumberAnimation {
                                        target: pulseAnimation
                                        property: "opacity"
                                        from: 1.0
                                        to: 0.7
                                        duration: 800
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: delegate.isCurrentSong ? 
                                    App.Spacing.overallMargin * 3 : 
                                    App.Spacing.overallMargin * 2
                                anchors.rightMargin: App.Spacing.overallMargin * 2
                                spacing: 0

                                // Title section (with album art)
                                RowLayout {
                                    Layout.preferredWidth: parent.width * 0.4
                                    Layout.fillHeight: true
                                    spacing: App.Spacing.overallMargin * 2

                                    // Album art with frame - simplified
                                    Rectangle {
                                        id: albumArtContainer
                                        Layout.preferredWidth: App.Spacing.mediaPlayerAlbumArtSize * 1.3
                                        Layout.preferredHeight: App.Spacing.mediaPlayerAlbumArtSize * 1.3
                                        radius: 8
                                        color: Qt.rgba(1, 1, 1, 0.08) // Subtle glass effect
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.2)
                                        clip: true // Simple clipping for rounded corners
                                        
                                        // Album art image
                                        Image {
                                            id: albumArt
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            source: delegate.albumArtSource
                                            sourceSize.width: width * 1.5
                                            sourceSize.height: height * 1.5
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: true
                                        }
                                        
                                        // Simple highlight effect for glass appearance
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 3
                                            height: parent.height * 0.3
                                            radius: 6
                                            color: "white"
                                            opacity: 0.1
                                        }
                                    }

                                    // Title and duration container
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        
                                        ColumnLayout {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: App.Spacing.overallMargin

                                            // Song title
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.replace('.mp3', '')
                                                color: App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.2
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            // Duration
                                            Text {
                                                text: mediaManager ? 
                                                    mediaManager.get_formatted_duration(modelData) : 
                                                    "0:00"
                                                color: App.Style.secondaryTextColor
                                                font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.1
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // Artist column
                                Item {
                                    Layout.preferredWidth: parent.width * 0.3
                                    Layout.fillHeight: true
                                    clip: true
                                    
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: mediaManager ? 
                                            mediaManager.get_band(modelData) : 
                                            "Unknown Artist"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.2
                                        elide: Text.ElideRight
                                    }
                                }

                                // Album column
                                Item {
                                    Layout.preferredWidth: parent.width * 0.3
                                    Layout.fillHeight: true
                                    clip: true
                                    
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: mediaManager ? 
                                            mediaManager.get_album(modelData) : 
                                            "Unknown Album"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            
                            // Click behavior for list items
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (mediaManager) {
                                        // If Spotify is playing, pause it and switch to local
                                        if (spotifyManager && spotifyManager.is_connected()) {
                                            if (spotifyManager.is_playing()) {
                                                spotifyManager.pause()
                                            }
                                        }

                                        // Switch to local source
                                        if (settingsManager && settingsManager.mediaSource !== "local") {
                                            settingsManager.set_media_source("local")
                                        }

                                        // Play the selected file
                                        mediaManager.play_file(modelData)
                                        lastPlayedSong = modelData
                                        stackView.push("MediaRoom.qml", {
                                            stackView: mediaPlayer.stackView
                                        })
                                    }
                                }
                            }
                            
                            // Add subtle scaling effect on active song
                            scale: delegate.isCurrentSong ? 1.02 : 1.0
                            Behavior on scale {
                                NumberAnimation { 
                                    duration: 200
                                    easing.type: Easing.OutCubic 
                                }
                            }
                            
                            // Shadow for depth (using Rectangle instead of effects)
                            Rectangle {
                                z: -1
                                anchors.fill: parent
                                anchors.margins: -2
                                radius: parent.radius + 2
                                color: "black"
                                opacity: delegate.isCurrentSong ? 0.15 : 0.08
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: verticalScrollBar
                        active: true
                        policy: ScrollBar.AsNeeded
                        
                        Component.onCompleted: {
                            background.implicitWidth = 12
                        }
                    
                        palette.mid: App.Style.accent
                    }
                }
            }

            // Empty state message
            Text {
                anchors.centerIn: parent
                text: "No songs found in media folder"
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.3
                visible: mediaListView.count === 0
            }
        }
    }

    // Connect to mediaManager signals
    Connections {
        target: mediaManager

        // Media list updated
        function onMediaListChanged(files) {
            console.log("Media list updated: " + files.length + " files");
            mediaFiles = files;

            if (currentSortColumn !== "none") {
                sortMediaFiles();
            } else {
                updateTimer.restart();
            }
        }

        // Current media changed
        function onCurrentMediaChanged(filename) {
            lastPlayedSong = filename
            updateTimer.restart()
        }

        // Play state changed
        function onPlayStateChanged(isPlaying) {
            isPaused = !isPlaying
            if (mediaManager) {
                var currentFile = mediaManager.get_current_file()
                if (currentFile) {
                    lastPlayedSong = currentFile
                }
            }
            updateTimer.restart()
        }

        // Statistics updates
        function onTotalDurationChanged(duration) {
            totalDurationText.text = duration
        }

        function onAlbumCountChanged(count) {
            albumCountText.text = count
        }

        function onArtistCountChanged(count) {
            artistCountText.text = count
        }

        // Playlist updates
        function onPlaylistsChanged() {
            console.log("Playlists changed")
            playlistNames = mediaManager.get_playlist_names()
        }

        function onCurrentPlaylistChanged(name) {
            console.log("Current playlist changed to: " + name)
            currentPlaylistName = name
        }
    }
}