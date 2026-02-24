import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App
import "settings"

Item {
    id: settingsMenu
    objectName: "settingsMenu"
    required property var stackView
    required property var mainWindow
    required property string initialSection

    property string currentSection: ""

    // Central page model — single source of truth for all pages
    readonly property var pageModel: [
        { name: "Display",     section: "displaySettings",     source: "settings/DisplaySettingsPage.qml",     icon: "\u263C",
          group: "Appearance",
          subSections: ["Layout", "Window", "Appearance", "Clock"] },
        { name: "Media",       section: "mediaSettings",       source: "settings/MediaSettingsPage.qml",       icon: "\u266B",
          group: "Appearance",
          subSections: ["Library", "Playback", "Album Art", "Background", "Effects", "Spotify"] },
        { name: "Phone Dock",  section: "phoneDockSettings",   source: "settings/PhoneDockSettingsPage.qml",   icon: "\u260E",
          group: "Connectivity",
          subSections: ["Android Auto", "Phone Mirror"] },
        { name: "OBD",         section: "obdSettings",         source: "settings/OBDSettingsPage.qml",         icon: "\u26A1",
          group: "Connectivity",
          subSections: ["Connection", "Parameters"] },
        { name: "Accessories", section: "accessoriesSettings", source: "settings/AccessoriesSettingsPage.qml", icon: "\u2388",
          group: "Connectivity",
          subSections: ["Volume Knob", "Gesture Sensor"] },
        { name: "Device",      section: "deviceSettings",      source: "settings/DeviceSettingsPage.qml",      icon: "\u2699",
          group: "System",
          subSections: [] },
        { name: "About",       section: "about",               source: "settings/AboutPage.qml",               icon: "\u2139",
          group: "System",
          subSections: [] }
    ]

    // Derived section order for fallback
    readonly property var sectionOrder: {
        var order = []
        for (var i = 0; i < pageModel.length; i++)
            order.push(pageModel[i].section)
        return order
    }

    // Visible pages model
    property var hubModel: []

    Component.onCompleted: {
        buildHubModel()

        // If we have an initial section, jump to that page
        if (initialSection && initialSection !== "") {
            var idx = indexForSection(initialSection)
            if (idx >= 0) {
                swipeView.currentIndex = idx
                currentSection = initialSection
            }
        }
    }

    function pageForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i]
        }
        return null
    }

    function nameForSection(section) {
        for (var i = 0; i < pageModel.length; i++) {
            if (pageModel[i].section === section)
                return pageModel[i].name
        }
        return "Settings"
    }

    function isVisible(section) {
        return settingsManager ? settingsManager.is_settings_section_visible(section) : true
    }

    function indexForSection(section) {
        for (var i = 0; i < hubModel.length; i++) {
            if (hubModel[i].section === section)
                return i
        }
        return -1
    }

    function buildHubModel() {
        var model = []
        for (var i = 0; i < pageModel.length; i++) {
            var page = pageModel[i]
            if (!isVisible(page.section)) continue
            model.push({
                name: page.name,
                section: page.section,
                source: page.source,
                icon: page.icon,
                group: page.group || ""
            })
        }
        hubModel = model
    }

    function navigateToCategory(section) {
        var idx = indexForSection(section)
        if (idx >= 0)
            swipeView.currentIndex = idx
        currentSection = section
        if (settingsManager)
            settingsManager.set_last_settings_section(section)
    }

    function navigateToSubSection(section, subSection) {
        navigateToCategory(section)
        pendingScrollTarget = subSection
        scrollToSectionTimer.restart()
    }

    property string pendingScrollTarget: ""

    // When visibility changes, rebuild
    Connections {
        target: settingsManager
        function onSettingsMenuVisibilityChanged() {
            buildHubModel()
        }
    }


    // MAIN LAYOUT
    Rectangle {
        anchors.fill: parent
        color: App.Style.backgroundColor

        // Environment backgrounds
        ContentSonar {}
        ContentSolarSystem {}

        // ─── Category tab strip (top) ───
        Row {
            id: tabStrip
            anchors.top: parent.top
            anchors.topMargin: App.Spacing.dp(2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: App.Spacing.dp(4)
            z: 20

            // Uniform tab width: divide available space equally
            property real tabWidth: hubModel.length > 0
                ? (parent.width - App.Spacing.dp(4) * (hubModel.length - 1)) / hubModel.length
                : App.Spacing.dp(80)

            Repeater {
                model: hubModel.length

                Rectangle {
                    property bool isCurrent: index === swipeView.currentIndex

                    width: tabStrip.tabWidth
                    height: App.Spacing.dp(28)
                    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.chipRadius === -1
                        ? 6 : App.EnvironmentTheme.active.chipRadius, 2)

                    color: isCurrent
                        ? Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.2)
                        : tabArea.containsMouse
                            ? Qt.rgba(App.Style.primaryTextColor.r, App.Style.primaryTextColor.g, App.Style.primaryTextColor.b, 0.08)
                            : "transparent"

                    border.width: isCurrent ? 1 : 0
                    border.color: Qt.rgba(App.Style.accent.r, App.Style.accent.g, App.Style.accent.b, 0.4)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: tabLabel
                        anchors.centerIn: parent
                        text: (hubModel[index] ? hubModel[index].icon + "  " + hubModel[index].name : "")
                        color: isCurrent ? App.Style.accent : App.Style.secondaryTextColor
                        font.pixelSize: App.Spacing.overallText * 0.8
                        font.family: App.Style.fontFamily
                        font.bold: isCurrent
                        font.letterSpacing: App.EnvironmentTheme.active.labelLetterSpacing
                        font.capitalization: App.EnvironmentTheme.active.labelUppercase ? Font.AllUppercase : Font.MixedCase
                        opacity: isCurrent ? 1.0 : 0.6

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: swipeView.currentIndex = index
                    }
                }
            }
        }

        // ─── SwipeView: swipe left/right between settings pages ───
        SwipeView {
            id: swipeView
            anchors.top: tabStrip.bottom
            anchors.topMargin: App.Spacing.dp(2)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            // Track current section and persist it
            onCurrentIndexChanged: {
                if (hubModel[currentIndex]) {
                    settingsMenu.currentSection = hubModel[currentIndex].section
                    if (settingsManager)
                        settingsManager.set_last_settings_section(hubModel[currentIndex].section)
                }
            }

            Repeater {
                model: hubModel.length

                SettingsHubCard {
                    property var itemData: hubModel[index] || {}

                    categoryName: itemData.name || ""
                    section: itemData.section || ""
                    pageSource: itemData.source || ""
                    categoryIcon: itemData.icon || ""
                    groupName: itemData.group || ""
                    isCenter: SwipeView.isCurrentItem
                    radius: App.Spacing.dpMin(App.EnvironmentTheme.active.hubCardRadius, 2)
                    settingsMenu: settingsMenu
                }
            }
        }

        // ─── Sub-section scroll targeting ───
        Timer {
            id: scrollToSectionTimer
            interval: 16
            repeat: true
            onTriggered: {
                if (pendingScrollTarget === "") { stop(); return }

                var card = swipeView.currentItem
                if (!card) return
                var loader = findLoader(card)
                if (!loader || !loader.item) return

                var fl = loader.item
                if (fl.contentHeight <= 0 || fl.height <= 0) return

                var content = fl.contentItem ? fl.contentItem : fl
                var targetCard = findChildByObjectName(content, pendingScrollTarget)
                if (targetCard) {
                    var pos = targetCard.mapToItem(fl.contentItem, 0, 0)
                    var scrollMax = Math.max(0, fl.contentHeight - fl.height)
                    fl.contentY = Math.min(pos.y, scrollMax)
                    pendingScrollTarget = ""
                    stop()
                }
            }

            function findLoader(item) {
                for (var i = 0; i < item.children.length; i++) {
                    var child = item.children[i]
                    if (child.toString().indexOf("QQuickLoader") !== -1 && child.item)
                        return child
                    var found = findLoader(child)
                    if (found) return found
                }
                return null
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
    }
}
