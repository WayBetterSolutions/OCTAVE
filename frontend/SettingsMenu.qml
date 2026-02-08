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

                            // Background - rounded pill selection
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
                                    ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
                                    : "transparent"
                                border.width: currentSection === section ? 1 : 0
                                border.color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // Hover effect - rounded
                            Rectangle {
                                id: navHoverRectangle
                                visible: false
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
                            }

                            // Text
                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 20
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: name
                                color: currentSection === section ? App.Style.primaryTextColor : App.Style.secondaryTextColor
                                font.pixelSize: App.Spacing.overallText*2
                                font.family: App.Style.fontFamily
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

                                onEntered: {
                                    if (currentSection !== section) {
                                        navHoverRectangle.visible = true
                                    }
                                }
                                onExited: {
                                    navHoverRectangle.visible = false
                                }
                            }
                        }
                    }
                }
            }

            // Vertical separator between sidebar and content
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.08)
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
