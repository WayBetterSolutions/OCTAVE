// Style.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    property string currentTheme: "SolarizedLight"
    property string currentFont: "System Default"

    // Available fonts (populated from Main.qml after scanning fonts folder)
    property var availableFonts: ["System Default"]

    // Map of font display names to their loaded font family names
    property var fontFamilyMap: ({})

    // System default font family (set by Main.qml at startup)
    property string systemDefaultFont: ""

    // The actual font family to use (resolved from currentFont)
    // Always returns a valid font family name - systemDefaultFont for System Default, custom font family otherwise
    property string fontFamily: currentFont === "System Default" ? systemDefaultFont : (fontFamilyMap[currentFont] || systemDefaultFont)

    // Signal when fonts list is updated
    signal fontsUpdated()

    // Signal when font changes (for real-time updates)
    signal fontChanged()

    // Function to set the current font
    function setFont(fontName) {
        if (availableFonts.indexOf(fontName) !== -1 || fontName === "System Default") {
            currentFont = fontName
            fontChanged()
        }
    }

    // Function to register available fonts (called from Main.qml)
    function registerFonts(fontList, familyMap) {
        availableFonts = ["System Default"].concat(fontList)
        fontFamilyMap = familyMap
        fontsUpdated()
    }

    // This will store our custom themes that are loaded from settings
    property var customThemes: ({})

    // Dynamic album art theme - updated in real-time based on current song
    property var albumArtTheme: null
    property bool isAlbumArtCaptureActive: currentTheme === "Album Art Capture"

    // Define theme palettes (built-in themes)
    readonly property var themes: ({
        "SolarizedLight": {
            "base": "#FDF6E3",
            "baseAlt": "#EEE8D5",
            "accent": "#268BD2",
            "text": {
                "primary": "#073642",
                "secondary": "#586E75"
            },
            "states": {
                "hover": "#E0DAC3",
                "paused": "#D6D0B9",
                "playing": "#CCC6AF"
            },
            "sliders": {
                "volume": "#268BD2",
                "media": "#586E75",
                "settings": "#268BD2"
            },
            "bottombar": {
                "previous": "#268BD2",
                "play": "#268BD2",
                "pause": "#268BD2",
                "next": "#268BD2",
                "volume": "#268BD2",
                "shuffle": "#268BD2",
                "toggleShade": "#E0DAC3",
                "homeButton": "#268BD2",
                "obdButton": "#268BD2",
                "mediaButton": "#268BD2",
                "settingsButton": "#268BD2",
                "androidAutoButton": "#268BD2",
                "phoneMirrorButton": "#268BD2"
            },
            "mediaroom": {
                "previous": "#2AA198",
                "play": "#2AA198",
                "pause": "#2AA198",
                "next": "#2AA198",
                "left": "#2AA198",
                "right": "#2AA198",
                "shuffle": "#2AA198",
                "toggleShade": "#D6D0B9"
            },
            "mainmenu": {
                "mediaContainer": "#9d2aa1"
            },
            "obd": {
                "boxBackground": "#EEE8D5",
                "barColor": "#2AA198"
            }
        },

        "NeonMatrix": {
            "base": "#0C0C0C",
            "baseAlt": "#161616",
            "accent": "#00FF41",
            "text": {
                "primary": "#CCFFCC",
                "secondary": "#88CC88"
            },
            "states": {
                "hover": "#202020",
                "paused": "#1C1C1C",
                "playing": "#282828"
            },
            "sliders": {
                "volume": "#00FF41",
                "media": "#88CC88",
                "settings": "#00FF41"
            },
            "bottombar": {
                "previous": "#00FF41",
                "play": "#00FF41",
                "pause": "#00FF41",
                "next": "#00FF41",
                "volume": "#00FF41",
                "shuffle": "#00FF41",
                "toggleShade": "#202020",
                "homeButton": "#00FF41",
                "obdButton": "#00FF41",
                "mediaButton": "#00FF41",
                "settingsButton": "#00FF41",
                "androidAutoButton": "#00FF41",
                "phoneMirrorButton": "#00FF41"
            },
            "mediaroom": {
                "previous": "#33FF66",
                "play": "#33FF66",
                "pause": "#33FF66",
                "next": "#33FF66",
                "left": "#33FF66",
                "right": "#33FF66",
                "shuffle": "#33FF66",
                "toggleShade": "#1C1C1C"
            },
            "mainmenu": {
                "mediaContainer": "#005500"
            },
            "obd": {
                "boxBackground": "#161616",
                "barColor": "#33FF66"
            }
        },

        "CosmicVoyager": {
        "base": "#0A0E17",
        "baseAlt": "#151C29",
        "accent": "#00BFFF",
        "text": {
            "primary": "#E0F2FF",
            "secondary": "#A0C2E0"
        },
        "states": {
            "hover": "#1E2A3D",
            "paused": "#192433",
            "playing": "#243143"
        },
        "sliders": {
            "volume": "#00BFFF", // Bright blue for primary volume
            "media": "#FF5E94",  // Contrast with pink for media
            "settings": "#7CB9E8" // Softer blue for settings
        },
        "bottombar": {
            "previous": "#7D9EC0", // Lighter blue
            "play": "#00CCFF",    // Bright cyan for emphasis
            "pause": "#00CCFF",   // Match play
            "next": "#7D9EC0",    // Match previous
            "volume": "#00BFFF",  // Match accent
            "shuffle": "#FF5E94", // Pink for distinction
            "toggleShade": "#1E2A3D",
            "homeButton": "#00BFFF", // Match accent
            "obdButton": "#FF8C42",  // Orange for OBD
            "mediaButton": "#00E673", // Green for media
            "settingsButton": "#7CB9E8", // Match settings slider
            "androidAutoButton": "#7CB9E8",
            "phoneMirrorButton": "#7CB9E8"
        },
        "mediaroom": {
            "previous": "#7D9EC0",
            "play": "#00E0FF", // Brighter than bottombar
            "pause": "#00E0FF",
            "next": "#7D9EC0",
            "left": "#4DA6FF",
            "right": "#4DA6FF",
            "shuffle": "#FF5E94",
            "toggleShade": "#192433"
        },
        "mainmenu": {
            "mediaContainer": "#004080" // Darker blue for container
        },
        "obd": {
            "boxBackground": "#151C29",
            "barColor": "#FF8C42" // Orange matches OBD button
        }
    },

    "TechnoRetro": {
        "base": "#1E1014",
        "baseAlt": "#2A1B22",
        "accent": "#FF00AA",
        "text": {
            "primary": "#F5E0FF",
            "secondary": "#CAA0D4"
        },
        "states": {
            "hover": "#3D2A33",
            "paused": "#33222B",
            "playing": "#482F3A"
        },
        "sliders": {
            "volume": "#FF00AA", // Hot pink for volume
            "media": "#00FFCC",  // Teal for media (contrasting)
            "settings": "#D436FF" // Purple for settings
        },
        "bottombar": {
            "previous": "#B347B9", // Muted purple
            "play": "#FF00AA",    // Hot pink for emphasis
            "pause": "#FF00AA",   // Match play
            "next": "#B347B9",    // Match previous
            "volume": "#D436FF",  // Purple accent
            "shuffle": "#00FFCC", // Teal for distinction
            "toggleShade": "#3D2A33",
            "homeButton": "#FF47B9", // Lighter pink
            "obdButton": "#FFDD00",  // Yellow for OBD
            "mediaButton": "#00FFCC", // Teal for media
            "settingsButton": "#D436FF", // Match settings slider
            "androidAutoButton": "#D436FF",
            "phoneMirrorButton": "#D436FF"
        },
        "mediaroom": {
            "previous": "#B347B9",
            "play": "#FF47B9", // Lighter play button in media room
            "pause": "#FF47B9",
            "next": "#B347B9",
            "left": "#E566FF", // Light purple
            "right": "#E566FF",
            "shuffle": "#00FFCC",
            "toggleShade": "#33222B"
        },
        "mainmenu": {
            "mediaContainer": "#990066" // Darker pink for container
        },
        "obd": {
            "boxBackground": "#2A1B22",
            "barColor": "#FFDD00" // Yellow matches OBD button
        }
    },

    "AutumnCascade": {
        "base": "#2D1E12",
        "baseAlt": "#3E2918",
        "accent": "#E67E22",
        "text": {
            "primary": "#FDF2E9",
            "secondary": "#D5BBA8"
        },
        "states": {
            "hover": "#4E3923",
            "paused": "#44321E",
            "playing": "#5A4329"
        },
        "sliders": {
            "volume": "#E67E22", // Orange for volume
            "media": "#8D6E63",  // Woody brown for media
            "settings": "#F5B041" // Golden for settings
        },
        "bottombar": {
            "previous": "#BA6B40", // Rusty orange
            "play": "#FF9F45",    // Brighter orange for play
            "pause": "#FF9F45",   // Match play
            "next": "#BA6B40",    // Match previous
            "volume": "#E67E22",  // Match accent
            "shuffle": "#5D4037", // Dark brown for shuffle
            "toggleShade": "#4E3923",
            "homeButton": "#F5B041", // Golden
            "obdButton": "#A04000",  // Deep rust for OBD
            "mediaButton": "#D35400", // Burnt orange for media
            "settingsButton": "#F39C12", // Match settings slider
            "androidAutoButton": "#F39C12",
            "phoneMirrorButton": "#F39C12"
        },
        "mediaroom": {
            "previous": "#BA6B40", 
            "play": "#FFA44F", // Even brighter in media room
            "pause": "#FFA44F",
            "next": "#BA6B40",
            "left": "#CD853F", // Lighter brown
            "right": "#CD853F",
            "shuffle": "#5D4037",
            "toggleShade": "#44321E"
        },
        "mainmenu": {
            "mediaContainer": "#7E5109" // Deep amber for container
        },
        "obd": {
            "boxBackground": "#3E2918",
            "barColor": "#A04000" // Match OBD button
        }
    },

    "VividGradient": {
        "base": "#12001A",
        "baseAlt": "#1D0029",
        "accent": "#C837AB",
        "text": {
            "primary": "#FCEFF8",
            "secondary": "#E0B0D5"
        },
        "states": {
            "hover": "#33004D",
            "paused": "#2B0042",
            "playing": "#390059"
        },
        "sliders": {
            "volume": "#C837AB", // Magenta volume
            "media": "#00B2EE",  // Blue for media (contrast)
            "settings": "#7D3C98" // Purple for settings
        },
        "bottombar": {
            "previous": "#8E44AD", // Deep purple for nav
            "play": "#C837AB",    // Match accent for play
            "pause": "#C837AB",   // Match play
            "next": "#8E44AD",    // Match previous
            "volume": "#7D3C98",  // Softer purple for volume
            "shuffle": "#3498DB", // Blue for shuffle
            "toggleShade": "#33004D",
            "homeButton": "#9B59B6", // Lavender for home
            "obdButton": "#F39C12",  // Gold for OBD contrast
            "mediaButton": "#00B2EE", // Blue for media
            "settingsButton": "#7D3C98", // Match settings slider
            "androidAutoButton": "#7D3C98",
            "phoneMirrorButton": "#7D3C98"
        },
        "mediaroom": {
            "previous": "#8E44AD",
            "play": "#D94DBE", // Brighter magenta
            "pause": "#D94DBE",
            "next": "#8E44AD",
            "left": "#9B59B6", // Lavender
            "right": "#9B59B6",
            "shuffle": "#3498DB", // Blue
            "toggleShade": "#2B0042"
        },
        "mainmenu": {
            "mediaContainer": "#6C0A94" // Deep magenta container
        },
        "obd": {
            "boxBackground": "#1D0029",
            "barColor": "#F39C12" // Gold matches OBD button
        }
    },

    "DesertOasis": {
        "base": "#201007",
        "baseAlt": "#30180B",
        "accent": "#D2B48C", // Tan accent
        "text": {
            "primary": "#F9F0E3",
            "secondary": "#D4C3AD"
        },
        "states": {
            "hover": "#412B1A",
            "paused": "#372415",
            "playing": "#4B321E"
        },
        "sliders": {
            "volume": "#D2B48C", // Tan for volume
            "media": "#5B8A72",  // Sage for media (oasis)
            "settings": "#B1866A" // Sandstone for settings
        },
        "bottombar": {
            "previous": "#8B4513", // Brown for previous
            "play": "#D2B48C",    // Tan for play
            "pause": "#D2B48C",   // Match play
            "next": "#8B4513",    // Match previous
            "volume": "#B1866A",  // Sandstone for volume
            "shuffle": "#5B8A72", // Sage for shuffle
            "toggleShade": "#412B1A",
            "homeButton": "#D2691E", // Chocolate for home
            "obdButton": "#CD853F",  // Peru for OBD
            "mediaButton": "#5B8A72", // Sage for media
            "settingsButton": "#B1866A", // Match settings slider
            "androidAutoButton": "#B1866A",
            "phoneMirrorButton": "#B1866A"
        },
        "mediaroom": {
            "previous": "#8B4513",
            "play": "#E0C9A6", // Lighter tan
            "pause": "#E0C9A6",
            "next": "#8B4513",
            "left": "#A0522D", // Sienna
            "right": "#A0522D",
            "shuffle": "#5B8A72", // Sage
            "toggleShade": "#372415"
        },
        "mainmenu": {
            "mediaContainer": "#65402A" // Dark brown container
        },
        "obd": {
            "boxBackground": "#30180B",
            "barColor": "#CD853F" // Match OBD button
        }
    },

    "QuantumNebula": {
        "base": "#0F0F1A",
        "baseAlt": "#17172A",
        "accent": "#9C27B0", // Purple accent
        "text": {
            "primary": "#F0E6FF",
            "secondary": "#B5A4D4"
        },
        "states": {
            "hover": "#24243F",
            "paused": "#1F1F37",
            "playing": "#2D2D4A"
        },
        "sliders": {
            "volume": "#9C27B0", // Purple for volume
            "media": "#00BCD4",  // Cyan for media
            "settings": "#673AB7" // Deeper purple for settings
        },
        "bottombar": {
            "previous": "#4A148C", // Dark purple for previous
            "play": "#9C27B0",    // Purple for play
            "pause": "#9C27B0",   // Match play
            "next": "#4A148C",    // Match previous
            "volume": "#673AB7",  // Violet for volume
            "shuffle": "#00BCD4", // Cyan for shuffle
            "toggleShade": "#24243F",
            "homeButton": "#7B1FA2", // Medium purple for home
            "obdButton": "#00E5FF",  // Bright cyan for OBD
            "mediaButton": "#00BCD4", // Regular cyan for media
            "settingsButton": "#673AB7", // Match settings slider
            "androidAutoButton": "#673AB7",
            "phoneMirrorButton": "#673AB7"
        },
        "mediaroom": {
            "previous": "#4A148C",
            "play": "#BA68C8", // Lighter purple 
            "pause": "#BA68C8",
            "next": "#4A148C",
            "left": "#7C4DFF", // Indigo variant
            "right": "#7C4DFF",
            "shuffle": "#00BCD4", // Cyan
            "toggleShade": "#1F1F37"
        },
        "mainmenu": {
            "mediaContainer": "#4A0072" // Deep purple container
        },
        "obd": {
            "boxBackground": "#17172A",
            "barColor": "#00E5FF" // Match OBD button
        }
    },

    // Album Art Capture - Default placeholder (dynamically updated)
    "Album Art Capture": {
        "base": "#1a1a2e",
        "baseAlt": "#16213e",
        "accent": "#e94560",
        "text": {
            "primary": "#f0f0f0",
            "secondary": "#b4b4b4"
        },
        "states": {
            "hover": "#2a2a4e",
            "paused": "#252545",
            "playing": "#303060"
        },
        "sliders": {
            "volume": "#e94560",
            "media": "#0f3460",
            "settings": "#e94560"
        },
        "bottombar": {
            "previous": "#e94560",
            "play": "#e94560",
            "pause": "#e94560",
            "next": "#e94560",
            "volume": "#e94560",
            "shuffle": "#e94560",
            "toggleShade": "#2a2a4e",
            "homeButton": "#e94560",
            "obdButton": "#e94560",
            "mediaButton": "#e94560",
            "settingsButton": "#e94560",
            "androidAutoButton": "#e94560",
            "phoneMirrorButton": "#e94560"
        },
        "mediaroom": {
            "previous": "#d43850",
            "play": "#e94560",
            "pause": "#e94560",
            "next": "#d43850",
            "left": "#c93048",
            "right": "#c93048",
            "shuffle": "#0f3460",
            "toggleShade": "#252545"
        },
        "mainmenu": {
            "mediaContainer": "#8c2a3a"
        },
        "obd": {
            "boxBackground": "#16213e",
            "barColor": "#e94560"
        }
    }
    })

    // Reactive current theme object - this is what all color bindings should use
    // It updates whenever currentTheme changes OR when album art colors are extracted
    property var activeTheme: {
        // If Album Art Capture is active and we have dynamic colors, use them
        if (currentTheme === "Album Art Capture" && albumArtTheme) {
            return albumArtTheme
        }
        // Check if theme is a custom theme first
        if (customThemes[currentTheme]) {
            return customThemes[currentTheme]
        }
        // Fall back to built-in themes
        return themes[currentTheme] || themes["SolarizedLight"]
    }

    // Helper function for backward compatibility
    function getCurrentTheme() {
        return activeTheme
    }

    // Function to update the Album Art Capture theme with new colors
    function updateAlbumArtTheme(themeJson) {
        console.log("[AlbumArtCapture QML] updateAlbumArtTheme called")
        try {
            let newTheme = JSON.parse(themeJson)
            console.log("[AlbumArtCapture QML] Parsed theme, base color:", newTheme.base, "accent:", newTheme.accent)

            // Store the new theme - this should trigger activeTheme to re-evaluate
            albumArtTheme = newTheme

            // If Album Art Capture is currently active, trigger a visual refresh
            if (currentTheme === "Album Art Capture") {
                console.log("[AlbumArtCapture QML] Theme is active, forcing refresh...")

                // Force activeTheme binding to re-evaluate by toggling currentTheme
                let savedTheme = currentTheme
                currentTheme = ""
                currentTheme = savedTheme

                // Emit signal for any listeners
                albumArtThemeUpdated()

                console.log("[AlbumArtCapture QML] UI refresh complete")
            }
        } catch (e) {
            console.log("[AlbumArtCapture QML] Error parsing album art theme:", e)
        }
    }

    // Signal emitted when album art theme colors are updated
    signal albumArtThemeUpdated()
    
    // Function to add a custom theme
    function addCustomTheme(name, themeObject) {
        customThemes[name] = themeObject
        // Emit a signal that themes have changed
        customThemesUpdated()
    }
    
    // Function to get all theme names (built-in + custom)
    function getAllThemeNames() {
        let allNames = Object.keys(themes)
        allNames = allNames.concat(Object.keys(customThemes))
        return allNames
    }

    // Transition duration for smooth color shifts (e.g. album art theme changes)
    property int colorTransitionMs: 1000

    property color bottomBarGradientStart: activeTheme.base
    Behavior on bottomBarGradientStart { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarGradientEnd: activeTheme.baseAlt
    Behavior on bottomBarGradientEnd { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarToggleShade: activeTheme.bottombar.toggleShade
    Behavior on bottomBarToggleShade { ColorAnimation { duration: colorTransitionMs } }
    property color hoverColor: activeTheme.states.hover
    Behavior on hoverColor { ColorAnimation { duration: colorTransitionMs } }
    property color hoverPausedColor: activeTheme.states.paused
    Behavior on hoverPausedColor { ColorAnimation { duration: colorTransitionMs } }
    property color hoverPlayingColor: activeTheme.states.paused
    Behavior on hoverPlayingColor { ColorAnimation { duration: colorTransitionMs } }
    property color pausedHighlightColor: activeTheme.states.paused
    Behavior on pausedHighlightColor { ColorAnimation { duration: colorTransitionMs } }
    property color playingHighlightColor: activeTheme.states.playing
    Behavior on playingHighlightColor { ColorAnimation { duration: colorTransitionMs } }
    property color rowBackgroundColor: activeTheme.base
    Behavior on rowBackgroundColor { ColorAnimation { duration: colorTransitionMs } }
    property color backgroundColor: activeTheme.base
    Behavior on backgroundColor { ColorAnimation { duration: colorTransitionMs } }
    property color headerBackgroundColor: activeTheme.baseAlt
    Behavior on headerBackgroundColor { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomToggleShade: activeTheme.mediaroom.toggleShade
    Behavior on mediaRoomToggleShade { ColorAnimation { duration: colorTransitionMs } }
    property color mediaContentArea: activeTheme.mainmenu.mediaContainer
    Behavior on mediaContentArea { ColorAnimation { duration: colorTransitionMs } }
    property color obdBoxBackground: activeTheme.obd.boxBackground
    Behavior on obdBoxBackground { ColorAnimation { duration: colorTransitionMs } }
    property color sidebarColor: activeTheme.base
    Behavior on sidebarColor { ColorAnimation { duration: colorTransitionMs } }
    property color contentColor: activeTheme.baseAlt
    Behavior on contentColor { ColorAnimation { duration: colorTransitionMs } }

    property color primaryTextColor: activeTheme.text.primary
    Behavior on primaryTextColor { ColorAnimation { duration: colorTransitionMs } }
    property color secondaryTextColor: activeTheme.text.secondary
    Behavior on secondaryTextColor { ColorAnimation { duration: colorTransitionMs } }
    property color headerTextColor: activeTheme.text.primary
    Behavior on headerTextColor { ColorAnimation { duration: colorTransitionMs } }
    property color clockTextColor: activeTheme.accent
    Behavior on clockTextColor { ColorAnimation { duration: colorTransitionMs } }
    property color metadataColor: activeTheme.accent
    Behavior on metadataColor { ColorAnimation { duration: colorTransitionMs } }
    property color obdLabelColor: activeTheme.obd.labelColor ? activeTheme.obd.labelColor : secondaryTextColor
    Behavior on obdLabelColor { ColorAnimation { duration: colorTransitionMs } }
    property color obdValueColor: activeTheme.obd.valueColor ? activeTheme.obd.valueColor : primaryTextColor
    Behavior on obdValueColor { ColorAnimation { duration: colorTransitionMs } }

    property color accent: activeTheme.accent
    Behavior on accent { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarActiveToggleButton: activeTheme.accent
    Behavior on bottomBarActiveToggleButton { ColorAnimation { duration: colorTransitionMs } }

    // Bottom bar button icon colors
    property color bottomBarPreviousButton: activeTheme.bottombar.previous
    Behavior on bottomBarPreviousButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarPlayButton: activeTheme.bottombar.play
    Behavior on bottomBarPlayButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarPauseButton: activeTheme.bottombar.pause
    Behavior on bottomBarPauseButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarNextButton: activeTheme.bottombar.next
    Behavior on bottomBarNextButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarVolumeButton: activeTheme.bottombar.volume
    Behavior on bottomBarVolumeButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarShuffleButton: activeTheme.bottombar.shuffle
    Behavior on bottomBarShuffleButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarHomeButton: activeTheme.bottombar.homeButton
    Behavior on bottomBarHomeButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarOBDButton: activeTheme.bottombar.obdButton
    Behavior on bottomBarOBDButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarMediaButton: activeTheme.bottombar.mediaButton
    Behavior on bottomBarMediaButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarSettingsButton: activeTheme.bottombar.settingsButton
    Behavior on bottomBarSettingsButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarAndroidAutoButton: activeTheme.bottombar.androidAutoButton
    Behavior on bottomBarAndroidAutoButton { ColorAnimation { duration: colorTransitionMs } }
    property color bottomBarPhoneMirrorButton: activeTheme.bottombar.phoneMirrorButton
    Behavior on bottomBarPhoneMirrorButton { ColorAnimation { duration: colorTransitionMs } }

    // MediaRoom button icon colors
    property color mediaRoomPreviousButton: activeTheme.mediaroom.previous
    Behavior on mediaRoomPreviousButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomPlayButton: activeTheme.mediaroom.play
    Behavior on mediaRoomPlayButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomPauseButton: activeTheme.mediaroom.pause
    Behavior on mediaRoomPauseButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomNextButton: activeTheme.mediaroom.next
    Behavior on mediaRoomNextButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomLeftButton: activeTheme.mediaroom.left
    Behavior on mediaRoomLeftButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomRightButton: activeTheme.mediaroom.right
    Behavior on mediaRoomRightButton { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomToggleButton: activeTheme.mediaroom.shuffle
    Behavior on mediaRoomToggleButton { ColorAnimation { duration: colorTransitionMs } }

    // Slider colors
    property color volumeSliderColor: activeTheme.sliders.volume
    Behavior on volumeSliderColor { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomSlider: activeTheme.sliders.media
    Behavior on mediaRoomSlider { ColorAnimation { duration: colorTransitionMs } }
    property color mediaRoomSeekColor: activeTheme.sliders.volume
    Behavior on mediaRoomSeekColor { ColorAnimation { duration: colorTransitionMs } }
    property color settingsSliderColor: activeTheme.sliders.settings
    Behavior on settingsSliderColor { ColorAnimation { duration: colorTransitionMs } }
    property color obdBarColor: activeTheme.obd.barColor
    Behavior on obdBarColor { ColorAnimation { duration: colorTransitionMs } }

    // Status colors (with safe fallbacks for themes that don't define them)
    property color statusConnected: activeTheme.status ? activeTheme.status.connected : "#44AA44"
    Behavior on statusConnected { ColorAnimation { duration: colorTransitionMs } }
    property color statusDisconnected: activeTheme.status ? activeTheme.status.disconnected : "#AA4444"
    Behavior on statusDisconnected { ColorAnimation { duration: colorTransitionMs } }
    property color statusError: activeTheme.status ? activeTheme.status.error : "#F44336"
    Behavior on statusError { ColorAnimation { duration: colorTransitionMs } }
    property color statusWarning: activeTheme.status ? activeTheme.status.warning : "#FF9800"
    Behavior on statusWarning { ColorAnimation { duration: colorTransitionMs } }
    property color statusInfo: activeTheme.status ? activeTheme.status.info : "#2196F3"
    Behavior on statusInfo { ColorAnimation { duration: colorTransitionMs } }
    property color statusSuccess: activeTheme.status ? activeTheme.status.success : "#4CAF50"
    Behavior on statusSuccess { ColorAnimation { duration: colorTransitionMs } }
    property color statusDanger: activeTheme.status ? activeTheme.status.danger : "#e74c3c"
    Behavior on statusDanger { ColorAnimation { duration: colorTransitionMs } }

    // Function to update theme
    function setTheme(theme) {
        if (themes[theme] || customThemes[theme]) {
            currentTheme = theme
        }
    }
    
    // Changed signal name to avoid conflict
    signal customThemesUpdated()
}