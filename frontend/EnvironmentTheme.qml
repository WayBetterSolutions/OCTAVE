// EnvironmentTheme.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    property string currentEnvironment: "Standard"

    // Signal when environment changes
    signal environmentChanged()

    // Define environment presets
    readonly property var environments: ({
        "Standard": {
            // Card
            cardRadius: 12,
            cornerBrackets: false,
            accentBorder: false,
            accentBorderOpacity: 0,

            // Divider
            dividerAnimated: false,
            dividerGradient: false,
            dividerHeight: 1,

            // Button
            buttonRadius: 6,
            buttonGlowBorder: false,
            buttonSolidFill: true,

            // Slider
            sliderTickMarks: false,
            sliderHandleGlow: false,
            sliderHandleRadius: -1,

            // Switch
            switchRadius: 13,
            switchKnobRadius: 10,

            // Toggle
            toggleTrackRadius: -1,
            toggleHandleRadius: -1,
            toggleRectShadow: false,

            // Labels & Text
            labelUppercase: false,
            labelLetterSpacing: 0,

            // Value Display
            valueDisplayBrackets: false,
            valueAccentColor: false,

            // Sidebar / Nav
            sidebarGrid: false,
            navItemRadius: 8,
            navAccentBarWidth: 3,
            navAccentBarFullHeight: false,

            // Chips
            chipRadius: -1,
            chipAccentBorder: false,

            // Section Header
            sectionHeaderLines: false,

            // TextField
            textFieldRadius: 4,
            textFieldCornerMarks: false,

            // Dropdown
            dropdownRadius: 4,

            // Checkbox
            checkboxRadius: 4,

            // Segmented Control
            segmentGlowBar: false,

            // Radio
            radioSquare: false,

            // Terminal
            terminalRadius: 4,
            terminalAccentBorder: false,
            terminalCornerBrackets: false,
            terminalScanlines: false,
            terminalHeaderAccent: false,
            terminalAccentScroll: false,

            // Enhanced effects
            scanlineOverlay: false,
            pulsingElements: false,
            contentHudLines: false,
            dividerDiamondRotate: false
        },

        "Spacecraft": {
            // Card
            cardRadius: 2,
            cornerBrackets: true,
            accentBorder: true,
            accentBorderOpacity: 0.3,

            // Divider
            dividerAnimated: true,
            dividerGradient: true,
            dividerHeight: 2,

            // Button
            buttonRadius: 2,
            buttonGlowBorder: true,
            buttonSolidFill: false,

            // Slider
            sliderTickMarks: true,
            sliderHandleGlow: true,
            sliderHandleRadius: 4,

            // Switch
            switchRadius: 4,
            switchKnobRadius: 4,

            // Toggle
            toggleTrackRadius: 6,
            toggleHandleRadius: 8,
            toggleRectShadow: true,

            // Labels & Text
            labelUppercase: true,
            labelLetterSpacing: 1,

            // Value Display
            valueDisplayBrackets: true,
            valueAccentColor: true,

            // Sidebar / Nav
            sidebarGrid: true,
            navItemRadius: 2,
            navAccentBarWidth: 2,
            navAccentBarFullHeight: true,

            // Chips
            chipRadius: 4,
            chipAccentBorder: true,

            // Section Header
            sectionHeaderLines: true,

            // TextField
            textFieldRadius: 2,
            textFieldCornerMarks: true,

            // Dropdown
            dropdownRadius: 2,

            // Checkbox
            checkboxRadius: 1,

            // Segmented Control
            segmentGlowBar: true,

            // Radio
            radioSquare: true,

            // Terminal
            terminalRadius: 2,
            terminalAccentBorder: true,
            terminalCornerBrackets: true,
            terminalScanlines: true,
            terminalHeaderAccent: true,
            terminalAccentScroll: true,

            // Enhanced effects
            scanlineOverlay: true,
            pulsingElements: true,
            contentHudLines: true,
            dividerDiamondRotate: true
        }
    })

    // Active environment object - bindings re-evaluate when currentEnvironment changes
    property var active: environments[currentEnvironment] || environments["Standard"]

    // Set the environment
    function setEnvironment(name) {
        if (environments[name]) {
            currentEnvironment = name
            environmentChanged()
        }
    }

    // Get all available environment names
    function getAllEnvironmentNames() {
        return Object.keys(environments)
    }
}
