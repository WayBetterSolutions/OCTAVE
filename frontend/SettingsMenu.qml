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

    // Folder dialog for selecting music library folder
    FolderDialog {
        id: folderDialog
        title: "Select Music Library Folder"
        onAccepted: {
            // Convert from file:/// URL to local path
            var path = selectedFolder.toString()
            if (path.startsWith("file:///")) {
                path = path.substring(8)  // Remove "file:///"
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
        Layout.fillWidth: true
    }
    
    component SettingDescription: Text {
        color: App.Style.secondaryTextColor
        font.pixelSize: App.Spacing.overallText * 0.8
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
            onPressed: {
                // Calculate value based on mouse position
                var newPos = Math.max(0, Math.min(1, (mouseX - control.leftPadding) / control.availableWidth))
                control.value = control.from + newPos * (control.to - control.from)
                control.pressed = true
                mouse.accepted = false  // Allow the event to propagate to the Slider
            }
            onReleased: {
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
        Layout.preferredWidth: 250
        Layout.maximumWidth: 400
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
            
            // Left-side label
            Text {
                text: control.text
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.1  // Increased text size
                Layout.fillWidth: true
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        control.checked = !control.checked
                        control.toggled(control.checked)
                    }
                }
            }
            
            // Modern toggle with subtle animations
            Item {
                width: 80  // Increased from 64
                height: 40  // Increased from 32
                
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
                    
                    // Status text inside track
                    Text {
                        anchors {
                            left: control.checked ? undefined : parent.left
                            right: control.checked ? parent.right : undefined
                            margins: 10  // Increased from 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: control.checked ? "ON" : "OFF"
                        font.pixelSize: App.Spacing.overallText * 0.8  // Increased text size
                        font.bold: true
                        color: control.checked ? control.activeColor : Qt.rgba(control.inactiveColor.r, 
                                                                            control.inactiveColor.g, 
                                                                            control.inactiveColor.b, 0.7)
                        visible: width < (parent.width - handle.width - 10)
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                
                // Handle with shadow and subtle effects
                Rectangle {
                    id: handle
                    width: 40  // Increased from 32
                    height: 40  // Increased from 32
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
        Layout.topMargin: 2
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
                            ListElement { name: "About"; section: "about" }
                        }
                        
                        delegate: Item {
                            required property string name
                            required property string section
                            
                            width: navListView.width
                            height: App.Spacing.settingsButtonHeight
                            
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
                            case "about": return 5;
                            default: return 0;
                        }
                    }
                    
                    
                    ScrollView { // Device Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width

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
                            
                            Item { Layout.fillHeight: true } // Spacer
                        }
                    }
                    
                    ScrollView { // Media Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width

                            // Music Library Folder
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Music Library Folder"
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

                                    // Browse button
                                    Rectangle {
                                        id: browseButton
                                        Layout.preferredWidth: 85
                                        Layout.preferredHeight: mediaFolderField.height
                                        color: browseMouseArea.pressed ? Qt.darker(App.Style.accent, 1.4) :
                                               browseMouseArea.containsMouse ? Qt.darker(App.Style.accent, 1.2) : App.Style.accent
                                        radius: 6
                                        border.width: 1
                                        border.color: Qt.darker(App.Style.accent, 1.3)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Browse"
                                            color: "white"
                                            font.pixelSize: App.Spacing.overallText
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: browseMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                folderDialog.open()
                                            }
                                        }

                                        ToolTip.visible: browseMouseArea.containsMouse
                                        ToolTip.text: "Browse for music folder"
                                        ToolTip.delay: 300
                                    }

                                    // Scan library button
                                    Rectangle {
                                        id: scanLibraryButton
                                        Layout.preferredWidth: 70
                                        Layout.preferredHeight: mediaFolderField.height
                                        color: scanMouseArea.pressed ? Qt.darker(App.Style.accent, 1.4) :
                                               scanMouseArea.containsMouse ? Qt.darker(App.Style.accent, 1.2) : App.Style.accent
                                        radius: 6
                                        border.width: 1
                                        border.color: Qt.darker(App.Style.accent, 1.3)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Scan"
                                            color: "white"
                                            font.pixelSize: App.Spacing.overallText
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: scanMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (mediaManager) {
                                                    mediaManager.scan_library()
                                                }
                                            }
                                        }

                                        ToolTip.visible: scanMouseArea.containsMouse
                                        ToolTip.text: "Rescan library for playlists"
                                        ToolTip.delay: 300
                                    }
                                }

                                SettingDescription {
                                    text: "Each subfolder becomes a playlist. MP3s in the root go to 'Unsorted'."
                                }
                            }
                            
                            SettingsDivider {}

                            // Startup Volume
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Startup Volume"
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

                                SettingLabel {
                                    text: "Auto-Play on Startup"
                                }

                                SettingsToggle {
                                    id: autoPlayToggle
                                    Layout.fillWidth: true
                                    text: "Automatically resume playback when app starts"
                                    checked: settingsManager ? settingsManager.autoPlayOnStartup : false
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: {
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

                                SettingDescription {
                                    text: "When enabled, the app will resume playing from where you left off"
                                }
                            }

                            SettingsDivider {}

                            // Media Room Background Blur Effect
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Media Room Background Blur Effect"
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
                                    text: "Media Room Background"
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
                                
                                SettingLabel {
                                    text: "Show Background Overlay"
                                }
                                
                                SettingsToggle {
                                    id: backgroundOverlayToggle
                                    Layout.fillWidth: true
                                    text: "Enable dark overlay on album art"
                                    checked: settingsManager ? settingsManager.showBackgroundOverlay : true
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor
                                    
                                    onToggled: {
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
                                    text: spotifyManager && spotifyManager.is_connected()
                                        ? "Connected to Spotify"
                                        : "Control Spotify playback from this app. Get credentials from developer.spotify.com"
                                    color: spotifyManager && spotifyManager.is_connected() ? App.Style.accent : App.Style.secondaryTextColor
                                }

                                // Client ID field
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Client ID"
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText - 2
                                    }

                                    SettingsTextField {
                                        id: spotifyClientIdField
                                        Layout.fillWidth: true
                                        text: settingsManager ? settingsManager.get_spotify_client_id() : ""

                                        onTextEdited: {
                                            // Auto-save when text changes
                                            if (settingsManager) {
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
                                    }

                                    SettingsTextField {
                                        id: spotifyClientSecretField
                                        Layout.fillWidth: true
                                        text: settingsManager ? settingsManager.get_spotify_client_secret() : ""
                                        echoMode: TextInput.Password

                                        onTextEdited: {
                                            // Auto-save when text changes
                                            if (settingsManager) {
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

                                // Action buttons row
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.overallSpacing

                                    // Connect button (only when not connected)
                                    Rectangle {
                                        id: spotifyConnectButton
                                        width: spotifyConnectText.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight
                                        visible: spotifyManager && !spotifyManager.is_connected()
                                        color: spotifyConnectMouseArea.pressed ? Qt.darker(App.Style.accent, 1.4) :
                                               spotifyConnectMouseArea.containsMouse ? Qt.darker(App.Style.accent, 1.2) : App.Style.accent
                                        radius: height / 2

                                        Text {
                                            id: spotifyConnectText
                                            anchors.centerIn: parent
                                            text: "Connect to Spotify"
                                            color: "white"
                                            font.pixelSize: App.Spacing.overallText
                                        }

                                        MouseArea {
                                            id: spotifyConnectMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (spotifyManager) {
                                                    spotifyManager.authenticate()
                                                }
                                            }
                                        }
                                    }

                                    // Disconnect button (only when connected)
                                    Rectangle {
                                        id: spotifyDisconnectButton
                                        width: spotifyDisconnectText.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight
                                        visible: spotifyManager && spotifyManager.is_connected()
                                        color: spotifyDisconnectMouseArea.pressed ? Qt.darker("#e74c3c", 1.4) :
                                               spotifyDisconnectMouseArea.containsMouse ? Qt.darker("#e74c3c", 1.2) : "#e74c3c"
                                        radius: height / 2

                                        Text {
                                            id: spotifyDisconnectText
                                            anchors.centerIn: parent
                                            text: "Disconnect"
                                            color: "white"
                                            font.pixelSize: App.Spacing.overallText
                                        }

                                        MouseArea {
                                            id: spotifyDisconnectMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (spotifyManager) {
                                                    spotifyManager.disconnect()
                                                }
                                            }
                                        }
                                    }

                                    // Refresh devices button (only when connected)
                                    Rectangle {
                                        id: spotifyRefreshButton
                                        width: spotifyRefreshText.width + App.Spacing.overallSpacing * 3
                                        height: App.Spacing.formElementHeight
                                        visible: spotifyManager && spotifyManager.is_connected()
                                        color: spotifyRefreshMouseArea.pressed ? Qt.darker(App.Style.hoverColor, 1.4) :
                                               spotifyRefreshMouseArea.containsMouse ? Qt.darker(App.Style.hoverColor, 1.2) : App.Style.hoverColor
                                        radius: height / 2
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r,
                                                            App.Style.primaryTextColor.g,
                                                            App.Style.primaryTextColor.b, 0.1)

                                        Text {
                                            id: spotifyRefreshText
                                            anchors.centerIn: parent
                                            text: "Refresh Devices"
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                        }

                                        MouseArea {
                                            id: spotifyRefreshMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (spotifyManager) {
                                                    spotifyManager.refresh_devices()
                                                }
                                            }
                                        }
                                    }
                                }

                                // Connection status / error display
                                Text {
                                    id: spotifyStatusText
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    color: text.startsWith("Error") ? "#e74c3c" : App.Style.accent
                                    font.pixelSize: App.Spacing.overallText - 2
                                    wrapMode: Text.WordWrap

                                    Connections {
                                        target: spotifyManager
                                        function onConnectionStateChanged(connected) {
                                            spotifyStatusText.text = connected ? "Successfully connected to Spotify!" : ""
                                            spotifyAuthUrlText.visible = false
                                            // Refresh devices when connected to populate the list
                                            if (connected && spotifyManager) {
                                                spotifyManager.refresh_devices()
                                            }
                                        }
                                        function onErrorOccurred(error) {
                                            spotifyStatusText.text = "Error: " + error
                                        }
                                        function onAuthUrlReady(url) {
                                            spotifyAuthUrlText.text = url
                                            spotifyAuthUrlText.visible = true
                                            spotifyStatusText.text = "Click the link below to authenticate:"
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
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 2

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Qt.openUrlExternally(spotifyAuthUrlText.text)
                                        }
                                    }

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
                                    }

                                    // Chip-style device selector (like theme chips)
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: App.Spacing.overallSpacing

                                        Repeater {
                                            id: spotifyDevicesRepeater
                                            model: spotifyManager ? spotifyManager.get_devices() : []

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

                                                // Subtle shadow for active device
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

                                    Connections {
                                        target: spotifyManager
                                        function onDevicesChanged(devices) {
                                            spotifyDevicesRepeater.model = devices
                                        }
                                    }

                                    Text {
                                        visible: spotifyDevicesRepeater.count === 0
                                        text: "No devices found. Open Spotify on a device first."
                                        color: App.Style.secondaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        font.italic: true
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true } // Spacer
                        }
                    }

                    ScrollView { // Display Settings Page
                        contentWidth: parent.width
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: parent.width

                            Component.onCompleted: {
                                // When the display settings page loads, set the color boxes to match the current theme
                                Qt.callLater(function() {
                                    if (settingsManager) {
                                        loadThemeColors(settingsManager.themeSetting)
                                    }
                                    function loadThemeColors(themeName) {
                                        console.log("Loading theme colors for:", themeName)
                                        let themeObj
                                        
                                        try {
                                            // Check if it's a custom theme
                                            if (settingsManager && settingsManager.customThemes && 
                                                settingsManager.customThemes.indexOf(themeName) !== -1) {
                                                let themeJSON = settingsManager.get_custom_theme(themeName)
                                                themeObj = JSON.parse(themeJSON)
                                            } else if (App.Style.themes[themeName]) {
                                                // Built-in theme
                                                themeObj = App.Style.themes[themeName]
                                            } else {
                                                console.log("Unknown theme:", themeName)
                                                return // Unknown theme
                                            }
                                            
                                            // Set the theme name in the input field
                                            customThemeName.text = themeName
                                            
                                            // Update color rectangles
                                            baseColorRect.color = themeObj.base
                                            baseColorRect.colorValue = themeObj.base
                                            
                                            baseAltColorRect.color = themeObj.baseAlt
                                            baseAltColorRect.colorValue = themeObj.baseAlt
                                            
                                            accentColorRect.color = themeObj.accent
                                            accentColorRect.colorValue = themeObj.accent
                                            
                                            primaryTextColorRect.color = themeObj.text.primary
                                            primaryTextColorRect.colorValue = themeObj.text.primary
                                            
                                            secondaryTextColorRect.color = themeObj.text.secondary
                                            secondaryTextColorRect.colorValue = themeObj.text.secondary
                                            
                                            // State colors
                                            if (themeObj.states) {
                                                if (themeObj.states.hover) {
                                                    hoverStateColorRect.color = themeObj.states.hover
                                                    hoverStateColorRect.colorValue = themeObj.states.hover
                                                }
                                                
                                                if (themeObj.states.paused) {
                                                    pausedStateColorRect.color = themeObj.states.paused
                                                    pausedStateColorRect.colorValue = themeObj.states.paused
                                                }
                                                
                                                if (themeObj.states.playing) {
                                                    playingStateColorRect.color = themeObj.states.playing
                                                    playingStateColorRect.colorValue = themeObj.states.playing
                                                }
                                            }
                                            
                                            // Slider colors
                                            if (themeObj.sliders) {
                                                if (themeObj.sliders.volume) {
                                                    volumeSliderColorRect.color = themeObj.sliders.volume
                                                    volumeSliderColorRect.colorValue = themeObj.sliders.volume
                                                } else {
                                                    volumeSliderColorRect.color = themeObj.accent
                                                    volumeSliderColorRect.colorValue = themeObj.accent
                                                }
                                                
                                                if (themeObj.sliders.media) {
                                                    mediaHighlightColorRect.color = themeObj.sliders.media
                                                    mediaHighlightColorRect.colorValue = themeObj.sliders.media
                                                } else {
                                                    mediaHighlightColorRect.color = themeObj.accent
                                                    mediaHighlightColorRect.colorValue = themeObj.accent
                                                }
                                            }
                                            
                                            // Bottom bar button colors
                                            if (themeObj.bottombar && themeObj.bottombar.play) {
                                                bottomBarButtonsColorRect.color = themeObj.bottombar.play
                                                bottomBarButtonsColorRect.colorValue = themeObj.bottombar.play
                                            } else {
                                                bottomBarButtonsColorRect.color = themeObj.accent
                                                bottomBarButtonsColorRect.colorValue = themeObj.accent
                                            }
                                            
                                            // Media room button colors
                                            if (themeObj.mediaroom && themeObj.mediaroom.play) {
                                                mediaRoomButtonsColorRect.color = themeObj.mediaroom.play
                                                mediaRoomButtonsColorRect.colorValue = themeObj.mediaroom.play
                                            } else {
                                                mediaRoomButtonsColorRect.color = themeObj.accent
                                                mediaRoomButtonsColorRect.colorValue = themeObj.accent
                                            }
                                            
                                            // Media container color
                                            if (themeObj.mainmenu && themeObj.mainmenu.mediaContainer) {
                                                mediaContainerColorRect.color = themeObj.mainmenu.mediaContainer
                                                mediaContainerColorRect.colorValue = themeObj.mainmenu.mediaContainer
                                            } else {
                                                mediaContainerColorRect.color = Qt.darker(themeObj.accent, 1.2)
                                                mediaContainerColorRect.colorValue = Qt.darker(themeObj.accent, 1.2)
                                            }
                                            
                                        } catch (e) {
                                            console.error("Error in loadThemeColors:", e)
                                        }
                                    }
                                })
                            }

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
                                    text: "Adjusts the size of all UI elements. Changes apply immediately."
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { //nav bar orientation
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Bottom Bar Orientation"
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
                                    text: "Choose whether the navigation bar appears at the bottom or side of the screen"
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout { // Bottom Bar Media Controls
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Bottom Bar Media Controls"
                                }

                                SettingsToggle {
                                    id: bottomBarMediaControlsToggle
                                    Layout.fillWidth: true
                                    text: "Show media controls on the bottom bar"
                                    checked: settingsManager ? settingsManager.showBottomBarMediaControls : true
                                    activeColor: App.Style.accent
                                    inactiveColor: App.Style.hoverColor

                                    onToggled: {
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
                                        Layout.preferredWidth: 70  // Increased from 60
                                    }
                                    
                                    SettingsTextField {
                                        id: screenWidth
                                        Layout.preferredWidth: 120  // Increased from 100
                                        text: mainWindow.width
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 400
                                            top: 3840
                                        }
                                        
                                        onEditingFinished: {
                                            if (text && settingsManager) {
                                                const width = parseInt(text)
                                                settingsManager.save_screen_width(width)
                                                mainWindow.width = width
                                                App.Spacing.updateDimensions(width, mainWindow.height)
                                            }
                                        }
                                        
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
                                        Layout.preferredWidth: 70  // Increased from 60
                                    }
                                    
                                    SettingsTextField {
                                        id: screenHeight
                                        Layout.preferredWidth: 120  // Increased from 100
                                        text: mainWindow.height
                                        horizontalAlignment: TextInput.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 300
                                            top: 2160
                                        }
                                        
                                        onEditingFinished: {
                                            if (text && settingsManager) {
                                                const height = parseInt(text)
                                                settingsManager.save_screen_height(height)
                                                mainWindow.height = height
                                                App.Spacing.updateDimensions(mainWindow.width, height)
                                            }
                                        }
                                        
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
                                            try {
                                                loadThemeColors(value)
                                            } catch (e) {
                                                console.error("Error loading theme colors:", e)
                                            }
                                        }
                                    }
                                }
                                
                                // Spacer to push delete button to bottom
                                Item {
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 10
                                }
                                
                                // Container for delete button to position it at right
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: deleteThemeButton.height
                                    
                                    // Delete button in bottom right
                                    Button {
                                        id: deleteThemeButton
                                        text: "Delete Theme"
                                        anchors.right: parent.right
                                        enabled: settingsManager && 
                                                settingsManager.customThemes && 
                                                settingsManager.customThemes.indexOf(settingsManager.themeSetting) !== -1
                                        Layout.preferredWidth: 150
                                        width: 150
                                        height: 50
                                        
                                        background: Rectangle {
                                            color: {
                                                if (!deleteThemeButton.enabled) {
                                                    return "#cccccc"  // Gray when disabled
                                                } else if (deleteThemeButton.pressed) {
                                                    return Qt.darker("#f44336", 1.2)
                                                } else if (deleteThemeButton.hovered) {
                                                    return Qt.lighter("#f44336", 1.1)
                                                } else {
                                                    return "#f44336"
                                                }
                                            }
                                            radius: 4
                                        }
                                        
                                        contentItem: Text {
                                            text: deleteThemeButton.text
                                            color: deleteThemeButton.enabled ? "white" : "#666666"  // Darker text when disabled
                                            font.pixelSize: App.Spacing.overallText * 0.9
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            if (deleteThemeButton.enabled) {
                                                deleteThemeConfirmDialog.themeName = settingsManager.themeSetting
                                                deleteThemeConfirmDialog.open()
                                            }
                                        }
                                    }
                                }
                            }

                            SettingsDivider {}

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Custom Theme Creator"
                                }
                                
                                SettingDescription {
                                    text: "Create and save your own custom themes"
                                }
                                
                                // Theme name input
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: App.Spacing.rowSpacing
                                    
                                    Text {
                                        text: "Theme Name:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    SettingsTextField {
                                        id: customThemeName
                                        Layout.fillWidth: true
                                        // Initially set to current theme name
                                        text: settingsManager ? settingsManager.themeSetting : ""
                                        // This ensures placeholder disappears when typing instead of moving to the top
                                        placeholderTextColor: customThemeName.text.length > 0 ? "transparent" : Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.5)
                                        placeholderText: "My Custom Theme"
                                    }
                                }
                                
                                // Color selection grid - expanded with more color options
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: App.Spacing.overallSpacing * 2
                                    rowSpacing: App.Spacing.rowSpacing
                                    
                                    // Base color
                                    Text {
                                        text: "Base Background:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: baseColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#f5f5f5"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#f5f5f5"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = baseColorRect.color
                                                colorDialog.targetRect = baseColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Alt base color
                                    Text {
                                        text: "Alt Background:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: baseAltColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#e5e5e5"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#e5e5e5"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = baseAltColorRect.color
                                                colorDialog.targetRect = baseAltColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Accent color
                                    Text {
                                        text: "Accent Color:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: accentColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#2196F3"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#2196F3"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = accentColorRect.color
                                                colorDialog.targetRect = accentColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Primary text color
                                    Text {
                                        text: "Primary Text:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: primaryTextColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#212121"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#212121"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = primaryTextColorRect.color
                                                colorDialog.targetRect = primaryTextColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Secondary text color
                                    Text {
                                        text: "Secondary Text:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: secondaryTextColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#757575"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#757575"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = secondaryTextColorRect.color
                                                colorDialog.targetRect = secondaryTextColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Media player highlight color
                                    Text {
                                        text: "Media Highlight:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: mediaHighlightColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#1976D2"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#1976D2"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = mediaHighlightColorRect.color
                                                colorDialog.targetRect = mediaHighlightColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Volume Slider color
                                    Text {
                                        text: "Volume Slider:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: volumeSliderColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#FF9800"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#FF9800"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = volumeSliderColorRect.color
                                                colorDialog.targetRect = volumeSliderColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Bottom Bar Buttons color
                                    Text {
                                        text: "Bottom Bar Buttons:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: bottomBarButtonsColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#4CAF50"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#4CAF50"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = bottomBarButtonsColorRect.color
                                                colorDialog.targetRect = bottomBarButtonsColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Media Room Buttons color
                                    Text {
                                        text: "Media Room Buttons:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: mediaRoomButtonsColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#9C27B0"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#9C27B0"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = mediaRoomButtonsColorRect.color
                                                colorDialog.targetRect = mediaRoomButtonsColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Media Container color
                                    Text {
                                        text: "Media Container:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: mediaContainerColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: "#607D8B"
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: "#607D8B"
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = mediaContainerColorRect.color
                                                colorDialog.targetRect = mediaContainerColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Hover state color
                                    Text {
                                        text: "Hover Effect:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: hoverStateColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: Qt.lighter(baseAltColorRect.color, 1.1)
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: Qt.lighter(baseAltColorRect.colorValue, 1.1)
                                        
                                        // Update hover color when baseAlt changes
                                        Connections {
                                            target: baseAltColorRect
                                            function onColorChanged() {
                                                hoverStateColorRect.color = Qt.lighter(baseAltColorRect.color, 1.1)
                                                hoverStateColorRect.colorValue = Qt.lighter(baseAltColorRect.colorValue, 1.1)
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = hoverStateColorRect.color
                                                colorDialog.targetRect = hoverStateColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Paused state color
                                    Text {
                                        text: "Paused State:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: pausedStateColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: Qt.lighter(baseAltColorRect.color, 1.2)
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: Qt.lighter(baseAltColorRect.colorValue, 1.2)
                                        
                                        // Update paused color when baseAlt changes
                                        Connections {
                                            target: baseAltColorRect
                                            function onColorChanged() {
                                                pausedStateColorRect.color = Qt.lighter(baseAltColorRect.color, 1.2)
                                                pausedStateColorRect.colorValue = Qt.lighter(baseAltColorRect.colorValue, 1.2)
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = pausedStateColorRect.color
                                                colorDialog.targetRect = pausedStateColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                    
                                    // Playing state color
                                    Text {
                                        text: "Playing State:"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                    }
                                    
                                    Rectangle {
                                        id: playingStateColorRect
                                        Layout.preferredWidth: 120
                                        Layout.preferredHeight: 30
                                        color: Qt.lighter(baseAltColorRect.color, 1.3)
                                        radius: 4
                                        border.width: 1
                                        border.color: Qt.rgba(App.Style.primaryTextColor.r, 
                                                            App.Style.primaryTextColor.g, 
                                                            App.Style.primaryTextColor.b, 0.3)
                                        
                                        property string colorValue: Qt.lighter(baseAltColorRect.colorValue, 1.3)
                                        
                                        // Update playing color when baseAlt changes
                                        Connections {
                                            target: baseAltColorRect
                                            function onColorChanged() {
                                                playingStateColorRect.color = Qt.lighter(baseAltColorRect.color, 1.3)
                                                playingStateColorRect.colorValue = Qt.lighter(baseAltColorRect.colorValue, 1.3)
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                colorDialog.currentColor = playingStateColorRect.color
                                                colorDialog.targetRect = playingStateColorRect
                                                colorDialog.open()
                                            }
                                        }
                                    }
                                }
                                
                                // Save theme button
                                Button {
                                    text: "Save Theme"
                                    Layout.alignment: Qt.AlignRight
                                    Layout.preferredWidth: 150
                                    Layout.preferredHeight: 50
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(App.Style.accent, 1.4) : 
                                            parent.hovered ? Qt.darker(App.Style.accent, 1.2) : 
                                            App.Style.accent
                                        radius: 4
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        font.pixelSize: App.Spacing.overallText
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        // Validate theme name
                                        if (customThemeName.text.trim() === "") {
                                            themeNameErrorDialog.open()
                                            return
                                        }
                                        
                                        // Create theme object with all color values
                                        let customTheme = {
                                            "base": baseColorRect.colorValue,
                                            "baseAlt": baseAltColorRect.colorValue,
                                            "accent": accentColorRect.colorValue,
                                            "text": {
                                                "primary": primaryTextColorRect.colorValue,
                                                "secondary": secondaryTextColorRect.colorValue
                                            },
                                            "states": {
                                                "hover": hoverStateColorRect.colorValue,
                                                "paused": pausedStateColorRect.colorValue,
                                                "playing": playingStateColorRect.colorValue
                                            },
                                            "sliders": {
                                                "volume": volumeSliderColorRect.colorValue,
                                                "media": mediaHighlightColorRect.colorValue
                                            },
                                            "bottombar": {
                                                "previous": bottomBarButtonsColorRect.colorValue,
                                                "play": bottomBarButtonsColorRect.colorValue,
                                                "pause": bottomBarButtonsColorRect.colorValue,
                                                "next": bottomBarButtonsColorRect.colorValue,
                                                "volume": bottomBarButtonsColorRect.colorValue,
                                                "shuffle": bottomBarButtonsColorRect.colorValue,
                                                "toggleShade": baseAltColorRect.colorValue
                                            },
                                            "mediaroom": {
                                                "previous": mediaRoomButtonsColorRect.colorValue,
                                                "play": mediaRoomButtonsColorRect.colorValue,
                                                "pause": mediaRoomButtonsColorRect.colorValue,
                                                "next": mediaRoomButtonsColorRect.colorValue,
                                                "left": mediaRoomButtonsColorRect.colorValue,
                                                "right": mediaRoomButtonsColorRect.colorValue,
                                                "shuffle": mediaRoomButtonsColorRect.colorValue,
                                                "toggleShade": baseAltColorRect.colorValue
                                            },
                                            "mainmenu": {
                                                "mediaContainer": mediaContainerColorRect.colorValue
                                            }
                                        }
                                        
                                        // Save the custom theme
                                        if (settingsManager) {
                                            settingsManager.save_custom_theme(customThemeName.text, JSON.stringify(customTheme))
                                            
                                            // Show success message
                                            saveThemeSuccessDialog.open()
                                            
                                            // Refresh theme list
                                            Qt.callLater(function() {
                                                themeButton.options = App.Style.getAllThemeNames()
                                            })
                                        }
                                    }
                                }
                                
                                // Function to load theme colors from theme name
                                function loadThemeColors(themeName) {
                                    let themeObj
                                    
                                    try {
                                        // Check if it's a custom theme
                                        if (settingsManager && settingsManager.customThemes && 
                                            settingsManager.customThemes.indexOf(themeName) !== -1) {
                                            let themeJSON = settingsManager.get_custom_theme(themeName)
                                            themeObj = JSON.parse(themeJSON)
                                        } else if (App.Style.themes[themeName]) {
                                            // Built-in theme
                                            themeObj = App.Style.themes[themeName]
                                        } else {
                                            console.log("Unknown theme:", themeName)
                                            return // Unknown theme
                                        }
                                        
                                        // Update color rectangles
                                        baseColorRect.color = themeObj.base
                                        baseColorRect.colorValue = themeObj.base
                                        
                                        baseAltColorRect.color = themeObj.baseAlt
                                        baseAltColorRect.colorValue = themeObj.baseAlt
                                        
                                        accentColorRect.color = themeObj.accent
                                        accentColorRect.colorValue = themeObj.accent
                                        
                                        primaryTextColorRect.color = themeObj.text.primary
                                        primaryTextColorRect.colorValue = themeObj.text.primary
                                        
                                        secondaryTextColorRect.color = themeObj.text.secondary
                                        secondaryTextColorRect.colorValue = themeObj.text.secondary
                                        
                                        // Use the media highlight color if available, otherwise use accent
                                        let mediaColor = themeObj.sliders && themeObj.sliders.media ? 
                                                    themeObj.sliders.media : themeObj.accent
                                        mediaHighlightColorRect.color = mediaColor
                                        mediaHighlightColorRect.colorValue = mediaColor
                                        
                                        // Don't set theme name when loading - only when using "Copy of"
                                        if (customThemeName.text === "" || customThemeName.text.startsWith("Copy of")) {
                                            customThemeName.text = "Copy of " + themeName
                                        }
                                    } catch (e) {
                                    }
                                }
                                
                                // Initialize with current theme when component loads
                                Component.onCompleted: {
                                    Qt.callLater(function() {
                                        if (settingsManager) {
                                            loadThemeColors(settingsManager.themeSetting)
                                        }
                                    })
                                }
                                
                                // Update when theme changes
                                Connections {
                                    target: settingsManager
                                    function onThemeSettingChanged() {
                                        if (settingsManager) {
                                            loadThemeColors(settingsManager.themeSetting)
                                        }
                                        function loadThemeColors(themeName) {
                                            console.log("Loading theme colors for:", themeName)
                                            let themeObj
                                            
                                            try {
                                                // Check if it's a custom theme
                                                if (settingsManager && settingsManager.customThemes && 
                                                    settingsManager.customThemes.indexOf(themeName) !== -1) {
                                                    let themeJSON = settingsManager.get_custom_theme(themeName)
                                                    themeObj = JSON.parse(themeJSON)
                                                } else if (App.Style.themes[themeName]) {
                                                    // Built-in theme
                                                    themeObj = App.Style.themes[themeName]
                                                } else {
                                                    console.log("Unknown theme:", themeName)
                                                    return // Unknown theme
                                                }
                                                
                                                // Set the theme name in the input field
                                                customThemeName.text = themeName
                                                
                                                // Update color rectangles
                                                baseColorRect.color = themeObj.base
                                                baseColorRect.colorValue = themeObj.base
                                                
                                                baseAltColorRect.color = themeObj.baseAlt
                                                baseAltColorRect.colorValue = themeObj.baseAlt
                                                
                                                accentColorRect.color = themeObj.accent
                                                accentColorRect.colorValue = themeObj.accent
                                                
                                                primaryTextColorRect.color = themeObj.text.primary
                                                primaryTextColorRect.colorValue = themeObj.text.primary
                                                
                                                secondaryTextColorRect.color = themeObj.text.secondary
                                                secondaryTextColorRect.colorValue = themeObj.text.secondary
                                                
                                                // State colors
                                                if (themeObj.states) {
                                                    if (themeObj.states.hover) {
                                                        hoverStateColorRect.color = themeObj.states.hover
                                                        hoverStateColorRect.colorValue = themeObj.states.hover
                                                    }
                                                    
                                                    if (themeObj.states.paused) {
                                                        pausedStateColorRect.color = themeObj.states.paused
                                                        pausedStateColorRect.colorValue = themeObj.states.paused
                                                    }
                                                    
                                                    if (themeObj.states.playing) {
                                                        playingStateColorRect.color = themeObj.states.playing
                                                        playingStateColorRect.colorValue = themeObj.states.playing
                                                    }
                                                }
                                                
                                                // Slider colors
                                                if (themeObj.sliders) {
                                                    if (themeObj.sliders.volume) {
                                                        volumeSliderColorRect.color = themeObj.sliders.volume
                                                        volumeSliderColorRect.colorValue = themeObj.sliders.volume
                                                    } else {
                                                        volumeSliderColorRect.color = themeObj.accent
                                                        volumeSliderColorRect.colorValue = themeObj.accent
                                                    }
                                                    
                                                    if (themeObj.sliders.media) {
                                                        mediaHighlightColorRect.color = themeObj.sliders.media
                                                        mediaHighlightColorRect.colorValue = themeObj.sliders.media
                                                    } else {
                                                        mediaHighlightColorRect.color = themeObj.accent
                                                        mediaHighlightColorRect.colorValue = themeObj.accent
                                                    }
                                                }
                                                
                                                // Bottom bar button colors
                                                if (themeObj.bottombar && themeObj.bottombar.play) {
                                                    bottomBarButtonsColorRect.color = themeObj.bottombar.play
                                                    bottomBarButtonsColorRect.colorValue = themeObj.bottombar.play
                                                } else {
                                                    bottomBarButtonsColorRect.color = themeObj.accent
                                                    bottomBarButtonsColorRect.colorValue = themeObj.accent
                                                }
                                                
                                                // Media room button colors
                                                if (themeObj.mediaroom && themeObj.mediaroom.play) {
                                                    mediaRoomButtonsColorRect.color = themeObj.mediaroom.play
                                                    mediaRoomButtonsColorRect.colorValue = themeObj.mediaroom.play
                                                } else {
                                                    mediaRoomButtonsColorRect.color = themeObj.accent
                                                    mediaRoomButtonsColorRect.colorValue = themeObj.accent
                                                }
                                                
                                                // Media container color
                                                if (themeObj.mainmenu && themeObj.mainmenu.mediaContainer) {
                                                    mediaContainerColorRect.color = themeObj.mainmenu.mediaContainer
                                                    mediaContainerColorRect.colorValue = themeObj.mainmenu.mediaContainer
                                                } else {
                                                    mediaContainerColorRect.color = Qt.darker(themeObj.accent, 1.2)
                                                    mediaContainerColorRect.colorValue = Qt.darker(themeObj.accent, 1.2)
                                                }
                                                
                                            } catch (e) {
                                                console.error("Error in loadThemeColors:", e)
                                            }
                                        }
                                    }
                                }
                                
                                // Update when theme button options change
                                Connections {
                                    target: themeButton
                                    function onCurrentValueChanged() {
                                        if (settingsManager && themeButton.currentValue) {
                                            loadThemeColors(themeButton.currentValue)
                                        }
                                        function loadThemeColors(themeName) {
                                            console.log("Loading theme colors for:", themeName)
                                            let themeObj
                                            
                                            try {
                                                // Check if it's a custom theme
                                                if (settingsManager && settingsManager.customThemes && 
                                                    settingsManager.customThemes.indexOf(themeName) !== -1) {
                                                    let themeJSON = settingsManager.get_custom_theme(themeName)
                                                    themeObj = JSON.parse(themeJSON)
                                                } else if (App.Style.themes[themeName]) {
                                                    // Built-in theme
                                                    themeObj = App.Style.themes[themeName]
                                                } else {
                                                    console.log("Unknown theme:", themeName)
                                                    return // Unknown theme
                                                }
                                                
                                                // Set the theme name in the input field
                                                customThemeName.text = themeName
                                                
                                                // Update color rectangles
                                                baseColorRect.color = themeObj.base
                                                baseColorRect.colorValue = themeObj.base
                                                
                                                baseAltColorRect.color = themeObj.baseAlt
                                                baseAltColorRect.colorValue = themeObj.baseAlt
                                                
                                                accentColorRect.color = themeObj.accent
                                                accentColorRect.colorValue = themeObj.accent
                                                
                                                primaryTextColorRect.color = themeObj.text.primary
                                                primaryTextColorRect.colorValue = themeObj.text.primary
                                                
                                                secondaryTextColorRect.color = themeObj.text.secondary
                                                secondaryTextColorRect.colorValue = themeObj.text.secondary
                                                
                                                // State colors
                                                if (themeObj.states) {
                                                    if (themeObj.states.hover) {
                                                        hoverStateColorRect.color = themeObj.states.hover
                                                        hoverStateColorRect.colorValue = themeObj.states.hover
                                                    }
                                                    
                                                    if (themeObj.states.paused) {
                                                        pausedStateColorRect.color = themeObj.states.paused
                                                        pausedStateColorRect.colorValue = themeObj.states.paused
                                                    }
                                                    
                                                    if (themeObj.states.playing) {
                                                        playingStateColorRect.color = themeObj.states.playing
                                                        playingStateColorRect.colorValue = themeObj.states.playing
                                                    }
                                                }
                                                
                                                // Slider colors
                                                if (themeObj.sliders) {
                                                    if (themeObj.sliders.volume) {
                                                        volumeSliderColorRect.color = themeObj.sliders.volume
                                                        volumeSliderColorRect.colorValue = themeObj.sliders.volume
                                                    } else {
                                                        volumeSliderColorRect.color = themeObj.accent
                                                        volumeSliderColorRect.colorValue = themeObj.accent
                                                    }
                                                    
                                                    if (themeObj.sliders.media) {
                                                        mediaHighlightColorRect.color = themeObj.sliders.media
                                                        mediaHighlightColorRect.colorValue = themeObj.sliders.media
                                                    } else {
                                                        mediaHighlightColorRect.color = themeObj.accent
                                                        mediaHighlightColorRect.colorValue = themeObj.accent
                                                    }
                                                }
                                                
                                                // Bottom bar button colors
                                                if (themeObj.bottombar && themeObj.bottombar.play) {
                                                    bottomBarButtonsColorRect.color = themeObj.bottombar.play
                                                    bottomBarButtonsColorRect.colorValue = themeObj.bottombar.play
                                                } else {
                                                    bottomBarButtonsColorRect.color = themeObj.accent
                                                    bottomBarButtonsColorRect.colorValue = themeObj.accent
                                                }
                                                
                                                // Media room button colors
                                                if (themeObj.mediaroom && themeObj.mediaroom.play) {
                                                    mediaRoomButtonsColorRect.color = themeObj.mediaroom.play
                                                    mediaRoomButtonsColorRect.colorValue = themeObj.mediaroom.play
                                                } else {
                                                    mediaRoomButtonsColorRect.color = themeObj.accent
                                                    mediaRoomButtonsColorRect.colorValue = themeObj.accent
                                                }
                                                
                                                // Media container color
                                                if (themeObj.mainmenu && themeObj.mainmenu.mediaContainer) {
                                                    mediaContainerColorRect.color = themeObj.mainmenu.mediaContainer
                                                    mediaContainerColorRect.colorValue = themeObj.mainmenu.mediaContainer
                                                } else {
                                                    mediaContainerColorRect.color = Qt.darker(themeObj.accent, 1.2)
                                                    mediaContainerColorRect.colorValue = Qt.darker(themeObj.accent, 1.2)
                                                }
                                                
                                            } catch (e) {
                                                console.error("Error in loadThemeColors:", e)
                                            }
                                        }
                                    }
                                }
                            }

                            // Color Dialog for picking colors
                            Dialog {
                                id: colorDialog
                                title: "Select Color"
                                width: 320
                                height: 420
                                anchors.centerIn: parent
                                modal: true
                                
                                property var targetRect: null
                                property color currentColor: "white"
                                property var colorGrid: [
                                    ["#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3"],
                                    ["#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39"],
                                    ["#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#795548", "#9e9e9e"],
                                    ["#607d8b", "#ffffff", "#f5f5f5", "#eeeeee", "#bdbdbd", "#212121"]
                                ]
                                
                                contentItem: ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 10
                                    
                                    // Current color preview
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        color: colorDialog.currentColor
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.2)
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: colorDialog.currentColor
                                            color: isDarkColor(colorDialog.currentColor) ? "white" : "black"
                                            font.pixelSize: 16
                                            
                                            // Simple function to determine if text should be white or black
                                            function isDarkColor(color) {
                                                let r = color.r * 255
                                                let g = color.g * 255
                                                let b = color.b * 255
                                                return (r * 0.299 + g * 0.587 + b * 0.114) < 128
                                            }
                                        }
                                    }
                                    
                                    // Color grid
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 6
                                        columnSpacing: 5
                                        rowSpacing: 5
                                        
                                        Repeater {
                                            model: {
                                                // Create a flattened array manually
                                                let flatColors = [];
                                                for (let i = 0; i < colorDialog.colorGrid.length; i++) {
                                                    let row = colorDialog.colorGrid[i];
                                                    for (let j = 0; j < row.length; j++) {
                                                        flatColors.push(row[j]);
                                                    }
                                                }
                                                return flatColors;
                                            }
                                            
                                            delegate: Rectangle {
                                                width: 40
                                                height: 40
                                                color: modelData
                                                border.width: 1
                                                border.color: Qt.rgba(0, 0, 0, 0.2)
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        colorDialog.currentColor = modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Custom color components (RGB)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        
                                        Text {
                                            text: "R:"
                                            color: App.Style.primaryTextColor
                                        }
                                        
                                        Slider {
                                            id: redSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 255
                                            value: {
                                                let val = colorDialog.currentColor.r * 255;
                                                return isNaN(val) ? 0 : val;
                                            }
                                            
                                            onValueChanged: {
                                                colorDialog.currentColor = Qt.rgba(value / 255, 
                                                                                colorDialog.currentColor.g, 
                                                                                colorDialog.currentColor.b, 
                                                                                1.0)
                                            }
                                        }

                                        
                                        Text {
                                            text: Math.round(redSlider.value)
                                            color: App.Style.primaryTextColor
                                            width: 30
                                        }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        
                                        Text {
                                            text: "G:"
                                            color: App.Style.primaryTextColor
                                        }
                                        
                                        Slider {
                                            id: greenSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 255
                                            value: colorDialog.currentColor.g * 255
                                            
                                            onValueChanged: {
                                                colorDialog.currentColor = Qt.rgba(colorDialog.currentColor.r, 
                                                                                value / 255, 
                                                                                colorDialog.currentColor.b, 
                                                                                1.0)
                                            }
                                        }
                                        
                                        Text {
                                            text: Math.round(greenSlider.value)
                                            color: App.Style.primaryTextColor
                                            width: 30
                                        }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        
                                        Text {
                                            text: "B:"
                                            color: App.Style.primaryTextColor
                                        }
                                        
                                        Slider {
                                            id: blueSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 255
                                            value: colorDialog.currentColor.b * 255
                                            
                                            onValueChanged: {
                                                colorDialog.currentColor = Qt.rgba(colorDialog.currentColor.r, 
                                                                                colorDialog.currentColor.g, 
                                                                                value / 255, 
                                                                                1.0)
                                            }
                                        }
                                        
                                        Text {
                                            text: Math.round(blueSlider.value)
                                            color: App.Style.primaryTextColor
                                            width: 30
                                        }
                                    }
                                    
                                    // OK/Cancel buttons
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignRight
                                        spacing: 10
                                        
                                        Button {
                                            text: "Cancel"
                                            onClicked: {
                                                colorDialog.close()
                                            }
                                        }
                                        
                                        Button {
                                            text: "OK"
                                            onClicked: {
                                                // Update the target rectangle with the selected color
                                                if (colorDialog.targetRect) {
                                                    colorDialog.targetRect.color = colorDialog.currentColor
                                                    
                                                    // Convert color to hex string and store it
                                                    let r = Math.round(colorDialog.currentColor.r * 255).toString(16).padStart(2, '0')
                                                    let g = Math.round(colorDialog.currentColor.g * 255).toString(16).padStart(2, '0')
                                                    let b = Math.round(colorDialog.currentColor.b * 255).toString(16).padStart(2, '0')
                                                    let hexColor = "#" + r + g + b
                                                    colorDialog.targetRect.colorValue = hexColor
                                                }
                                                colorDialog.close()
                                            }
                                        }
                                    }
                                }
                            }

                            // Error dialog for empty theme name
                            Dialog {
                                id: themeNameErrorDialog
                                title: "Error"
                                width: 300
                                height: 150
                                anchors.centerIn: parent
                                modal: true
                                
                                contentItem: ColumnLayout {
                                    spacing: 20
                                    anchors.fill: parent
                                    
                                    Text {
                                        text: "Please enter a name for your theme"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                    
                                    Button {
                                        text: "OK"
                                        Layout.alignment: Qt.AlignHCenter
                                        onClicked: themeNameErrorDialog.close()
                                    }
                                }
                            }

                            // Success dialog for theme save
                            Dialog {
                                id: saveThemeSuccessDialog
                                title: "Theme Saved"
                                width: 300
                                height: 150
                                anchors.centerIn: parent
                                modal: true
                                
                                contentItem: ColumnLayout {
                                    spacing: 20
                                    anchors.fill: parent
                                    
                                    Text {
                                        text: "Your theme has been saved and is now available in the theme selection list"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                    
                                    Button {
                                        text: "OK"
                                        Layout.alignment: Qt.AlignHCenter
                                        onClicked: saveThemeSuccessDialog.close()
                                    }
                                }
                            }
                            
                            // Add this dialog for confirming theme deletion
                            Dialog {
                                id: deleteThemeConfirmDialog
                                title: "Delete Theme"
                                width: 300
                                height: 180
                                anchors.centerIn: parent
                                modal: true
                                
                                property string themeName: ""
                                
                                contentItem: ColumnLayout {
                                    spacing: 20
                                    anchors.fill: parent
                                    
                                    Text {
                                        text: "Are you sure you want to delete the theme '" + deleteThemeConfirmDialog.themeName + "'?"
                                        color: App.Style.primaryTextColor
                                        font.pixelSize: App.Spacing.overallText
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                    
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 20
                                        
                                        Button {
                                            text: "Cancel"
                                            onClicked: deleteThemeConfirmDialog.close()
                                        }
                                        
                                        Button {
                                            text: "Delete"
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker("#f44336", 1.2) : 
                                                    parent.hovered ? Qt.lighter("#f44336", 1.1) : "#f44336"
                                                radius: 4
                                            }
                                            
                                            contentItem: Text {
                                                text: parent.text
                                                color: "white"
                                                font.pixelSize: App.Spacing.overallText * 0.9
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                if (settingsManager) {
                                                    // Delete the theme
                                                    settingsManager.delete_custom_theme(deleteThemeConfirmDialog.themeName)
                                                    
                                                    // Switch to default theme
                                                    mainWindow.updateTheme("Dark")
                                                    
                                                    // Close the dialog
                                                    deleteThemeConfirmDialog.close()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        
                            // Bottom spacer
                            Item { 
                                Layout.fillHeight: true
                                Layout.minimumHeight: App.Spacing.bottomBar
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
                                    text: "OBD Connection Status"
                                }
                                
                                Rectangle {
                                    id: connectionStatusRect
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    
                                    // Use more diverse status colors
                                    property var statusColors: {
                                        "Connected": App.Style.accent,
                                        "Connecting": "#FF9800",  // Orange
                                        "Device Not Found": "#F44336",  // Red
                                        "Error": "#F44336",  // Red
                                        "Disconnected": "#E91E63",  // Pink
                                        "Device Lost": "#9C27B0",  // Purple
                                        "No Vehicle": "#2196F3"  // Blue
                                    }
                                    
                                    // Default to red if status not in our map
                                    color: obdManager ? 
                                        (statusColors[obdManager.get_connection_status()] || "#F44336") : 
                                        "#F44336"
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
                                            text: "Reconnect"
                                            onTriggered: {
                                                if (obdManager) {
                                                    clickAnimation.start()
                                                    obdManager.reconnect()
                                                }
                                            }
                                        }
                                        
                                        MenuItem {
                                            text: "Reset Connection"
                                            onTriggered: {
                                                if (obdManager) {
                                                    clickAnimation.start()
                                                    obdManager.reset_connection()
                                                }
                                            }
                                        }
                                        
                                        MenuItem {
                                            text: "Check Device Presence"
                                            onTriggered: {
                                                if (obdManager) {
                                                    let present = obdManager.check_device_presence()
                                                    if (present) {
                                                        deviceFoundNotification.open()
                                                    } else {
                                                        deviceNotFoundNotification.open()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Connections to OBD manager
                                    Connections {
                                        target: obdManager
                                        
                                        function onConnectionStatusChanged(status) {
                                            connectionStatusRect.connecting = (status === "Connecting")
                                            connectionTimeoutTimer.stop()
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
                                        color: "#F44336"
                                        radius: 4
                                    }
                                    
                                    contentItem: Text {
                                        text: "OBD device not found. Check connections."
                                        color: "white"
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: App.Spacing.overallText
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

                                Popup {
                                    id: deviceFoundNotification
                                    x: (parent.width - width) / 2
                                    y: parent.height - height - 20
                                    width: 300
                                    height: 60
                                    modal: false
                                    focus: true
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                    
                                    background: Rectangle {
                                        color: App.Style.accent
                                        radius: 4
                                    }
                                    
                                    contentItem: Text {
                                        text: "OBD device found!"
                                        color: "white"
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: App.Spacing.overallText
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
                                        interval: 2000
                                        running: deviceFoundNotification.visible
                                        onTriggered: deviceFoundNotification.close()
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Click the status bar above to attempt reconnection"
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Bluetooth Device Path
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "Bluetooth OBD Device"
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
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Enter the Bluetooth device port for your OBD adapter"
                                }
                            }
                            
                            SettingsDivider {}
                            
                            // Fast Mode Toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                            
                                SettingsToggle {
                                    text: "Fast Mode"
                                    Layout.fillWidth: true
                                    checked: settingsManager ? settingsManager.obdFastMode : true
                                    
                                    onToggled: {
                                        if (settingsManager) {
                                            settingsManager.save_obd_fast_mode(checked)
                                        }
                                    }
                                }
                                
                                SettingDescription {
                                    text: "Fast mode optimizes for quicker updates but may not work with all vehicles"
                                }
                            }

                            SettingsDivider {}

                            // Auto-Reconnect Attempts
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing

                                SettingLabel {
                                    text: "Auto-Reconnect Attempts"
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
                                        font.bold: true
                                        Layout.preferredWidth: 30
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                SettingDescription {
                                    text: "Number of times to retry connecting to OBD device (0 = disabled)"
                                }
                            }

                            SettingsDivider {}

                            // Parameter selection
                            ColumnLayout {
                                id: parameterSelectionLayout
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingLabel {
                                    text: "OBD Parameters"
                                }
                                
                                // Controls row (Select All and Deselect All buttons)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 10
                                    
                                    // Select All button
                                    Button {
                                        id: selectAllButton
                                        text: "Select All"
                                        implicitHeight: App.Spacing.overallSpacing * 2
                                        
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
                                        }
                                        
                                        contentItem: Text {
                                            text: selectAllButton.text
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        MouseArea {
                                            id: selectAllMouseArea
                                            anchors.fill: parent
                                            onClicked: {
                                                // Select all parameters
                                                if (settingsManager) {
                                                    const parameterList = [
                                                        "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE", "ENGINE_LOAD", 
                                                        "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                                                        "MAF", "SPEED", "RPM", "COMMANDED_EQUIV_RATIO",
                                                        "FUEL_LEVEL", "INTAKE_PRESSURE", "SHORT_FUEL_TRIM_1",
                                                        "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                                                        "OIL_TEMP", "IGNITION_TIMING"
                                                    ];
                                                    
                                                    parameterList.forEach(function(param) {
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
                                        }
                                        
                                        contentItem: Text {
                                            text: deselectAllButton.text
                                            color: App.Style.primaryTextColor
                                            font.pixelSize: App.Spacing.overallText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        MouseArea {
                                            id: deselectAllMouseArea
                                            anchors.fill: parent
                                            onClicked: {
                                                // Deselect all parameters
                                                if (settingsManager) {
                                                    const parameterList = [
                                                        "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE", "ENGINE_LOAD", 
                                                        "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                                                        "MAF", "SPEED", "RPM", "COMMANDED_EQUIV_RATIO",
                                                        "FUEL_LEVEL", "INTAKE_PRESSURE", "SHORT_FUEL_TRIM_1",
                                                        "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                                                        "OIL_TEMP", "IGNITION_TIMING"
                                                    ];
                                                    
                                                    parameterList.forEach(function(param) {
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
                                        
                                        // Count enabled parameters
                                        function updateEnabledCount() {
                                            if (!settingsManager) return;
                                            
                                            const parameterList = [
                                                "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE", "ENGINE_LOAD", 
                                                "THROTTLE_POS", "INTAKE_TEMP", "TIMING_ADVANCE",
                                                "MAF", "SPEED", "RPM", "COMMANDED_EQUIV_RATIO",
                                                "FUEL_LEVEL", "INTAKE_PRESSURE", "SHORT_FUEL_TRIM_1",
                                                "LONG_FUEL_TRIM_1", "O2_B1S1", "FUEL_PRESSURE",
                                                "OIL_TEMP", "IGNITION_TIMING"
                                            ];
                                            
                                            let count = 0;
                                            parameterList.forEach(function(param) {
                                                if (settingsManager.get_obd_parameter_enabled(param, true)) {
                                                    count++;
                                                }
                                            });
                                            
                                            enabledCount.text = count + " of " + parameterList.length + " enabled";
                                        }
                                        
                                        Component.onCompleted: {
                                            updateEnabledCount();
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
                                    Layout.preferredHeight: Math.min(600, childrenRect.height)
                                    
                                    // Parameter chips model
                                    property var parametersModel: [
                                        // Original parameters
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
                                        { name: "Short Term Fuel Trim", command: "SHORT_FUEL_TRIM_1" },
                                        { name: "Long Term Fuel Trim", command: "LONG_FUEL_TRIM_1" },
                                        { name: "O2 Sensor Voltage", command: "O2_B1S1" },
                                        { name: "Fuel Pressure", command: "FUEL_PRESSURE" },
                                        { name: "Oil Temperature", command: "OIL_TEMP" },
                                        { name: "Ignition Timing", command: "IGNITION_TIMING" }
                                    ]
                                    
                                    Repeater {
                                        model: parameterChipsFlow.parametersModel
                                        
                                        delegate: Rectangle {
                                            id: paramChip
                                            width: Math.min(parameterChipsFlow.width * 0.3, 400)
                                            height: App.Spacing.settingsButtonHeight*.8
                                            radius: 12
                                            
                                            // Bind the color directly to the parameter's enabled state
                                            property bool isEnabled: settingsManager ? 
                                                settingsManager.get_obd_parameter_enabled(modelData.command, true) : true
                                            
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
                                                        paramChip.isEnabled = settingsManager.get_obd_parameter_enabled(modelData.command, true);
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
                                                                // Add to home screen if space available
                                                                if (homeParams.length < 4) {
                                                                    homeParams.push(modelData.command);
                                                                    settingsManager.save_home_obd_parameters(homeParams);
                                                                } else {
                                                                    // Show replacement dialog if full
                                                                    replaceDialog.paramToAdd = modelData.command;
                                                                    replaceDialog.open();
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
                                Layout.minimumHeight: App.Spacing.bottomBar
                            }

                            function updateHomeDisplay() {
                                // Force refresh of home parameters display
                                homeParametersRepeater.model = [];
                                Qt.callLater(function() {
                                    if (settingsManager) {
                                        homeParametersRepeater.model = settingsManager.get_home_obd_parameters();
                                        homeParametersEmptyRepeater.model = Math.max(0, 4 - (settingsManager ? settingsManager.get_home_obd_parameters().length : 0));
                                        
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

                            // Show Clock Toggle - Using the new toggle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: App.Spacing.rowSpacing
                                
                                SettingsToggle {
                                    text: "Show Clock"
                                    Layout.fillWidth: true
                                    checked: settingsManager ? settingsManager.showClock : true
                                    
                                    onToggled: {
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
                            
                            Item { Layout.fillHeight: true } // Spacer
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
                                        font.bold: true
                                        color: App.Style.accent
                                        anchors.centerIn: parent
                                        z: 1
                                    }
                                }


                                // Description text
                                Text {
                                    id: descriptionText
                                    text: "Welcome to OCTAVE, an open-source, cross-platform telematics system for an augmented vehicle experience. Developed by Way Better Solutions, our mission is simple: we make things better.\n\nThis software is designed to provide a seamless interface for vehicle systems, media playback, navigation, and more."
                                    wrapMode: Text.WordWrap
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
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
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                
                                // GitHub link
                                Text {
                                    text: "<a href='https://github.com/WayBetterSolutions/OCTAVE'>github.com/WayBetterSolutions/OCTAVE</a>"
                                    color: App.Style.accent
                                    linkColor: App.Style.accent
                                    font.pixelSize: App.Spacing.overallText
                                    Layout.fillWidth: true
                                    onLinkActivated: Qt.openUrlExternally(link)
                                }
                                
                                Text {
                                    text: "Copyright © 2025 Way Better Solutions"
                                    color: App.Style.primaryTextColor
                                    font.pixelSize: App.Spacing.overallText
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
}