import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

ApplicationWindow {
    id: mainWindow
    visible: true
    title: deviceName

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
    property string lastSettingsSection: "deviceSettings"

    // Screen dimension properties
    property int screenWidth: settingsManager ? settingsManager.screenWidth : 1280
    property int screenHeight: settingsManager ? settingsManager.screenHeight : 720

    // Bottom bar orientation property
    property bool isVerticalLayout: settingsManager ? 
                                   settingsManager.bottomBarOrientation === "side" : false

    // Set initial window size
    width: screenWidth
    height: screenHeight

    // Initialize settings and theme
    Component.onCompleted: {
        if (settingsManager) {
            // Load theme
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

    // Settings update functions
    function updateDeviceName(newDeviceName) {
        if (settingsManager && newDeviceName.trim() !== "") {
            settingsManager.save_device_name(newDeviceName)
            deviceName = newDeviceName
        }
    }

    function updateTheme(newTheme) {
        if (settingsManager) {
            settingsManager.save_theme_setting(newTheme)
            App.Style.setTheme(newTheme)
            theme = newTheme
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