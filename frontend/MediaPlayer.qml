import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: mediaPlayer
    objectName: "mediaPlayer"
    required property StackView stackView
    required property ApplicationWindow mainWindow

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Core properties
    property var mediaFiles: []
    property string lastPlayedSong: ""
    property real listViewPosition: 0
    property bool isPaused: false
    
    // Playlist properties
    property var playlistNames: []
    property string currentPlaylistName: ""

    // Spotify playlist properties
    property bool spotifyConnected: spotifyManager && spotifyManager.is_connected()
    property var spotifyPlaylistNames: []
    property var spotifyTracks: []
    property var spotifyTrackNames: []
    property string currentSpotifyPlaylistName: ""
    property bool isSpotifyPlaylist: false  // true if currently viewing a Spotify playlist
    property int playlistRefreshCounter: 0  // Incremented to force delegate rebindings

    // Cached playback state to avoid constant re-evaluation in delegates
    property string currentSpotifyTrackName: spotifyManager ? spotifyManager.get_current_track_name() : ""
    property bool spotifyIsPlaying: false

    // Initial scroll position (calculated before render)
    property real initialScrollPosition: -1

    // Force model refresh when switching between local and Spotify playlists
    onIsSpotifyPlaylistChanged: {
        console.log("isSpotifyPlaylist changed to: " + isSpotifyPlaylist)
        playlistRefreshCounter++  // Force delegates to re-evaluate bindings
        updateTimer.restart()
    }

    // Combined playlists for unified dropdown
    property var combinedPlaylists: {
        var list = []
        // Add local playlists first
        for (var i = 0; i < playlistNames.length; i++) {
            list.push({ name: playlistNames[i], type: "local" })
        }
        // Add Spotify playlists if connected
        if (spotifyConnected && spotifyPlaylistNames.length > 0) {
            for (var j = 0; j < spotifyPlaylistNames.length; j++) {
                list.push({ name: spotifyPlaylistNames[j], type: "spotify" })
            }
        }
        return list
    }

    // Get the display name for the dropdown
    property string displayPlaylistName: isSpotifyPlaylist ? currentSpotifyPlaylistName : currentPlaylistName

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

    // Calculate initial scroll position for a given track
    function calculateScrollPosition(trackName, model) {
        if (!trackName || model.length === 0) return -1

        for (var i = 0; i < model.length; i++) {
            if (model[i] === trackName) {
                var itemHeight = App.Spacing.mediaPlayerRowHeight * 1.4 + 6
                // Estimate list height (will be corrected when ListView is ready)
                var listHeight = 600
                var targetY = (i * itemHeight) - (listHeight / 2) + (itemHeight / 2)
                return Math.max(0, targetY)
            }
        }
        return -1
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
                // Pre-calculate scroll position for local files
                initialScrollPosition = calculateScrollPosition(currentFile, mediaFiles)
            }
            updateTimer.restart()
        }

        // Load Spotify playlists if connected
        if (spotifyConnected && spotifyManager) {
            spotifyPlaylistNames = spotifyManager.get_spotify_playlist_names()

            // Check if we should restore Spotify playlist state
            // If Spotify is the current media source and has a playlist loaded, show it
            if (settingsManager && settingsManager.mediaSource === "spotify" &&
                spotifyManager.has_spotify_playlist_loaded()) {

                console.log("Restoring Spotify playlist state")
                isSpotifyPlaylist = true
                currentSpotifyPlaylistName = spotifyManager.get_current_spotify_playlist_name()
                currentSpotifyTrackName = spotifyManager.get_current_track_name()

                // Load the tracks for display
                var playlistId = spotifyManager.get_current_spotify_playlist_id()
                if (playlistId) {
                    spotifyManager.select_spotify_playlist(playlistId)
                }
            }
        }

        // For local files, apply scroll position after a brief delay to ensure ListView is ready
        if (!isSpotifyPlaylist && initialScrollPosition >= 0) {
            scrollToCurrentTimer.restart()
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
            // Use correct model based on current mode
            mediaListView.model = isSpotifyPlaylist ? spotifyTrackNames : mediaFiles
            mediaListView.contentY = listViewPosition
        }
    }

    // Function to scroll to the currently playing track (instant, no animation)
    function scrollToCurrentTrack() {
        var currentTrackName = ""
        var model = []

        if (isSpotifyPlaylist) {
            currentTrackName = currentSpotifyTrackName
            model = spotifyTrackNames
        } else {
            currentTrackName = lastPlayedSong
            model = mediaFiles
        }

        if (!currentTrackName || model.length === 0) return

        // Find the index of the current track
        for (var i = 0; i < model.length; i++) {
            if (model[i] === currentTrackName) {
                // Calculate the content position to center this item
                var itemHeight = App.Spacing.mediaPlayerRowHeight * 1.4 + 6  // height + spacing
                var targetY = (i * itemHeight) - (mediaListView.height / 2) + (itemHeight / 2)
                // Clamp to valid range
                targetY = Math.max(0, Math.min(targetY, mediaListView.contentHeight - mediaListView.height))
                // Set position directly (instant, no animation)
                mediaListView.contentY = targetY
                console.log("Scrolled to track at index: " + i)
                break
            }
        }
    }

    // Timer to scroll to current track after model is loaded
    Timer {
        id: scrollToCurrentTimer
        interval: 50  // Minimal delay, just enough for model to populate
        repeat: false
        onTriggered: scrollToCurrentTrack()
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
                            text: displayPlaylistName || "Select Playlist"
                            color: isSpotifyPlaylist ? "#1DB954" : App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.3
                            font.bold: true
                            font.family: mediaPlayer.globalFont
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
                            font.family: mediaPlayer.globalFont
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
                                    model: combinedPlaylists

                                    Rectangle {
                                        width: playlistColumn.width
                                        height: App.Spacing.formElementHeight
                                        color: itemMouseArea.containsMouse ?
                                            (modelData.type === "spotify" ? "#1DB954" : App.Style.accent) :
                                            "transparent"
                                        radius: 4

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: App.Spacing.overallMargin
                                            anchors.rightMargin: App.Spacing.overallMargin
                                            spacing: App.Spacing.overallMargin

                                            // Spotify indicator circle
                                            Rectangle {
                                                visible: modelData.type === "spotify"
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: itemMouseArea.containsMouse ? "white" : "#1DB954"
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: {
                                                    if (itemMouseArea.containsMouse) {
                                                        return "white"
                                                    }
                                                    return modelData.type === "spotify" ? "#1DB954" : App.Style.primaryTextColor
                                                }
                                                font.pixelSize: App.Spacing.overallText
                                                font.bold: (modelData.type === "local" && modelData.name === currentPlaylistName) ||
                                                           (modelData.type === "spotify" && modelData.name === currentSpotifyPlaylistName)
                                                font.family: mediaPlayer.globalFont
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: itemMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                console.log("Playlist selected: " + modelData.name + ", type: " + modelData.type)
                                                if (modelData.type === "spotify") {
                                                    // Set Spotify mode FIRST before loading tracks
                                                    mediaPlayer.isSpotifyPlaylist = true
                                                    mediaPlayer.currentSpotifyPlaylistName = modelData.name
                                                    console.log("isSpotifyPlaylist set to: " + mediaPlayer.isSpotifyPlaylist)

                                                    // Switch media source
                                                    if (settingsManager) {
                                                        settingsManager.set_media_source("spotify")
                                                    }
                                                    // Get playlist ID and select it (this will load tracks and emit signal)
                                                    if (spotifyManager) {
                                                        var playlistId = spotifyManager.get_spotify_playlist_id(modelData.name)
                                                        console.log("Spotify playlist ID: " + playlistId)
                                                        if (playlistId) {
                                                            spotifyManager.select_spotify_playlist(playlistId)
                                                        }
                                                    }
                                                } else {
                                                    // Switch to local mode FIRST
                                                    mediaPlayer.isSpotifyPlaylist = false
                                                    console.log("isSpotifyPlaylist set to: " + mediaPlayer.isSpotifyPlaylist)

                                                    // Switch media source
                                                    if (settingsManager) {
                                                        settingsManager.set_media_source("local")
                                                    }
                                                    if (mediaManager && modelData.name) {
                                                        mediaManager.select_playlist(modelData.name)
                                                    }
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
                        font.family: mediaPlayer.globalFont
                    }
                    Text {
                        text: isSpotifyPlaylist ? spotifyTrackNames.length : mediaFiles.length
                        color: isSpotifyPlaylist ? "#1DB954" : App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                        font.family: mediaPlayer.globalFont
                    }
                }

                // Number of Albums
                RowLayout {
                    visible: !isSpotifyPlaylist
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Albums:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.family: mediaPlayer.globalFont
                    }
                    Text {
                        id: albumCountText
                        text: mediaManager ? mediaManager.get_album_count() : "-"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                        font.family: mediaPlayer.globalFont
                    }
                }

                // Number of Artists
                RowLayout {
                    visible: !isSpotifyPlaylist
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Artists:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.family: mediaPlayer.globalFont
                    }
                    Text {
                        id: artistCountText
                        text: mediaManager ? mediaManager.get_artist_count() : "-"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                        font.family: mediaPlayer.globalFont
                    }
                }

                // Total Duration
                RowLayout {
                    visible: !isSpotifyPlaylist
                    spacing: App.Spacing.overallMargin
                    Text {
                        text: "Total:"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.family: mediaPlayer.globalFont
                    }
                    Text {
                        id: totalDurationText
                        text: mediaManager ? mediaManager.get_total_duration() : "--:--:--"
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.bold: true
                        font.family: mediaPlayer.globalFont
                    }
                }

                // Spotify indicator when viewing Spotify playlist
                RowLayout {
                    visible: isSpotifyPlaylist
                    spacing: App.Spacing.overallMargin
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#1DB954"
                    }
                    Text {
                        text: "Spotify Playlist"
                        color: "#1DB954"
                        font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.2
                        font.family: mediaPlayer.globalFont
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
                                font.family: mediaPlayer.globalFont
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
                                font.family: mediaPlayer.globalFont
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
                                font.family: mediaPlayer.globalFont
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
                    model: isSpotifyPlaylist ? spotifyTrackNames : mediaFiles
                    cacheBuffer: height * 0.5
                    displayMarginBeginning: 40
                    displayMarginEnd: 40
                    reuseItems: true

                    // Add spacing between items
                    spacing: 6

                    // Set initial position when ListView geometry is ready
                    onHeightChanged: {
                        if (height > 0 && initialScrollPosition >= 0) {
                            // Recalculate with actual height and apply
                            scrollToCurrentTrack()
                            initialScrollPosition = -1  // Only do this once
                        }
                    }

                    // List item delegate
                    delegate: Item {
                        id: delegate
                        width: ListView.view.width
                        height: App.Spacing.mediaPlayerRowHeight * 1.4
                        visible: y >= mediaListView.contentY - height &&
                                y <= mediaListView.contentY + mediaListView.height

                        // Active song properties - check against Spotify current track when in Spotify mode
                        // Bind directly to cached properties for stable updates without model refresh
                        property bool isCurrentSong: mediaPlayer.isSpotifyPlaylist
                            ? (mediaPlayer.currentSpotifyTrackName === modelData)
                            : (lastPlayedSong === modelData)

                        property bool isPlaying: mediaPlayer.isSpotifyPlaylist
                            ? (isCurrentSong && mediaPlayer.spotifyIsPlaying)
                            : (isCurrentSong && !isPaused)

                        // Properties for album art - conditionally fetch from Spotify or local
                        property var albumArtSource: {
                            // Reference playlistRefreshCounter to force rebinding
                            var _ = mediaPlayer.playlistRefreshCounter
                            if (!visible) return ""
                            if (mediaPlayer.isSpotifyPlaylist && spotifyManager) {
                                return spotifyManager.get_spotify_track_image(modelData) || "./assets/missing_art.png"
                            }
                            return mediaManager ? (mediaManager.get_album_art(modelData) || "./assets/missing_art.png") : "./assets/missing_art.png"
                        }
                        
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
                                                // Reference playlistRefreshCounter to force rebinding when mode changes
                                                text: {
                                                    var _ = mediaPlayer.playlistRefreshCounter
                                                    return mediaPlayer.isSpotifyPlaylist ? modelData : modelData.replace('.mp3', '')
                                                }
                                                color: App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 1.2
                                                font.family: mediaPlayer.globalFont
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            // Duration
                                            Text {
                                                text: {
                                                    // Reference playlistRefreshCounter to force rebinding
                                                    var _ = mediaPlayer.playlistRefreshCounter
                                                    if (mediaPlayer.isSpotifyPlaylist && spotifyManager) {
                                                        return spotifyManager.get_spotify_track_duration_formatted(modelData)
                                                    }
                                                    return mediaManager ? mediaManager.get_formatted_duration(modelData) : "0:00"
                                                }
                                                color: App.Style.secondaryTextColor
                                                font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.1
                                                font.family: mediaPlayer.globalFont
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
                                        text: {
                                            // Reference playlistRefreshCounter to force rebinding
                                            var _ = mediaPlayer.playlistRefreshCounter
                                            if (mediaPlayer.isSpotifyPlaylist && spotifyManager) {
                                                return spotifyManager.get_spotify_track_artist(modelData)
                                            }
                                            return mediaManager ? mediaManager.get_band(modelData) : "Unknown Artist"
                                        }
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.2
                                        font.family: mediaPlayer.globalFont
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
                                        text: {
                                            // Reference playlistRefreshCounter to force rebinding
                                            var _ = mediaPlayer.playlistRefreshCounter
                                            if (mediaPlayer.isSpotifyPlaylist && spotifyManager) {
                                                return spotifyManager.get_spotify_track_album(modelData)
                                            }
                                            return mediaManager ? mediaManager.get_album(modelData) : "Unknown Album"
                                        }
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.mediaPlayerSecondaryTextSize * 1.2
                                        font.family: mediaPlayer.globalFont
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            
                            // Click behavior for list items
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    console.log("Song clicked - isSpotifyPlaylist: " + mediaPlayer.isSpotifyPlaylist + ", modelData: " + modelData)
                                    if (mediaPlayer.isSpotifyPlaylist) {
                                        // Handle Spotify track playback
                                        if (spotifyManager) {
                                            // Pause local playback first
                                            if (mediaManager && mediaManager.is_playing()) {
                                                mediaManager.pause()
                                            }

                                            var uri = spotifyManager.get_spotify_track_uri(modelData)
                                            console.log("Playing Spotify URI: " + uri)
                                            if (uri) {
                                                spotifyManager.play_uri(uri)
                                            }
                                            stackView.push("MediaRoom.qml", {
                                                stackView: mediaPlayer.stackView
                                            })
                                        }
                                    } else {
                                        // Handle local file playback
                                        if (mediaManager) {
                                            // If Spotify is playing, pause it
                                            if (spotifyManager && spotifyManager.is_connected() && spotifyManager.is_playing()) {
                                                spotifyManager.pause()
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
                            }
                            
                            // Add subtle scaling effect on active song (no animation to prevent bounce on page load)
                            scale: delegate.isCurrentSong ? 1.02 : 1.0
                            
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
                font.family: mediaPlayer.globalFont
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

    // Connect to spotifyManager signals
    Connections {
        target: spotifyManager

        function onPlaylistsChanged(playlists) {
            console.log("Spotify playlists changed: " + playlists.length + " playlists")
            spotifyPlaylistNames = spotifyManager.get_spotify_playlist_names()
        }

        function onSpotifyTracksChanged(tracks) {
            console.log("Spotify tracks changed: " + tracks.length + " tracks")
            console.log("isSpotifyPlaylist at signal time: " + mediaPlayer.isSpotifyPlaylist)
            spotifyTracks = tracks
            // Extract track names for the model
            var names = []
            for (var i = 0; i < tracks.length; i++) {
                names.push(tracks[i].name)
                if (i < 3) {
                    console.log("Track " + i + ": " + tracks[i].name + " by " + tracks[i].artist)
                }
            }
            spotifyTrackNames = names
            console.log("spotifyTrackNames length: " + spotifyTrackNames.length)
            updateTimer.restart()
            // Scroll to current track after model updates
            scrollToCurrentTimer.restart()
        }

        function onCurrentSpotifyPlaylistChanged(name) {
            console.log("Current Spotify playlist changed to: " + name)
            currentSpotifyPlaylistName = name
        }

        function onConnectionStateChanged(connected) {
            console.log("Spotify connection state changed: " + connected)
            if (connected) {
                spotifyPlaylistNames = spotifyManager.get_spotify_playlist_names()
            } else {
                spotifyPlaylistNames = []
                // If viewing Spotify playlist, reset to local
                if (isSpotifyPlaylist) {
                    isSpotifyPlaylist = false
                    spotifyTrackNames = []
                }
            }
        }

        function onCurrentTrackChanged(title, artist, album, artUrl) {
            // Update cached track name - delegates will automatically update via binding
            currentSpotifyTrackName = title
        }

        function onPlayStateChanged(playing) {
            // Update cached play state - delegates will automatically update via binding
            spotifyIsPlaying = playing
        }
    }
}