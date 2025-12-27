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

    // Dark background with subtle gradient
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(App.Style.backgroundColor, 1.2) }
            GradientStop { position: 1.0; color: App.Style.backgroundColor }
        }
    }

    // Main content area
    ColumnLayout {
        anchors.fill: parent
        spacing: 0


        // Main dashboard area
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 10
            spacing: 10

            // Now Playing section
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.5 - 10
                color: App.Style.backgroundColor
                border.color: App.Style.accent
                border.width: 2
                radius: 5

                // Header
                Rectangle {
                    id: nowPlayingHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                }

                // Album art and song info
                Item {
                    id: mediaContentArea
                    anchors.top: nowPlayingHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10

                    // Variables to track current media
                    property string currentFile: ""
                    property string currentArt: ""
                    property string currentTitle: ""
                    property string currentArtist: ""
                    property string currentAlbum: ""

                    // Album art container
                    Item {
                        id: albumArtContainer
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.6


                        // Album art image
                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true  // Enable caching to prevent flicker
                            source: mediaContentArea.currentArt || "./assets/missing_art.png"
                            
                            // When the image is loaded, fade it in
                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    opacity = 1;
                                }
                            }
                            
                            // Add a reload function
                            function reload() {
                                if (mediaManager && mediaContentArea.currentFile) {
                                    var artUrl = mediaManager.get_album_art(mediaContentArea.currentFile);
                                    if (artUrl && artUrl !== mediaContentArea.currentArt) {
                                        mediaContentArea.currentArt = ""; // Force a refresh
                                        mediaContentArea.currentArt = artUrl;
                                    }
                                }
                            }

                        }
                    }

                    // Song info section - Make text bigger
                    ColumnLayout {
                        anchors.top: albumArtContainer.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 10
                        spacing: 8
                        visible: mediaContentArea.currentFile !== ""

                        // Song title - Bigger text
                        Text {
                            id: songTitleText
                            text: mediaContentArea.currentTitle
                            color: App.Style.primaryTextColor
                            font.pixelSize: 24  // Increased from 18
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        // Artist & Album - Bigger text
                        Text {
                            id: artistAlbumText
                            text: mediaContentArea.currentArtist + " • " + mediaContentArea.currentAlbum
                            color: App.Style.secondaryTextColor
                            font.pixelSize: 20  // Increased from 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                        
                        // Duration/seek bar
                        Rectangle {
                            id: miniSeekBarContainer
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 5
                                
                                Text {
                                    id: miniPositionText
                                    text: "0:00"
                                    color: App.Style.secondaryTextColor
                                    font.pixelSize: 12
                                }
                                
                                Slider {
                                    id: miniProgressSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1
                                    value: 0
                                    enabled: mediaManager && mediaManager.get_duration() > 0
                                    
                                    property bool userSeeking: false
                                    
                                    background: Rectangle {
                                        x: miniProgressSlider.leftPadding
                                        y: miniProgressSlider.topPadding + miniProgressSlider.availableHeight / 2 - height / 2
                                        width: miniProgressSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: App.Style.secondaryTextColor
                                        
                                        Rectangle {
                                            width: miniProgressSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
                                            color: App.Style.accent
                                        }
                                    }
                                    
                                    handle: Rectangle {
                                        x: miniProgressSlider.leftPadding + miniProgressSlider.visualPosition * (miniProgressSlider.availableWidth - width)
                                        y: miniProgressSlider.topPadding + miniProgressSlider.availableHeight / 2 - height / 2
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: miniProgressSlider.pressed ? "#666666" : "#808080"
                                        visible: true
                                    }
                                    
                                    onPressedChanged: {
                                        if (pressed) {
                                            userSeeking = true;
                                        } else {
                                            userSeeking = false;
                                            if (mediaManager) {
                                                mediaManager.set_position(value);
                                            }
                                        }
                                    }
                                }
                                
                                Text {
                                    id: miniDurationText
                                    text: "0:00"
                                    color: App.Style.secondaryTextColor
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }


                    // Function to update media information
                    function updateMedia() {
                        if (mediaManager) {
                            var filename = mediaManager.get_current_file();
                            if (filename) {
                                // Update current file
                                mediaContentArea.currentFile = filename;
                                
                                // Update title
                                mediaContentArea.currentTitle = filename.replace('.mp3', '');
                                
                                // Update artist and album
                                mediaContentArea.currentArtist = mediaManager.get_band(filename);
                                mediaContentArea.currentAlbum = mediaManager.get_album(filename);

                                mediaContentArea.currentArt = mediaManager.get_album_art(filename);
                            }
                        }
                    }

                    // Load media on creation
                    Component.onCompleted: {
                        // Use timer to delay loading until MediaManager is fully initialized
                        initialLoadTimer.start();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (mediaContentArea.currentFile !== "") {
                            stackView.push("MediaRoom.qml", {
                                stackView: mainMenu.stackView
                            });
                        } else {
                            stackView.push("MediaPlayer.qml", {
                                stackView: stackView,
                                mainWindow: mainWindow
                            });
                        }
                    }
                }
            }

            // Vehicle Status section in MainMenu.qml
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "transparent"
                border.color: App.Style.accent
                border.width: 2
                radius: 5

                // Header
                Rectangle {
                    id: vehicleHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                }

                // Use the HomeOBDView component
                HomeOBDView {
                    anchors.top: vehicleHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
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
    }
    
    // Timer for initial delayed loading of media data
    Timer {
        id: initialLoadTimer
        interval: 0  // Half second delay to ensure MediaManager is ready
        repeat: false
        running: false
        onTriggered: {
            mediaContentArea.updateMedia();
        }
    }

    // Media Connections
    Connections {
        target: mediaManager
    
        
        function onMetadataChanged(title, artist, album) {
            mediaContentArea.updateMedia();
            mediaContentArea.currentTitle = title;
            mediaContentArea.currentArtist = artist;
            mediaContentArea.currentAlbum = album;
        }
    }

    // Media Connections - consolidate into one section
    Connections {
        target: mediaManager
        
        function onMetadataChanged(title, artist, album) {
            mediaContentArea.updateMedia();
            mediaContentArea.currentTitle = title;
            mediaContentArea.currentArtist = artist;
            mediaContentArea.currentAlbum = album;
        }
        
        function onPositionChanged(position) {
            if (!miniProgressSlider.userSeeking) {
                miniProgressSlider.value = position;
                
                // Format and update position text
                var minutes = Math.floor(position / 60000);
                var seconds = Math.floor((position % 60000) / 1000);
                miniPositionText.text = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
            }
        }
        
        function onDurationChanged(duration) {
            miniProgressSlider.to = duration > 0 ? duration : 1;
            
            // Format and update duration text
            var minutes = Math.floor(duration / 60000);
            var seconds = Math.floor((duration % 60000) / 1000);
            miniDurationText.text = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
        }
        
        function onCurrentMediaChanged(filename) {
            // Update time displays when media changes
            if (mediaManager) {
                // Update duration
                var duration = mediaManager.get_duration();
                var durationMinutes = Math.floor(duration / 60000);
                var durationSeconds = Math.floor((duration % 60000) / 1000);
                miniDurationText.text = durationMinutes + ":" + (durationSeconds < 10 ? "0" : "") + durationSeconds;
                
                // Reset position to 0
                miniPositionText.text = "0:00";
            }
        }
    }

    // Add this connection in MainMenu.qml
    Connections {
        target: settingsManager
        function onHomeOBDParametersChanged() {
            // Force refresh of OBD values when the parameters change
            if (obdManager && obdManager.refresh_values) {
                obdManager.refresh_values()
            }
        }
    }
    
    Component.onCompleted: {

        if (obdManager) {
            // Refresh OBD values if available
            if (obdManager.refresh_values) {
                obdManager.refresh_values();
            }
        }
    }
}