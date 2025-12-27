// Style.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    property string currentTheme: "SolarizedLight"
    
    // This will store our custom themes that are loaded from settings
    property var customThemes: ({})

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
                "settingsButton": "#268BD2"
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

        "MidnightAurora": {
            "base": "#0F1123",
            "baseAlt": "#1A1C3A",
            "accent": "#7B68EE",
            "text": {
                "primary": "#E0E0FF",
                "secondary": "#A0A0C5"
            },
            "states": {
                "hover": "#282A4A",
                "paused": "#232440",
                "playing": "#2D2E54"
            },
            "sliders": {
                "volume": "#7B68EE",
                "media": "#A0A0C5",
                "settings": "#7B68EE"
            },
            "bottombar": {
                "previous": "#7B68EE",
                "play": "#7B68EE",
                "pause": "#7B68EE",
                "next": "#7B68EE",
                "volume": "#7B68EE",
                "shuffle": "#7B68EE",
                "toggleShade": "#282A4A",
                "homeButton": "#7B68EE",
                "obdButton": "#7B68EE",
                "mediaButton": "#7B68EE",
                "settingsButton": "#7B68EE"
            },
            "mediaroom": {
                "previous": "#9F91F1",
                "play": "#9F91F1",
                "pause": "#9F91F1",
                "next": "#9F91F1",
                "left": "#9F91F1",
                "right": "#9F91F1",
                "shuffle": "#9F91F1",
                "toggleShade": "#232440"
            },
            "mainmenu": {
                "mediaContainer": "#413786"
            },
            "obd": {
                "boxBackground": "#1A1C3A",
                "barColor": "#9F91F1"
            }
        },

        "DesertSunset": {
            "base": "#2A1B0F",
            "baseAlt": "#3C2915",
            "accent": "#FF7F50",
            "text": {
                "primary": "#FFF0E0",
                "secondary": "#D5BCA7"
            },
            "states": {
                "hover": "#4E3824",
                "paused": "#45321F",
                "playing": "#5A4330"
            },
            "sliders": {
                "volume": "#FF7F50",
                "media": "#D5BCA7",
                "settings": "#FF7F50"
            },
            "bottombar": {
                "previous": "#FF7F50",
                "play": "#FF7F50",
                "pause": "#FF7F50",
                "next": "#FF7F50",
                "volume": "#FF7F50",
                "shuffle": "#FF7F50",
                "toggleShade": "#4E3824",
                "homeButton": "#FF7F50",
                "obdButton": "#FF7F50",
                "mediaButton": "#FF7F50",
                "settingsButton": "#FF7F50"
            },
            "mediaroom": {
                "previous": "#FFA07A",
                "play": "#FFA07A",
                "pause": "#FFA07A",
                "next": "#FFA07A",
                "left": "#FFA07A",
                "right": "#FFA07A",
                "shuffle": "#FFA07A",
                "toggleShade": "#45321F"
            },
            "mainmenu": {
                "mediaContainer": "#8B4513"
            },
            "obd": {
                "boxBackground": "#3C2915",
                "barColor": "#FFA07A"
            }
        },

        "ForestCanopy": {
            "base": "#0A220A",
            "baseAlt": "#153415",
            "accent": "#66CD00",
            "text": {
                "primary": "#E0FFE0",
                "secondary": "#A8C9A8"
            },
            "states": {
                "hover": "#224422",
                "paused": "#1D3A1D",
                "playing": "#2B4F2B"
            },
            "sliders": {
                "volume": "#66CD00",
                "media": "#A8C9A8",
                "settings": "#66CD00"
            },
            "bottombar": {
                "previous": "#66CD00",
                "play": "#66CD00",
                "pause": "#66CD00",
                "next": "#66CD00",
                "volume": "#66CD00",
                "shuffle": "#66CD00",
                "toggleShade": "#224422",
                "homeButton": "#66CD00",
                "obdButton": "#66CD00",
                "mediaButton": "#66CD00",
                "settingsButton": "#66CD00"
            },
            "mediaroom": {
                "previous": "#7CCD7C",
                "play": "#7CCD7C",
                "pause": "#7CCD7C",
                "next": "#7CCD7C",
                "left": "#7CCD7C",
                "right": "#7CCD7C",
                "shuffle": "#7CCD7C",
                "toggleShade": "#1D3A1D"
            },
            "mainmenu": {
                "mediaContainer": "#228B22"
            },
            "obd": {
                "boxBackground": "#153415",
                "barColor": "#7CCD7C"
            }
        },

        "OceanDepth": {
            "base": "#0A1F33",
            "baseAlt": "#152E45",
            "accent": "#00BFFF",
            "text": {
                "primary": "#E0F5FF",
                "secondary": "#A7C4DB"
            },
            "states": {
                "hover": "#203D58",
                "paused": "#1B3650",
                "playing": "#254666"
            },
            "sliders": {
                "volume": "#00BFFF",
                "media": "#A7C4DB",
                "settings": "#00BFFF"
            },
            "bottombar": {
                "previous": "#00BFFF",
                "play": "#00BFFF",
                "pause": "#00BFFF",
                "next": "#00BFFF",
                "volume": "#00BFFF",
                "shuffle": "#00BFFF",
                "toggleShade": "#203D58",
                "homeButton": "#00BFFF",
                "obdButton": "#00BFFF",
                "mediaButton": "#00BFFF",
                "settingsButton": "#00BFFF"
            },
            "mediaroom": {
                "previous": "#4DC4FF",
                "play": "#4DC4FF",
                "pause": "#4DC4FF",
                "next": "#4DC4FF",
                "left": "#4DC4FF",
                "right": "#4DC4FF",
                "shuffle": "#4DC4FF",
                "toggleShade": "#1B3650"
            },
            "mainmenu": {
                "mediaContainer": "#005F87"
            },
            "obd": {
                "boxBackground": "#152E45",
                "barColor": "#4DC4FF"
            }
        },

        "CherryBlossom": {
            "base": "#FFF0F5",
            "baseAlt": "#FFE4E9",
            "accent": "#FF69B4",
            "text": {
                "primary": "#4A2C38",
                "secondary": "#7A5965"
            },
            "states": {
                "hover": "#FFD9DF",
                "paused": "#FFCCD6",
                "playing": "#FFBFCE"
            },
            "sliders": {
                "volume": "#FF69B4",
                "media": "#7A5965",
                "settings": "#FF69B4"
            },
            "bottombar": {
                "previous": "#FF69B4",
                "play": "#FF69B4",
                "pause": "#FF69B4",
                "next": "#FF69B4",
                "volume": "#FF69B4",
                "shuffle": "#FF69B4",
                "toggleShade": "#FFD9DF",
                "homeButton": "#FF69B4",
                "obdButton": "#FF69B4",
                "mediaButton": "#FF69B4",
                "settingsButton": "#FF69B4"
            },
            "mediaroom": {
                "previous": "#FF85C2",
                "play": "#FF85C2",
                "pause": "#FF85C2",
                "next": "#FF85C2",
                "left": "#FF85C2",
                "right": "#FF85C2",
                "shuffle": "#FF85C2",
                "toggleShade": "#FFCCD6"
            },
            "mainmenu": {
                "mediaContainer": "#DB7093"
            },
            "obd": {
                "boxBackground": "#FFE4E9",
                "barColor": "#FF85C2"
            }
        },

        "AmberGlow": {
            "base": "#211100",
            "baseAlt": "#3A2000",
            "accent": "#FF9500",
            "text": {
                "primary": "#FFE0B2",
                "secondary": "#D0B084"
            },
            "states": {
                "hover": "#4D2D00",
                "paused": "#452700",
                "playing": "#5A3400"
            },
            "sliders": {
                "volume": "#FF9500",
                "media": "#D0B084",
                "settings": "#FF9500"
            },
            "bottombar": {
                "previous": "#FF9500",
                "play": "#FF9500",
                "pause": "#FF9500",
                "next": "#FF9500",
                "volume": "#FF9500",
                "shuffle": "#FF9500",
                "toggleShade": "#4D2D00",
                "homeButton": "#FF9500",
                "obdButton": "#FF9500",
                "mediaButton": "#FF9500",
                "settingsButton": "#FF9500"
            },
            "mediaroom": {
                "previous": "#FFB74D",
                "play": "#FFB74D",
                "pause": "#FFB74D",
                "next": "#FFB74D",
                "left": "#FFB74D",
                "right": "#FFB74D",
                "shuffle": "#FFB74D",
                "toggleShade": "#452700"
            },
            "mainmenu": {
                "mediaContainer": "#8A5000"
            },
            "obd": {
                "boxBackground": "#3A2000",
                "barColor": "#FFB74D"
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
                "settingsButton": "#00FF41"
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
        "LavenderDream": {
            "base": "#F5F0FF",
            "baseAlt": "#EEE4FF",
            "accent": "#9370DB",
            "text": {
                "primary": "#3A2C4A",
                "secondary": "#6A5A7A"
            },
            "states": {
                "hover": "#E6D9FF",
                "paused": "#DDCCFF",
                "playing": "#D4BFFF"
            },
            "sliders": {
                "volume": "#9370DB",
                "media": "#6A5A7A",
                "settings": "#9370DB"
            },
            "bottombar": {
                "previous": "#9370DB",
                "play": "#9370DB",
                "pause": "#9370DB",
                "next": "#9370DB",
                "volume": "#9370DB",
                "shuffle": "#9370DB",
                "toggleShade": "#E6D9FF",
                "homeButton": "#9370DB",
                "obdButton": "#9370DB",
                "mediaButton": "#9370DB",
                "settingsButton": "#9370DB"
            },
            "mediaroom": {
                "previous": "#AB8EE6",
                "play": "#AB8EE6",
                "pause": "#AB8EE6",
                "next": "#AB8EE6",
                "left": "#AB8EE6",
                "right": "#AB8EE6",
                "shuffle": "#AB8EE6",
                "toggleShade": "#DDCCFF"
            },
            "mainmenu": {
                "mediaContainer": "#7B68EE"
            },
            "obd": {
                "boxBackground": "#EEE4FF",
                "barColor": "#AB8EE6"
            }
        },

        "MintFrost": {
            "base": "#F0FFF5",
            "baseAlt": "#E4FFED",
            "accent": "#40E0B0",
            "text": {
                "primary": "#2C4A3A",
                "secondary": "#5A7A6A"
            },
            "states": {
                "hover": "#D9FFE6",
                "paused": "#CCFFDD",
                "playing": "#BFFFD4"
            },
            "sliders": {
                "volume": "#40E0B0",
                "media": "#5A7A6A",
                "settings": "#40E0B0"
            },
            "bottombar": {
                "previous": "#40E0B0",
                "play": "#40E0B0",
                "pause": "#40E0B0",
                "next": "#40E0B0",
                "volume": "#40E0B0",
                "shuffle": "#40E0B0",
                "toggleShade": "#D9FFE6",
                "homeButton": "#40E0B0",
                "obdButton": "#40E0B0",
                "mediaButton": "#40E0B0",
                "settingsButton": "#40E0B0"
            },
            "mediaroom": {
                "previous": "#66E9C2",
                "play": "#66E9C2",
                "pause": "#66E9C2",
                "next": "#66E9C2",
                "left": "#66E9C2",
                "right": "#66E9C2",
                "shuffle": "#66E9C2",
                "toggleShade": "#CCFFDD"
            },
            "mainmenu": {
                "mediaContainer": "#20B090"
            },
            "obd": {
                "boxBackground": "#E4FFED",
                "barColor": "#66E9C2"
            }
        },

        "PeachSorbet": {
            "base": "#FFF5F0",
            "baseAlt": "#FFEDE4",
            "accent": "#FFAA80",
            "text": {
                "primary": "#4A382C",
                "secondary": "#7A685A"
            },
            "states": {
                "hover": "#FFE6D9",
                "paused": "#FFDDCC",
                "playing": "#FFD4BF"
            },
            "sliders": {
                "volume": "#FFAA80",
                "media": "#7A685A",
                "settings": "#FFAA80"
            },
            "bottombar": {
                "previous": "#FFAA80",
                "play": "#FFAA80",
                "pause": "#FFAA80",
                "next": "#FFAA80",
                "volume": "#FFAA80",
                "shuffle": "#FFAA80",
                "toggleShade": "#FFE6D9",
                "homeButton": "#FFAA80",
                "obdButton": "#FFAA80",
                "mediaButton": "#FFAA80",
                "settingsButton": "#FFAA80"
            },
            "mediaroom": {
                "previous": "#FFBB99",
                "play": "#FFBB99",
                "pause": "#FFBB99",
                "next": "#FFBB99",
                "left": "#FFBB99",
                "right": "#FFBB99",
                "shuffle": "#FFBB99",
                "toggleShade": "#FFDDCC"
            },
            "mainmenu": {
                "mediaContainer": "#E67E50"
            },
            "obd": {
                "boxBackground": "#FFEDE4",
                "barColor": "#FFBB99"
            }
        },

        "BlueberryYogurt": {
            "base": "#F0F5FF",
            "baseAlt": "#E4EDFF",
            "accent": "#6495ED",
            "text": {
                "primary": "#2C3A4A",
                "secondary": "#5A687A"
            },
            "states": {
                "hover": "#D9E6FF",
                "paused": "#CCDDFF",
                "playing": "#BFD4FF"
            },
            "sliders": {
                "volume": "#6495ED",
                "media": "#5A687A",
                "settings": "#6495ED"
            },
            "bottombar": {
                "previous": "#6495ED",
                "play": "#6495ED",
                "pause": "#6495ED",
                "next": "#6495ED",
                "volume": "#6495ED",
                "shuffle": "#6495ED",
                "toggleShade": "#D9E6FF",
                "homeButton": "#6495ED",
                "obdButton": "#6495ED",
                "mediaButton": "#6495ED",
                "settingsButton": "#6495ED"
            },
            "mediaroom": {
                "previous": "#82A9F1",
                "play": "#82A9F1",
                "pause": "#82A9F1",
                "next": "#82A9F1",
                "left": "#82A9F1",
                "right": "#82A9F1",
                "shuffle": "#82A9F1",
                "toggleShade": "#CCDDFF"
            },
            "mainmenu": {
                "mediaContainer": "#4169E1"
            },
            "obd": {
                "boxBackground": "#E4EDFF",
                "barColor": "#82A9F1"
            }
        },

        "LilyPond": {
            "base": "#F0FFF9",
            "baseAlt": "#E4FFF2",
            "accent": "#4FD1C5",
            "text": {
                "primary": "#2C4A42",
                "secondary": "#5A7A72"
            },
            "states": {
                "hover": "#D9FFEE",
                "paused": "#CCFFE7",
                "playing": "#BFFFE0"
            },
            "sliders": {
                "volume": "#4FD1C5",
                "media": "#5A7A72",
                "settings": "#4FD1C5"
            },
            "bottombar": {
                "previous": "#4FD1C5",
                "play": "#4FD1C5",
                "pause": "#4FD1C5",
                "next": "#4FD1C5",
                "volume": "#4FD1C5",
                "shuffle": "#4FD1C5",
                "toggleShade": "#D9FFEE",
                "homeButton": "#4FD1C5",
                "obdButton": "#4FD1C5",
                "mediaButton": "#4FD1C5",
                "settingsButton": "#4FD1C5"
            },
            "mediaroom": {
                "previous": "#76DCD2",
                "play": "#76DCD2",
                "pause": "#76DCD2",
                "next": "#76DCD2",
                "left": "#76DCD2",
                "right": "#76DCD2",
                "shuffle": "#76DCD2",
                "toggleShade": "#CCFFE7"
            },
            "mainmenu": {
                "mediaContainer": "#319F94"
            },
            "obd": {
                "boxBackground": "#E4FFF2",
                "barColor": "#76DCD2"
            }
        },

        "RoseGold": {
            "base": "#FFF0F3",
            "baseAlt": "#FFE4E9",
            "accent": "#E6A59E",
            "text": {
                "primary": "#4A2D33",
                "secondary": "#7A5A60"
            },
            "states": {
                "hover": "#FFD9DF",
                "paused": "#FFCCD4",
                "playing": "#FFBFC9"
            },
            "sliders": {
                "volume": "#E6A59E",
                "media": "#7A5A60",
                "settings": "#E6A59E"
            },
            "bottombar": {
                "previous": "#E6A59E",
                "play": "#E6A59E",
                "pause": "#E6A59E",
                "next": "#E6A59E",
                "volume": "#E6A59E",
                "shuffle": "#E6A59E",
                "toggleShade": "#FFD9DF",
                "homeButton": "#E6A59E",
                "obdButton": "#E6A59E",
                "mediaButton": "#E6A59E",
                "settingsButton": "#E6A59E"
            },
            "mediaroom": {
                "previous": "#ECBAB4",
                "play": "#ECBAB4",
                "pause": "#ECBAB4",
                "next": "#ECBAB4",
                "left": "#ECBAB4",
                "right": "#ECBAB4",
                "shuffle": "#ECBAB4",
                "toggleShade": "#FFCCD4"
            },
            "mainmenu": {
                "mediaContainer": "#C17B74"
            },
            "obd": {
                "boxBackground": "#FFE4E9",
                "barColor": "#ECBAB4"
            }
        },

        "VanillaCream": {
            "base": "#FFFDF5",
            "baseAlt": "#FFF9E8",
            "accent": "#FFDC7D",
            "text": {
                "primary": "#4A442C",
                "secondary": "#7A745A"
            },
            "states": {
                "hover": "#FFF5D9",
                "paused": "#FFF0CC",
                "playing": "#FFEBBF"
            },
            "sliders": {
                "volume": "#FFDC7D",
                "media": "#7A745A",
                "settings": "#FFDC7D"
            },
            "bottombar": {
                "previous": "#FFDC7D",
                "play": "#FFDC7D",
                "pause": "#FFDC7D",
                "next": "#FFDC7D",
                "volume": "#FFDC7D",
                "shuffle": "#FFDC7D",
                "toggleShade": "#FFF5D9",
                "homeButton": "#FFDC7D",
                "obdButton": "#FFDC7D",
                "mediaButton": "#FFDC7D",
                "settingsButton": "#FFDC7D"
            },
            "mediaroom": {
                "previous": "#FFE499",
                "play": "#FFE499",
                "pause": "#FFE499",
                "next": "#FFE499",
                "left": "#FFE499",
                "right": "#FFE499",
                "shuffle": "#FFE499",
                "toggleShade": "#FFF0CC"
            },
            "mainmenu": {
                "mediaContainer": "#D4B44C"
            },
            "obd": {
                "boxBackground": "#FFF9E8",
                "barColor": "#FFE499"
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
            "settingsButton": "#7CB9E8" // Match settings slider
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
            "settingsButton": "#D436FF" // Match settings slider
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
            "settingsButton": "#F39C12" // Match settings slider
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
            "settingsButton": "#7D3C98" // Match settings slider
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

    "SeasonalQuartet": {
        "base": "#0D1C12",
        "baseAlt": "#15291B",
        "accent": "#4CAF50",
        "text": {
            "primary": "#F2F9F5",
            "secondary": "#B0D6BA"
        },
        "states": {
            "hover": "#1F3926",
            "paused": "#1A3320",
            "playing": "#25432D"
        },
        "sliders": {
            "volume": "#4CAF50", // Spring green for volume
            "media": "#FF9800",  // Autumn orange for media
            "settings": "#2196F3" // Winter blue for settings
        },
        "bottombar": {
            "previous": "#F44336", // Summer red for previous
            "play": "#4CAF50",    // Spring green for play
            "pause": "#4CAF50",   // Match play
            "next": "#F44336",    // Match previous
            "volume": "#4CAF50",  // Match accent
            "shuffle": "#FF9800", // Autumn orange for shuffle
            "toggleShade": "#1F3926",
            "homeButton": "#2196F3", // Winter blue for home
            "obdButton": "#E91E63",  // Pink for OBD
            "mediaButton": "#FF9800", // Autumn for media
            "settingsButton": "#2196F3" // Match settings slider
        },
        "mediaroom": {
            "previous": "#F44336", // Summer red
            "play": "#66BB6A", // Lighter green 
            "pause": "#66BB6A",
            "next": "#F44336",
            "left": "#FF5722", // Deep orange
            "right": "#FF5722",
            "shuffle": "#FF9800", // Autumn orange
            "toggleShade": "#1A3320"
        },
        "mainmenu": {
            "mediaContainer": "#2E7D32" // Dark green container
        },
        "obd": {
            "boxBackground": "#15291B",
            "barColor": "#E91E63" // Pink matches OBD button
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
            "settingsButton": "#B1866A" // Match settings slider
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
            "settingsButton": "#673AB7" // Match settings slider
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
    }
    })

    // Helper function to get current theme
    function getCurrentTheme() {
        // Check if theme is a custom theme first
        if (customThemes[currentTheme]) {
            return customThemes[currentTheme]
        }
        // Fall back to built-in themes
        return themes[currentTheme] || themes["Nightfall"]
    }
    
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

    // Color properties that reference the theme
    property color volumeSliderColor: getCurrentTheme().sliders.volume
    property color bottomBarGradientStart: getCurrentTheme().base
    property color bottomBarGradientEnd: getCurrentTheme().baseAlt
    property color clockTextColor: getCurrentTheme().accent
    property color bottomBarPreviousButton: getCurrentTheme().bottombar.previous
    property color bottomBarPlayButton: getCurrentTheme().bottombar.play
    property color bottomBarPauseButton: getCurrentTheme().bottombar.pause
    property color bottomBarNextButton: getCurrentTheme().bottombar.next
    property color bottomBarVolumeButton: getCurrentTheme().bottombar.volume
    property color bottomBarShuffleButton: getCurrentTheme().bottombar.shuffle
    property color bottomBarToggleShade: getCurrentTheme().bottombar.toggleShade
    property color bottomBarActiveToggleButton: getCurrentTheme().accent
    
    // New nav button colors
    property color bottomBarHomeButton: getCurrentTheme().bottombar.homeButton
    property color bottomBarOBDButton: getCurrentTheme().bottombar.obdButton
    property color bottomBarMediaButton: getCurrentTheme().bottombar.mediaButton
    property color bottomBarSettingsButton: getCurrentTheme().bottombar.settingsButton

    // MediaRoom
    property color metadataColor: getCurrentTheme().accent
    property color mediaRoomSlider: getCurrentTheme().sliders.media
    property color mediaRoomSeekColor: getCurrentTheme().sliders.volume
    property color mediaRoomPreviousButton: getCurrentTheme().mediaroom.previous
    property color mediaRoomPlayButton: getCurrentTheme().mediaroom.play
    property color mediaRoomPauseButton: getCurrentTheme().mediaroom.pause
    property color mediaRoomNextButton: getCurrentTheme().mediaroom.next
    property color mediaRoomLeftButton: getCurrentTheme().mediaroom.left
    property color mediaRoomRightButton: getCurrentTheme().mediaroom.right
    property color mediaRoomToggleButton: getCurrentTheme().mediaroom.shuffle
    property color mediaRoomToggleShade: getCurrentTheme().mediaroom.toggleShade

    // MediaPlayer
    property color accent: getCurrentTheme().accent
    property color primaryTextColor: getCurrentTheme().text.primary
    property color secondaryTextColor: getCurrentTheme().text.secondary
    property color hoverColor: getCurrentTheme().states.hover
    property color hoverPausedColor: getCurrentTheme().states.paused
    property color hoverPlayingColor: getCurrentTheme().states.paused
    property color pausedHighlightColor: getCurrentTheme().states.paused
    property color playingHighlightColor: getCurrentTheme().states.playing
    property color rowBackgroundColor: getCurrentTheme().base
    property color backgroundColor: getCurrentTheme().base
    property color headerBackgroundColor: getCurrentTheme().baseAlt
    property color headerTextColor: getCurrentTheme().text.primary

    // MainMenu
    property color mediaContentArea: getCurrentTheme().mainmenu.mediaContainer

    // OBD Page
    property color obdBoxBackground: getCurrentTheme().obd.boxBackground
    property color obdBarColor: getCurrentTheme().obd.barColor

    // Settings
    property color sidebarColor: getCurrentTheme().base
    property color contentColor: getCurrentTheme().baseAlt
    property color settingsSliderColor: getCurrentTheme().sliders.settings
    
    // Function to update theme
    function setTheme(theme) {
        if (themes[theme] || customThemes[theme]) {
            currentTheme = theme
            // Determine the correct theme object to get button colors
            let themeObj = themes[theme] || customThemes[theme]
            svgManager.update_svg_color(themeObj.bottombar.play)
        }
    }
    
    // Changed signal name to avoid conflict
    signal customThemesUpdated()
}