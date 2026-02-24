import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    property var mainWindow: null

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: App.Spacing.sectionSpacing

        SettingsCard {
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
                        if (text.trim() !== "" && settingsManager && mainWindow) {
                            mainWindow.updateDeviceName(text)
                        }
                    }
                }
            }
        }

        SettingsCard {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsSectionHeader {
                    title: "Network"
                    description: "Current network connection status"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    // Connection status dot
                    Rectangle {
                        width: App.Spacing.dp(10)
                        height: App.Spacing.dp(10)
                        radius: width / 2
                        color: networkManager && networkManager.isConnected ? "#4CAF50" : "#F44336"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing * 0.25

                        Text {
                            text: {
                                if (!networkManager) return "Unknown"
                                if (!networkManager.isConnected) return "Not Connected"
                                return networkManager.networkName || "Connected"
                            }
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText
                            font.family: App.Style.fontFamily
                            font.bold: true
                        }

                        Text {
                            text: {
                                if (!networkManager) return ""
                                if (!networkManager.isConnected) return "No internet access"
                                if (networkManager.networkName)
                                    return "Internet connected"
                                return "Internet connected"
                            }
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.8
                            font.family: App.Style.fontFamily
                        }
                    }

                    SettingsButton {
                        text: "Refresh"
                        height: App.Spacing.dp(28)
                        onClicked: {
                            if (networkManager)
                                networkManager.refreshNetwork()
                        }
                    }
                }
            }
        }

        SettingsCard {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: App.Spacing.rowSpacing

                SettingsSectionHeader {
                    title: "Power"
                }

                SettingDescription {
                    text: "Shut down OCTAVE and power off the device."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: App.Spacing.overallSpacing

                    property bool confirmingShutdown: false

                    // Reset confirmation after 5 seconds
                    Timer {
                        id: shutdownResetTimer
                        interval: 5000
                        onTriggered: parent.confirmingShutdown = false
                    }

                    SettingsButton {
                        text: parent.confirmingShutdown ? "Confirm Shutdown" : "Shut Down"
                        buttonColor: parent.confirmingShutdown ? "#F44336" : App.Style.accent
                        height: App.Spacing.dp(34)
                        onClicked: {
                            if (parent.confirmingShutdown) {
                                if (networkManager)
                                    networkManager.shutdown_device()
                            } else {
                                parent.confirmingShutdown = true
                                shutdownResetTimer.restart()
                            }
                        }
                    }

                    Text {
                        text: "Press again to confirm"
                        color: "#F44336"
                        font.pixelSize: App.Spacing.overallText * 0.8
                        font.family: App.Style.fontFamily
                        visible: parent.confirmingShutdown
                        Layout.alignment: Qt.AlignVCenter

                        SequentialAnimation on opacity {
                            running: parent.parent.confirmingShutdown
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
                            NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: App.Spacing.bottomBarHeight
        }
    }
}
