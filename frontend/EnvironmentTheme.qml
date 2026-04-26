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
            // Hub Card
            hubCardRadius: 12,

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
            switchRadius: 8,
            switchKnobRadius: 6,

            // Toggle
            toggleTrackRadius: 10,
            toggleHandleRadius: 8,
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
            chipRadius: 8,
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
            dividerDiamondRotate: false,

            // Deep Sea effects
            sidebarBubbles: false,
            contentSonar: false,
            dividerSonarPing: false,
            cardGlassEffect: false
        },

        "Spacecraft": {
            // Hub Card
            hubCardRadius: 2,

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
            dividerDiamondRotate: true,

            // Deep Sea effects
            sidebarBubbles: false,
            contentSonar: false,
            dividerSonarPing: false,
            cardGlassEffect: false
        },

        "Deep Sea": {
            // Hub Card
            hubCardRadius: 16,

            // Card
            cardRadius: 16,
            cornerBrackets: false,
            accentBorder: true,
            accentBorderOpacity: 0.12,

            // Divider
            dividerAnimated: false,
            dividerGradient: false,
            dividerHeight: 1,

            // Button
            buttonRadius: 12,
            buttonGlowBorder: false,
            buttonSolidFill: true,

            // Slider
            sliderTickMarks: false,
            sliderHandleGlow: true,
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
            labelLetterSpacing: 0.5,

            // Value Display
            valueDisplayBrackets: false,
            valueAccentColor: true,

            // Sidebar / Nav
            sidebarGrid: false,
            navItemRadius: 12,
            navAccentBarWidth: 4,
            navAccentBarFullHeight: false,

            // Chips
            chipRadius: -1,
            chipAccentBorder: false,

            // Section Header
            sectionHeaderLines: false,

            // TextField
            textFieldRadius: 10,
            textFieldCornerMarks: false,

            // Dropdown
            dropdownRadius: 10,

            // Checkbox
            checkboxRadius: 6,

            // Segmented Control
            segmentGlowBar: false,

            // Radio
            radioSquare: false,

            // Terminal
            terminalRadius: 10,
            terminalAccentBorder: true,
            terminalCornerBrackets: false,
            terminalScanlines: false,
            terminalHeaderAccent: true,
            terminalAccentScroll: true,

            // Enhanced effects
            scanlineOverlay: false,
            pulsingElements: true,
            contentHudLines: false,
            dividerDiamondRotate: false,

            // Deep Sea effects
            sidebarBubbles: true,
            contentSonar: true,
            dividerSonarPing: true,
            cardGlassEffect: true
        }
    })

    // Active environment object - bindings re-evaluate when currentEnvironment changes
    property var active: environments[currentEnvironment] || environments["Standard"]

    // Environments other than Standard are temporarily disabled — see Display
    // settings. The presets remain in `environments` for the future redo, but
    // the public API only exposes Standard so nothing can switch the look.
    function setEnvironment(name) {
        if (currentEnvironment !== "Standard") {
            currentEnvironment = "Standard"
            environmentChanged()
        }
    }

    function getAllEnvironmentNames() {
        return ["Standard"]
    }
}
