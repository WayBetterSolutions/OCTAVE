import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import "." as App
import "settings"

Item {
    id: settingsMenu
    objectName: "settingsMenu"
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: initialSection

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        RowLayout {
            anchors.fill: parent
            spacing: 0


            Rectangle { // Left Navigation Panel
                id: sidebarPanel
                Layout.preferredWidth: App.Spacing.settingsNavWidth
                Layout.fillHeight: true
                color: App.Style.sidebarColor

                // Sidebar lighting gradient (subtle overhead light simulation)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.04) }
                        GradientStop { position: 0.6; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.06) }
                    }
                }

                // Lit edge highlight along the top
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                // Soft shadow on the right edge (replaces hard separator)
                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.right
                    }
                    width: 10
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.06) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

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

                            // Elevation shadow - outer (soft, wide spread)
                            Rectangle {
                                x: navBackground.x - 2
                                y: navBackground.y + 4
                                width: navBackground.width + 4
                                height: navBackground.height + 2
                                radius: navBackground.radius + 3
                                color: Qt.rgba(0, 0, 0, 0.06)
                                opacity: currentSection === section ? 1.0
                                    : (navMouseArea.containsMouse ? 0.6 : 0)

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Elevation shadow - inner (sharper, tighter)
                            Rectangle {
                                x: navBackground.x - 1
                                y: navBackground.y + 2
                                width: navBackground.width + 2
                                height: navBackground.height + 1
                                radius: navBackground.radius + 1
                                color: Qt.rgba(0, 0, 0, 0.12)
                                opacity: currentSection === section
                                    ? (navMouseArea.pressed ? 0.4 : 1.0)
                                    : (navMouseArea.containsMouse ? 0.5 : 0)

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Background - rounded selection
                            Rectangle {
                                id: navBackground
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 8
                                    rightMargin: 8
                                    topMargin: 3
                                    bottomMargin: 3
                                }
                                radius: 8
                                color: currentSection === section
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.25)
                                    : "transparent"
                                scale: navMouseArea.pressed ? 0.97 : 1.0

                                // Top lit edge on selected/hovered item
                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: 2
                                        rightMargin: 2
                                    }
                                    height: 1
                                    radius: 0.5
                                    color: Qt.rgba(255, 255, 255, 0.1)
                                    opacity: currentSection === section ? 1.0
                                        : (navMouseArea.containsMouse ? 0.5 : 0)

                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                            }

                            // Left accent bar for selected item
                            Rectangle {
                                id: accentBar
                                anchors {
                                    left: parent.left
                                    leftMargin: 4
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 3
                                height: currentSection === section ? parent.height * 0.5 : 0
                                radius: 1.5
                                color: App.Style.accent

                                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            }

                            // Hover effect - rounded
                            Rectangle {
                                id: navHoverRectangle
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 8
                                    rightMargin: 8
                                    topMargin: 3
                                    bottomMargin: 3
                                }
                                radius: 8
                                color: Qt.rgba(App.Style.hoverColor.r, App.Style.hoverColor.g, App.Style.hoverColor.b, 0.3)
                                opacity: 0

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Text
                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 24
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: name
                                color: currentSection === section ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.overallText * 2
                                font.bold: currentSection === section
                                font.family: App.Style.fontFamily
                                elide: Text.ElideRight
                            }

                            // Entire area clickable
                            MouseArea {
                                id: navMouseArea
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

                                onEntered: {
                                    if (currentSection !== section) {
                                        navHoverRectangle.opacity = 1
                                    }
                                }
                                onExited: {
                                    navHoverRectangle.opacity = 0
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { // Right Content Area
                id: contentArea
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

                    DeviceSettingsPage {
                        mainWindow: settingsMenu.mainWindow
                    }

                    MediaSettingsPage {
                        currentSection: settingsMenu.currentSection
                    }

                    DisplaySettingsPage {
                        stackView: settingsMenu.stackView
                        mainWindow: settingsMenu.mainWindow
                        currentSection: settingsMenu.currentSection
                    }

                    OBDSettingsPage {}

                    ClockSettingsPage {}

                    AndroidAutoSettingsPage {}

                    PhoneMirrorSettingsPage {}

                    VolumeKnobSettingsPage {}

                    AboutPage {}
                }
            }
        }
    }
}
