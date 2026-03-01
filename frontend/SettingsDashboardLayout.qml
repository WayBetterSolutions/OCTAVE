import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings"
import "settings/ScrollMemory.js" as ScrollMemory

Item {
    id: dashboardLayout

    // Required from orchestrator
    property var settingsMenu: null
    property var hubModel: []

    // State: "hub" = card grid landing, "detail" = full-width settings page
    property string viewState: ""

    // Sub-section scroll targeting
    property string pendingScrollTarget: ""

    // Decide initial viewState once settingsMenu is wired up by the orchestrator's onLoaded
    onSettingsMenuChanged: {
        if (!settingsMenu || viewState !== "") return

        // Mid-session layout switch: stay in detail if already viewing a section
        if (settingsMenu.currentSection && settingsMenu.currentSection !== "") {
            var page = settingsMenu.pageForSection(settingsMenu.currentSection)
            if (page && settingsMenu.isVisible(settingsMenu.currentSection)) {
                viewState = "detail"
                return
            }
        }
        // Initial app launch: resume last category if valid
        if (settingsMenu.isInitialLoad
                && settingsMenu.initialSection && settingsMenu.initialSection !== "") {
            var page2 = settingsMenu.pageForSection(settingsMenu.initialSection)
            if (page2 && settingsMenu.isVisible(settingsMenu.initialSection)) {
                settingsMenu.currentSection = settingsMenu.initialSection
                viewState = "detail"
                return
            }
        }
        viewState = "hub"
    }

    function sourceForSection(section) {
        if (!settingsMenu) return ""
        for (var i = 0; i < settingsMenu.pageModel.length; i++) {
            if (settingsMenu.pageModel[i].section === section)
                return settingsMenu.pageModel[i].source
        }
        return settingsMenu.pageModel[0].source
    }

    // Dashboard column span — important categories get 2 columns in 3-col mode
    function getSpanForSection(section) {
        switch (section) {
            case "displaySettings":
            case "mediaSettings":
                return 2
            default:
                return 1
        }
    }

    // Widget source for a section
    function getWidgetForSection(section) {
        if (!settingsMenu) return ""
        for (var i = 0; i < settingsMenu.pageModel.length; i++) {
            if (settingsMenu.pageModel[i].section === section)
                return settingsMenu.pageModel[i].widget || ""
        }
        return ""
    }

    // Count how many grid rows the model occupies
    function getRowCount(cols) {
        var col = 0
        var rows = 1
        for (var i = 0; i < dashModel.length; i++) {
            var span = dashModel[i].span
            if (cols <= 2) span = 1
            if (col + span > cols) {
                rows++
                col = 0
            }
            col += span
            if (col >= cols) {
                if (i < dashModel.length - 1) rows++
                col = 0
            }
        }
        return Math.max(rows, 1)
    }

    // Build dashboard model with optimal grid packing order:
    // Pair each span-2 card with a span-1 card to fill a 3-column row,
    // then append remaining span-1 cards in groups of 3.
    property var dashModel: {
        var wides = []   // span-2 items
        var narrows = [] // span-1 items
        for (var i = 0; i < hubModel.length; i++) {
            var page = hubModel[i]
            var entry = {
                name: page.name,
                section: page.section,
                icon: page.icon,
                widgetItems: [],
                widgetSource: getWidgetForSection(page.section),
                span: getSpanForSection(page.section)
            }
            if (entry.span >= 2)
                wides.push(entry)
            else
                narrows.push(entry)
        }
        // Interleave: wide + narrow fills a 3-col row
        var model = []
        for (var w = 0; w < wides.length; w++) {
            model.push(wides[w])
            if (narrows.length > 0)
                model.push(narrows.shift())
        }
        // Remaining narrows fill in groups of 3
        for (var n = 0; n < narrows.length; n++)
            model.push(narrows[n])
        return model
    }

    // Navigate to a category detail view
    function navigateToCategory(section) {
        if (settingsMenu) {
            settingsMenu.currentSection = section
            if (settingsManager)
                settingsManager.set_last_settings_section(section)
        }
        viewState = "detail"
    }

    // Navigate to sub-section
    function navigateToSubSection(section, subSection) {
        pendingScrollTarget = subSection
        navigateToCategory(section)
    }

    // Return to hub
    function navigateToHub() {
        viewState = "hub"
    }

    // ─── Hub State ───
    Item {
        id: hubView
        anchors.fill: parent
        visible: false
        opacity: 0

        // Environment backgrounds (behind grid)
        ContentSonar {}
        ContentSolarSystem {}

        GridLayout {
            id: hubGrid
            anchors.fill: parent
            anchors.margins: App.Spacing.settingsHubGridSpacing
            columns: width > 800 ? 3 : 2
            columnSpacing: App.Spacing.settingsHubGridSpacing
            rowSpacing: App.Spacing.settingsHubGridSpacing

            // Compute card height to fill available space
            property int rowCount: getRowCount(columns)
            property real cardHeight: (height - (rowCount - 1) * rowSpacing) / rowCount

            Repeater {
                model: dashModel.length

                SettingsDashboardCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: hubGrid.cardHeight
                    Layout.columnSpan: hubGrid.columns === 3 ? (dashModel[index] ? dashModel[index].span : 1) : 1
                    categoryName: dashModel[index] ? dashModel[index].name : ""
                    section: dashModel[index] ? dashModel[index].section : ""
                    widgetItems: dashModel[index] ? dashModel[index].widgetItems : []
                    widgetSource: dashModel[index] ? dashModel[index].widgetSource : ""
                    categoryIcon: dashModel[index] ? dashModel[index].icon : ""
                    cardSpan: hubGrid.columns === 3 ? (dashModel[index] ? dashModel[index].span : 1) : 1
                    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.hubCardRadius, 2)

                    onCategorySelected: function(sec) {
                        dashboardLayout.navigateToCategory(sec)
                    }
                    onSubSectionSelected: function(sec, sub) {
                        dashboardLayout.navigateToSubSection(sec, sub)
                    }
                }
            }
        }
    }

    // ─── Detail State ───
    Item {
        id: detailView
        anchors.fill: parent
        visible: false
        opacity: 0

        Rectangle {
            anchors.fill: parent
            color: App.Style.contentColor

            // HUD lines (spacecraft)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: App.Spacing.settingsContentMargin
                anchors.rightMargin: App.Spacing.settingsContentMargin
                height: 1
                z: 1
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                visible: App.EnvironmentTheme.active.contentHudLines
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: App.Spacing.settingsContentMargin
                anchors.rightMargin: App.Spacing.settingsContentMargin
                height: 1
                z: 1
                color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.3)
                visible: App.EnvironmentTheme.active.contentHudLines
            }

            ContentSonar {}
            ContentSolarSystem {}

            // ─── Heading bar ───
            Item {
                id: headingBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: App.Spacing.overallSpacing * 2.4
                z: 2

                Row {
                    id: headingRow
                    anchors.left: parent.left
                    anchors.leftMargin: App.Spacing.settingsContentMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: App.Spacing.overallSpacing * 0.5

                    Text {
                        text: "\u2190"
                        color: floatingLabelArea.containsMouse ? App.Style.accent : App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText * 1.1
                        font.family: App.Style.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        text: settingsMenu ? settingsMenu.nameForSection(settingsMenu.currentSection) : ""
                        color: floatingLabelArea.containsMouse ? App.Style.accent : App.Style.primaryTextColor
                        font.pixelSize: App.Spacing.overallText * 1.1
                        font.bold: true
                        font.family: App.Style.fontFamily
                        font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
                        font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: floatingLabelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dashboardLayout.navigateToHub()
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: App.Style.accent }
                        GradientStop { position: 0.6; color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // ─── Scroll rail (touch-friendly drag area) ───
            Rectangle {
                id: scrollRail
                anchors.top: headingBar.bottom
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: App.Spacing.dp(40)
                color: Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.03)

                property var flick: contentLoader.item
                property bool canScroll: flick && flick.contentHeight > flick.height

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.15)
                }

                Rectangle {
                    id: scrollHandle
                    visible: scrollRail.canScroll
                    width: App.Spacing.dp(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: width / 2
                    color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                                   scrollHandleArea.pressed ? 0.8 : scrollHandleArea.containsMouse ? 0.6 : 0.4)

                    Behavior on color { ColorAnimation { duration: 100 } }

                    property real trackHeight: scrollRail.height
                    property real handleRatio: scrollRail.flick ? Math.min(1, scrollRail.flick.height / scrollRail.flick.contentHeight) : 1
                    height: Math.max(App.Spacing.dp(50), trackHeight * handleRatio)

                    y: {
                        if (!scrollRail.canScroll) return 0
                        var scrollRange = scrollRail.flick.contentHeight - scrollRail.flick.height
                        var trackRange = scrollRail.height - height
                        if (scrollRange <= 0) return 0
                        return (scrollRail.flick.contentY / scrollRange) * trackRange
                    }
                }

                MouseArea {
                    id: scrollHandleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true

                    property real dragStartY: 0
                    property real dragStartContentY: 0

                    onPressed: function(mouse) {
                        if (!scrollRail.canScroll) return
                        var scrollRange = scrollRail.flick.contentHeight - scrollRail.flick.height
                        var trackRange = scrollRail.height - scrollHandle.height
                        if (trackRange > 0) {
                            var targetHandleY = Math.max(0, Math.min(mouse.y - scrollHandle.height / 2, trackRange))
                            scrollRail.flick.contentY = (targetHandleY / trackRange) * scrollRange
                        }
                        dragStartY = mouse.y
                        dragStartContentY = scrollRail.flick.contentY
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || !scrollRail.canScroll) return
                        var deltaY = mouse.y - dragStartY
                        var scrollRange = scrollRail.flick.contentHeight - scrollRail.flick.height
                        var trackRange = scrollRail.height - scrollHandle.height
                        if (trackRange <= 0) return
                        var newContentY = dragStartContentY + (deltaY / trackRange) * scrollRange
                        scrollRail.flick.contentY = Math.max(0, Math.min(newContentY, scrollRange))
                    }
                }
            }

            // ─── Content below heading ───
            Loader {
                id: contentLoader
                anchors {
                    top: headingBar.bottom
                    left: scrollRail.right
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: App.Spacing.settingsContentMargin
                    bottomMargin: App.Spacing.settingsContentMargin
                }
                source: viewState === "detail" && settingsMenu ? sourceForSection(settingsMenu.currentSection) : ""

                onLoaded: {
                    if (item && typeof item.mainWindow !== "undefined" && settingsMenu)
                        item.mainWindow = settingsMenu.mainWindow
                    if (item && typeof item.stackView !== "undefined" && settingsMenu)
                        item.stackView = settingsMenu.stackView
                    if (item && typeof item.currentSection !== "undefined" && settingsMenu)
                        item.currentSection = Qt.binding(function() { return settingsMenu ? settingsMenu.currentSection : "" })

                    if (pendingScrollTarget !== "") {
                        scrollToSectionTimer.targetName = pendingScrollTarget
                        pendingScrollTarget = ""
                        scrollToSectionTimer.restart()
                    } else {
                        var savedY = settingsMenu ? ScrollMemory.positions[settingsMenu.currentSection] : undefined
                        if (item && typeof item.contentY !== "undefined" && savedY !== undefined && savedY > 0) {
                            scrollRestoreTimer.savedY = savedY
                            scrollRestoreTimer.restart()
                        } else {
                            scrollRestoreTimer.stop()
                        }
                    }
                }
            }

            Timer {
                id: scrollRestoreTimer
                interval: 16
                repeat: true
                property real savedY: -1
                onTriggered: {
                    var fl = contentLoader.item
                    if (fl && fl.contentHeight > 0 && fl.height > 0 && savedY >= 0) {
                        fl.contentY = Math.min(savedY, Math.max(0, fl.contentHeight - fl.height))
                        savedY = -1
                        stop()
                    }
                }
            }

            Timer {
                id: scrollToSectionTimer
                interval: 16
                repeat: true
                property string targetName: ""
                onTriggered: {
                    var fl = contentLoader.item
                    if (!fl || fl.contentHeight <= 0 || fl.height <= 0 || targetName === "") return

                    var content = fl.contentItem ? fl.contentItem : fl
                    var targetCard = findChildByObjectName(content, targetName)
                    if (targetCard) {
                        var pos = targetCard.mapToItem(fl.contentItem, 0, 0)
                        var scrollMax = Math.max(0, fl.contentHeight - fl.height)
                        fl.contentY = Math.min(pos.y, scrollMax)
                        targetName = ""
                        stop()
                    }
                }

                function findChildByObjectName(parent, name) {
                    for (var i = 0; i < parent.children.length; i++) {
                        var child = parent.children[i]
                        if (child.objectName === name) return child
                        var found = findChildByObjectName(child, name)
                        if (found) return found
                    }
                    return null
                }
            }

            Connections {
                target: contentLoader.item
                function onContentYChanged() {
                    if (contentLoader.item && settingsMenu && settingsMenu.currentSection)
                        ScrollMemory.positions[settingsMenu.currentSection] = contentLoader.item.contentY
                }
            }
        }
    }

    // ─── State management ───
    states: [
        State {
            name: "hub"
            when: viewState === "hub"
            PropertyChanges { target: hubView; visible: true; opacity: 1.0 }
            PropertyChanges { target: detailView; visible: false; opacity: 0 }
        },
        State {
            name: "detail"
            when: viewState === "detail"
            PropertyChanges { target: hubView; visible: false; opacity: 0 }
            PropertyChanges { target: detailView; visible: true; opacity: 1.0 }
        }
    ]

    transitions: []
}
