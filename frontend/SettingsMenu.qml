import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings"
import "settings/ScrollMemory.js" as ScrollMemory

Item {
    id: settingsMenu
    objectName: "settingsMenu"
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: ""

    // State: "hub" = card grid landing, "detail" = full-width settings page
    // Default "" so neither state matches initially — avoids hub flash when entering detail directly
    property string viewState: ""

    // Central page model — single source of truth for all pages
    // Order optimized for dashboard grid packing: span-2 cards first in each row, span-1 fills column 3
    // Row 1: Display(2) + Device(1)  |  Row 2: Media(2) + Phone Dock(1)  |  Row 3: OBD(1) + Accessories(1) + About(1)
    readonly property var pageModel: [
        { name: "Display",     section: "displaySettings",     source: "settings/DisplaySettingsPage.qml",     widget: "widgets/DisplayWidget.qml",     icon: "\u263C" },
        { name: "Device",      section: "deviceSettings",      source: "settings/DeviceSettingsPage.qml",      widget: "widgets/DeviceWidget.qml",      icon: "\u2699" },
        { name: "Media",       section: "mediaSettings",       source: "settings/MediaSettingsPage.qml",       widget: "widgets/MediaWidget.qml",       icon: "\u266B" },
        { name: "Phone Dock",  section: "phoneDockSettings",   source: "settings/PhoneDockSettingsPage.qml",   widget: "widgets/PhoneDockWidget.qml",   icon: "\u260E" },
        { name: "OBD",         section: "obdSettings",         source: "settings/OBDSettingsPage.qml",         widget: "widgets/OBDWidget.qml",         icon: "\u26A1" },
        { name: "Accessories", section: "accessoriesSettings", source: "settings/AccessoriesSettingsPage.qml", widget: "widgets/AccessoriesWidget.qml", icon: "\u2388" },
        { name: "About",       section: "about",               source: "settings/AboutPage.qml",               widget: "widgets/AboutWidget.qml",       icon: "\u2139" }
    ]

    // Derived section order for fallback when current section is hidden
    readonly property var sectionOrder: {
        var order = []
        for (var i = 0; i < pageModel.length; i++)
            order.push(pageModel[i].section)
        return order
    }

    // Visible pages model for the hub grid
    property var hubModel: []

    Component.onCompleted: {
        buildHubModel()

        // Entry behavior: resume last category if valid
        if (initialSection && initialSection !== "") {
            var page = pageForSection(initialSection)
            if (page && isVisible(initialSection)) {
                currentSection = initialSection
                viewState = "detail"
                return
            }
        }
        viewState = "hub"
    }


    // Look up the QML source for a given section
    function sourceForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i].source
        }
        return pageModel[0].source
    }

    // Look up page info by section
    function pageForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i]
        }
        return null
    }

    // Look up page name by section
    function nameForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i].name
        }
        return "Settings"
    }

    // Check if a section is visible
    function isVisible(section) {
        return settingsManager ? settingsManager.is_settings_section_visible(section) : true
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

    // Count how many grid rows the hub model occupies (simulates GridLayout packing)
    function getRowCount(cols) {
        var col = 0
        var rows = 1
        for (var i = 0; i < hubModel.length; i++) {
            var span = hubModel[i].span
            if (cols <= 2) span = 1  // 2-col mode ignores spans
            if (col + span > cols) {
                rows++
                col = 0
            }
            col += span
            if (col >= cols) {
                if (i < hubModel.length - 1) rows++
                col = 0
            }
        }
        return Math.max(rows, 1)
    }

    // Build the hub model from pageModel, respecting visibility
    function buildHubModel() {
        var model = []
        for (var i = 0; i < pageModel.length; i++) {
            var page = pageModel[i]
            if (isVisible(page.section)) {
                model.push({
                    name: page.name,
                    section: page.section,
                    icon: page.icon,
                    widgetItems: [],
                    widgetSource: page.widget || "",
                    span: getSpanForSection(page.section)
                })
            }
        }
        hubModel = model
    }

    // Navigate to a category detail view
    function navigateToCategory(section) {
        currentSection = section
        viewState = "detail"
        if (settingsManager) {
            settingsManager.set_last_settings_section(section)
        }
    }

    // Return to hub
    function navigateToHub() {
        buildHubModel()
        viewState = "hub"
    }

    // ─── Sub-section scroll targeting ───
    // When a chip is clicked, we navigate to the detail page and scroll to the target card
    property string pendingScrollTarget: ""

    function navigateToSubSection(section, subSection) {
        pendingScrollTarget = subSection
        navigateToCategory(section)
    }

    // When visibility changes, rebuild hub and check if we need to navigate away
    Connections {
        target: settingsManager
        function onSettingsMenuVisibilityChanged() {
            buildHubModel()
            if (viewState === "detail" && !isVisible(currentSection)) {
                navigateToHub()
            }
        }
    }

    // Note: Live hub refresh Connections removed — widget QML files have live
    // property bindings that update automatically. Only visibility changes
    // (handled by onSettingsMenuVisibilityChanged above) require rebuilding hubModel.

    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        // ─── Hub State ───────────────────────────────────────────────
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
                anchors.margins: App.Spacing.settingsContentMargin
                anchors.bottomMargin: App.Spacing.settingsContentMargin
                columns: width > 800 ? 3 : 2
                columnSpacing: App.Spacing.settingsHubGridSpacing
                rowSpacing: App.Spacing.settingsHubGridSpacing

                // Compute card height to fill available space
                property int rowCount: getRowCount(columns)
                property real cardHeight: (height - (rowCount - 1) * rowSpacing) / rowCount

                Repeater {
                    model: hubModel.length

                    SettingsHubCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: hubGrid.cardHeight
                        Layout.columnSpan: hubGrid.columns === 3 ? (hubModel[index] ? hubModel[index].span : 1) : 1
                        categoryName: hubModel[index] ? hubModel[index].name : ""
                        section: hubModel[index] ? hubModel[index].section : ""
                        widgetItems: hubModel[index] ? hubModel[index].widgetItems : []
                        widgetSource: hubModel[index] ? hubModel[index].widgetSource : ""
                        categoryIcon: hubModel[index] ? hubModel[index].icon : ""
                        cardSpan: hubGrid.columns === 3 ? (hubModel[index] ? hubModel[index].span : 1) : 1
                        radius: App.Spacing.dpMin(App.EnvironmentTheme.active.hubCardRadius, 2)

                        onCategorySelected: function(sec) {
                            settingsMenu.navigateToCategory(sec)
                        }
                        onSubSectionSelected: function(sec, sub) {
                            settingsMenu.navigateToSubSection(sec, sub)
                        }
                    }
                }
            }

        }

        // ─── Detail State ────────────────────────────────────────────
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

                        // Back arrow
                        Text {
                            text: "\u2190"
                            color: floatingLabelArea.containsMouse ? App.Style.accent : App.Style.secondaryTextColor
                            font.pixelSize: App.Spacing.overallText * 1.1
                            font.family: App.Style.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Category name
                        Text {
                            id: categoryLabelText
                            text: nameForSection(currentSection)
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
                        onClicked: settingsMenu.navigateToHub()
                    }

                    // Bottom separator line
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

                    // Convenience aliases for the loaded Flickable
                    property var flick: contentLoader.item
                    property bool canScroll: flick && flick.contentHeight > flick.height

                    // Right-edge separator
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.15)
                    }

                    // Scroll handle
                    Rectangle {
                        id: scrollHandle
                        visible: scrollRail.canScroll
                        width: App.Spacing.dp(6)
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: width / 2
                        color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b,
                                       scrollHandleArea.pressed ? 0.8 : scrollHandleArea.containsMouse ? 0.6 : 0.4)

                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Handle height proportional to visible/total content
                        property real trackHeight: scrollRail.height
                        property real handleRatio: scrollRail.flick ? Math.min(1, scrollRail.flick.height / scrollRail.flick.contentHeight) : 1
                        height: Math.max(App.Spacing.dp(50), trackHeight * handleRatio)

                        // Position bound to Flickable scroll position
                        y: {
                            if (!scrollRail.canScroll) return 0
                            var scrollRange = scrollRail.flick.contentHeight - scrollRail.flick.height
                            var trackRange = scrollRail.height - height
                            if (scrollRange <= 0) return 0
                            return (scrollRail.flick.contentY / scrollRange) * trackRange
                        }
                    }

                    // Full-rail touch/drag area
                    MouseArea {
                        id: scrollHandleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true

                        property real dragStartY: 0
                        property real dragStartContentY: 0

                        onPressed: function(mouse) {
                            if (!scrollRail.canScroll) return
                            // If pressing outside the handle, jump to that position first
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
                    source: viewState === "detail" ? sourceForSection(currentSection) : ""

                    onLoaded: {
                        // Bind optional properties if the page declares them
                        if (item && typeof item.mainWindow !== "undefined")
                            item.mainWindow = settingsMenu.mainWindow
                        if (item && typeof item.stackView !== "undefined")
                            item.stackView = settingsMenu.stackView
                        if (item && typeof item.currentSection !== "undefined")
                            item.currentSection = Qt.binding(function() { return settingsMenu.currentSection })

                        // Sub-section scroll targeting — find card by objectName and scroll to it
                        if (pendingScrollTarget !== "") {
                            scrollToSectionTimer.targetName = pendingScrollTarget
                            pendingScrollTarget = ""
                            scrollToSectionTimer.restart()
                        } else {
                            // Normal scroll restore from memory
                            var savedY = ScrollMemory.positions[currentSection]
                            if (item && typeof item.contentY !== "undefined" && savedY !== undefined && savedY > 0) {
                                scrollRestoreTimer.savedY = savedY
                                scrollRestoreTimer.restart()
                            } else {
                                scrollRestoreTimer.stop()
                            }
                        }
                    }
                }

                // Polls each frame until the Flickable has valid dimensions, then restores scroll
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

                // Polls until layout is ready, then scrolls to the target SettingsCard by objectName
                Timer {
                    id: scrollToSectionTimer
                    interval: 16
                    repeat: true
                    property string targetName: ""
                    onTriggered: {
                        var fl = contentLoader.item
                        if (!fl || fl.contentHeight <= 0 || fl.height <= 0 || targetName === "") return

                        // Walk the Flickable's content children to find a card with matching objectName
                        var content = fl.contentItem ? fl.contentItem : fl
                        var targetCard = findChildByObjectName(content, targetName)
                        if (targetCard) {
                            // Map the card's position to the Flickable's coordinate space
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
                            // Recurse one level into ColumnLayouts
                            var found = findChildByObjectName(child, name)
                            if (found) return found
                        }
                        return null
                    }
                }

                // Continuously save scroll position as the user scrolls —
                // always up-to-date regardless of how they navigate away
                Connections {
                    target: contentLoader.item
                    function onContentYChanged() {
                        if (contentLoader.item && currentSection)
                            ScrollMemory.positions[currentSection] = contentLoader.item.contentY
                    }
                }
            }
        }

        // ─── State management ────────────────────────────────────────
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
}
