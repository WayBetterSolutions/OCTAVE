import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: downloadPage
    objectName: "downloadPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property StackView stackView
    property var mainWindow

    property string globalFont: App.Style.fontFamily
    property color bgColor: App.Style.backgroundColor
    property color accentColor: App.Style.accent
    property color textColor: App.Style.primaryTextColor
    property color dimTextColor: App.Style.secondaryTextColor
    property color cardColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
    property color cardBorderColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.2)
    property color successColor: "#4CAF50"

    // On-screen keyboard state
    property bool showKeyboard: false

    // Search state
    property var searchResults: []
    property bool isSearching: false
    property string statusText: "Search for songs to download"
    property bool hasMoreResults: false

    // Download state — keyed by song_id for uniqueness
    property var activeDownloads: ({})    // song_id -> progress (0.0-1.0)
    property var downloadNames: ({})      // song_id -> display name

    // Playlist selector state
    property var downloadPlaylists: []
    property string selectedPlaylist: ""

    Component.onCompleted: {
        // Load available playlists for the download target selector
        if (mediaManager) {
            downloadPlaylists = mediaManager.get_movable_playlist_names()
        }
        if (downloadManager) {
            selectedPlaylist = downloadManager.get_download_playlist()
        }
    }

    Connections {
        target: mediaManager
        function onPlaylistsChanged() {
            var newList = mediaManager.get_movable_playlist_names()
            downloadPlaylists = newList
            // Clear stale selection if the playlist was deleted or renamed
            if (selectedPlaylist && newList.indexOf(selectedPlaylist) === -1) {
                selectedPlaylist = downloadManager ? downloadManager.get_download_playlist() : ""
            }
        }
    }

    // ─── Connections to DownloadManager ──────────────────────────────

    Connections {
        target: downloadManager

        function onSearchResults(jsonStr) {
            try {
                var results = JSON.parse(jsonStr)
                downloadPage.searchResults = results
                // If we got a full page (20), there are probably more
                downloadPage.hasMoreResults = (results.length % 20 === 0) && results.length > 0
            } catch (e) {
                downloadPage.searchResults = []
                downloadPage.hasMoreResults = false
            }
        }

        function onSearchInProgress(inProgress) {
            downloadPage.isSearching = inProgress
        }

        function onSearchError(msg) {
            downloadPage.statusText = "Search error: " + msg
        }

        function onDownloadStarted(songId, songName) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            downloads[songId] = 0.0
            downloadPage.activeDownloads = downloads
            var names = Object.assign({}, downloadPage.downloadNames)
            names[songId] = songName
            downloadPage.downloadNames = names
        }

        function onDownloadProgress(songId, progress) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            downloads[songId] = progress
            downloadPage.activeDownloads = downloads
        }

        function onDownloadComplete(songId, filePath) {
            var displayName = downloadPage.downloadNames[songId] || ""
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            delete downloads[songId]
            downloadPage.activeDownloads = downloads
            var names = Object.assign({}, downloadPage.downloadNames)
            delete names[songId]
            downloadPage.downloadNames = names
            downloadPage.statusText = displayName ? ("Downloaded: " + displayName) : "Download complete"
        }

        function onDownloadError(songId, songName, errorMsg) {
            var displayName = downloadPage.downloadNames[songId] || songName || "download"
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            delete downloads[songId]
            downloadPage.activeDownloads = downloads
            var names = Object.assign({}, downloadPage.downloadNames)
            delete names[songId]
            downloadPage.downloadNames = names
            downloadPage.statusText = "Error: " + displayName + " - " + errorMsg
        }

        function onStatusMessage(msg) {
            downloadPage.statusText = msg
        }
    }

    // ─── Main Layout ─────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: bgColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: App.Spacing.dp(16)
            spacing: App.Spacing.dp(12)

            // ─── Header ──────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: App.Spacing.bottomBarNavButtonHeight + App.Spacing.dp(8)
                spacing: App.Spacing.dp(12)

                Text {
                    text: "Download Music"
                    font.family: downloadPage.globalFont
                    font.pixelSize: App.Spacing.dp(24)
                    font.weight: Font.Bold
                    color: textColor
                }

                Item { Layout.fillWidth: true }

                // Status text
                Text {
                    text: downloadPage.statusText
                    font.family: downloadPage.globalFont
                    font.pixelSize: App.Spacing.dp(11)
                    color: dimTextColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: App.Spacing.dp(300)
                }

                // Playlist target selector (styled to match MediaPlayer dropdown)
                Item {
                    id: dlPlaylistDropdownContainer
                    Layout.preferredWidth: Math.min(App.Spacing.dp(220), downloadPage.width * 0.25)
                    Layout.preferredHeight: App.Spacing.bottomBarNavButtonHeight

                    property bool dlDropdownCooldown: false
                    Timer {
                        id: dlDropdownCooldownTimer
                        interval: 100
                        onTriggered: dlPlaylistDropdownContainer.dlDropdownCooldown = false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: dlDropdownMouse.containsMouse
                            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
                            : "transparent"
                        radius: App.Spacing.dpMin(8, 2)
                        border.width: 1
                        border.color: accentColor

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        // Label
                        Text {
                            id: dlDropdownLabel
                            anchors.top: parent.top
                            anchors.topMargin: App.Spacing.dp(4)
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SAVE TO"
                            color: accentColor
                            font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 0.85
                            font.bold: true
                            font.family: downloadPage.globalFont
                            font.letterSpacing: App.Spacing.dp(1)
                        }

                        // Selected playlist name
                        Text {
                            anchors.left: parent.left
                            anchors.right: dlDropdownArrow.left
                            anchors.top: dlDropdownLabel.bottom
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: App.Spacing.overallMargin * 2
                            verticalAlignment: Text.AlignVCenter
                            text: downloadPage.selectedPlaylist || "Downloads"
                            color: textColor
                            font.pixelSize: App.Spacing.mediaPlayerStatsTextSize * 1.4
                            font.bold: true
                            font.family: downloadPage.globalFont
                            elide: Text.ElideRight
                        }

                        // Arrow
                        Text {
                            id: dlDropdownArrow
                            anchors.right: parent.right
                            anchors.rightMargin: App.Spacing.overallMargin * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: dlPlaylistPopup.visible ? "\u25B2" : "\u25BC"
                            color: accentColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: downloadPage.globalFont
                        }

                        MouseArea {
                            id: dlDropdownMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dlPlaylistDropdownContainer.dlDropdownCooldown) return
                                if (dlPlaylistPopup.visible) {
                                    dlPlaylistPopup.close()
                                } else {
                                    dlPlaylistPopup.open()
                                }
                            }
                        }
                    }

                    Popup {
                        id: dlPlaylistPopup
                        parent: dlPlaylistDropdownContainer
                        y: dlPlaylistDropdownContainer.height + App.Spacing.dp(4)
                        width: dlPlaylistDropdownContainer.width
                        height: Math.min(dlPlaylistColumn.implicitHeight + App.Spacing.dp(20), App.Spacing.dp(400))
                        padding: App.Spacing.dp(10)
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        onClosed: {
                            dlPlaylistDropdownContainer.dlDropdownCooldown = true
                            dlDropdownCooldownTimer.restart()
                        }

                        background: Rectangle {
                            color: bgColor
                            border.color: accentColor
                            border.width: 1
                            radius: App.Spacing.dpMin(8, 2)
                        }

                        contentItem: Flickable {
                            clip: true
                            contentHeight: dlPlaylistColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: dlPlaylistColumn
                                width: parent.width
                                spacing: App.Spacing.dp(4)

                                Repeater {
                                    model: downloadPage.downloadPlaylists

                                    Rectangle {
                                        width: dlPlaylistColumn.width
                                        height: App.Spacing.bottomBarNavButtonHeight
                                        color: {
                                            var isActive = modelData === downloadPage.selectedPlaylist
                                            if (isActive) return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
                                            if (dlItemMouse.containsMouse) return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                                            return "transparent"
                                        }
                                        radius: App.Spacing.dpMin(6, 2)
                                        border.width: modelData === downloadPage.selectedPlaylist ? 1 : 0
                                        border.color: accentColor

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: App.Spacing.overallMargin * 2
                                            anchors.rightMargin: App.Spacing.overallMargin * 2
                                            spacing: App.Spacing.overallMargin * 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData
                                                color: textColor
                                                font.pixelSize: App.Spacing.overallText * 1.1
                                                font.bold: modelData === downloadPage.selectedPlaylist
                                                font.family: downloadPage.globalFont
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: dlItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                downloadPage.selectedPlaylist = modelData
                                                downloadManager.set_download_playlist(modelData)
                                                dlPlaylistPopup.close()
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

            // ─── Search Bar ──────────────────────────────────────

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: App.Spacing.dp(44)
                color: cardColor
                border.color: searchInput.activeFocus ? accentColor : cardBorderColor
                border.width: 1
                radius: App.Spacing.dp(8)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: App.Spacing.dp(12)
                    anchors.rightMargin: App.Spacing.dp(8)
                    spacing: App.Spacing.dp(8)

                    // Search icon
                    Image {
                        id: searchIconImg
                        Layout.preferredWidth: App.Spacing.dp(18)
                        Layout.preferredHeight: App.Spacing.dp(18)
                        source: "./assets/search_icon.svg"
                        sourceSize: Qt.size(App.Spacing.dp(36), App.Spacing.dp(36))
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    ColorOverlay {
                        Layout.preferredWidth: App.Spacing.dp(18)
                        Layout.preferredHeight: App.Spacing.dp(18)
                        source: searchIconImg
                        color: dimTextColor
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Song name, artist, or Spotify URL..."
                        placeholderTextColor: dimTextColor
                        font.family: downloadPage.globalFont
                        font.pixelSize: App.Spacing.dp(14)
                        color: textColor
                        background: Item {}
                        selectByMouse: true

                        onAccepted: {
                            if (text.trim().length > 0) {
                                downloadManager.search(text.trim())
                                downloadPage.showKeyboard = false
                            }
                        }
                    }

                    // Keyboard toggle button
                    Rectangle {
                        Layout.preferredWidth: App.Spacing.dp(32)
                        Layout.preferredHeight: App.Spacing.dp(32)
                        color: downloadPage.showKeyboard
                            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
                            : kbToggleMouse.containsMouse
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
                                : "transparent"
                        radius: App.Spacing.dp(6)
                        border.width: 1
                        border.color: downloadPage.showKeyboard ? accentColor : cardBorderColor

                        Text {
                            anchors.centerIn: parent
                            text: "\u2328"
                            font.pixelSize: App.Spacing.dp(18)
                            color: downloadPage.showKeyboard ? accentColor : dimTextColor
                        }

                        MouseArea {
                            id: kbToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                downloadPage.showKeyboard = !downloadPage.showKeyboard
                                if (downloadPage.showKeyboard) searchInput.forceActiveFocus()
                            }
                        }
                    }

                    // Search button
                    Rectangle {
                        Layout.preferredWidth: App.Spacing.dp(70)
                        Layout.preferredHeight: App.Spacing.dp(32)
                        color: searchMouseArea.pressed ? Qt.darker(accentColor, 1.3) : accentColor
                        radius: App.Spacing.dp(6)
                        opacity: downloadPage.isSearching ? 0.5 : 1.0

                        Text {
                            anchors.centerIn: parent
                            text: downloadPage.isSearching ? "..." : "Search"
                            font.family: downloadPage.globalFont
                            font.pixelSize: App.Spacing.dp(12)
                            font.weight: Font.DemiBold
                            color: "#000000"
                        }

                        MouseArea {
                            id: searchMouseArea
                            anchors.fill: parent
                            enabled: !downloadPage.isSearching
                            onClicked: {
                                if (searchInput.text.trim().length > 0) {
                                    downloadManager.search(searchInput.text.trim())
                                    downloadPage.showKeyboard = false
                                }
                            }
                        }
                    }
                }
            }

            // ─── On-Screen Keyboard ───────────────────────────────
            Rectangle {
                id: onScreenKeyboard
                Layout.fillWidth: true
                Layout.fillHeight: downloadPage.showKeyboard
                visible: downloadPage.showKeyboard
                color: cardColor
                border.color: cardBorderColor
                border.width: 1
                radius: App.Spacing.dp(8)

                property var rows: [
                    ["1","2","3","4","5","6","7","8","9","0"],
                    ["Q","W","E","R","T","Y","U","I","O","P"],
                    ["A","S","D","F","G","H","J","K","L"],
                    ["Z","X","C","V","B","N","M"]
                ]

                // Dynamic key sizing: 5 rows (4 letter + 1 bottom), 10 keys wide
                property real kbMargin: App.Spacing.dp(8)
                property real kbSpacing: App.Spacing.dp(4)
                property real kbRowCount: 5
                property real kbColCount: 10
                property real keyWidth: Math.floor((width - kbMargin * 2 - kbSpacing * (kbColCount - 1)) / kbColCount)
                property real keyHeight: Math.floor((height - kbMargin * 2 - kbSpacing * (kbRowCount - 1)) / kbRowCount)
                property real keyFontSize: Math.max(App.Spacing.dp(12), Math.min(keyHeight * 0.45, App.Spacing.dp(32)))

                Column {
                    id: kbGrid
                    anchors.fill: parent
                    anchors.margins: onScreenKeyboard.kbMargin
                    spacing: onScreenKeyboard.kbSpacing

                    Repeater {
                        model: onScreenKeyboard.rows

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: onScreenKeyboard.kbSpacing

                            Repeater {
                                model: modelData

                                Rectangle {
                                    width: onScreenKeyboard.keyWidth
                                    height: onScreenKeyboard.keyHeight
                                    radius: App.Spacing.dp(6)
                                    color: kbKeyMouse.pressed
                                        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
                                        : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: downloadPage.globalFont
                                        font.pixelSize: onScreenKeyboard.keyFontSize
                                        font.weight: Font.DemiBold
                                        color: textColor
                                    }

                                    MouseArea {
                                        id: kbKeyMouse
                                        anchors.fill: parent
                                        onClicked: {
                                            searchInput.text += modelData.toLowerCase()
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom row: backspace, space, clear, search
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: onScreenKeyboard.kbSpacing

                        // Backspace
                        Rectangle {
                            width: onScreenKeyboard.keyWidth * 1.5 + onScreenKeyboard.kbSpacing * 0.5
                            height: onScreenKeyboard.keyHeight
                            radius: App.Spacing.dp(6)
                            color: bkspMouse.pressed
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
                                : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "\u232B"
                                font.pixelSize: onScreenKeyboard.keyFontSize * 1.2
                                color: textColor
                            }

                            MouseArea {
                                id: bkspMouse
                                anchors.fill: parent
                                onClicked: {
                                    if (searchInput.text.length > 0) {
                                        searchInput.text = searchInput.text.slice(0, -1)
                                    }
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }

                        // Space bar
                        Rectangle {
                            width: onScreenKeyboard.keyWidth * 4.5 + onScreenKeyboard.kbSpacing * 3.5
                            height: onScreenKeyboard.keyHeight
                            radius: App.Spacing.dp(6)
                            color: spaceMouse.pressed
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
                                : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "SPACE"
                                font.family: downloadPage.globalFont
                                font.pixelSize: onScreenKeyboard.keyFontSize * 0.85
                                font.weight: Font.DemiBold
                                color: dimTextColor
                            }

                            MouseArea {
                                id: spaceMouse
                                anchors.fill: parent
                                onClicked: {
                                    searchInput.text += " "
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }

                        // Clear
                        Rectangle {
                            width: onScreenKeyboard.keyWidth * 1.5 + onScreenKeyboard.kbSpacing * 0.5
                            height: onScreenKeyboard.keyHeight
                            radius: App.Spacing.dp(6)
                            color: clearMouse.pressed
                                ? Qt.rgba(1, 0.227, 0.208, 0.2)
                                : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "CLR"
                                font.family: downloadPage.globalFont
                                font.pixelSize: onScreenKeyboard.keyFontSize * 0.85
                                font.weight: Font.DemiBold
                                color: "#e53935"
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                onClicked: {
                                    searchInput.text = ""
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }

                        // Search from keyboard
                        Rectangle {
                            width: onScreenKeyboard.keyWidth * 2 + onScreenKeyboard.kbSpacing
                            height: onScreenKeyboard.keyHeight
                            radius: App.Spacing.dp(6)
                            color: kbSearchMouse.pressed ? Qt.darker(accentColor, 1.3) : accentColor
                            opacity: searchInput.text.trim().length > 0 ? 1.0 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: "SEARCH"
                                font.family: downloadPage.globalFont
                                font.pixelSize: onScreenKeyboard.keyFontSize * 0.85
                                font.weight: Font.Bold
                                color: "#000000"
                            }

                            MouseArea {
                                id: kbSearchMouse
                                anchors.fill: parent
                                enabled: searchInput.text.trim().length > 0 && !downloadPage.isSearching
                                onClicked: {
                                    downloadManager.search(searchInput.text.trim())
                                    downloadPage.showKeyboard = false
                                }
                            }
                        }
                    }
                }
            }

            // ─── Results List ────────────────────────────────────

            ListView {
                id: resultsListView
                Layout.fillWidth: true
                Layout.fillHeight: !downloadPage.showKeyboard
                visible: !downloadPage.showKeyboard
                clip: true
                spacing: App.Spacing.dp(6)
                model: downloadPage.searchResults

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: songDelegate
                    property color failedColor: "#e53935"
                    property string songId: modelData.song_id || ""
                    property bool isDownloading: songId !== "" && downloadPage.activeDownloads.hasOwnProperty(songId)
                    property real dlProgress: isDownloading ? (downloadPage.activeDownloads[songId] || 0) : 0
                    onDlProgressChanged: if (progressRing.visible) progressRing.requestPaint()

                    width: resultsListView.width
                    height: App.Spacing.dp(72)
                    color: delegateMouseArea.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12) : cardColor
                    border.color: {
                        if (modelData.is_downloaded) return Qt.rgba(successColor.r, successColor.g, successColor.b, 0.3)
                        if (modelData.is_failed) return Qt.rgba(failedColor.r, failedColor.g, failedColor.b, 0.3)
                        return cardBorderColor
                    }
                    border.width: 1
                    radius: App.Spacing.dp(8)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: App.Spacing.dp(10)
                        spacing: App.Spacing.dp(12)

                        // Album art thumbnail
                        Rectangle {
                            Layout.preferredWidth: App.Spacing.dp(52)
                            Layout.preferredHeight: App.Spacing.dp(52)
                            radius: App.Spacing.dp(6)
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                            clip: true

                            Image {
                                id: albumArtImg
                                anchors.fill: parent
                                source: modelData.cover_url || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            // Fallback icon
                            Text {
                                anchors.centerIn: parent
                                text: "\u266A"
                                font.pixelSize: App.Spacing.dp(20)
                                color: dimTextColor
                                visible: albumArtImg.status !== Image.Ready
                            }
                        }

                        // Song info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: App.Spacing.dp(2)

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || "Unknown"
                                font.family: downloadPage.globalFont
                                font.pixelSize: App.Spacing.dp(14)
                                font.weight: Font.DemiBold
                                color: textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.artist || "Unknown Artist"
                                font.family: downloadPage.globalFont
                                font.pixelSize: App.Spacing.dp(12)
                                color: dimTextColor
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: App.Spacing.dp(8)

                                Text {
                                    text: modelData.album_name || ""
                                    font.family: downloadPage.globalFont
                                    font.pixelSize: App.Spacing.dp(10)
                                    color: dimTextColor
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: App.Spacing.dp(200)
                                }

                                Text {
                                    text: {
                                        var dur = modelData.duration || 0
                                        var m = Math.floor(dur / 60)
                                        var s = dur % 60
                                        return m + ":" + (s < 10 ? "0" : "") + s
                                    }
                                    font.family: downloadPage.globalFont
                                    font.pixelSize: App.Spacing.dp(10)
                                    color: dimTextColor
                                }

                                Rectangle {
                                    visible: modelData.explicit === true
                                    width: explicitLabel.implicitWidth + App.Spacing.dp(6)
                                    height: explicitLabel.implicitHeight + App.Spacing.dp(4)
                                    color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
                                    radius: 2

                                    Text {
                                        id: explicitLabel
                                        anchors.centerIn: parent
                                        text: "E"
                                        font.family: downloadPage.globalFont
                                        font.pixelSize: App.Spacing.dp(9)
                                        font.weight: Font.Bold
                                        color: "#000"
                                    }
                                }

                                // Playlist badge for downloaded songs
                                Rectangle {
                                    visible: modelData.is_downloaded === true && (modelData.downloaded_playlist || "") !== ""
                                    width: playlistBadgeText.implicitWidth + App.Spacing.dp(10)
                                    height: playlistBadgeText.implicitHeight + App.Spacing.dp(4)
                                    color: Qt.rgba(successColor.r, successColor.g, successColor.b, 0.15)
                                    border.width: 1
                                    border.color: Qt.rgba(successColor.r, successColor.g, successColor.b, 0.3)
                                    radius: App.Spacing.dp(3)

                                    Text {
                                        id: playlistBadgeText
                                        anchors.centerIn: parent
                                        text: modelData.downloaded_playlist || ""
                                        font.family: downloadPage.globalFont
                                        font.pixelSize: App.Spacing.dp(9)
                                        font.weight: Font.DemiBold
                                        color: successColor
                                    }
                                }
                            }
                        }

                        // Download button / Downloaded / Failed / Downloading indicator
                        Rectangle {
                            Layout.preferredWidth: App.Spacing.dp(40)
                            Layout.preferredHeight: App.Spacing.dp(40)
                            radius: App.Spacing.dp(20)
                            color: {
                                if (modelData.is_downloaded)
                                    return Qt.rgba(successColor.r, successColor.g, successColor.b, 0.15)
                                if (modelData.is_failed)
                                    return Qt.rgba(failedColor.r, failedColor.g, failedColor.b, 0.12)
                                if (isDownloading)
                                    return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                                return dlBtnMouse.pressed ? Qt.darker(accentColor, 1.3) : accentColor
                            }

                            // Download icon (shown when available to download)
                            Image {
                                id: dlBtnIcon
                                anchors.centerIn: parent
                                width: App.Spacing.dp(20)
                                height: App.Spacing.dp(20)
                                source: "./assets/download_button.svg"
                                sourceSize: Qt.size(App.Spacing.dp(40), App.Spacing.dp(40))
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: dlBtnIcon
                                source: dlBtnIcon
                                color: "#000000"
                                visible: !modelData.is_downloaded && !modelData.is_failed && !isDownloading
                            }

                            // Progress ring (shown while downloading)
                            Canvas {
                                id: progressRing
                                anchors.centerIn: parent
                                width: App.Spacing.dp(32)
                                height: App.Spacing.dp(32)
                                visible: isDownloading
                                onPaint: {
                                    var ctx = getContext("2d")
                                    var cx = width / 2
                                    var cy = height / 2
                                    var r = (width / 2) - 2.5
                                    var startAngle = -Math.PI / 2

                                    ctx.clearRect(0, 0, width, height)

                                    // Background track
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                    ctx.lineWidth = 3
                                    ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
                                    ctx.stroke()

                                    // Progress arc
                                    var sweep = dlProgress * 2 * Math.PI
                                    if (sweep > 0) {
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, r, startAngle, startAngle + sweep)
                                        ctx.lineWidth = 3
                                        ctx.strokeStyle = accentColor
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }
                                }
                            }

                            // Percentage text inside ring
                            Text {
                                anchors.centerIn: parent
                                text: Math.round(dlProgress * 100)
                                font.family: downloadPage.globalFont
                                font.pixelSize: App.Spacing.dp(9)
                                font.weight: Font.Bold
                                color: accentColor
                                visible: isDownloading
                            }

                            // Checkmark (shown when downloaded)
                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                font.pixelSize: App.Spacing.dp(20)
                                font.weight: Font.Bold
                                color: successColor
                                visible: modelData.is_downloaded === true
                            }

                            // X mark (shown when failed)
                            Text {
                                anchors.centerIn: parent
                                text: "\u2717"
                                font.pixelSize: App.Spacing.dp(18)
                                font.weight: Font.Bold
                                color: failedColor
                                visible: modelData.is_failed === true && !modelData.is_downloaded
                            }

                            MouseArea {
                                id: dlBtnMouse
                                anchors.fill: parent
                                enabled: !isDownloading
                                cursorShape: isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.is_downloaded) {
                                        // Play the downloaded song and navigate to MediaRoom
                                        var artist = modelData.artist || ""
                                        var name = modelData.name || ""
                                        var playlist = modelData.downloaded_playlist || ""
                                        if (mediaManager && artist && name && playlist) {
                                            if (spotifyManager && spotifyManager.is_connected() && spotifyManager.is_playing()) {
                                                spotifyManager.pause()
                                            }
                                            if (settingsManager && settingsManager.mediaSource !== "local") {
                                                settingsManager.set_media_source("local")
                                            }
                                            mediaManager.play_downloaded_song(artist, name, playlist)
                                            if (downloadPage.stackView) {
                                                downloadPage.stackView.push("MediaRoom.qml", {
                                                    stackView: downloadPage.stackView
                                                })
                                            }
                                        }
                                    } else if (modelData.is_failed) {
                                        errorPopup.errorMsg = modelData.error_message || "Download failed — no audio source found"
                                        errorPopup.songName = (modelData.artist || "") + " - " + (modelData.name || "")
                                        errorPopup.open()
                                    } else {
                                        downloadManager.download_song(JSON.stringify(modelData))
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        onClicked: function(mouse) { mouse.accepted = false }
                        onPressed: function(mouse) { mouse.accepted = false }
                        onReleased: function(mouse) { mouse.accepted = false }
                    }
                }

                // ─── Load More footer ───────────────────────────

                footer: Item {
                    width: resultsListView.width
                    height: downloadPage.hasMoreResults ? App.Spacing.dp(52) : 0
                    visible: downloadPage.hasMoreResults

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: App.Spacing.dp(6)
                        color: loadMoreMouse.containsMouse
                            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                            : cardColor
                        border.color: cardBorderColor
                        border.width: 1
                        radius: App.Spacing.dp(8)

                        Text {
                            anchors.centerIn: parent
                            text: downloadPage.isSearching ? "Loading..." : "Load More Results"
                            font.family: downloadPage.globalFont
                            font.pixelSize: App.Spacing.dp(13)
                            font.weight: Font.DemiBold
                            color: accentColor
                        }

                        MouseArea {
                            id: loadMoreMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !downloadPage.isSearching
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                downloadManager.search_more()
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: !downloadPage.isSearching && downloadPage.searchResults.length === 0
                    text: "Search for a song, paste a Spotify URL, or enter an artist name"
                    font.family: downloadPage.globalFont
                    font.pixelSize: App.Spacing.dp(14)
                    color: dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }

                // Loading indicator
                BusyIndicator {
                    anchors.centerIn: parent
                    visible: downloadPage.isSearching && downloadPage.searchResults.length === 0
                    running: downloadPage.isSearching && downloadPage.searchResults.length === 0
                    palette.dark: accentColor
                }
            }

            // ─── Active Downloads Bar ────────────────────────────

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: activeDownloadsList.count > 0 ? App.Spacing.dp(Math.min(activeDownloadsList.count * 44, 132)) : 0
                color: cardColor
                border.color: cardBorderColor
                border.width: activeDownloadsList.count > 0 ? 1 : 0
                radius: App.Spacing.dp(8)
                clip: true
                visible: activeDownloadsList.count > 0

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ListView {
                    id: activeDownloadsList
                    anchors.fill: parent
                    anchors.margins: App.Spacing.dp(6)
                    spacing: App.Spacing.dp(4)
                    clip: true
                    model: ListModel { id: activeDownloadsModel }

                    delegate: RowLayout {
                        width: activeDownloadsList.width
                        height: App.Spacing.dp(36)
                        spacing: App.Spacing.dp(8)

                        Text {
                            Layout.fillWidth: true
                            text: model.songName || ""
                            font.family: downloadPage.globalFont
                            font.pixelSize: App.Spacing.dp(12)
                            color: textColor
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: App.Spacing.dp(120)
                            Layout.preferredHeight: App.Spacing.dp(6)
                            radius: 3
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.2)

                            Rectangle {
                                width: parent.width * (model.progress || 0)
                                height: parent.height
                                radius: 3
                                color: accentColor

                                Behavior on width {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }

                        Text {
                            text: Math.round((model.progress || 0) * 100) + "%"
                            font.family: downloadPage.globalFont
                            font.pixelSize: App.Spacing.dp(11)
                            color: dimTextColor
                            Layout.preferredWidth: App.Spacing.dp(36)
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }

    // ─── Active Downloads Model Sync ─────────────────────────────

    onActiveDownloadsChanged: {
        activeDownloadsModel.clear()
        var downloads = downloadPage.activeDownloads
        for (var songId in downloads) {
            if (downloads.hasOwnProperty(songId)) {
                activeDownloadsModel.append({
                    songName: downloadPage.downloadNames[songId] || songId,
                    progress: downloads[songId]
                })
            }
        }
    }

    // ─── Error Detail Popup ───────────────────────────────────────

    Popup {
        id: errorPopup
        anchors.centerIn: parent
        width: App.Spacing.dp(320)
        height: errorPopupContent.implicitHeight + App.Spacing.dp(32)
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string songName: ""
        property string errorMsg: ""

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        background: Rectangle {
            color: bgColor
            border.color: Qt.rgba(errorPopup.parent ? downloadPage.accentColor.r : 0, errorPopup.parent ? downloadPage.accentColor.g : 0, errorPopup.parent ? downloadPage.accentColor.b : 0, 0.3)
            border.width: 1
            radius: App.Spacing.dp(12)
        }

        ColumnLayout {
            id: errorPopupContent
            anchors.fill: parent
            anchors.margins: App.Spacing.dp(16)
            spacing: App.Spacing.dp(12)

            Text {
                text: "Download Failed"
                font.family: downloadPage.globalFont
                font.pixelSize: App.Spacing.dp(18)
                font.weight: Font.Bold
                color: "#e53935"
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: errorSongLabel.implicitHeight + App.Spacing.dp(12)
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                radius: App.Spacing.dp(6)

                Text {
                    id: errorSongLabel
                    anchors.centerIn: parent
                    width: parent.width - App.Spacing.dp(16)
                    text: errorPopup.songName
                    font.family: downloadPage.globalFont
                    font.pixelSize: App.Spacing.dp(13)
                    font.weight: Font.DemiBold
                    color: textColor
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Text {
                text: errorPopup.errorMsg
                font.family: downloadPage.globalFont
                font.pixelSize: App.Spacing.dp(12)
                color: dimTextColor
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: App.Spacing.dp(36)
                color: errorDismissMouse.pressed
                    ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                    : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.2)
                border.width: 1
                radius: App.Spacing.dp(6)

                Text {
                    anchors.centerIn: parent
                    text: "OK"
                    font.family: downloadPage.globalFont
                    font.pixelSize: App.Spacing.dp(13)
                    font.weight: Font.DemiBold
                    color: textColor
                }

                MouseArea {
                    id: errorDismissMouse
                    anchors.fill: parent
                    onClicked: errorPopup.close()
                }
            }
        }
    }
}
