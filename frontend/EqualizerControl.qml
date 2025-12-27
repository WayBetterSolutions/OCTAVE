import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Basic 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import "." as App

Item {
    id: equalizerControl
    required property StackView stackView
    
    // Properties for equalizer data
    property var frequencies: equalizerManager ? equalizerManager.get_equalizer_frequencies() : []
    property var values: equalizerManager ? equalizerManager.get_equalizer_values() : []
    property var presets: equalizerManager ? equalizerManager.get_available_presets() : []
    property string currentPreset: equalizerManager ? equalizerManager.get_current_preset() : "Flat"

    property var mediaManager: null
    
    // System equalizer properties
    property bool systemEqualizerAvailable: equalizerManager ? equalizerManager.is_system_equalizer_available() : false
    property bool equalizerActive: equalizerManager ? equalizerManager.is_equalizer_active() : false
    
    // Visual properties
    property color backgroundColor: "black"
    property color transparentColor: "transparent"
    
    // Background with blur effect
    Rectangle {
        id: backgroundContainer
        anchors.fill: parent
        color: App.Style.backgroundColor
        z: -1
        
        // Add connection to listen for media changes
        Connections {
            target: mediaManager
            function onCurrentMediaChanged() {
                backgroundImage.source = mediaManager ? 
                        (mediaManager.get_current_file() ? 
                            mediaManager.get_album_art(mediaManager.get_current_file()) || "./assets/missing_art.png" : 
                            "./assets/missing_art.png") : 
                        "./assets/missing_art.png"
            }
        }
        
        Image {
            id: backgroundImage
            anchors.fill: parent
            source: mediaManager ? 
                    (mediaManager.get_current_file() ? 
                        mediaManager.get_album_art(mediaManager.get_current_file()) || "./assets/missing_art.png" : 
                        "./assets/missing_art.png") : 
                    "./assets/missing_art.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.4
            visible: false
        }
        
        FastBlur {
            id: backgroundBlur
            anchors.fill: backgroundImage
            source: backgroundImage
            radius: 64
            visible: true
        }
        
        // Dark overlay
        Rectangle {
            anchors.fill: parent
            color: "#B0000000"
            opacity: settingsManager && settingsManager.showBackgroundOverlay ? 1.0 : 0.0
        }
    }
    
    // Main content
    Rectangle {
        anchors.fill: parent
        color: transparentColor

        // Back button
        Button {
            id: backButton
            implicitHeight: App.Spacing.mediaRoomMediaPlayerButtonHeight
            implicitWidth: App.Spacing.mediaRoomMediaPlayerButtonWidth
            background: null
            anchors {
                left: parent.left
                top: parent.top
                margins: App.Spacing.overallMargin
            }
            z: 10

            contentItem: Item {
                Image {
                    id: leftArrowImage
                    anchors.centerIn: parent
                    source: "./assets/left_arrow.svg"
                    fillMode: Image.PreserveAspectFit
                    width: parent.width
                    height: parent.height
                    smooth: true
                    antialiasing: true
                    sourceSize: Qt.size(width * 2, height * 2)
                    mipmap: true
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: leftArrowImage
                    source: leftArrowImage
                    color: App.Style.mediaRoomLeftButton
                }
            }

            onClicked: stackView.pop()
        }

        // Main content area
        Rectangle {
            id: mainContent
            anchors {
                top: backButton.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: App.Spacing.overallMargin
            }
            color: "transparent"

            // Presets row
            Rectangle {
                id: presetsContainer
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: App.Spacing.overallMargin * 6
                color: Qt.rgba(0, 0, 0, 0.5)
                radius: 5

                RowLayout {
                    anchors {
                        fill: parent
                        margins: App.Spacing.overallMargin
                    }
                    spacing: App.Spacing.overallMargin

                    Text {
                        text: "PRESET:"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerTextSize
                        font.bold: true
                    }

                    ComboBox {
                        id: presetComboBox
                        Layout.fillWidth: true
                        model: presets
                        currentIndex: presets && currentPreset ? Math.max(0, presets.indexOf(currentPreset)) : 0
                        onActivated: {
                            equalizerManager.apply_preset(presets[currentIndex])
                        }
                        
                        background: Rectangle {
                            color: Qt.rgba(0.1, 0.1, 0.1, 0.7)
                            radius: 5
                            border.color: App.Style.accent
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: presetComboBox.displayText
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.mediaPlayerTextSize
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            leftPadding: App.Spacing.overallMargin
                        }
                        
                        popup: Popup {
                            y: presetComboBox.height
                            width: presetComboBox.width
                            height: Math.min(300, contentItem.implicitHeight)
                            padding: 1
                            
                            background: Rectangle {
                                color: Qt.rgba(0.1, 0.1, 0.1, 0.9)
                                border.color: App.Style.accent
                                border.width: 1
                                radius: 5
                            }
                            
                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: presetComboBox.popup.visible ? presetComboBox.delegateModel : null
                                
                                ScrollBar.vertical: ScrollBar {
                                    active: true
                                }
                            }
                        }
                        
                        delegate: ItemDelegate {
                            width: presetComboBox.width
                            height: App.Spacing.overallMargin * 4
                            
                            contentItem: Text {
                                text: modelData
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize
                                font.bold: equalizerManager && equalizerManager.is_builtin_preset(modelData)
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignLeft
                            }
                            
                            background: Rectangle {
                                color: highlighted ? App.Style.accent : Qt.rgba(0.1, 0.1, 0.1, 0.5)
                            }
                            
                            highlighted: presetComboBox.highlightedIndex === index
                        }
                    }
                }
            }

            // System equalizer controls - simplified
            Rectangle {
                id: systemEqContainer
                anchors {
                    top: presetsContainer.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: App.Spacing.overallMargin
                }
                height: App.Spacing.overallMargin * 6
                color: Qt.rgba(0, 0, 0, 0.5)
                radius: 5
                visible: systemEqualizerAvailable

                RowLayout {
                    anchors {
                        fill: parent
                        margins: App.Spacing.overallMargin
                    }
                    spacing: App.Spacing.overallMargin

                    Switch {
                        id: eqActiveSwitch
                        text: "System Equalizer"
                        checked: equalizerActive
                        onToggled: {
                            if (equalizerManager) {
                                equalizerManager.set_equalizer_active(checked)
                            }
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 40
                            implicitHeight: 20
                            x: eqActiveSwitch.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            color: eqActiveSwitch.checked ? App.Style.accent : "#555555"
                            border.color: eqActiveSwitch.checked ? App.Style.accent : "#999999"

                            Rectangle {
                                x: eqActiveSwitch.checked ? parent.width - width - 2 : 2
                                y: 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                                
                                Behavior on x {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                        
                        contentItem: Text {
                            text: eqActiveSwitch.text
                            font.pixelSize: App.Spacing.mediaPlayerTextSize
                            color: App.Style.primaryTextColor
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: eqActiveSwitch.indicator.width + 10
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // No System Equalizer Warning - simplified
            Rectangle {
                id: noSystemEqContainer
                anchors {
                    top: presetsContainer.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: App.Spacing.overallMargin
                }
                height: App.Spacing.overallMargin * 6
                color: "#30FF0000"  // Semi-transparent red
                radius: 5
                visible: !systemEqualizerAvailable

                RowLayout {
                    anchors {
                        fill: parent
                        margins: App.Spacing.overallMargin
                    }
                    spacing: App.Spacing.overallMargin

                    Text {
                        text: "No system equalizer detected"
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.mediaPlayerTextSize
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Install EasyEffects"
                        implicitHeight: App.Spacing.overallMargin * 3
                        implicitWidth: App.Spacing.overallMargin * 12
                        
                        background: Rectangle {
                            color: App.Style.accent
                            radius: 5
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: App.Spacing.mediaPlayerTextSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            var url = "";
                            if (Qt.platform.os === "windows") {
                                url = "https://sourceforge.net/projects/equalizerapo/";
                            } else if (Qt.platform.os === "linux") {
                                url = "https://flathub.org/apps/com.github.wwmm.easyeffects";
                            } else if (Qt.platform.os === "osx") {
                                url = "https://eqmac.app/";
                            }
                            
                            if (url) {
                                Qt.openUrlExternally(url);
                            }
                        }
                    }
                }
            }

            // Equalizer sliders - simplified
            Flickable {
                id: sliderFlickable
                anchors {
                    top: systemEqualizerAvailable ? systemEqContainer.bottom : noSystemEqContainer.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: App.Spacing.overallMargin
                }
                contentWidth: sliderRow.width
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: sliderRow
                    spacing: Math.max(10, (sliderFlickable.width - frequencies.length * 70) / (frequencies.length - 1))
                    height: sliderFlickable.height

                    Repeater {
                        model: frequencies.length
                        delegate: Column {
                            id: sliderColumn
                            spacing: 5
                            height: parent.height
                            width: 70

                            // Simplified labels
                            Text {
                                text: "+12 dB"
                                color: App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 0.8
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Simplified slider
                            Slider {
                                id: bandSlider
                                orientation: Qt.Vertical
                                height: parent.height - 150
                                width: 60
                                anchors.horizontalCenter: parent.horizontalCenter
                                from: 12.0
                                to: -12.0
                                value: values[index]
                                stepSize: 0.1
                                enabled: equalizerActive || !systemEqualizerAvailable

                                background: Rectangle {
                                    x: bandSlider.width / 2 - width / 2
                                    y: 0
                                    width: 6
                                    height: bandSlider.height
                                    radius: 3
                                    color: bandSlider.enabled ? "#424242" : "#222222"

                                    // Colored portion - matched with background
                                    Rectangle {
                                        width: parent.width
                                        height: bandSlider.visualPosition * parent.height
                                        y: bandSlider.height - height
                                        radius: 3
                                        color: values[index] > 0 ? 
                                               (bandSlider.enabled ? App.Style.accent : Qt.darker(App.Style.accent, 1.2)) : 
                                               (bandSlider.enabled ? "#2979ff" : "#193a77")
                                    }
                                }

                                handle: Rectangle {
                                    x: bandSlider.leftPadding + bandSlider.availableWidth / 2 - width / 2
                                    y: bandSlider.topPadding + bandSlider.visualPosition * bandSlider.availableHeight - height / 2
                                    width: 24
                                    height: 12
                                    radius: 6
                                    color: bandSlider.pressed ? "#666666" : (bandSlider.enabled ? "#808080" : "#505050")
                                    border.color: bandSlider.pressed ? "#ffffff" : (bandSlider.enabled ? "#cccccc" : "#888888")
                                    opacity: bandSlider.enabled ? 1.0 : 0.7

                                    // Simple center line
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.6
                                        height: 1
                                        color: bandSlider.enabled ? "#cccccc" : "#888888"
                                    }
                                }

                                onMoved: {
                                    equalizerManager.set_equalizer_band(index, value)
                                }
                                
                                // Double-click to reset band
                                MouseArea {
                                    anchors.fill: parent
                                    onDoubleClicked: {
                                        bandSlider.value = 0.0
                                        equalizerManager.set_equalizer_band(index, 0.0)
                                    }
                                    
                                    onPressed: function(mouse) {
                                        mouse.accepted = false
                                    }
                                }
                            }

                            // Zero line
                            Rectangle {
                                width: 30
                                height: 2
                                color: "#cccccc"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Simplified labels
                            Text {
                                text: "-12 dB"
                                color: App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 0.8
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Frequency label
                            Text {
                                text: frequencies[index] >= 1000 ? 
                                      (frequencies[index] / 1000) + "K" : 
                                      frequencies[index] + "Hz"
                                color: App.Style.primaryTextColor
                                font.pixelSize: App.Spacing.mediaPlayerTextSize
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // Value label - simplified
                            Text {
                                text: values[index].toFixed(1) + " dB"
                                color: values[index] > 0 ? 
                                       App.Style.accent :
                                       (values[index] < 0 ? "#2979ff" : App.Style.secondaryTextColor)
                                font.pixelSize: App.Spacing.mediaPlayerTextSize * 0.8
                                font.bold: Math.abs(values[index]) > 0.1
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Simplified scrollbar
                ScrollBar.horizontal: ScrollBar {
                    active: sliderRow.width > sliderFlickable.width
                    
                    background: Rectangle {
                        implicitHeight: 8
                        color: "transparent"
                        radius: height / 2
                    }
                    
                    contentItem: Rectangle {
                        implicitHeight: 8
                        implicitWidth: 100
                        radius: height / 2
                        color: App.Style.accent
                        opacity: 0.7
                    }
                }
            }
        }
    }

    // Connect to equalizerManager signals
    Connections {
        target: equalizerManager
        
        function onEqualizerBandsChanged(newValues) {
            values = newValues
        }
        
        function onPresetChanged(newPreset) {
            currentPreset = newPreset
            presetComboBox.currentIndex = presets.indexOf(newPreset)
        }
        
        function onEqualizerStatusChanged(isActive) {
            equalizerActive = isActive
            eqActiveSwitch.checked = isActive
        }
    }

    // Initial setup
    Component.onCompleted: {
        if (equalizerManager) {
            values = equalizerManager.get_equalizer_values()
            frequencies = equalizerManager.get_equalizer_frequencies()
            presets = equalizerManager.get_available_presets()
            currentPreset = equalizerManager.get_current_preset()
            
            systemEqualizerAvailable = equalizerManager.is_system_equalizer_available()
            equalizerActive = equalizerManager.is_equalizer_active()
        }
    }
}