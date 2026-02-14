import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".." as App

Flickable {
    contentWidth: width
    contentHeight: settingsContent.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 1200
    maximumFlickVelocity: 4000
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: settingsContent
        width: parent.width
        spacing: 0

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: App.Spacing.overallMargin * 2
            columns: 1
            rowSpacing: App.Spacing.overallSpacing * 2

            Item {
                Layout.fillWidth: true
                width: parent.width
                height: App.Spacing.dp(100)

                Text {
                    id: glowText
                    text: "OCTAVE"
                    font.pixelSize: App.Spacing.overallText * 5
                    font.family: App.Style.fontFamily
                    font.bold: true
                    color: App.Style.primaryTextColor
                    opacity: 0.5
                    anchors.centerIn: parent
                    scale: 1.05
                    z: 0

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 0.7; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.7; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                    }
                }

                Text {
                    id: titleText
                    text: "OCTAVE"
                    font.pixelSize: App.Spacing.overallText * 5
                    font.family: App.Style.fontFamily
                    font.bold: true
                    color: App.Style.accent
                    anchors.centerIn: parent
                    z: 1
                }
            }

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
                        font.family: App.Style.fontFamily
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing

                        Text {
                            text: "Commit:"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: App.Style.fontFamily
                        }
                        Text {
                            text: settingsManager ? settingsManager.get_git_commit_hash() : "unknown"
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: App.Style.fontFamily
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: App.Spacing.overallSpacing

                        Text {
                            text: "Date:"
                            color: App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: App.Style.fontFamily
                        }
                        Text {
                            text: settingsManager ? settingsManager.get_git_commit_date() : "unknown"
                            color: App.Style.primaryTextColor
                            font.pixelSize: App.Spacing.overallText * 0.85
                            font.family: App.Style.fontFamily
                        }
                    }

                    Text {
                        text: settingsManager ? settingsManager.get_git_commit_message() : ""
                        color: App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText * 0.8
                        font.family: App.Style.fontFamily
                        font.italic: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        visible: text !== ""
                    }
                }
            }

            Text {
                id: descriptionText
                text: "Welcome to OCTAVE, an open-source, cross-platform telematics system for an augmented vehicle experience. Developed by Way Better Solutions, our mission is simple: we make things better.

This software is designed to provide a seamless interface for vehicle systems, media playback, navigation, and more."
                wrapMode: Text.WordWrap
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                font.family: App.Style.fontFamily
                Layout.fillWidth: true
                Layout.topMargin: App.Spacing.overallSpacing
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: App.Style.hoverColor
                Layout.topMargin: App.Spacing.overallSpacing
                Layout.bottomMargin: App.Spacing.overallSpacing
            }

            Text {
                text: "GitHub Repository"
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText * 1.2
                font.family: App.Style.fontFamily
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: "<a href='https://github.com/WayBetterSolutions/OCTAVE'>github.com/WayBetterSolutions/OCTAVE</a>"
                color: App.Style.accent
                linkColor: App.Style.accent
                font.pixelSize: App.Spacing.overallText
                font.family: App.Style.fontFamily
                Layout.fillWidth: true
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Text {
                text: "2026 Way Better Solutions"
                color: App.Style.primaryTextColor
                font.pixelSize: App.Spacing.overallText
                font.family: App.Style.fontFamily
                Layout.fillWidth: true
                Layout.topMargin: App.Spacing.overallSpacing
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: App.Spacing.overallSpacing * 4
            }
        }
    }
}
