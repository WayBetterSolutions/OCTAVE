import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import QtQuick.Dialogs
import "." as App

Item {
    id: settingsMenu
    objectName: "settingsMenu"  // Add this line
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: initialSection

    // Reactive property for Spotify devices - updated by signal, bound by repeater
    property var spotifyDevicesList: []

    // Refresh Spotify devices when navigating to media settings
    onCurrentSectionChanged: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
    }

    // Refresh devices on initial load if starting on media settings
    Component.onCompleted: {
        if (currentSection === "mediaSettings" && spotifyManager && spotifyManager.is_connected()) {
            spotifyManager.refresh_devices()
        }
        // Initialize with current devices if already connected
        if (spotifyManager && spotifyManager.is_connected()) {
            spotifyDevicesList = spotifyManager.get_devices()
        }
    }

    // Top-level Spotify connections (always active, not dependent on visibility)
    Connections {
        target: spotifyManager
        function onDevicesChanged(devices) {
            settingsMenu.spotifyDevicesList = devices
        }
        function onConnectionStateChanged(connected) {
            if (connected) {
                // Refresh devices when connection established
                spotifyManager.refresh_devices()
            } else {
                settingsMenu.spotifyDevicesList = []
            }
        }
    }

    // Global font binding for all text in this component
    // fontFamily always returns a valid font (systemDefaultFont or custom font)
    property string globalFont: App.Style.fontFamily

    // Folder dialog for selecting music library folder
    FolderDialog {
        id: folderDialog
        title: "Select Music Library Folder"
        onAccepted: {
            // Convert from file:/// URL to local path
            var path = selectedFolder.toString()
            if (path.startsWith("file:///")) {
                // On Windows: file:///C:/path -> remove 8 chars -> C:/path
                // On Unix: file:///home/path -> remove 7 chars -> /home/path
                // Check if it's a Windows path (has drive letter after file:///)
                var afterScheme = path.substring(8)
                if (afterScheme.length > 1 && afterScheme.charAt(1) === ':') {
                    // Windows path with drive letter (e.g., C:/)
                    path = afterScheme
                } else {
                    // Unix path - keep the leading slash
                    path = path.substring(7)  // Remove "file://" only
                }
            }
            mediaFolderField.text = path
            if (settingsManager) {
                settingsManager.save_media_folder(path)
            }
        }
    }

    component SettingLabel: Label {
        color: App.Style.primaryTextColor
        font.pixelSize: App.Spacing.overallText
        font.family: settingsMenu.globalFont
        Layout.fillWidth: true
    }

    component SettingDescription: Text {
        color: App.Style.secondaryTextColor
        font.pixelSize: App.Spacing.overallText * 0.8
        font.family: settingsMenu.globalFont
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    
    component SettingsDivider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.1)
        Layout.topMargin: App.Spacing.overallSpacing
        Layout.bottomMargin: App.Spacing.overallSpacing
    }
    
    component SettingsSlider: Slider {
        id: control
        Layout.fillWidth: true
        
        // Slightly increase the implicit height for more touch area without changing appearance
        implicitHeight: App.Spacing.overallSliderHeight * 2.5
        
        // Use the new settingsSliderColor property
        property color activeColor: App.Style.settingsSliderColor
        property double visualValue: value
        property string valueDisplay: ""
        
        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: App.Spacing.overallSliderWidth
            height: App.Spacing.overallSliderHeight
            radius: App.Spacing.overallSliderRadius
            color: control.pressed ? Qt.darker(control.activeColor, 1.1) : control.activeColor
            
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        
        background: Rectangle {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: control.availableWidth
            height: App.Spacing.overallSliderHeight / 2
            radius: height / 2
            color: App.Style.secondaryTextColor
            
            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                color: control.activeColor
                radius: parent.radius
            }
        }
        
        // Make the whole track area clickable while preserving original appearance
        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                // Calculate value based on mouse position
                var newPos = Math.max(0, Math.min(1, (mouseX - control.leftPadding) / control.availableWidth))
                control.value = control.from + newPos * (control.to - control.from)
                control.pressed = true
                mouse.accepted = false  // Allow the event to propagate to the Slider
            }
            onReleased: function(mouse) {
                control.pressed = false
                mouse.accepted = false
            }
        }
    }
    
    component SettingsSwitch: Switch {
        id: control
        
        indicator: Rectangle {
            implicitWidth: 48
            implicitHeight: 26
            x: control.leftPadding
            y: control.height / 2 - height / 2
            radius: 13
            color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
            border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
            
            Rectangle {
                x: control.checked ? parent.width - width - 3 : 3
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                
                Behavior on x { NumberAnimation { duration: 150 } }
            }
        }
        
        contentItem: Text {
            text: control.text
            color: App.Style.primaryTextColor
            verticalAlignment: Text.AlignVCenter
            leftPadding: control.indicator.width + control.spacing
            font.family: settingsMenu.globalFont
        }
    }

    component SettingsRadio: RadioButton {
        id: control
        
        indicator: Rectangle {
            implicitWidth: 20
            implicitHeight: 20
            x: control.leftPadding
            y: control.height / 2 - height / 2
            radius: 10
            border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
            border.width: 2
            
            Rectangle {
                width: 10
                height: 10
                x: 5
                y: 5
                radius: 5
                color: control.checked ? App.Style.accent : "transparent"
                
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
        
        contentItem: Text {
            text: control.text
            color: App.Style.primaryTextColor
            verticalAlignment: Text.AlignVCenter
            leftPadding: control.indicator.width + control.spacing
            elide: Text.ElideRight
            width: control.width - control.indicator.width - control.spacing - 10
            font.family: settingsMenu.globalFont
        }
    }

    component SettingsCheckBox: Item {
        id: control
        height: 44
        implicitHeight: 44
        Layout.fillWidth: true
        
        property bool checked: false
        property string text: ""
        signal toggled(bool checked)
        
        RowLayout {
            anchors.fill: parent
            spacing: App.Spacing.overallSpacing * 1.5
            
            // Larger, more touchable checkbox
            Rectangle {
                id: checkboxRect
                width: 30
                height: 30
                radius: 4
                color: control.checked ? App.Style.accent : "transparent"
                border.color: control.checked ? App.Style.accent : App.Style.secondaryTextColor
                border.width: 2
                
                // Checkmark
                Text {
                    visible: control.checked
                    text: "✓"
                    font.pixelSize: 22
                    color: "white"
                    anchors.centerIn: parent
                    font.family: settingsMenu.globalFont
                }
                
                // Add a mouseover effect
                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    radius: 4
                    opacity: checkboxArea.containsMouse ? 0.1 : 0
                }
            }
            
            // Text label
            Text {
                text: control.text
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: settingsMenu.globalFont
            }
        }
        
        // Make entire row clickable for improved touch interaction
        MouseArea {
            id: checkboxArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                control.checked = !control.checked
                control.toggled(control.checked)
            }
        }
    }
    
    component SettingsTextField: TextField {
        id: control
        Layout.preferredHeight: App.Spacing.formElementHeight
        Layout.preferredWidth: 500
        Layout.maximumWidth: 800
        color: App.Style.primaryTextColor
        font.pixelSize: App.Spacing.overallText
        placeholderTextColor: App.Style.secondaryTextColor
        leftPadding: 20  // Increased from 15
        rightPadding: 20 // Increased from 15
        verticalAlignment: TextInput.AlignVCenter
        
        background: Rectangle {
            color: App.Style.hoverColor
            radius: 4
            border.color: control.activeFocus ? App.Style.accent : "transparent"
            border.width: 1
            
            // Highlight effect on hover
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            }
            
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }
    }

    component HomeScreenButton: Item {
        id: control
        width: 64
        height: 44
        Layout.alignment: Qt.AlignCenter // Add this to center it in the layout
        
        property bool isActive: false
        signal clicked()
        
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: control.isActive ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) : "transparent"
            border.color: control.isActive ? App.Style.accent : "transparent"
            border.width: 1
            
            // Visual feedback on hover
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: homeButtonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            }
            
            // Home icon with better visibility
            Image {
                id: homeIcon
                anchors.centerIn: parent
                source: "assets/home_button.svg"
                width: App.Spacing.settingsButtonHeight * .3
                height: App.Spacing.settingsButtonHeight * .3
                sourceSize.width: App.Spacing.settingsButtonHeight * .3
                sourceSize.height: App.Spacing.settingsButtonHeight * .3
            }
        }
        
        // Larger touch area
        MouseArea {
            id: homeButtonArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: control.clicked()
        }
    }
    

    component SettingsDropdown: Button {
        id: control
        Layout.preferredHeight: App.Spacing.formElementHeight
        Layout.preferredWidth: 300
        Layout.maximumWidth: 400
        Layout.minimumWidth: 250  // Ensure dropdown is never too small
        Layout.fillWidth: true
        property string displayText: ""
        property var options: []
        property var onSelected: function(value) {}
        
        contentItem: Item {
            anchors.fill: parent
            
            Text {
                id: labelText
                text: control.displayText
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                font.family: settingsMenu.globalFont
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter

                anchors {
                    left: parent.left
                    leftMargin: 20  // Increased from 15
                    right: arrowText.left
                    rightMargin: 15
                    verticalCenter: parent.verticalCenter
                }
            }

            Text {
                id: arrowText
                text: "▼"
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 0.8
                font.family: settingsMenu.globalFont
                verticalAlignment: Text.AlignVCenter

                anchors {
                    right: parent.right
                    rightMargin: 20  // Increased from 15
                    verticalCenter: parent.verticalCenter
                }
            }
        }
        
        background: Rectangle {
            color: control.pressed ? Qt.darker(App.Style.hoverColor, 1.2) : 
                   control.hovered ? Qt.darker(App.Style.hoverColor, 1.1) : App.Style.hoverColor
            radius: 4
            
            // Highlight effect
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            }
            
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        
        property var dropdownPopup: Popup {
            id: popup
            width: control.width
            y: control.height
            height: Math.min(contentItem.implicitHeight, 300)
            
            background: Rectangle {
                color: App.Style.backgroundColor
                border.color: App.Style.accent
                border.width: 1
                radius: 6
            }
            
            contentItem: ListView {
                id: optionsList
                implicitHeight: contentHeight
                model: control.options
                clip: true
                
                delegate: ItemDelegate {
                    required property int index
                    required property var modelData
                    
                    width: parent.width
                    height: 45  // Increased from 40
                    
                    contentItem: Text {
                        text: modelData
                        color: App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.overallText
                        font.family: settingsMenu.globalFont
                        leftPadding: 20  // Increased from 15
                        rightPadding: 20 // Increased from 15
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    
                    background: Rectangle {
                        color: parent.hovered ? App.Style.hoverColor : "transparent"
                    }
                    
                    onClicked: {
                        control.onSelected(modelData)
                        popup.close()
                    }
                }
                
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 0 // Just 1 pixel wide
                    active: true  // Always active
                    interactive: true
                    opacity: 0.2  // Very faint
                }
            }
        }
        
        onClicked: {
            dropdownPopup.opened ? dropdownPopup.close() : dropdownPopup.open()
        }
    }


    component SettingsToggle: Item {
        id: control
        height: 60  // Increased from 40
        Layout.preferredHeight: 60  // Increased from 40
        Layout.fillWidth: true
        
        property bool checked: false
        property string text: ""
        property color activeColor: App.Style.accent
        property color inactiveColor: App.Style.hoverColor
        signal toggled(bool checked)
        
        RowLayout {
            anchors.fill: parent
            spacing: App.Spacing.overallSpacing * 2

            // Label
            Text {
                text: control.text
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.1
                font.family: settingsMenu.globalFont
                Layout.preferredWidth: control.width * 0.55

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        control.checked = !control.checked
                        control.toggled(control.checked)
                    }
                }
            }

            // Toggle switch
            Item {
                width: 96
                height: 48
                
                // Main track - flatter design
                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: height / 2
                    color: control.checked ? Qt.rgba(control.activeColor.r, control.activeColor.g, control.activeColor.b, 0.3) : 
                                        Qt.rgba(control.inactiveColor.r, control.inactiveColor.g, control.inactiveColor.b, 0.3)
                    
                    // Subtle gradient overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                        }
                    }
                    
                    // Animated highlight that expands from the handle
                    Rectangle {
                        id: highlightTrack
                        width: control.checked ? parent.width : 0
                        height: parent.height
                        radius: parent.radius
                        anchors.right: control.checked ? parent.right : undefined
                        anchors.left: !control.checked ? parent.left : undefined
                        color: control.activeColor
                        opacity: control.checked ? 0.5 : 0
                        
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                    
                }
                
                // Handle with shadow and subtle effects
                Rectangle {
                    id: handle
                    width: 48
                    height: 48
                    radius: width / 2
                    x: control.checked ? parent.width - width : 0
                    y: 0
                    
                    // Create a subtle layer effect
                    color: "white"
                    
                    // Inner indicator for "on" state
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.4
                        height: width
                        radius: width / 2
                        color: control.activeColor
                        opacity: control.checked ? 1 : 0
                        scale: control.checked ? 1 : 0.5
                        
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    
                    // Handle shadow
                    layer.enabled: true
                    layer.effect: DropShadow {
                        verticalOffset: 2
                        radius: 6.0
                        samples: 17
                        color: Qt.rgba(0, 0, 0, 0.2)
                    }
                    
                    // Create subtle animation on click
                    scale: controlMouseArea.pressed ? 0.95 : 1.0
                    
                    Behavior on x { 
                        NumberAnimation { 
                            duration: 300
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.6
                        }
                    }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }
                
                // Interactive area
                MouseArea {
                    id: controlMouseArea
                    anchors.fill: parent
                    onClicked: {
                        control.checked = !control.checked
                        control.toggled(control.checked)
                    }
                    
                    // Add subtle pulse animation on click
                    onPressed: {
                        pulseAnimation.start()
                    }
                    
                    SequentialAnimation {
                        id: pulseAnimation
                        PropertyAnimation {
                            target: handle
                            property: "scale"
                            to: 0.9
                            duration: 100
                        }
                        PropertyAnimation {
                            target: handle
                            property: "scale"
                            to: 1.0
                            duration: 100
                        }
                    }
                }
            }

        }
    }

    component SettingsSegmentedControl: RowLayout {
        id: control
        spacing: 1
        Layout.fillWidth: true
        
        property var options: []
        property string currentValue: ""
        property var onSelected: function(value) {}
        
        Repeater {
            model: control.options
            
            delegate: Rectangle {
                required property int index
                required property var modelData
                
                id: segmentRect
                Layout.fillWidth: true
                Layout.minimumWidth: 80
                height: App.Spacing.formElementHeight
                
                color: modelData === control.currentValue ? App.Style.accent : App.Style.hoverColor
                border.color: App.Style.hoverColor
                
                // Add a property to track hover state
                property bool isHovered: false
                
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: modelData === control.currentValue ? "white" : App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: settingsMenu.globalFont
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: control.onSelected(modelData)
                    onEntered: segmentRect.isHovered = true
                    onExited: segmentRect.isHovered = false
                }
                
                // Highlight effect using the property
                Rectangle {
                    anchors.fill: parent
                    color: segmentRect.isHovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    visible: modelData !== control.currentValue // Only show hover on non-selected segments
                }
            }
        }
    }

    component SettingsChips: Flow {
        id: control
        spacing: App.Spacing.overallSpacing
        Layout.fillWidth: true
        
        property var options: []
        property string currentValue: ""
        property var onSelected: function(value) {}
        
        Repeater {
            model: control.options
            
            delegate: Rectangle {
                required property int index
                required property var modelData
                
                id: chipRect
                width: chipText.width + App.Spacing.overallSpacing * 3
                height: App.Spacing.formElementHeight * 0.8
                radius: height / 2
                
                color: modelData === control.currentValue ? App.Style.accent : App.Style.hoverColor
                property bool isHovered: false
                
                // Add subtle border for non-selected chips
                border.width: modelData === control.currentValue ? 0 : 1
                border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                    App.Style.primaryTextColor.g, 
                                    App.Style.primaryTextColor.b, 0.1)
                
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData
                    color: modelData === control.currentValue ? "white" : App.Style.primaryTextColor
                    font.pixelSize: App.Spacing.overallText
                    font.family: settingsMenu.globalFont
                }
                
                MouseArea {
                    id: chipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: control.onSelected(modelData)
                    onEntered: { 
                        chipRect.isHovered = true
                        chipRect.scale = 1.05
                    }
                    onExited: { 
                        chipRect.isHovered = false
                        chipRect.scale = 1.0
                    }
                }
                
                // Subtle shadow for selected chips
                layer.enabled: modelData === control.currentValue
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 4.0
                    samples: 9
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
                
                // Animation for scale changes
                Behavior on scale {
                    NumberAnimation { 
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
    
    component ValueDisplay: Text {
        color: App.Style.secondaryTextColor
        font.pixelSize: App.Spacing.overallText
        font.family: settingsMenu.globalFont
        Layout.topMargin: 2
    }

    component SettingsButton: Rectangle {
        id: control

        property string text: ""
        property string tooltipText: ""
        property color buttonColor: App.Style.accent
        property bool bold: true
        signal clicked()

        Layout.preferredWidth: buttonLabel.implicitWidth + App.Spacing.overallSpacing * 1.5
        Layout.minimumWidth: 70
        color: buttonArea.pressed ? Qt.darker(control.buttonColor, 1.4) :
               buttonArea.containsMouse ? Qt.darker(control.buttonColor, 1.2) : control.buttonColor
        radius: 6
        border.width: 1
        border.color: Qt.darker(control.buttonColor, 1.3)
        clip: true

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: control.text
            color: "white"
            font.pixelSize: App.Spacing.overallText
            font.bold: control.bold
            font.family: settingsMenu.globalFont
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: control.clicked()
        }

        ToolTip.visible: buttonArea.containsMouse && control.tooltipText !== ""
        ToolTip.text: control.tooltipText
        ToolTip.delay: 300
    }

    component SettingsSectionHeader: ColumnLayout {
        Layout.fillWidth: true
        spacing: App.Spacing.rowSpacing

        property string title: ""
        property string description: ""

        SettingLabel {
            text: parent.title
            font.pixelSize: App.Spacing.overallText * 1.5
            font.bold: true
        }

        SettingDescription {
            text: parent.description
            visible: parent.description !== ""
        }
    }

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor
        
        RowLayout {
            anchors.fill: parent
            spacing: 0
            
            
            Rectangle { // Left Navigation Panel
                Layout.preferredWidth: App.Spacing.settingsNavWidth
                Layout.fillHeight: true
                color: App.Style.sidebarColor
                
                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: App.Spacing.settingsNavMargin
                    }
                    spacing: 0
                    
                    ListView {
                        id: navListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        interactive: true
                        clip: true
                        
                        model: ListModel {
                            ListElement { name: "Device"; section: "deviceSettings" }
                            ListElement { name: "Media"; section: "mediaSettings" }
                            ListElement { name: "Display"; section: "displaySettings" }
                            ListElement { name: "OBD"; section: "obdSettings" }
                            ListElement { name: "Clock"; section: "clockSettings" }
                            ListElement { name: "Android Auto"; section: "androidAutoSettings" }
                            ListElement { name: "Phone Mirror"; section: "phoneMirrorSettings" }
                            ListElement { name: "Volume Knob"; section: "volumeKnobSettings" }
                            ListElement { name: "About"; section: "about" }
                        }
                        
                        delegate: Item {
                            required property string name
                            required property string section

                            // Check visibility from settings manager
                            property bool sectionVisible: settingsManager ? settingsManager.is_settings_section_visible(section) : true

                            width: navListView.width
                            height: sectionVisible ? App.Spacing.settingsButtonHeight : 0
                            visible: sectionVisible
                            clip: true

                            // Update visibility when settings change
                            Connections {
                                target: settingsManager
                                function onSettingsMenuVisibilityChanged() {
                                    sectionVisible = settingsManager.is_settings_section_visible(section)
                                }
                            }
                            
                            // Active indicator
                            Rectangle {
                                visible: currentSection === section
                                width: 4
                                height: parent.height
                                color: App.Style.accent
                                anchors.left: parent.left
                            }
                            
                            // Background
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: 4 // Space for indicator
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                color: currentSection === section ? App.Style.hoverColor : "transparent"
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            // Text
                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: App.Spacing.overallMargin
                                    right: parent.right
                                    rightMargin: 5
                                    verticalCenter: parent.verticalCenter
                                }
                                text: name
                                color: currentSection === section ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.overallText*2
                                font.family: settingsMenu.globalFont
                                elide: Text.ElideRight
                            }
                            
                            // Entire area clickable
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    currentSection = section
                                    mainWindow.lastSettingsSection = section
                                    // Persist to settings
                                    if (settingsManager) {
                                        settingsManager.set_last_settings_section(section)
                                    }
                                }
                                hoverEnabled: true
                                
                                // Hover effect
                                onEntered: {
                                    if (currentSection !== section) {
                                        navHoverRectangle.visible = true
                                    }
                                }
                                onExited: {
                                    navHoverRectangle.visible = false
                                }
                            }
                            
                            // Hover effect
                            Rectangle {
                                id: navHoverRectangle
                                visible: false
                                anchors {
                                    left: parent.left
                                    leftMargin: 4
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)
                            }
                        }
                    }
                }
            }
            
            
            Rectangle { // Right Content Area
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: App.Style.contentColor
                
                StackLayout {
                    id: contentStack
                    anchors {
                        fill: parent
                        margins: App.Spacing.settingsContentMargin
                    }
                    currentIndex: {
                        switch(currentSection) {
                            case "deviceSettings": return 0;
                            case "mediaSettings": return 1;
                            case "displaySettings": return 2;
                            case "obdSettings": return 3;
                            case "clockSettings": return 4;
                            case "androidAutoSettings": return 5;
                            case "phoneMirrorSettings": return 6;
                            case "volumeKnobSettings": return 7;
                            case "about": return 8;
                            default: return 0;
                        }
                    }
                    
                    
                    ScrollView { // Device Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing


                            // Device Name Setting
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Device Name"
                                }
                                
                                SettingsTextField {
                                    id: deviceName
                                    Layout.fillWidth: true
                                    text: settingsManager ? settingsManager.deviceName : ""
                                    
                                    onEditingFinished: {
                                        if (text.trim() !== "" && settingsManager) {
                                            mainWindow.updateDeviceName(text)
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}
                            
                            // Future device settings can be added here
                            
                            // Bottom spacer
                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }
                    
                    ScrollView { // Media Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing


                            // Music Library Folder
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Library Folder"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.rowSpacing

                                    SettingsTextField {
                                        id: mediaFolderField
                                        Layout.fillWidth: true
                                        text: settingsManager ? settingsManager.mediaFolder : ""

                                        // Update when setting changes externally
                                        Connections {
                                            target: settingsManager
                                            function onMediaFolderChanged() {
                                                mediaFolderField.text = settingsManager.mediaFolder
                                            }
                                        }

                                        onEditingFinished: {
                                            if (text.trim() !== "" && settingsManager) {
                                                settingsManager.save_media_folder(text)
                                            }
                                        }
                                    }

                                    SettingsButton {
                                        text: "Browse"
                                        Layout.preferredHeight: mediaFolderField.height
                                        onClicked: folderDialog.open()
                                    }

                                    SettingsButton {
                                        text: "Scan"
                                        Layout.preferredHeight: mediaFolderField.height
                                        onClicked: {
                                            if (mediaManager) {
                                                mediaManager.scan_library()
                                            }
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Subfolders become playlists. Root MP3s go to 'Unsorted'."
                                }

                                // Terminal feedback for scan progress
                                TerminalFeedback {
                                    id: scanTerminal
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    Layout.topMargin: App.Spacing.rowSpacing
                                    title: "Library Scan Output"

                                    // Connect to mediaManager scan progress signal
                                    Connections {
                                        target: mediaManager
                                        function onScanProgress(message) {
                                            scanTerminal.appendLine(message)
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Startup Volume
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Startup volume"
                                }
                                
                                SettingsSlider {
                                    id: volumeSlider
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: settingsManager ? settingsManager.startUpVolume : 0.5
                                    visualValue: Math.round(Math.sqrt(value) * 100)
                                    valueDisplay: visualValue + "%"
                                    activeColor: App.Style.volumeSliderColor
                                    
                                    // Debounce updates
                                    Timer {
                                        id: volumeUpdateTimer
                                        interval: 100
                                        running: false
                                        repeat: false
                                        onTriggered: {
                                            if (settingsManager) {
                                                settingsManager.save_start_volume(volumeSlider.value)
                                            }
                                        }
                                    }
                                    
                                    onMoved: volumeUpdateTimer.restart()
                                }
                                
                                ValueDisplay {
                                    text: volumeSlider.valueDisplay
                                }
                            }

                            SettingsDivider {}

                            // Auto-Play on Startup
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: autoPlayToggle
                                    Layout.fillWidth: true
                                    text: "Autoplay on startup"
                                    checked: settingsManager ? settingsManager.autoPlayOnStartup : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_auto_play_on_startup(checked)
                                        }
                                    }

                                    // Update when setting changes externally
                                    Connections {
                                        target: settingsManager
                                        function onAutoPlayOnStartupChanged() {
                                            autoPlayToggle.checked = settingsManager.autoPlayOnStartup
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Music Button Default Page
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: musicButtonDefaultPageToggle
                                    Layout.fillWidth: true
                                    text: "Default to library view"
                                    checked: settingsManager ? settingsManager.musicButtonDefaultPage === "mediaPlayer" : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_music_button_default_page(checked ? "mediaPlayer" : "mediaRoom")
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onMusicButtonDefaultPageChanged() {
                                            musicButtonDefaultPageToggle.checked = settingsManager.musicButtonDefaultPage === "mediaPlayer"
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Return to Library After Selection
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: returnToLibraryToggle
                                    Layout.fillWidth: true
                                    text: "Return to library after playing"
                                    checked: settingsManager ? settingsManager.returnToLibraryAfterSelection : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_return_to_library_after_selection(checked)
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onReturnToLibraryAfterSelectionChanged() {
                                            returnToLibraryToggle.checked = settingsManager.returnToLibraryAfterSelection
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Waveform Visualizer
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: waveformVisualizerToggle
                                    Layout.fillWidth: true
                                    text: "Waveform visualizer"
                                    checked: settingsManager ? settingsManager.showWaveformVisualizer : true
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_show_waveform_visualizer(checked)
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onShowWaveformVisualizerChanged() {
                                            waveformVisualizerToggle.checked = settingsManager.showWaveformVisualizer
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Animated waveform in Now Playing, themed to match."
                                }
                            }

                            SettingsDivider {}

                            // Media Room Background Blur Effect
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Album Art Blur"
                                }
                                
                                SettingsSlider {
                                    id: blurRadiusSlider
                                    from: 0
                                    to: 100
                                    stepSize: 1
                                    value: settingsManager ? settingsManager.backgroundBlurRadius : 40
                                    activeColor: App.Style.accent
                                    
                                    // Debounce updates
                                    Timer {
                                        id: blurUpdateTimer
                                        interval: 100
                                        running: false
                                        repeat: false
                                        onTriggered: {
                                            if (settingsManager) {
                                                settingsManager.save_background_blur_radius(blurRadiusSlider.value)
                                            }
                                        }
                                    }
                                    
                                    onMoved: blurUpdateTimer.restart()
                                }
                                
                                ValueDisplay {
                                    text: blurRadiusSlider.value.toFixed(0)
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Media Room Background
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Album Art Layout"
                                }
                                
                                SettingsSegmentedControl {
                                    id: backgroundGridButton
                                    Layout.fillWidth: true
                                    currentValue: settingsManager ? settingsManager.backgroundGrid : "4x4"
                                    options: ["Normal", "2x2", "4x4"]
                                    
                                    onSelected: function(value) {
                                        if (settingsManager) {
                                            settingsManager.save_background_grid(value)
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Background Overlay Toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingsToggle {
                                    id: backgroundOverlayToggle
                                    Layout.fillWidth: true
                                    text: "Dark overlay on album art"
                                    checked: settingsManager ? settingsManager.showBackgroundOverlay : true
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor
                                    
                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_show_background_overlay(checked)
                                        }
                                    }
                                    
                                    // Update when setting changes externally
                                    Connections {
                                        target: settingsManager
                                        function onShowBackgroundOverlayChanged() {
                                            backgroundOverlayToggle.checked = settingsManager.showBackgroundOverlay
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Spotify Connect Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Spotify Connect"
                                }

                                SettingDescription {
                                    text: "Get credentials from developer.spotify.com"
                                }

                                // Credentials row with Client ID and Secret
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    // Client ID field
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Client ID"
                                            color: App.Style.secondaryTextColor
                                            font.pixelSize: App.Spacing.overallText - 2
                                            font.family: settingsMenu.globalFont
                                        }

                                        SettingsTextField {
                                            id: spotifyClientIdField
                                            Layout.fillWidth: true
                                            text: settingsManager ? settingsManager.get_spotify_client_id() : ""

                                            onEditingFinished: {
                                                if (settingsManager && text.trim() !== "") {
                                                    settingsManager.save_spotify_credentials(
                                                        text.trim(),
                                                        spotifyClientSecretField.text.trim()
                                                    )
                                                }
                                            }

                                            Connections {
                                                target: settingsManager
                                                function onSpotifyCredentialsChanged() {
                                                    spotifyClientIdField.text = settingsManager.get_spotify_client_id()
                                                }
                                            }
                                        }
                                    }

                                    // Client Secret field
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Client Secret"
                                            color: App.Style.secondaryTextColor
                                            font.pixelSize: App.Spacing.overallText - 2
                                            font.family: settingsMenu.globalFont
                                        }

                                        SettingsTextField {
                                            id: spotifyClientSecretField
                                            Layout.fillWidth: true
                                            text: settingsManager ? settingsManager.get_spotify_client_secret() : ""
                                            echoMode: TextInput.Password

                                            onEditingFinished: {
                                                if (settingsManager && text.trim() !== "") {
                                                    settingsManager.save_spotify_credentials(
                                                        spotifyClientIdField.text.trim(),
                                                        text.trim()
                                                    )
                                                }
                                            }

                                            Connections {
                                                target: settingsManager
                                                function onSpotifyCredentialsChanged() {
                                                    spotifyClientSecretField.text = settingsManager.get_spotify_client_secret()
                                                }
                                            }
                                        }
                                    }
                                }

                                // Action buttons row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    SettingsButton {
                                        text: "Connect"
                                        Layout.preferredHeight: spotifyClientIdField.height
                                        visible: spotifyManager && !spotifyManager.is_connected()
                                        tooltipText: "Connect to Spotify"
                                        onClicked: {
                                            if (spotifyManager) spotifyManager.authenticate()
                                        }
                                    }

                                    SettingsButton {
                                        text: "Disconnect"
                                        Layout.preferredHeight: spotifyClientIdField.height
                                        Layout.minimumWidth: 90
                                        visible: spotifyManager && spotifyManager.is_connected()
                                        buttonColor: App.Style.statusDanger
                                        tooltipText: "Disconnect from Spotify"
                                        onClicked: {
                                            if (spotifyManager) spotifyManager.disconnect()
                                        }
                                    }

                                    SettingsButton {
                                        text: "Refresh"
                                        Layout.preferredHeight: spotifyClientIdField.height
                                        visible: spotifyManager && spotifyManager.is_connected()
                                        tooltipText: "Refresh available devices"
                                        onClicked: {
                                            if (spotifyManager) spotifyManager.refresh_devices()
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                // Terminal feedback for Spotify connection
                                TerminalFeedback {
                                    id: spotifyTerminal
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    title: "Spotify Connection"

                                    Connections {
                                        target: spotifyManager
                                        function onStatusProgress(message) {
                                            spotifyTerminal.appendLine(message)
                                        }
                                        function onAuthUrlReady(url) {
                                            spotifyTerminal.appendLine("[INFO] Auth URL ready - opening browser...")
                                            spotifyAuthUrlText.text = url
                                            spotifyAuthUrlText.visible = true
                                        }
                                        function onConnectionStateChanged(connected) {
                                            spotifyAuthUrlText.visible = false
                                            if (connected && spotifyManager) {
                                                spotifyManager.refresh_devices()
                                            }
                                        }
                                    }
                                }

                                // Clickable auth URL (fallback if browser doesn't open)
                                Text {
                                    id: spotifyAuthUrlText
                                    Layout.fillWidth: true
                                    visible: false
                                    color: App.Style.accent
                                    font.pixelSize: App.Spacing.overallText - 2
                                    font.underline: true
                                    font.family: settingsMenu.globalFont
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 2

                                    ToolTip.visible: authUrlMouseArea.containsMouse
                                    ToolTip.text: "Click to open in browser"
                                    ToolTip.delay: 300

                                    MouseArea {
                                        id: authUrlMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Qt.openUrlExternally(spotifyAuthUrlText.text)
                                        }
                                    }
                                }

                                // Available devices list (when connected)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: spotifyManager && spotifyManager.is_connected()
                                    spacing: App.Spacing.overallSpacing

                                    Text {
                                        text: "Available Devices"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                    }

                                    // Chip-style device selector
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: App.Spacing.overallSpacing

                                        Repeater {
                                            id: spotifyDevicesRepeater
                                            model: settingsMenu.spotifyDevicesList

                                            Rectangle {
                                                id: deviceChip
                                                width: deviceChipText.width + App.Spacing.overallSpacing * 3
                                                height: App.Spacing.formElementHeight * 0.8
                                                radius: height / 2
                                                color: modelData.is_active ? App.Style.accent : App.Style.hoverColor
                                                border.width: modelData.is_active ? 0 : 1
                                                border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                                    App.Style.primaryTextColor.g,
                                                                    App.Style.primaryTextColor.b, 0.1)

                                                Text {
                                                    id: deviceChipText
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    color: modelData.is_active ? "white" : App.Style.primaryTextColor
                                                    font.pixelSize: App.Spacing.overallText
                                                    font.family: settingsMenu.globalFont
                                                }

                                                MouseArea {
                                                    id: deviceChipMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (spotifyManager && !modelData.is_active) {
                                                            spotifyManager.set_active_device(modelData.id)
                                                        }
                                                    }
                                                    onEntered: deviceChip.scale = 1.05
                                                    onExited: deviceChip.scale = 1.0
                                                }

                                                Behavior on scale {
                                                    NumberAnimation { duration: 100 }
                                                }

                                                layer.enabled: modelData.is_active
                                                layer.effect: DropShadow {
                                                    horizontalOffset: 0
                                                    verticalOffset: 2
                                                    radius: 4.0
                                                    samples: 9
                                                    color: Qt.rgba(0, 0, 0, 0.2)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: spotifyDevicesRepeater.count === 0
                                        text: "No devices found. Open Spotify on a device first."
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                        font.italic: true
                                    }
                                }
                            }

                            // Bottom spacer
                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // Display Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing



                            ColumnLayout { // UI Scaling slider
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "UI Scaling"
                                }
                                
                                SettingsSlider {
                                    id: uiScaleSlider
                                    from: 0.2
                                    to: 1.2
                                    stepSize: 0.05
                                    value: App.Spacing.globalScale
                                    
                                    Timer {
                                        id: scaleUpdateTimer
                                        interval: 100
                                        running: false
                                        repeat: false
                                        onTriggered: {
                                            if (settingsManager) {
                                                settingsManager.save_ui_scale(uiScaleSlider.value)
                                                App.Spacing.globalScale = uiScaleSlider.value
                                            }
                                        }
                                    }
                                    
                                    onMoved: scaleUpdateTimer.restart()
                                }
                                
                                ValueDisplay {
                                    text: (uiScaleSlider.value * 100).toFixed(0) + "%"
                                }
                                
                                SettingDescription {
                                    text: "Scales all UI elements. Applied immediately."
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { //nav bar orientation
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Nav Bar Position"
                                }
                                
                                SettingsSegmentedControl {
                                    id: bottomBarOrientation
                                    Layout.fillWidth: true
                                    currentValue: settingsManager ? settingsManager.bottomBarOrientation : "bottom"
                                    options: ["bottom", "side"]
                                    
                                    onSelected: function(value) {
                                        if (settingsManager) {
                                            settingsManager.save_bottom_bar_orientation(value)
                                            
                                            // Create a timer for a short delay
                                            var timer = Qt.createQmlObject('import QtQuick 2.15; Timer {}', bottomBarOrientation);
                                            timer.interval = 5;  // 250ms delay
                                            timer.repeat = false;
                                            timer.triggered.connect(function() {
                                                stackView.replace(stackView.currentItem, "SettingsMenu.qml", {
                                                    stackView: stackView,
                                                    mainWindow: mainWindow,
                                                    initialSection: currentSection  // Fixed typo here
                                                });
                                                timer.destroy();
                                            });
                                            timer.start();
                                        }
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Bottom or side placement"
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { // Nav Bar Media Controls
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: bottomBarMediaControlsToggle
                                    Layout.fillWidth: true
                                    text: "Nav bar media controls"
                                    checked: settingsManager ? settingsManager.showBottomBarMediaControls : true
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_show_bottom_bar_media_controls(checked)
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onShowBottomBarMediaControlsChanged() {
                                            bottomBarMediaControlsToggle.checked = settingsManager.showBottomBarMediaControls
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { // Screen Dimensions
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Screen Dimensions"
                                }
                                
                                RowLayout {
                                    spacing: App.Spacing.overallSpacing
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        text: "Width:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                    }
                                    
                                    SettingsTextField {
                                        id: screenWidth
                                        Layout.preferredWidth: 120
                                        text: mainWindow.width
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 400
                                            top: 3840
                                        }

                                        function applyWidth() {
                                            if (text && settingsManager) {
                                                const width = parseInt(text)
                                                settingsManager.save_screen_width(width)
                                                mainWindow.width = width
                                                App.Spacing.updateDimensions(width, mainWindow.height)
                                            }
                                        }

                                        onEditingFinished: applyWidth()
                                        onActiveFocusChanged: if (!activeFocus) applyWidth()
                                        
                                        Connections {
                                            target: mainWindow
                                            function onWidthChanged() {
                                                if (!screenWidth.activeFocus) {
                                                    screenWidth.text = mainWindow.width
                                                    if (settingsManager) {
                                                        settingsManager.save_screen_width(mainWindow.width)
                                                    }
                                                    App.Spacing.updateDimensions(mainWindow.width, mainWindow.height)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "Height:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                    }

                                    SettingsTextField {
                                        id: screenHeight
                                        Layout.preferredWidth: 120
                                        text: mainWindow.height
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 300
                                            top: 2160
                                        }

                                        function applyHeight() {
                                            if (text && settingsManager) {
                                                const height = parseInt(text)
                                                settingsManager.save_screen_height(height)
                                                mainWindow.height = height
                                                App.Spacing.updateDimensions(mainWindow.width, height)
                                            }
                                        }

                                        onEditingFinished: applyHeight()
                                        onActiveFocusChanged: if (!activeFocus) applyHeight()
                                        
                                        Connections {
                                            target: mainWindow
                                            function onHeightChanged() {
                                                if (!screenHeight.activeFocus) {
                                                    screenHeight.text = mainWindow.height
                                                    if (settingsManager) {
                                                        settingsManager.save_screen_height(mainWindow.height)
                                                    }
                                                    App.Spacing.updateDimensions(mainWindow.width, mainWindow.height)
                                                }
                                            }
                                        }
                                    }

                                    SettingsButton {
                                        text: mainWindow.visibility === Window.FullScreen ? "Exit Fullscreen" : "Fullscreen"
                                        Layout.preferredHeight: screenHeight.height
                                        Layout.minimumWidth: 80
                                        tooltipText: mainWindow.visibility === Window.FullScreen ? "Exit fullscreen mode" : "Enter fullscreen mode"
                                        onClicked: {
                                            if (mainWindow.visibility === Window.FullScreen) {
                                                mainWindow.visibility = Window.Windowed
                                                if (settingsManager) settingsManager.save_window_state("windowed")
                                            } else {
                                                mainWindow.visibility = Window.FullScreen
                                                if (settingsManager) settingsManager.save_window_state("fullscreen")
                                            }
                                        }
                                    }

                                    SettingsButton {
                                        text: "Maximize"
                                        Layout.preferredHeight: screenHeight.height
                                        Layout.minimumWidth: 80
                                        tooltipText: "Maximize window to fill screen"
                                        onClicked: {
                                            mainWindow.visibility = Window.Maximized
                                            if (settingsManager) settingsManager.save_window_state("maximized")
                                        }
                                    }

                                    Item { Layout.fillWidth: true } // Spacer
                                }
                            }

                            SettingsDivider {}
                            
                            ColumnLayout { // Theme Selection
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Theme"
                                }

                                // Update theme options when themes change
                                Connections {
                                    target: App.Style
                                    function onCustomThemesUpdated() {
                                        // Force refresh of theme options
                                        themeButton.options = App.Style.getAllThemeNames()
                                    }
                                }

                                // Theme selection chips
                                SettingsChips {
                                    id: themeButton
                                    Layout.fillWidth: true
                                    currentValue: settingsManager ? settingsManager.themeSetting : "Light"
                                    options: App.Style.getAllThemeNames()

                                    onSelected: function(value) {
                                        if (settingsManager) {
                                            mainWindow.updateTheme(value)
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { // Font Selection
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Font"
                                }

                                SettingDescription {
                                    text: "Drop .ttf/.otf files in the fonts folder"
                                }

                                // Update font options when fonts change
                                Connections {
                                    target: App.Style
                                    function onFontsUpdated() {
                                        fontButton.options = App.Style.availableFonts
                                    }
                                }

                                // Font selection chips
                                SettingsChips {
                                    id: fontButton
                                    Layout.fillWidth: true
                                    currentValue: settingsManager ? settingsManager.fontSetting : "System Default"
                                    options: App.Style.availableFonts

                                    onSelected: function(value) {
                                        if (settingsManager) {
                                            mainWindow.updateFont(value)
                                        }
                                    }
                                }
                            }

                            // Bottom spacer
                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // OBD Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing



                            // OBD Connection
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Connection Status"
                                }
                                
                                Rectangle {
                                    id: connectionStatusRect
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    
                                    // Use more diverse status colors
                                    property var statusColors: {
                                        "Connected": App.Style.accent,
                                        "Connecting": App.Style.statusWarning,
                                        "Device Not Found": App.Style.statusError,
                                        "Error": App.Style.statusError,
                                        "Disconnected": App.Style.statusDisconnected,
                                        "Device Lost": App.Style.statusWarning,
                                        "No Vehicle": App.Style.statusInfo
                                    }

                                    // Default to error color if status not in our map
                                    color: obdManager ?
                                        (statusColors[obdManager.get_connection_status()] || App.Style.statusError) :
                                        App.Style.statusError
                                    radius: 4
                                    
                                    // Properties for animations
                                    property bool connecting: obdManager ? 
                                        (obdManager.get_connection_status() === "Connecting") : false
                                    property real pulseOpacity: 0.7
                                    property real connectionProgress: obdManager ? 
                                        (obdManager._connectionProgress || 0) : 0
                                    
                                    // Progress indicator
                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            bottom: parent.bottom
                                        }
                                        width: parent.width * (connectionStatusRect.connectionProgress / 100)
                                        color: Qt.rgba(1, 1, 1, 0.2)
                                        radius: parent.radius
                                        visible: connectionStatusRect.connecting
                                    }
                                    
                                    // Pulse animation
                                    SequentialAnimation {
                                        id: pulseAnimation
                                        running: connectionStatusRect.connecting
                                        loops: Animation.Infinite
                                        
                                        NumberAnimation {
                                            target: connectionStatusRect
                                            property: "pulseOpacity"
                                            from: 0.7
                                            to: 1.0
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                        
                                        NumberAnimation {
                                            target: connectionStatusRect
                                            property: "pulseOpacity"
                                            from: 1.0
                                            to: 0.7
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    
                                    // Click animation
                                    SequentialAnimation {
                                        id: clickAnimation
                                        
                                        NumberAnimation {
                                            target: connectionStatusRect
                                            property: "scale"
                                            from: 1.0
                                            to: 0.95
                                            duration: 100
                                            easing.type: Easing.InOutQuad
                                        }
                                        
                                        NumberAnimation {
                                            target: connectionStatusRect
                                            property: "scale"
                                            from: 0.95
                                            to: 1.0
                                            duration: 100
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    
                                    // Text and spinner layout
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        
                                        // Main status row
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 10
                                            
                                            // Simple spinner using Rectangle animation
                                            Rectangle {
                                                id: spinner
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: "transparent"
                                                border.width: 2
                                                border.color: "white"
                                                visible: connectionStatusRect.connecting
                                                
                                                // Spinner dot that rotates around
                                                Rectangle {
                                                    id: spinnerDot
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: "white"
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.top: parent.top
                                                    anchors.topMargin: -3
                                                    
                                                    // Animation
                                                    RotationAnimation {
                                                        target: spinner
                                                        property: "rotation"
                                                        from: 0
                                                        to: 360
                                                        duration: 1200
                                                        loops: Animation.Infinite
                                                        running: connectionStatusRect.connecting
                                                    }
                                                }
                                            }
                                            
                                            // Status text
                                            Text {
                                                id: statusText
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: obdManager ? obdManager.get_connection_status() : "Not Connected"
                                                color: "white"
                                                font.pixelSize: App.Spacing.overallText
                                                font.family: settingsMenu.globalFont
                                                font.bold: true
                                                opacity: connectionStatusRect.connecting ? connectionStatusRect.pulseOpacity : 1.0
                                            }
                                        }
                                        
                                        // Detailed status text - only shown when available
                                        Text {
                                            id: detailText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: obdManager && obdManager._connectionDetail ?
                                                obdManager._connectionDetail : ""
                                            color: "white"
                                            font.pixelSize: App.Spacing.overallText * 0.7
                                            font.family: settingsMenu.globalFont
                                            visible: text !== ""
                                            opacity: 0.9
                                        }
                                    }
                                    
                                    // Click handling
                                    MouseArea {
                                        id: connectionClickArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        
                                        // Change cursor on hover
                                        cursorShape: Qt.PointingHandCursor
                    
                                        
                                        onClicked: {
                                            if (obdManager) {
                                                // Pop up the connection menu
                                                connectionMenu.popup()
                                            }
                                        }
                                    }
                                    
                                    // Connection menu with options
                                    Menu {
                                        id: connectionMenu

                                        MenuItem {
                                            text: "Reset Connection"
                                            onTriggered: {
                                                if (obdManager) {
                                                    clickAnimation.start()
                                                    obdManager.reset_connection()
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Connections to OBD manager
                                    Connections {
                                        target: obdManager
                                        
                                        function onConnectionStatusChanged(status) {
                                            connectionStatusRect.connecting = (status === "Connecting")
                                        }
                                        
                                        function onConnectionProgressChanged(progress) {
                                            connectionStatusRect.connectionProgress = progress
                                        }
                                        
                                        function onDevicePresenceChanged(present) {
                                            if (!present) {
                                                deviceNotFoundNotification.open()
                                            }
                                        }
                                    }
                                }

                                // Add notification popups
                                Popup {
                                    id: deviceNotFoundNotification
                                    x: (parent.width - width) / 2
                                    y: parent.height - height - 20
                                    width: 300
                                    height: 60
                                    modal: false
                                    focus: true
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                    
                                    background: Rectangle {
                                        color: App.Style.statusError
                                        radius: 4
                                    }

                                    contentItem: Text {
                                        text: "OBD device not found. Check connections."
                                        color: "white"
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    enter: Transition {
                                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                                    }
                                    
                                    exit: Transition {
                                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
                                    }
                                    
                                    Timer {
                                        interval: 3000
                                        running: deviceNotFoundNotification.visible
                                        onTriggered: deviceNotFoundNotification.close()
                                    }
                                }

                                SettingDescription {
                                    text: "Tap status bar to reconnect"
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Bluetooth Device Path
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Bluetooth Device"
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing
                                    
                                    SettingsTextField {
                                        id: bluetoothPortField
                                        Layout.fillWidth: true
                                        text: settingsManager ? settingsManager.obdBluetoothPort : "/dev/rfcomm0"
                                        
                                        onEditingFinished: {
                                            if (settingsManager && text.trim() !== "") {
                                                settingsManager.save_obd_bluetooth_port(text)
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "e.g. /dev/rfcomm0"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText * 0.8
                                        font.family: settingsMenu.globalFont
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Serial port for your Bluetooth OBD adapter"
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Fast Mode Toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                            
                                SettingsToggle {
                                    text: "Fast mode"
                                    Layout.fillWidth: true
                                    checked: settingsManager ? settingsManager.obdFastMode : true
                                    
                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_obd_fast_mode(checked)
                                        }
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Faster polling, may not work with all vehicles"
                                }
                            }

                            SettingsDivider {}

                            // Auto-Reconnect Attempts
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Reconnect Retries"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    SettingsSlider {
                                        id: autoReconnectSlider
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 10
                                        stepSize: 1
                                        value: settingsManager ? settingsManager.obdAutoReconnectAttempts : 0

                                        valueDisplay: value === 0 ? "Off" : value.toString()

                                        onMoved: {
                                            if (settingsManager) {
                                                settingsManager.save_obd_auto_reconnect_attempts(Math.round(value))
                                            }
                                        }
                                    }

                                    Text {
                                        text: autoReconnectSlider.value === 0 ? "Off" : autoReconnectSlider.value.toString()
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                        font.bold: true
                                        Layout.preferredWidth: 30
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                SettingDescription {
                                    text: "Retry attempts after disconnect (0 = off)"
                                }
                            }

                            SettingsDivider {}

                            // OBD Card Style
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: obdCardStyleToggle
                                    Layout.fillWidth: true
                                    text: "Circular gauges"
                                    checked: settingsManager ? settingsManager.get_setting_with_default("obdCardStyleCircular", false) : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_setting("obdCardStyleCircular", checked)
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Square cards or circular gauges (OBD page only)"
                                }
                            }

                            SettingsDivider {}

                            // Vehicle Scanner section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Vehicle Scan"
                                }

                                SettingDescription {
                                    text: "Detect which parameters your vehicle supports"
                                }

                                // Scan button
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    Button {
                                        id: vehicleScanButton
                                        property bool isScanning: false
                                        text: isScanning ? "Scanning..." : "Scan Vehicle"
                                        enabled: obdManager && obdManager.is_connected() && !isScanning
                                        implicitHeight: App.Spacing.overallSpacing * 2.5
                                        implicitWidth: vehicleScanButtonText.implicitWidth + App.Spacing.overallSpacing * 2

                                        scale: vehicleScanMouseArea.pressed ? 0.95 : 1.0
                                        opacity: enabled ? (vehicleScanMouseArea.pressed ? 0.8 : 1.0) : 0.5

                                        Behavior on scale {
                                            NumberAnimation { duration: 100; easing.type: Easing.OutBack }
                                        }

                                        background: Rectangle {
                                            color: vehicleScanButton.enabled ? App.Style.statusSuccess : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                                            radius: 4
                                        }

                                        contentItem: Text {
                                            id: vehicleScanButtonText
                                            text: vehicleScanButton.text
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.family: settingsMenu.globalFont
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: vehicleScanMouseArea
                                            anchors.fill: parent
                                            enabled: parent.enabled
                                            onClicked: {
                                                if (obdManager) {
                                                    vehicleScanTerminal.clear()
                                                    vehicleScanButton.isScanning = true
                                                    obdManager.scan_vehicle()
                                                }
                                            }
                                        }

                                        // Listen for scan completion
                                        Connections {
                                            target: obdManager
                                            function onScanCompleteChanged(supportedList) {
                                                vehicleScanButton.isScanning = false
                                            }
                                        }
                                    }

                                    Text {
                                        text: obdManager && obdManager.is_connected() ? "OBD Connected" : "Connect OBD first"
                                        color: obdManager && obdManager.is_connected() ? App.Style.statusSuccess : App.Style.statusError
                                        font.pixelSize: App.Spacing.smallText
                                        font.family: settingsMenu.globalFont
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                // Terminal output for scan progress
                                TerminalFeedback {
                                    id: vehicleScanTerminal
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    Layout.topMargin: App.Spacing.rowSpacing
                                    title: "Vehicle Scan Output"
                                    maxLines: 100

                                    // Connect to obdManager scan output signal
                                    Connections {
                                        target: obdManager
                                        function onScanOutputChanged(message) {
                                            vehicleScanTerminal.appendLine(message)
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Parameter selection
                            ColumnLayout {
                                id: parameterSelectionLayout
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Parameters"
                                }
                                
                                // Full parameter list for all operations
                                property var allOBDParameters: [
                                    // Original parameters
                                    "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE", "ENGINE_LOAD",
                                    "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                                    "MAF", "SPEED", "RPM", "COMMANDED_EQUIV_RATIO",
                                    "FUEL_LEVEL", "INTAKE_PRESSURE", "SHORT_FUEL_TRIM_1",
                                    "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                                    "OIL_TEMP", "IGNITION_TIMING",
                                    // Additional parameters
                                    "RUN_TIME", "DISTANCE_W_MIL", "FUEL_RAIL_PRESSURE_VAC",
                                    "FUEL_RAIL_PRESSURE_DIRECT", "BAROMETRIC_PRESSURE", "AMBIANT_AIR_TEMP",
                                    "RELATIVE_THROTTLE_POS", "THROTTLE_POS_B", "ACCELERATOR_POS_D",
                                    "CATALYST_TEMP_B1S1", "CATALYST_TEMP_B1S2", "EVAP_VAPOR_PRESSURE",
                                    "SHORT_FUEL_TRIM_2", "LONG_FUEL_TRIM_2", "O2_B1S2",
                                    "O2_B2S1", "O2_B2S2", "DISTANCE_SINCE_DTC_CLEAR",
                                    "WARMUPS_SINCE_DTC_CLEAR", "ABSOLUTE_LOAD", "COMMANDED_EGR",
                                    "EGR_ERROR", "ETHANOL_PERCENT",
                                    // Batch 2 - Additional O2 sensors
                                    "O2_B1S3", "O2_B1S4", "O2_B2S3", "O2_B2S4",
                                    // Wide-range O2 sensors voltage
                                    "O2_S1_WR_VOLTAGE", "O2_S2_WR_VOLTAGE", "O2_S3_WR_VOLTAGE", "O2_S4_WR_VOLTAGE",
                                    "O2_S5_WR_VOLTAGE", "O2_S6_WR_VOLTAGE", "O2_S7_WR_VOLTAGE", "O2_S8_WR_VOLTAGE",
                                    // Wide-range O2 sensors current
                                    "O2_S1_WR_CURRENT", "O2_S2_WR_CURRENT", "O2_S3_WR_CURRENT", "O2_S4_WR_CURRENT",
                                    "O2_S5_WR_CURRENT", "O2_S6_WR_CURRENT", "O2_S7_WR_CURRENT", "O2_S8_WR_CURRENT",
                                    // Bank 2 catalyst temps
                                    "CATALYST_TEMP_B2S1", "CATALYST_TEMP_B2S2",
                                    // Additional throttle/accelerator
                                    "THROTTLE_POS_C", "ACCELERATOR_POS_E", "ACCELERATOR_POS_F", "THROTTLE_ACTUATOR",
                                    // Fuel system
                                    "EVAPORATIVE_PURGE", "FUEL_RAIL_PRESSURE_ABS", "FUEL_INJECT_TIMING", "FUEL_RATE",
                                    // Time-based
                                    "RUN_TIME_MIL", "TIME_SINCE_DTC_CLEARED",
                                    // Other
                                    "MAX_MAF", "FUEL_TYPE", "EVAP_VAPOR_PRESSURE_ABS", "EVAP_VAPOR_PRESSURE_ALT",
                                    "SHORT_O2_TRIM_B1", "LONG_O2_TRIM_B1", "SHORT_O2_TRIM_B2", "LONG_O2_TRIM_B2",
                                    "RELATIVE_ACCEL_POS", "HYBRID_BATTERY_REMAINING", "ELM_VOLTAGE"
                                ]

                                // Scan vehicle state
                                property bool isScanning: false
                                property string scanStatus: ""
                                property int scanProgress: 0
                                property var supportedCommands: []

                                // Controls row (Select All and Deselect All buttons)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 10

                                    // Select All button
                                    Button {
                                        id: selectAllButton
                                        text: "Select All"
                                        implicitHeight: App.Spacing.overallSpacing * 2
                                        implicitWidth: selectAllButtonText.implicitWidth + App.Spacing.overallSpacing * 1.5

                                        // Add click animation
                                        scale: selectAllMouseArea.pressed ? 0.95 : 1.0
                                        opacity: selectAllMouseArea.pressed ? 0.8 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 100
                                                easing.type: Easing.OutBack
                                            }
                                        }

                                        Behavior on opacity {
                                            NumberAnimation { duration: 100 }
                                        }

                                        background: Rectangle {
                                            color: App.Style.accent
                                            radius: 4
                                            clip: true
                                        }

                                        contentItem: Text {
                                            id: selectAllButtonText
                                            text: selectAllButton.text
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.family: settingsMenu.globalFont
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: selectAllMouseArea
                                            anchors.fill: parent
                                            onClicked: {
                                                if (settingsManager) {
                                                    parameterSelectionLayout.allOBDParameters.forEach(function(param) {
                                                        settingsManager.save_obd_parameter_enabled(param, true);
                                                    });
                                                }
                                            }
                                        }
                                    }

                                    // Deselect All button
                                    Button {
                                        id: deselectAllButton
                                        text: "Deselect All"
                                        implicitHeight: App.Spacing.overallSpacing * 2
                                        implicitWidth: deselectAllButtonText.implicitWidth + App.Spacing.overallSpacing * 1.5

                                        // Add click animation
                                        scale: deselectAllMouseArea.pressed ? 0.95 : 1.0
                                        opacity: deselectAllMouseArea.pressed ? 0.8 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 100
                                                easing.type: Easing.OutBack
                                            }
                                        }

                                        Behavior on opacity {
                                            NumberAnimation { duration: 100 }
                                        }

                                        background: Rectangle {
                                            color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.5)
                                            radius: 4
                                            clip: true
                                        }

                                        contentItem: Text {
                                            id: deselectAllButtonText
                                            text: deselectAllButton.text
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.family: settingsMenu.globalFont
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: deselectAllMouseArea
                                            anchors.fill: parent
                                            onClicked: {
                                                if (settingsManager) {
                                                    parameterSelectionLayout.allOBDParameters.forEach(function(param) {
                                                        settingsManager.save_obd_parameter_enabled(param, false);
                                                    });
                                                }
                                            }
                                        }
                                    }

                                    // Spacer
                                    Item { Layout.fillWidth: true }

                                    // Parameter counter
                                    Text {
                                        id: enabledCount
                                        text: "0 of 0 enabled"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont

                                        // Count enabled parameters
                                        function updateEnabledCount() {
                                            if (!settingsManager) return;

                                            let count = 0;
                                            parameterSelectionLayout.allOBDParameters.forEach(function(param) {
                                                if (settingsManager.get_obd_parameter_enabled(param, false)) {
                                                    count++;
                                                }
                                            });

                                            enabledCount.text = count + " of " + parameterSelectionLayout.allOBDParameters.length + " enabled";
                                        }

                                        Component.onCompleted: {
                                            updateEnabledCount();
                                        }
                                    }
                                }

                                // Scan progress indicator (shown during scan)
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: parameterSelectionLayout.isScanning || parameterSelectionLayout.scanStatus !== ""
                                    spacing: 10

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 6
                                        color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.2)
                                        radius: 3

                                        Rectangle {
                                            width: parent.width * (parameterSelectionLayout.scanProgress / 100)
                                            height: parent.height
                                            color: App.Style.statusSuccess
                                            radius: 3

                                            Behavior on width {
                                                NumberAnimation { duration: 200 }
                                            }
                                        }
                                    }

                                    Text {
                                        text: parameterSelectionLayout.scanStatus
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText * 0.9
                                        font.family: settingsMenu.globalFont
                                    }
                                }

                                // OBD scan connections
                                Connections {
                                    target: obdManager

                                    function onScanProgressChanged(progress, message) {
                                        parameterSelectionLayout.scanProgress = progress;
                                        parameterSelectionLayout.scanStatus = message;
                                        parameterSelectionLayout.isScanning = progress < 100;
                                    }

                                    function onScanCompleteChanged(supportedParams) {
                                        parameterSelectionLayout.supportedCommands = supportedParams;
                                        parameterSelectionLayout.isScanning = false;

                                        // Auto-enable all supported parameters
                                        if (supportedParams.length > 0 && settingsManager) {
                                            supportedParams.forEach(function(param) {
                                                settingsManager.save_obd_parameter_enabled(param, true);
                                            });
                                        }
                                    }
                                }
                                
                                // Debounce timer for counter updates
                                Timer {
                                    id: updateCountTimer
                                    interval: 10
                                    running: false
                                    repeat: false
                                    onTriggered: {
                                        enabledCount.updateEnabledCount();
                                    }
                                }
                                
                                // Track settings changes
                                Connections {
                                    target: settingsManager
                                    function onObdParametersChanged() {
                                        updateCountTimer.restart();
                                    }
                                }
                                                    
                                // IMPROVED PARAMETER CHIPS AREA
                                Flow {
                                    id: parameterChipsFlow
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Layout.preferredHeight: childrenRect.height
                                    
                                    // Parameter chips model - all supported parameters
                                    property var parametersModel: [
                                        // Original parameters (enabled by default)
                                        { name: "Vehicle Speed", command: "SPEED" },
                                        { name: "Engine RPM", command: "RPM" },
                                        { name: "Coolant Temperature", command: "COOLANT_TEMP" },
                                        { name: "System Voltage", command: "CONTROL_MODULE_VOLTAGE" },
                                        { name: "Engine Load", command: "ENGINE_LOAD" },
                                        { name: "Throttle Position", command: "THROTTLE_POS" },
                                        { name: "Intake Temperature", command: "INTAKE_TEMP" },
                                        { name: "Timing Advance", command: "TIMING_ADVANCE" },
                                        { name: "Mass Air Flow", command: "MAF" },
                                        { name: "Air-Fuel Ratio", command: "COMMANDED_EQUIV_RATIO" },
                                        { name: "Fuel Level", command: "FUEL_LEVEL" },
                                        { name: "Intake Manifold Pressure", command: "INTAKE_PRESSURE" },
                                        { name: "Short Term Fuel Trim 1", command: "SHORT_FUEL_TRIM_1" },
                                        { name: "Long Term Fuel Trim 1", command: "LONG_FUEL_TRIM_1" },
                                        { name: "O2 Bank 1 Sensor 1", command: "O2_B1S1" },
                                        { name: "Fuel Pressure", command: "FUEL_PRESSURE" },
                                        { name: "Oil Temperature", command: "OIL_TEMP" },
                                        { name: "Ignition Timing", command: "IGNITION_TIMING" },
                                        // Additional parameters (disabled by default, enable via scan)
                                        { name: "Run Time", command: "RUN_TIME" },
                                        { name: "Distance w/ MIL", command: "DISTANCE_W_MIL" },
                                        { name: "Fuel Rail Pressure", command: "FUEL_RAIL_PRESSURE_VAC" },
                                        { name: "Fuel Rail Direct", command: "FUEL_RAIL_PRESSURE_DIRECT" },
                                        { name: "Barometric Pressure", command: "BAROMETRIC_PRESSURE" },
                                        { name: "Ambient Air Temp", command: "AMBIANT_AIR_TEMP" },
                                        { name: "Relative Throttle", command: "RELATIVE_THROTTLE_POS" },
                                        { name: "Throttle Position B", command: "THROTTLE_POS_B" },
                                        { name: "Accelerator Pedal", command: "ACCELERATOR_POS_D" },
                                        { name: "Catalyst Temp B1S1", command: "CATALYST_TEMP_B1S1" },
                                        { name: "Catalyst Temp B1S2", command: "CATALYST_TEMP_B1S2" },
                                        { name: "EVAP Vapor Pressure", command: "EVAP_VAPOR_PRESSURE" },
                                        { name: "Short Term Fuel Trim 2", command: "SHORT_FUEL_TRIM_2" },
                                        { name: "Long Term Fuel Trim 2", command: "LONG_FUEL_TRIM_2" },
                                        { name: "O2 Bank 1 Sensor 2", command: "O2_B1S2" },
                                        { name: "O2 Bank 2 Sensor 1", command: "O2_B2S1" },
                                        { name: "O2 Bank 2 Sensor 2", command: "O2_B2S2" },
                                        { name: "Distance Since Clear", command: "DISTANCE_SINCE_DTC_CLEAR" },
                                        { name: "Warmups Since Clear", command: "WARMUPS_SINCE_DTC_CLEAR" },
                                        { name: "Absolute Load", command: "ABSOLUTE_LOAD" },
                                        { name: "Commanded EGR", command: "COMMANDED_EGR" },
                                        { name: "EGR Error", command: "EGR_ERROR" },
                                        { name: "Ethanol Percent", command: "ETHANOL_PERCENT" },
                                        // Batch 2 - Additional O2 sensors
                                        { name: "O2 Bank 1 Sensor 3", command: "O2_B1S3" },
                                        { name: "O2 Bank 1 Sensor 4", command: "O2_B1S4" },
                                        { name: "O2 Bank 2 Sensor 3", command: "O2_B2S3" },
                                        { name: "O2 Bank 2 Sensor 4", command: "O2_B2S4" },
                                        // Wide-range O2 sensors voltage
                                        { name: "O2 S1 WR Voltage", command: "O2_S1_WR_VOLTAGE" },
                                        { name: "O2 S2 WR Voltage", command: "O2_S2_WR_VOLTAGE" },
                                        { name: "O2 S3 WR Voltage", command: "O2_S3_WR_VOLTAGE" },
                                        { name: "O2 S4 WR Voltage", command: "O2_S4_WR_VOLTAGE" },
                                        { name: "O2 S5 WR Voltage", command: "O2_S5_WR_VOLTAGE" },
                                        { name: "O2 S6 WR Voltage", command: "O2_S6_WR_VOLTAGE" },
                                        { name: "O2 S7 WR Voltage", command: "O2_S7_WR_VOLTAGE" },
                                        { name: "O2 S8 WR Voltage", command: "O2_S8_WR_VOLTAGE" },
                                        // Wide-range O2 sensors current
                                        { name: "O2 S1 WR Current", command: "O2_S1_WR_CURRENT" },
                                        { name: "O2 S2 WR Current", command: "O2_S2_WR_CURRENT" },
                                        { name: "O2 S3 WR Current", command: "O2_S3_WR_CURRENT" },
                                        { name: "O2 S4 WR Current", command: "O2_S4_WR_CURRENT" },
                                        { name: "O2 S5 WR Current", command: "O2_S5_WR_CURRENT" },
                                        { name: "O2 S6 WR Current", command: "O2_S6_WR_CURRENT" },
                                        { name: "O2 S7 WR Current", command: "O2_S7_WR_CURRENT" },
                                        { name: "O2 S8 WR Current", command: "O2_S8_WR_CURRENT" },
                                        // Bank 2 catalyst temps
                                        { name: "Catalyst Temp B2S1", command: "CATALYST_TEMP_B2S1" },
                                        { name: "Catalyst Temp B2S2", command: "CATALYST_TEMP_B2S2" },
                                        // Additional throttle/accelerator
                                        { name: "Throttle Position C", command: "THROTTLE_POS_C" },
                                        { name: "Accelerator Pos E", command: "ACCELERATOR_POS_E" },
                                        { name: "Accelerator Pos F", command: "ACCELERATOR_POS_F" },
                                        { name: "Throttle Actuator", command: "THROTTLE_ACTUATOR" },
                                        // Fuel system
                                        { name: "EVAP Purge", command: "EVAPORATIVE_PURGE" },
                                        { name: "Fuel Rail Abs", command: "FUEL_RAIL_PRESSURE_ABS" },
                                        { name: "Fuel Inject Timing", command: "FUEL_INJECT_TIMING" },
                                        { name: "Fuel Rate", command: "FUEL_RATE" },
                                        // Time-based
                                        { name: "Run Time w/ MIL", command: "RUN_TIME_MIL" },
                                        { name: "Time Since Clear", command: "TIME_SINCE_DTC_CLEARED" },
                                        // Other
                                        { name: "Max MAF", command: "MAX_MAF" },
                                        { name: "Fuel Type", command: "FUEL_TYPE" },
                                        { name: "EVAP Pressure Abs", command: "EVAP_VAPOR_PRESSURE_ABS" },
                                        { name: "EVAP Pressure Alt", command: "EVAP_VAPOR_PRESSURE_ALT" },
                                        { name: "Short O2 Trim B1", command: "SHORT_O2_TRIM_B1" },
                                        { name: "Long O2 Trim B1", command: "LONG_O2_TRIM_B1" },
                                        { name: "Short O2 Trim B2", command: "SHORT_O2_TRIM_B2" },
                                        { name: "Long O2 Trim B2", command: "LONG_O2_TRIM_B2" },
                                        { name: "Rel. Accel Position", command: "RELATIVE_ACCEL_POS" },
                                        { name: "Hybrid Battery", command: "HYBRID_BATTERY_REMAINING" },
                                        { name: "ELM Voltage", command: "ELM_VOLTAGE" }
                                    ]
                                    
                                    // Original parameters that are enabled by default
                                    property var originalParameters: [
                                        "SPEED", "RPM", "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE",
                                        "ENGINE_LOAD", "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                                        "MAF", "COMMANDED_EQUIV_RATIO", "FUEL_LEVEL", "INTAKE_PRESSURE",
                                        "SHORT_FUEL_TRIM_1", "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                                        "OIL_TEMP", "IGNITION_TIMING"
                                    ]

                                    // Helper function to get the default enabled state for a parameter
                                    function isOriginalParameter(command) {
                                        return originalParameters.indexOf(command) !== -1;
                                    }

                                    Repeater {
                                        model: parameterChipsFlow.parametersModel

                                        delegate: Rectangle {
                                            id: paramChip
                                            width: Math.min(parameterChipsFlow.width * 0.3, 400)
                                            height: App.Spacing.settingsButtonHeight*.8
                                            radius: 12

                                            // Check if this is an original parameter (enabled by default)
                                            property bool isOriginal: parameterChipsFlow.isOriginalParameter(modelData.command)

                                            // Bind the color directly to the parameter's enabled state
                                            property bool isEnabled: settingsManager ?
                                                settingsManager.get_obd_parameter_enabled(modelData.command, isOriginal) : isOriginal

                                            // Track if this parameter is on the home screen
                                            property bool isOnHomeScreen: {
                                                if (!settingsManager) return false;
                                                let homeParams = settingsManager.get_home_obd_parameters();
                                                return homeParams.indexOf(modelData.command) !== -1;
                                            }

                                            // Use a darker background for disabled chips to improve contrast
                                            color: isEnabled ?
                                                Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) :
                                                Qt.rgba(App.Style.backgroundColor.r, App.Style.backgroundColor.g, App.Style.backgroundColor.b, 0.5)

                                            border.width: 1
                                            border.color: isEnabled ?
                                                App.Style.accent :
                                                Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.3)

                                            // Add click animation
                                            scale: chipMouseArea.pressed ? 0.97 : 1.0
                                            opacity: chipMouseArea.pressed ? 0.9 : 1.0

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 100
                                                    easing.type: Easing.OutQuad
                                                }
                                            }

                                            Behavior on opacity {
                                                NumberAnimation { duration: 100 }
                                            }

                                            // Update enabled state when settings change
                                            Connections {
                                                target: settingsManager
                                                function onObdParametersChanged() {
                                                    if (settingsManager) {
                                                        paramChip.isEnabled = settingsManager.get_obd_parameter_enabled(modelData.command, paramChip.isOriginal);
                                                    }
                                                }
                                                
                                                function onHomeOBDParametersChanged() {
                                                    if (settingsManager) {
                                                        let homeParams = settingsManager.get_home_obd_parameters();
                                                        paramChip.isOnHomeScreen = homeParams.indexOf(modelData.command) !== -1;
                                                        homeButton.updateHomeStatus();
                                                    }
                                                }
                                            }
                                            
                                            RowLayout {
                                                anchors {
                                                    fill: parent
                                                    margins: 12
                                                }
                                                spacing: 8

                                                // Parameter name - always make the text visible regardless of enabled state
                                                Text {
                                                    text: modelData.name
                                                    color: App.Style.primaryTextColor
                                                    font.pixelSize: App.Spacing.overallText
                                                    font.family: settingsMenu.globalFont
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                                
                                                // Add home button
                                                HomeScreenButton {
                                                    id: homeButton
                                                    isActive: paramChip.isOnHomeScreen
                                                    
                                                    function updateHomeStatus() {
                                                        if (settingsManager) {
                                                            let homeParams = settingsManager.get_home_obd_parameters();
                                                            isActive = homeParams.indexOf(modelData.command) !== -1;
                                                        }
                                                    }
                                                    
                                                    Component.onCompleted: {
                                                        updateHomeStatus();
                                                    }
                                                    
                                                    onClicked: {
                                                        if (settingsManager) {
                                                            let homeParams = settingsManager.get_home_obd_parameters();
                                                            
                                                            if (isActive) {
                                                                // Remove from home screen
                                                                let index = homeParams.indexOf(modelData.command);
                                                                if (index !== -1) {
                                                                    homeParams.splice(index, 1);
                                                                    settingsManager.save_home_obd_parameters(homeParams);
                                                                }
                                                            } else {
                                                                // Add to home screen if space available (max 8)
                                                                if (homeParams.length < 8) {
                                                                    homeParams.push(modelData.command);
                                                                    settingsManager.save_home_obd_parameters(homeParams);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Simple click area with animation
                                            MouseArea {
                                                id: chipMouseArea
                                                anchors.fill: parent
                                                anchors.rightMargin: 64 // Leave space for home button
                                                onClicked: {
                                                    if (settingsManager) {
                                                        // Toggle the enabled state
                                                        let newState = !paramChip.isEnabled;
                                                        settingsManager.save_obd_parameter_enabled(modelData.command, newState);
                                                        updateCountTimer.restart();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Initialize counter on load
                                Component.onCompleted: {
                                    Qt.callLater(function() {
                                        if (enabledCount) {
                                            enabledCount.updateEnabledCount();
                                        }
                                    });
                                }
                            }
                            
                            // Bottom spacer
                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }

                            function updateHomeDisplay() {
                                // Force refresh of home parameters display
                                homeParametersRepeater.model = [];
                                Qt.callLater(function() {
                                    if (settingsManager) {
                                        homeParametersRepeater.model = settingsManager.get_home_obd_parameters();
                                        homeParametersEmptyRepeater.model = Math.max(0, 8 - (settingsManager ? settingsManager.get_home_obd_parameters().length : 0));

                                        // Also update all home buttons in the parameter list
                                        for (let i = 0; i < parameterListView.count; i++) {
                                            let item = parameterListView.itemAtIndex(i);
                                            if (item && item.homeButton) {
                                                item.homeButton.updateHomeStatus();
                                            }
                                        }
                                    }
                                });
                            }
                        }
                    }

                    ScrollView { // Clock Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing



                            // Show Clock Toggle - Using the new toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingsToggle {
                                    text: "Show clock"
                                    Layout.fillWidth: true
                                    checked: settingsManager ? settingsManager.showClock : true
                                    
                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_show_clock(checked)
                                        }
                                    }
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Clock Format Options - Using segmented control
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Time Format"
                                }
                                
                                SettingsSegmentedControl {
                                    id: timeFormatControl
                                    Layout.fillWidth: true
                                    options: ["24-hour", "12-hour (AM/PM)"]
                                    currentValue: settingsManager ? 
                                                (settingsManager.clockFormat24Hour ? "24-hour" : "12-hour (AM/PM)") : 
                                                "24-hour"
                                    
                                    onSelected: function(value) {
                                        if (settingsManager) {
                                            settingsManager.save_clock_format(value === "24-hour")
                                        }
                                    }
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Clock Size Slider - Keep this as is
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Clock Size"
                                }
                                
                                SettingsSlider {
                                    id: clockSizeSlider
                                    from: 10
                                    to: 85
                                    stepSize: 1
                                    value: settingsManager ? settingsManager.clockSize : 18
                                    
                                    onMoved: {
                                        if (settingsManager) {
                                            settingsManager.save_clock_size(value)
                                        }
                                    }
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    ValueDisplay {
                                        text: clockSizeSlider.value.toFixed(0) + " pixels"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                }
                            }
                            
                            // Bottom spacer
                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // Android Auto Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing



                            // Enable/Disable Android Auto
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: androidAutoEnabledToggle
                                    Layout.fillWidth: true
                                    text: "Show in nav bar"
                                    checked: settingsManager ? settingsManager.androidAutoEnabled : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_android_auto_enabled(checked)
                                        }
                                    }

                                    // Update when setting changes externally
                                    Connections {
                                        target: settingsManager
                                        function onAndroidAutoEnabledChanged() {
                                            androidAutoEnabledToggle.checked = settingsManager.androidAutoEnabled
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Requires Android Auto app and Developer Mode on your phone."
                                }
                            }

                            SettingsDivider {}

                            // Bottom spacer
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // Phone Mirror Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing



                            // Enable/Disable Phone Mirror
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: phoneMirrorEnabledToggle
                                    Layout.fillWidth: true
                                    text: "Show in nav bar"
                                    checked: settingsManager ? settingsManager.phoneMirrorEnabled : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_phone_mirror_enabled(checked)
                                        }
                                    }

                                    // Update when setting changes externally
                                    Connections {
                                        target: settingsManager
                                        function onPhoneMirrorEnabledChanged() {
                                            phoneMirrorEnabledToggle.checked = settingsManager.phoneMirrorEnabled
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Requires scrcpy and USB debugging enabled."
                                }
                            }

                            SettingsDivider {}

                            // Scrcpy Path Setting
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Scrcpy Path"
                                }

                                SettingDescription {
                                    text: "Leave empty to auto-detect from PATH"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    SettingsTextField {
                                        id: scrcpyPathField
                                        Layout.fillWidth: true
                                        text: settingsManager ? settingsManager.scrcpyPath : ""
                                        placeholderText: "Auto-detect"

                                        onEditingFinished: {
                                            if (settingsManager) {
                                                settingsManager.save_scrcpy_path(text)
                                                if (phoneMirrorManager) {
                                                    phoneMirrorManager.setScrcpyPath(text)
                                                }
                                            }
                                        }
                                    }

                                    SettingsButton {
                                        text: "Browse"
                                        Layout.preferredHeight: scrcpyPathField.height
                                        tooltipText: "Browse for scrcpy executable"
                                        onClicked: scrcpyFileDialog.open()
                                    }
                                }

                                // Update when setting changes externally
                                Connections {
                                    target: settingsManager
                                    function onScrcpyPathChanged() {
                                        scrcpyPathField.text = settingsManager.scrcpyPath
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Audio Forwarding Setting
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Audio Forwarding"
                                }

                                SettingsToggle {
                                    id: scrcpyAudioEnabledToggle
                                    Layout.fillWidth: true
                                    text: "Forward phone audio"
                                    checked: settingsManager ? settingsManager.scrcpyAudioEnabled : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            settingsManager.save_scrcpy_audio_enabled(checked)
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onScrcpyAudioEnabledChanged() {
                                            scrcpyAudioEnabledToggle.checked = settingsManager.scrcpyAudioEnabled
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Requires scrcpy 2.0+ and Android 11+"
                                }
                            }

                            SettingsDivider {}

                            // Status Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Status"
                                }

                                SettingDescription {
                                    text: phoneMirrorManager && phoneMirrorManager.isScrcpyInstalled
                                        ? "scrcpy found: " + phoneMirrorManager.scrcpyPath
                                        : "scrcpy not found. Set the path above or download from github.com/Genymobile/scrcpy"
                                    color: phoneMirrorManager && phoneMirrorManager.isScrcpyInstalled
                                        ? App.Style.statusConnected
                                        : App.Style.statusError
                                }
                            }

                            SettingsDivider {}

                            // Bottom spacer
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // Volume Knob Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            id: volumeKnobSettingsColumn
                            width: parent.width
                            spacing: App.Spacing.sectionSpacing

                            // Port data model
                            property var portsModel: []

                            function refreshPorts() {
                                if (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager) {
                                    try {
                                        var jsonStr = esp32VolumeManager.get_ports_with_descriptions()
                                        portsModel = JSON.parse(jsonStr)
                                    } catch (e) {
                                        portsModel = []
                                    }
                                }
                            }

                            Component.onCompleted: refreshPorts()



                            // Connection Status Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.overallSpacing

                                Rectangle {
                                    id: esp32StatusDot
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager && esp32VolumeManager.is_connected()) ? App.Style.statusConnected : App.Style.statusDisconnected

                                    Connections {
                                        target: typeof esp32VolumeManager !== "undefined" ? esp32VolumeManager : null
                                        function onConnectionStatusChanged(status) {
                                            esp32StatusDot.color = esp32VolumeManager.is_connected() ? App.Style.statusConnected : App.Style.statusDisconnected
                                        }
                                    }
                                }

                                Text {
                                    id: esp32StatusText
                                    text: (typeof esp32VolumeManager !== "undefined" && esp32VolumeManager) ? esp32VolumeManager.get_connection_detail() : "Not initialized"
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: settingsMenu.globalFont
                                    Layout.fillWidth: true

                                    Connections {
                                        target: typeof esp32VolumeManager !== "undefined" ? esp32VolumeManager : null
                                        function onConnectionDetailChanged(detail) {
                                            esp32StatusText.text = esp32VolumeManager.get_connection_detail()
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Serial Port Selection with chips
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    SettingLabel {
                                        text: "USB Serial Port"
                                        Layout.fillWidth: true
                                    }

                                    // Refresh button chip
                                    Rectangle {
                                        width: refreshChipText.width + App.Spacing.overallSpacing * 2
                                        height: App.Spacing.formElementHeight * 0.7
                                        radius: height / 2
                                        color: refreshChipArea.containsMouse ? App.Style.hoverColor : "transparent"
                                        border.width: 1
                                        border.color: App.Style.hoverColor

                                        Text {
                                            id: refreshChipText
                                            text: "⟳ Refresh"
                                            anchors.centerIn: parent
                                            color: App.Style.secondaryTextColor
                                            font.pixelSize: App.Spacing.overallText * 0.9
                                            font.family: settingsMenu.globalFont
                                        }

                                        MouseArea {
                                            id: refreshChipArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: volumeKnobSettingsColumn.refreshPorts()
                                        }
                                    }
                                }

                                // Port chips using Flow layout
                                Flow {
                                    id: portChipsFlow
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    Repeater {
                                        model: volumeKnobSettingsColumn.portsModel

                                        Rectangle {
                                            id: portChip
                                            width: portChipContent.width + App.Spacing.overallSpacing * 3
                                            height: App.Spacing.formElementHeight * 0.9
                                            radius: height / 2

                                            property bool isSelected: settingsManager && settingsManager.esp32VolumePort === modelData.port

                                            color: isSelected ? App.Style.accent : App.Style.hoverColor
                                            border.width: isSelected ? 0 : 1
                                            border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                                App.Style.primaryTextColor.g,
                                                                App.Style.primaryTextColor.b, 0.1)

                                            scale: portChipArea.pressed ? 0.97 : (portChipArea.containsMouse ? 1.03 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                            layer.enabled: isSelected
                                            layer.effect: DropShadow {
                                                horizontalOffset: 0
                                                verticalOffset: 2
                                                radius: 4.0
                                                samples: 9
                                                color: "#40000000"
                                            }

                                            Row {
                                                id: portChipContent
                                                anchors.centerIn: parent
                                                spacing: 6

                                                // Star indicator for ESP32-S3
                                                Text {
                                                    visible: modelData.isEsp32S3
                                                    text: "★"
                                                    color: portChip.isSelected ? "white" : App.Style.accent
                                                    font.pixelSize: App.Spacing.overallText * 0.9
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: modelData.port
                                                    color: portChip.isSelected ? "white" : App.Style.primaryTextColor
                                                    font.pixelSize: App.Spacing.overallText
                                                    font.family: settingsMenu.globalFont
                                                    font.bold: modelData.isEsp32S3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: portChipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (settingsManager) {
                                                        settingsManager.save_esp32_volume_port(modelData.port)
                                                        // Auto-enable and connect when port selected
                                                        if (!settingsManager.esp32VolumeEnabled) {
                                                            settingsManager.save_esp32_volume_enabled(true)
                                                        }
                                                        if (esp32VolumeManager) {
                                                            esp32VolumeManager.reset_reconnect_attempts()
                                                            esp32VolumeManager.connect_device()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // "No ports" message chip
                                    Rectangle {
                                        visible: volumeKnobSettingsColumn.portsModel.length === 0
                                        width: noPortsText.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight * 0.9
                                        radius: height / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                            App.Style.primaryTextColor.g,
                                                            App.Style.primaryTextColor.b, 0.2)

                                        Text {
                                            id: noPortsText
                                            text: "No ports found - click Refresh"
                                            anchors.centerIn: parent
                                            color: App.Style.secondaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            font.family: settingsMenu.globalFont
                                        }
                                    }
                                }

                                // Port description (shown for selected port)
                                Text {
                                    visible: {
                                        if (!settingsManager || !settingsManager.esp32VolumePort) return false
                                        for (var i = 0; i < volumeKnobSettingsColumn.portsModel.length; i++) {
                                            if (volumeKnobSettingsColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                                return true
                                            }
                                        }
                                        return false
                                    }
                                    text: {
                                        if (!settingsManager || !settingsManager.esp32VolumePort) return ""
                                        for (var i = 0; i < volumeKnobSettingsColumn.portsModel.length; i++) {
                                            if (volumeKnobSettingsColumn.portsModel[i].port === settingsManager.esp32VolumePort) {
                                                return volumeKnobSettingsColumn.portsModel[i].description
                                            }
                                        }
                                        return ""
                                    }
                                    color: App.Style.secondaryTextColor
                                    font.pixelSize: App.Spacing.overallText * 0.9
                                    font.family: settingsMenu.globalFont
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                }
                            }

                            SettingsDivider {}

                            // Volume Step Size Slider
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                RowLayout {
                                    Layout.fillWidth: true

                                    SettingLabel {
                                        text: "Volume Step Size"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: settingsManager ? settingsManager.esp32VolumeStepSize.toFixed(2) + "%" : "1.00%"
                                        color: App.Style.accent
                                        font.pixelSize: App.Spacing.overallText * 1.2
                                        font.family: settingsMenu.globalFont
                                        font.bold: true
                                    }
                                }

                                SettingDescription {
                                    text: "Volume change per encoder tick"
                                }

                                // Slider
                                Slider {
                                    id: volumeStepSlider
                                    Layout.fillWidth: true
                                    from: 0.25
                                    to: 10.0
                                    stepSize: 0.25
                                    value: settingsManager ? settingsManager.esp32VolumeStepSize : 1.0

                                    onMoved: {
                                        if (settingsManager) {
                                            settingsManager.save_esp32_volume_step_size(value)
                                        }
                                    }

                                    // Update slider when setting changes externally
                                    Connections {
                                        target: settingsManager
                                        function onEsp32VolumeStepSizeChanged(size) {
                                            volumeStepSlider.value = size
                                        }
                                    }

                                    background: Rectangle {
                                        x: volumeStepSlider.leftPadding
                                        y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: volumeStepSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: App.Style.hoverColor

                                        Rectangle {
                                            width: volumeStepSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: App.Style.accent
                                            radius: 3
                                        }
                                    }

                                    handle: Rectangle {
                                        x: volumeStepSlider.leftPadding + volumeStepSlider.visualPosition * (volumeStepSlider.availableWidth - width)
                                        y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 10
                                        color: volumeStepSlider.pressed ? Qt.darker(App.Style.accent, 1.1) : App.Style.accent
                                        border.color: "white"
                                        border.width: 2

                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }

                                // Quick preset chips
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing * 0.8

                                    Repeater {
                                        model: [0.25, 0.5, 1.0, 2.0, 5.0]

                                        Rectangle {
                                            width: presetText.width + App.Spacing.overallSpacing * 2
                                            height: App.Spacing.formElementHeight * 0.7
                                            radius: height / 2

                                            property bool isSelected: settingsManager && Math.abs(settingsManager.esp32VolumeStepSize - modelData) < 0.01

                                            color: isSelected ? App.Style.accent : "transparent"
                                            border.width: 1
                                            border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                                            scale: presetArea.pressed ? 0.95 : (presetArea.containsMouse ? 1.03 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 100 } }

                                            Text {
                                                id: presetText
                                                anchors.centerIn: parent
                                                text: modelData + "%"
                                                color: parent.isSelected ? "white" : App.Style.secondaryTextColor
                                                font.pixelSize: App.Spacing.overallText * 0.9
                                                font.family: settingsMenu.globalFont
                                            }

                                            MouseArea {
                                                id: presetArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (settingsManager) {
                                                        settingsManager.save_esp32_volume_step_size(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // LED Settings Section
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "LED Indicator"
                                    font.pixelSize: App.Spacing.overallText * 1.2
                                    font.bold: true
                                }

                                SettingDescription {
                                    text: "RGB LED indicator on the ESP32-S3 receiver"
                                }
                            }

                            // LED Keep Alive Toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingsToggle {
                                    id: ledSleepToggle
                                    Layout.fillWidth: true
                                    text: "Keep LEDs on"
                                    // Inverted: sleep enabled = keep alive OFF, sleep disabled = keep alive ON
                                    checked: settingsManager ? !settingsManager.esp32LedSleepEnabled : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: function(checked) {
                                        if (settingsManager) {
                                            // Inverted: switch ON = sleep disabled, switch OFF = sleep enabled
                                            settingsManager.save_esp32_led_sleep_enabled(!checked)
                                        }
                                    }

                                    Connections {
                                        target: settingsManager
                                        function onEsp32LedSleepEnabledChanged(enabled) {
                                            // Inverted display
                                            ledSleepToggle.checked = !enabled
                                        }
                                    }
                                }

                                SettingDescription {
                                    text: "Stay on while OCTAVE runs (off = sleep after 5s idle)"
                                }
                            }

                            SettingsDivider {}

                            // LED Color Mode
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Color Mode"
                                }

                                SettingDescription {
                                    text: "Album art accent colors or a fixed color"
                                }

                                // Color mode chips
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    Rectangle {
                                        width: themeModeContent.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight * 0.9
                                        radius: height / 2

                                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "theme"

                                        color: isSelected ? App.Style.accent : "transparent"
                                        border.width: 1
                                        border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                                        scale: themeModeArea.pressed ? 0.97 : (themeModeArea.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            id: themeModeContent
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "🎨"
                                                font.pixelSize: App.Spacing.overallText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Theme Colors"
                                                color: parent.parent.isSelected ? "white" : App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.overallText
                                                font.family: settingsMenu.globalFont
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: themeModeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (settingsManager) {
                                                    settingsManager.save_esp32_led_color_mode("theme")
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: staticModeContent.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight * 0.9
                                        radius: height / 2

                                        property bool isSelected: settingsManager && settingsManager.esp32LedColorMode === "static"

                                        color: isSelected ? App.Style.accent : "transparent"
                                        border.width: 1
                                        border.color: isSelected ? App.Style.accent : App.Style.hoverColor

                                        scale: staticModeArea.pressed ? 0.97 : (staticModeArea.containsMouse ? 1.03 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            id: staticModeContent
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Rectangle {
                                                width: App.Spacing.overallText
                                                height: App.Spacing.overallText
                                                radius: width / 2
                                                color: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.3)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Static Color"
                                                color: parent.parent.isSelected ? "white" : App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.overallText
                                                font.family: settingsMenu.globalFont
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: staticModeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (settingsManager) {
                                                    settingsManager.save_esp32_led_color_mode("static")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Static Color Picker (only shown when static mode is selected)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                visible: settingsManager && settingsManager.esp32LedColorMode === "static"

                                SettingLabel {
                                    text: "Static Color"
                                }

                                // Color preset chips
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing * 0.8

                                    Repeater {
                                        model: [
                                            { color: "#00FFFF", name: "Cyan" },
                                            { color: "#FF0080", name: "Pink" },
                                            { color: "#00FF00", name: "Green" },
                                            { color: "#FF8000", name: "Orange" },
                                            { color: "#8000FF", name: "Purple" },
                                            { color: "#FFFF00", name: "Yellow" },
                                            { color: "#0080FF", name: "Blue" },
                                            { color: "#FF0000", name: "Red" },
                                            { color: "#FFFFFF", name: "White" }
                                        ]

                                        Rectangle {
                                            width: colorChipRow.width + App.Spacing.overallSpacing * 2
                                            height: App.Spacing.formElementHeight * 0.8
                                            radius: height / 2

                                            property bool isSelected: settingsManager && settingsManager.esp32LedStaticColor.toUpperCase() === modelData.color

                                            color: isSelected ? modelData.color : "transparent"
                                            border.width: 2
                                            border.color: modelData.color

                                            scale: colorChipArea.pressed ? 0.95 : (colorChipArea.containsMouse ? 1.05 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 100 } }

                                            Row {
                                                id: colorChipRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Rectangle {
                                                    width: 12
                                                    height: 12
                                                    radius: 6
                                                    color: modelData.color
                                                    border.width: 1
                                                    border.color: Qt.rgba(0, 0, 0, 0.2)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !parent.parent.isSelected
                                                }

                                                Text {
                                                    text: modelData.name
                                                    color: parent.parent.isSelected ?
                                                           (modelData.color === "#FFFFFF" || modelData.color === "#FFFF00" || modelData.color === "#00FF00" ? "#000000" : "#FFFFFF") :
                                                           App.Style.primaryTextColor
                                                    font.pixelSize: App.Spacing.overallText * 0.9
                                                    font.family: settingsMenu.globalFont
                                                    font.bold: parent.parent.isSelected
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: colorChipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (settingsManager) {
                                                        settingsManager.save_esp32_led_static_color(modelData.color)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Custom color input
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    Text {
                                        text: "Custom:"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont
                                    }

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 4
                                        color: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                                        border.width: 2
                                        border.color: App.Style.hoverColor
                                    }

                                    TextField {
                                        id: customColorField
                                        Layout.preferredWidth: 100
                                        text: settingsManager ? settingsManager.esp32LedStaticColor : "#00FFFF"
                                        placeholderText: "#RRGGBB"
                                        font.pixelSize: App.Spacing.overallText
                                        font.family: settingsMenu.globalFont

                                        background: Rectangle {
                                            color: App.Style.hoverColor
                                            radius: 4
                                            border.width: customColorField.activeFocus ? 2 : 0
                                            border.color: App.Style.accent
                                        }

                                        color: App.Style.primaryTextColor

                                        onEditingFinished: {
                                            if (settingsManager && /^#[0-9A-Fa-f]{6}$/.test(text)) {
                                                settingsManager.save_esp32_led_static_color(text.toUpperCase())
                                            }
                                        }

                                        Connections {
                                            target: settingsManager
                                            function onEsp32LedStaticColorChanged(color) {
                                                customColorField.text = color
                                            }
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            // Bottom spacer
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBarHeight
                            }
                        }
                    }

                    ScrollView { // About Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 0

                            // Use a GridLayout for better control over positioning
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.margins: App.Spacing.overallMargin * 2
                                columns: 1
                                rowSpacing: App.Spacing.overallSpacing * 2
                                
                                // Title with adequate spacing from content
                                Item {
                                    Layout.fillWidth: true
                                    width: parent.width
                                    height: 100

                                    // Glow "shadow" layer
                                    Text {
                                        id: glowText
                                        text: "OCTAVE"
                                        font.pixelSize: App.Spacing.overallText * 5
                                        font.family: settingsMenu.globalFont
                                        font.bold: true
                                        color: App.Style.primaryTextColor
                                        opacity: 0.5
                                        anchors.centerIn: parent
                                        scale: 1.05
                                        z: 0

                                        // Pulsing animation
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.3; to: 0.7; duration: 600; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.7; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    // Main text layer
                                    Text {
                                        id: titleText
                                        text: "OCTAVE"
                                        font.pixelSize: App.Spacing.overallText * 5
                                        font.family: settingsMenu.globalFont
                                        font.bold: true
                                        color: App.Style.accent
                                        anchors.centerIn: parent
                                        z: 1
                                    }
                                }

                                // Build/Commit info section
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: commitInfoColumn.implicitHeight + App.Spacing.overallSpacing * 2
                                    color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)
                                    radius: App.Spacing.overallRadius

                                    ColumnLayout {
                                        id: commitInfoColumn
                                        anchors.fill: parent
                                        anchors.margins: App.Spacing.overallSpacing
                                        spacing: App.Spacing.overallSpacing * 0.5

                                        Text {
                                            text: "Latest Build"
                                            color: App.Style.accent
                                            font.pixelSize: App.Spacing.overallText * 0.9
                                            font.family: settingsMenu.globalFont
                                            font.bold: true
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: App.Spacing.overallSpacing

                                            Text {
                                                text: "Commit:"
                                                color: App.Style.secondaryTextColor
                                                font.pixelSize: App.Spacing.overallText * 0.85
                                                font.family: settingsMenu.globalFont
                                            }
                                            Text {
                                                text: settingsManager ? settingsManager.get_git_commit_hash() : "unknown"
                                                color: App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.overallText * 0.85
                                                font.family: settingsMenu.globalFont
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: App.Spacing.overallSpacing

                                            Text {
                                                text: "Date:"
                                                color: App.Style.secondaryTextColor
                                                font.pixelSize: App.Spacing.overallText * 0.85
                                                font.family: settingsMenu.globalFont
                                            }
                                            Text {
                                                text: settingsManager ? settingsManager.get_git_commit_date() : "unknown"
                                                color: App.Style.primaryTextColor
                                                font.pixelSize: App.Spacing.overallText * 0.85
                                                font.family: settingsMenu.globalFont
                                            }
                                        }

                                        Text {
                                            text: settingsManager ? settingsManager.get_git_commit_message() : ""
                                            color: App.Style.secondaryTextColor
                                            font.pixelSize: App.Spacing.overallText * 0.8
                                            font.family: settingsMenu.globalFont
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                        }
                                    }
                                }

                                // Description text
                                Text {
                                    id: descriptionText
                                    text: "Welcome to OCTAVE, an open-source, cross-platform telematics system for an augmented vehicle experience. Developed by Way Better Solutions, our mission is simple: we make things better.\n\nThis software is designed to provide a seamless interface for vehicle systems, media playback, navigation, and more."
                                    wrapMode: Text.WordWrap
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: settingsMenu.globalFont
                                    Layout.fillWidth: true
                                    Layout.topMargin: App.Spacing.overallSpacing
                                }
                                
                                // Separator
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: App.Style.hoverColor
                                    Layout.topMargin: App.Spacing.overallSpacing
                                    Layout.bottomMargin: App.Spacing.overallSpacing
                                }
                                
                                // GitHub Link section
                                Text {
                                    text: "GitHub Repository"
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText * 1.2
                                    font.family: settingsMenu.globalFont
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                
                                // GitHub link
                                Text {
                                    text: "<a href='https://github.com/WayBetterSolutions/OCTAVE'>github.com/WayBetterSolutions/OCTAVE</a>"
                                    color: App.Style.accent
                                    linkColor: App.Style.accent
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: settingsMenu.globalFont
                                    Layout.fillWidth: true
                                    onLinkActivated: Qt.openUrlExternally(link)
                                }
                                
                                Text {
                                    text: "2026 Way Better Solutions"
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
                                    font.family: settingsMenu.globalFont
                                    Layout.fillWidth: true
                                    Layout.topMargin: App.Spacing.overallSpacing
                                }
                                
                                // Bottom spacer
                                Item { 
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: App.Spacing.overallSpacing * 4
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // File dialog for selecting scrcpy executable
    FileDialog {
        id: scrcpyFileDialog
        title: "Select scrcpy executable"
        nameFilters: ["Executable files (*.exe)", "All files (*)"]
        onAccepted: {
            // Convert file URL to local path
            var path = selectedFile.toString()
            // Remove file:/// prefix on Windows
            if (path.startsWith("file:///")) {
                path = path.substring(8)
            }
            // Replace forward slashes with backslashes on Windows
            path = path.replace(/\//g, "\\")

            scrcpyPathField.text = path
            if (settingsManager) {
                settingsManager.save_scrcpy_path(path)
                if (phoneMirrorManager) {
                    phoneMirrorManager.setScrcpyPath(path)
                }
            }
        }
    }
}