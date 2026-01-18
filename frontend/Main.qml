import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.folderlistmodel 2.15
import "." as App

ApplicationWindow {
    id: mainWindow
    visible: true
    title: deviceName

    // Store the system default font family at startup
    property string systemDefaultFont: ""

    // Global font setting - applies to all child components
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    font.family: App.Style.fontFamily !== "" ? App.Style.fontFamily : systemDefaultFont

    // Minimum window constraints
    minimumWidth: 400
    minimumHeight: 300

    // Properties bound to settings manager
    property string deviceName: settingsManager ? settingsManager.deviceName : "Default Device"
    property string theme: settingsManager ? settingsManager.themeSetting : "Light"
    property real startUpVolume: settingsManager ? settingsManager.startUpVolume : 0.1
    property bool showClock: settingsManager ? settingsManager.showClock : true
    property bool clockFormat24Hour: settingsManager ? settingsManager.clockFormat24Hour : true
    property int clockSize: settingsManager ? settingsManager.clockSize : 18
    property string lastSettingsSection: settingsManager ? settingsManager.lastSettingsSection : "deviceSettings"
    property string fontSetting: settingsManager ? settingsManager.fontSetting : "System Default"

    // Album Art Colors - track last applied to detect changes
    property string lastAppliedAlbumArtColors: ""

    // Timer to poll for album art color changes (workaround for PySide6 signal issues)
    Timer {
        id: albumArtColorTimer
        interval: 250  // Check every 250ms for faster response
        repeat: true
        running: true
        property int tickCount: 0
        onTriggered: {
            tickCount++
            if (!settingsManager) return

            var isAlbumArtTheme = App.Style.currentTheme === "Album Art Capture"
            var newColors = settingsManager.albumArtColors

            // Debug log every 20 ticks (5 seconds)
            if (tickCount % 20 === 1) {
                console.log("[AlbumArtCapture] Timer: theme=" + App.Style.currentTheme +
                           ", colorsLen=" + (newColors ? newColors.length : 0) +
                           ", lastLen=" + lastAppliedAlbumArtColors.length)
            }

            if (isAlbumArtTheme && newColors && newColors.length > 0 && newColors !== lastAppliedAlbumArtColors) {
                console.log("[AlbumArtCapture] Applying new colors, length:", newColors.length)
                lastAppliedAlbumArtColors = newColors
                App.Style.updateAlbumArtTheme(newColors)
            }
        }
    }

    // Font loading properties
    property var loadedFonts: ({})
    property var fontLoaders: []

    // Screen dimension properties
    property int screenWidth: settingsManager ? settingsManager.screenWidth : 1280
    property int screenHeight: settingsManager ? settingsManager.screenHeight : 720

    // Bottom bar orientation property
    property bool isVerticalLayout: settingsManager ? 
                                   settingsManager.bottomBarOrientation === "side" : false

    // Set initial window size
    width: screenWidth
    height: screenHeight

    // Handle window close (force close / X button)
    onClosing: function(close) {
        console.log("Window closing - running cleanup...")
        if (mediaManager) {
            mediaManager._save_playback_state()
            mediaManager._clear_temp_files()
        }
        if (spotifyManager) {
            spotifyManager.cleanup()
        }
        close.accepted = true
    }

    // Initialize settings and theme
    Component.onCompleted: {
        console.log("[QML] Main.qml Component.onCompleted - QML console working!")

        // Capture the system default font at startup (before any custom font is applied)
        systemDefaultFont = font.family
        // Also store it in Style for other components to use
        App.Style.systemDefaultFont = font.family

        if (settingsManager) {
            // Load theme
            console.log("[QML] Loading theme:", settingsManager.themeSetting)
            if (settingsManager.themeSetting) {
                App.Style.setTheme(settingsManager.themeSetting)
            }
            
            // Load dimensions
            width = settingsManager.screenWidth
            height = settingsManager.screenHeight
            
            // Initialize spacing
            App.Spacing.updateDimensions(width, height)
            
            // Add this line to set the UI scale from settings
            App.Spacing.globalScale = settingsManager.uiScale

            if (mediaManager) {
                mediaManager.connect_settings_manager(settingsManager)
            }

            // Initialize orientation
            isVerticalLayout = settingsManager.bottomBarOrientation === "side"

            // Restore window state
            let savedState = settingsManager.get_window_state()
            if (savedState === "fullscreen") {
                mainWindow.visibility = Window.FullScreen
            } else if (savedState === "maximized") {
                mainWindow.visibility = Window.Maximized
            }
        }
        
        // Load custom themes
        if (settingsManager) {
            let customThemes = settingsManager.customThemes
            customThemes.forEach(function(themeName) {
                let themeJSON = settingsManager.get_custom_theme(themeName)
                let themeObj = JSON.parse(themeJSON)
                App.Style.addCustomTheme(themeName, themeObj)
            })
        }

        // Note: albumColorsExtracted signal is connected via Connections component below
        // for better reliability with PySide6 signals
        
        // Update theme list when custom themes change
        if (settingsManager) {
            settingsManager.customThemesChanged.connect(function() {
                // Clear existing custom themes
                App.Style.customThemes = {}
                
                // Reload custom themes
                let customThemes = settingsManager.customThemes
                customThemes.forEach(function(themeName) {
                    let themeJSON = settingsManager.get_custom_theme(themeName)
                    let themeObj = JSON.parse(themeJSON)
                    App.Style.addCustomTheme(themeName, themeObj)
                })
                
                // Force update of theme options
                App.Style.customThemesUpdated()
            })
        }
    }

    // Window resize handlers
    onWidthChanged: {
        if (settingsManager && width > 0 && width >= minimumWidth) {
            settingsManager.save_screen_width(width)
            screenWidth = width
            App.Spacing.updateDimensions(width, height)
        }
    }

    onHeightChanged: {
        if (settingsManager && height > 0 && height >= minimumHeight) {
            settingsManager.save_screen_height(height)
            screenHeight = height
            App.Spacing.updateDimensions(width, height)
        }
    }

    // Settings manager connections
    Connections {
        target: settingsManager
        
        function onScreenWidthChanged() {
            if (settingsManager) {
                width = settingsManager.screenWidth
                App.Spacing.updateDimensions(width, height)
            }
        }
        
        function onScreenHeightChanged() {
            if (settingsManager) {
                height = settingsManager.screenHeight
                App.Spacing.updateDimensions(width, height)
            }
        }
        
        function onThemeSettingChanged() {
            if (settingsManager) {
                App.Style.setTheme(settingsManager.themeSetting)
                theme = settingsManager.themeSetting
            }
        }

        function onFontSettingChanged() {
            if (settingsManager) {
                App.Style.setFont(settingsManager.fontSetting)
                fontSetting = settingsManager.fontSetting
            }
        }
        
        function onBottomBarOrientationChanged() {
            if (settingsManager) {
                isVerticalLayout = settingsManager.bottomBarOrientation === "side"
                // Force an update of the bottom bar
                bottomBar.isVertical = isVerticalLayout

                // Force recalculation of z-order
                stackView.z = 1
                bottomBar.z = 0
            }
        }

        function onAlbumArtColorsChanged(themeJson) {
            console.log("[AlbumArtCapture] settingsManager received albumArtColorsChanged!")
            // In PySide6, signal arguments may not pass through Connections properly
            // So we read directly from the property as a workaround
            var colors = settingsManager.albumArtColors
            console.log("[AlbumArtCapture] Colors from property, length:", colors ? colors.length : "null")
            if (colors && colors.length > 0) {
                console.log("[AlbumArtCapture] Updating theme with new colors...")
                App.Style.updateAlbumArtTheme(colors)
            }
        }
    }

    // Media manager connections for Album Art Capture (backup)
    Connections {
        target: mediaManager

        function onAlbumColorsExtracted(themeJson) {
            console.log("[AlbumArtCapture] Connections received albumColorsExtracted!")
            console.log("[AlbumArtCapture] themeJson:", themeJson ? themeJson.substring(0, 100) : "null")
            App.Style.updateAlbumArtTheme(themeJson)
        }
    }

    // Spotify manager connections for Album Art Capture
    Connections {
        target: spotifyManager

        function onAlbumColorsExtracted(themeJson) {
            console.log("[AlbumArtCapture Spotify] Received albumColorsExtracted!")
            console.log("[AlbumArtCapture Spotify] themeJson:", themeJson ? themeJson.substring(0, 100) : "null")
            lastAppliedAlbumArtColors = themeJson
            App.Style.updateAlbumArtTheme(themeJson)
        }
    }

    // Main layout container
    Item {
        anchors.fill: parent
        
        // Main stack view with adaptive anchoring
        StackView {
            id: stackView
            z: 1
            
            // Different anchoring based on orientation
            anchors {
                left: isVerticalLayout ? bottomBar.right : parent.left
                right: parent.right
                top: parent.top
                bottom: isVerticalLayout ? parent.bottom : bottomBar.top
            }
            
            initialItem: MainMenu {
                stackView: stackView
                windowWidth: mainWindow.width
                windowHeight: mainWindow.height
            }
            
            // Disable transitions for better performance
            pushEnter: null
            pushExit: null
            popEnter: null
            popExit: null
            replaceEnter: null
            replaceExit: null
        }

        // Bottom bar - positioning is handled internally in BottomBar.qml
        BottomBar {
            id: bottomBar
            z: 0
            stackView: stackView
            mainWindow: mainWindow
            isVertical: isVerticalLayout
            
            // Force update on orientation change
            onIsVerticalChanged: {
                // Trigger a layout update
                if (isVertical) {
                    anchors.left = parent.left
                    anchors.top = parent.top
                    anchors.bottom = parent.bottom
                    anchors.right = undefined
                    width = parent.width * 0.1
                } else {
                    anchors.bottom = parent.bottom
                    anchors.left = parent.left
                    anchors.right = parent.right
                    anchors.top = undefined
                    height = parent.height * App.Spacing.bottomBarHeightPercent
                }
            }
        }
    }

    // Font folder model to scan for available fonts
    FolderListModel {
        id: fontFolderModel
        folder: Qt.resolvedUrl("assets/fonts")
        nameFilters: ["*.ttf", "*.otf", "*.TTF", "*.OTF"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            console.log("Font folder status:", status, "count:", count, "folder:", folder)
            if (status === FolderListModel.Ready) {
                loadFontsFromFolder()
            }
        }

        onCountChanged: {
            console.log("Font folder count changed:", count)
            if (status === FolderListModel.Ready && count > 0) {
                loadFontsFromFolder()
            }
        }
    }

    // Dynamically created FontLoader instances
    property var fontLoaderComponent: Component {
        FontLoader {}
    }

    // Track pending font loads
    property int pendingFontLoads: 0
    property var pendingFontData: []

    // Function to load fonts from the folder
    function loadFontsFromFolder() {
        console.log("Loading fonts from folder, count:", fontFolderModel.count)

        // Clear previous loaders
        for (var j = 0; j < fontLoaders.length; j++) {
            fontLoaders[j].destroy()
        }
        fontLoaders = []
        pendingFontData = []
        pendingFontLoads = 0

        if (fontFolderModel.count === 0) {
            console.log("No fonts found in folder")
            App.Style.registerFonts([], {})
            return
        }

        pendingFontLoads = fontFolderModel.count

        for (var i = 0; i < fontFolderModel.count; i++) {
            var filePath = fontFolderModel.get(i, "fileUrl")
            var fileName = fontFolderModel.get(i, "fileName")

            // Create display name from filename (remove extension)
            var displayName = fileName.replace(/\.(ttf|otf)$/i, "").replace(/[-_]/g, " ")

            console.log("Creating FontLoader for:", fileName, "->", filePath)

            // Create a FontLoader for this font
            var loader = fontLoaderComponent.createObject(mainWindow, {
                "source": filePath,
                "objectName": displayName
            })

            fontLoaders.push(loader)

            // Handle async loading
            if (loader.status === FontLoader.Ready) {
                onFontLoaded(loader, displayName)
            } else if (loader.status === FontLoader.Loading) {
                // Connect to status change
                loader.statusChanged.connect(function() {
                    var ld = loader
                    var dn = displayName
                    return function() {
                        if (ld.status === FontLoader.Ready) {
                            onFontLoaded(ld, dn)
                        } else if (ld.status === FontLoader.Error) {
                            console.warn("Failed to load font:", dn)
                            pendingFontLoads--
                            checkFontsComplete()
                        }
                    }
                }())
            } else {
                console.warn("Font load error for:", fileName, "status:", loader.status)
                pendingFontLoads--
            }
        }

        // Check if all loaded synchronously
        checkFontsComplete()
    }

    function onFontLoaded(loader, displayName) {
        console.log("Font loaded:", displayName, "->", loader.name)
        pendingFontData.push({ name: displayName, family: loader.name })
        pendingFontLoads--
        checkFontsComplete()
    }

    function checkFontsComplete() {
        if (pendingFontLoads <= 0) {
            var fontNames = []
            var familyMap = {}

            for (var i = 0; i < pendingFontData.length; i++) {
                fontNames.push(pendingFontData[i].name)
                familyMap[pendingFontData[i].name] = pendingFontData[i].family
            }

            console.log("All fonts loaded:", fontNames)

            // Register fonts with Style
            App.Style.registerFonts(fontNames, familyMap)

            // Apply saved font setting
            if (settingsManager && settingsManager.fontSetting) {
                App.Style.setFont(settingsManager.fontSetting)
            }
        }
    }

    // Settings update functions
    function updateDeviceName(newDeviceName) {
        if (settingsManager && newDeviceName.trim() !== "") {
            settingsManager.save_device_name(newDeviceName)
            deviceName = newDeviceName
        }
    }

    function updateTheme(newTheme) {
        console.warn("[AlbumArtCapture] updateTheme called with:", newTheme)
        if (settingsManager) {
            settingsManager.save_theme_setting(newTheme)
            App.Style.setTheme(newTheme)
            theme = newTheme

            // If Album Art Capture is selected, immediately extract colors from current song
            console.warn("[AlbumArtCapture] Checking if Album Art Capture, mediaManager exists:", typeof mediaManager)
            if (newTheme === "Album Art Capture") {
                try {
                    if (mediaManager) {
                        let currentFile = mediaManager.get_current_file()
                        console.warn("[AlbumArtCapture] Theme selected, current file:", currentFile)
                        if (currentFile) {
                            console.warn("[AlbumArtCapture] Calling extract_colors_from_album_art now...")
                            mediaManager.extract_colors_from_album_art(currentFile)
                            console.warn("[AlbumArtCapture] Call completed")
                        } else {
                            console.warn("[AlbumArtCapture] No current file!")
                        }
                    } else {
                        console.warn("[AlbumArtCapture] mediaManager is null/undefined!")
                    }
                } catch (e) {
                    console.error("[AlbumArtCapture] Error:", e)
                }
            }
        }
    }

    function updateFont(newFont) {
        if (settingsManager) {
            settingsManager.save_font_setting(newFont)
            App.Style.setFont(newFont)
            fontSetting = newFont
        }
    }

    function updateStartupVolume(newVolume) {
        if (settingsManager) {
            settingsManager.save_start_volume(newVolume)
            startUpVolume = newVolume
        }
    }

    function updateScreenDimensions(newWidth, newHeight) {
        if (settingsManager) {
            if (newWidth >= minimumWidth) {
                settingsManager.save_screen_width(newWidth)
                width = newWidth
            }
            if (newHeight >= minimumHeight) {
                settingsManager.save_screen_height(newHeight)
                height = newHeight
            }
            App.Spacing.updateDimensions(width, height)
        }
    }
}