import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

Item {
    id: obdHome
    objectName: "obdHome"
    required property StackView stackView
    required property ApplicationWindow mainWindow

    property string globalFont: App.Style.fontFamily
    property color backgroundColor: App.Style.obdBoxBackground
    property color accentColor: App.Style.obdBarColor
    property color textColor: App.Style.obdValueColor
    property color labelColor: App.Style.obdLabelColor

    // Track last-visited subpage for visual indicator
    property string lastSubpage: settingsManager
        ? settingsManager.get_setting_with_default("lastOBDPage", "")
        : ""

    // Connection status
    property string connectionStatus: "Disconnected"
    property string connectionDetail: ""
    property bool connected: obdManager ? obdManager.is_connected() : false

    Connections {
        target: obdManager
        enabled: obdManager !== null

        function onConnectionStatusChanged(status) {
            obdHome.connectionStatus = status
            obdHome.connected = obdManager.is_connected()
        }
        function onConnectionStatusDetailChanged(detail) {
            obdHome.connectionDetail = detail
        }
    }

    // Helper to push a subpage
    function pushSubpage(qmlFile) {
        if (settingsManager) {
            settingsManager.save_setting("lastOBDPage", qmlFile)
            lastSubpage = qmlFile
        }
        var component = Qt.createComponent(qmlFile)
        if (component.status === Component.Ready) {
            var page = component.createObject(stackView, {
                stackView: obdHome.stackView,
                mainWindow: obdHome.mainWindow
            })
            if (page) {
                stackView.push(page)
            }
        } else {
            console.warn("[OBDHome] Failed to load", qmlFile, component.errorString())
        }
    }

    Rectangle {
        anchors.fill: parent
        color: backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: App.Spacing.dp(20)
            anchors.bottomMargin: App.Spacing.dp(70)
            spacing: App.Spacing.dp(20)

            // ── Connection status bar ────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: App.Spacing.dp(48)
                radius: App.Spacing.dpMin(8, 3)
                color: Qt.darker(backgroundColor, 0.9)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: App.Spacing.dp(16)
                    anchors.rightMargin: App.Spacing.dp(16)
                    spacing: App.Spacing.dp(10)

                    // Status dot
                    Rectangle {
                        width: App.Spacing.dp(12)
                        height: width
                        radius: width / 2
                        color: obdHome.connected ? "#00FF00"
                             : obdHome.connectionStatus === "Connecting" ? "#FFAA00"
                             : "#FF4444"

                        SequentialAnimation on opacity {
                            running: obdHome.connectionStatus === "Connecting"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        text: obdHome.connectionStatus
                        color: textColor
                        font.pixelSize: App.Spacing.overallText
                        font.bold: true
                        font.family: obdHome.globalFont
                    }

                    Text {
                        text: obdHome.connectionDetail
                        color: labelColor
                        font.pixelSize: App.Spacing.overallText * 0.85
                        font.family: obdHome.globalFont
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Button grid ──────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: App.Spacing.dp(16)
                columnSpacing: App.Spacing.dp(16)

                // --- Dashboards card ---
                Rectangle {
                    id: dashboardsCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: App.Spacing.dpMin(12, 4)
                    color: dashboardsMouse.containsMouse
                           ? Qt.lighter(Qt.darker(backgroundColor, 0.85), 1.08)
                           : Qt.darker(backgroundColor, 0.85)
                    border.color: lastSubpage === "OBDMenu.qml" ? accentColor : "transparent"
                    border.width: lastSubpage === "OBDMenu.qml" ? 2 : 0

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: dashboardsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: obdHome.pushSubpage("OBDMenu.qml")
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(12)

                        // Icon placeholder — tachometer shape
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: App.Spacing.dp(56)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: accentColor
                            border.width: 3

                            // Needle
                            Rectangle {
                                width: 3
                                height: parent.height * 0.35
                                color: accentColor
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.verticalCenter
                                transformOrigin: Item.Bottom
                                rotation: 45
                            }
                        }

                        Text {
                            text: "Dashboards"
                            color: textColor
                            font.pixelSize: App.Spacing.overallText * 1.2
                            font.bold: true
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Live gauges & parameters"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // --- Trouble Codes (DTC) card ---
                Rectangle {
                    id: dtcCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: App.Spacing.dpMin(12, 4)
                    color: dtcMouse.containsMouse
                           ? Qt.lighter(Qt.darker(backgroundColor, 0.85), 1.08)
                           : Qt.darker(backgroundColor, 0.85)
                    border.color: lastSubpage === "OBDDiagnostics.qml" ? accentColor : "transparent"
                    border.width: lastSubpage === "OBDDiagnostics.qml" ? 2 : 0

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: dtcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: obdHome.pushSubpage("OBDDiagnostics.qml")
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(12)

                        // Icon placeholder — warning triangle
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: App.Spacing.dp(56)
                            height: width

                            Text {
                                anchors.centerIn: parent
                                text: "\u26A0"
                                font.pixelSize: App.Spacing.dp(36)
                                color: accentColor
                            }
                        }

                        Text {
                            text: "Trouble Codes"
                            color: textColor
                            font.pixelSize: App.Spacing.overallText * 1.2
                            font.bold: true
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Read & clear DTCs"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // --- Vehicle Scan card (placeholder) ---
                Rectangle {
                    id: scanCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: App.Spacing.dpMin(12, 4)
                    color: Qt.darker(backgroundColor, 0.85)
                    opacity: 0.5

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(12)

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: App.Spacing.dp(56)
                            height: width

                            // Scan icon — concentric circles
                            Rectangle {
                                anchors.centerIn: parent
                                width: App.Spacing.dp(40)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: labelColor
                                border.width: 2

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.5
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: labelColor
                                    border.width: 2
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: App.Spacing.dp(6)
                                    height: width
                                    radius: width / 2
                                    color: labelColor
                                }
                            }
                        }

                        Text {
                            text: "Vehicle Scan"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 1.2
                            font.bold: true
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Coming soon"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                            opacity: 0.7
                        }
                    }
                }

                // --- Connection card (placeholder) ---
                Rectangle {
                    id: connectionCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: App.Spacing.dpMin(12, 4)
                    color: Qt.darker(backgroundColor, 0.85)
                    opacity: 0.5

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: App.Spacing.dp(12)

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: App.Spacing.dp(56)
                            height: width

                            // Connection icon — plug shape
                            Rectangle {
                                anchors.centerIn: parent
                                width: App.Spacing.dp(30)
                                height: App.Spacing.dp(6)
                                radius: 3
                                color: labelColor

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: App.Spacing.dp(12)
                                    height: App.Spacing.dp(20)
                                    radius: 3
                                    color: "transparent"
                                    border.color: labelColor
                                    border.width: 2
                                }
                            }
                        }

                        Text {
                            text: "Connection"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 1.2
                            font.bold: true
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Coming soon"
                            color: labelColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: obdHome.globalFont
                            Layout.alignment: Qt.AlignHCenter
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }
}
