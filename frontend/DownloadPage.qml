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

    // Search state
    property var searchResults: []
    property bool isSearching: false
    property string statusText: "Search for songs to download"
    property bool hasMoreResults: false

    // Download state
    property var activeDownloads: ({})  // songName -> progress (0.0-1.0)

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

        function onDownloadStarted(songName) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            downloads[songName] = 0.0
            downloadPage.activeDownloads = downloads
        }

        function onDownloadProgress(songName, progress) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            downloads[songName] = progress
            downloadPage.activeDownloads = downloads
        }

        function onDownloadComplete(songName, filePath) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            delete downloads[songName]
            downloadPage.activeDownloads = downloads
            downloadPage.statusText = "Downloaded: " + songName
        }

        function onDownloadError(songName, errorMsg) {
            var downloads = Object.assign({}, downloadPage.activeDownloads)
            delete downloads[songName]
            downloadPage.activeDownloads = downloads
            downloadPage.statusText = "Error: " + songName + " - " + errorMsg
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
                Layout.preferredHeight: App.Spacing.dp(40)
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
                Layout.fillHeight: true
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
                    property string songKey: (modelData.artist || "") + " - " + (modelData.name || "")
                    property bool isDownloading: downloadPage.activeDownloads.hasOwnProperty(songKey)
                    property real dlProgress: isDownloading ? (downloadPage.activeDownloads[songKey] || 0) : 0
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
                                enabled: !modelData.is_downloaded && !modelData.is_failed && !isDownloading
                                cursorShape: (modelData.is_downloaded || modelData.is_failed || isDownloading) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    downloadManager.download_song(JSON.stringify(modelData))
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
        for (var songName in downloads) {
            if (downloads.hasOwnProperty(songName)) {
                activeDownloadsModel.append({
                    songName: songName,
                    progress: downloads[songName]
                })
            }
        }
    }
}
