// WidgetCatalog.qml
//
// Single source of truth for the gauge primitives a dashboard can contain.
// Maps a spec `type` string to its QML source, plus the display metadata and
// curated editable props the Phase 3 editor surfaces.
//
// DashboardRenderer (render-time), the editor palette (which types you can add),
// and the properties panel (which props you can tweak) all read from here, so
// the supported-widget set can't drift between rendering and editing. It's also
// the natural home for the type whitelist the deferred renderer validation will
// use (see TODO/dashboards-roadmap.md, "fast-follow").
//
// Url note: this file lives in frontend/dashboards/, so the `../gauges/` prefix
// resolves to frontend/gauges/ regardless of which context loads the catalog.
pragma Singleton
import QtQuick 2.15

QtObject {
    id: catalog

    // Ordered list — also drives palette ordering. Each entry:
    //   type:            spec `type` string (matches the .qml filename)
    //   url:             resolved source for a Loader
    //   displayName:     human label for the palette
    //   glyph:           single-character icon for the palette card
    //   defaultColSpan/defaultRowSpan: span a freshly-placed cell takes
    //   supportedKinds:  PID `kind` values this widget accepts — MUST mirror the
    //                    `octaveSupportedKinds` declared in the gauge QML itself
    //                    (the catalog exists so the PID picker can filter without
    //                    instantiating a widget). "*" = any PID.
    //   editableProps:   curated props the properties panel exposes. Each:
    //                    { key, label, kind, def } where kind ∈ "bool" | "real" |
    //                    "int" and `def` is the gauge's actual default (null for
    //                    NaN-when-unset thresholds — the panel shows these as
    //                    empty/unset). Kept minimal and honest — only props with
    //                    a simple scalar editor.
    readonly property var widgets: [
        {
            "type": "CircularGauge",
            "url": Qt.resolvedUrl("../gauges/CircularGauge.qml"),
            "displayName": "Circular",
            "glyph": "◯",
            "defaultColSpan": 4, "defaultRowSpan": 4,
            "supportedKinds": ["*"],
            "editableProps": [
                { "key": "showNeedle",   "label": "Needle",        "kind": "bool", "def": false },
                { "key": "showTicks",    "label": "Ticks",         "kind": "bool", "def": true },
                { "key": "redlineStart", "label": "Redline start", "kind": "real", "def": null }
            ]
        },
        {
            "type": "ArcGauge",
            "url": Qt.resolvedUrl("../gauges/ArcGauge.qml"),
            "displayName": "Arc",
            "glyph": "◠",
            "defaultColSpan": 6, "defaultRowSpan": 3,
            "supportedKinds": ["*"],
            "editableProps": [
                { "key": "showNeedle",   "label": "Needle",        "kind": "bool", "def": false },
                { "key": "showTicks",    "label": "Ticks",         "kind": "bool", "def": true },
                { "key": "redlineStart", "label": "Redline start", "kind": "real", "def": null }
            ]
        },
        {
            "type": "BarGauge",
            "url": Qt.resolvedUrl("../gauges/BarGauge.qml"),
            "displayName": "Bar",
            "glyph": "▮",
            "defaultColSpan": 3, "defaultRowSpan": 2,
            "supportedKinds": ["percentage", "temperature", "numeric", "pressure", "voltage"],
            "editableProps": [
                { "key": "warnAbove", "label": "Warn above", "kind": "real", "def": null }
            ]
        },
        {
            "type": "LinearGauge",
            "url": Qt.resolvedUrl("../gauges/LinearGauge.qml"),
            "displayName": "Linear",
            "glyph": "↔",
            "defaultColSpan": 4, "defaultRowSpan": 2,
            "supportedKinds": ["bidirectional"],
            "editableProps": [
                { "key": "showTicks", "label": "Ticks", "kind": "bool", "def": true }
            ]
        },
        {
            "type": "DigitalReadout",
            "url": Qt.resolvedUrl("../gauges/DigitalReadout.qml"),
            "displayName": "Digital",
            "glyph": "88",
            "defaultColSpan": 4, "defaultRowSpan": 2,
            "supportedKinds": ["*"],
            "editableProps": [
                { "key": "showTitle", "label": "Title", "kind": "bool", "def": true },
                { "key": "showUnit",  "label": "Unit",  "kind": "bool", "def": true },
                { "key": "padDigits", "label": "Pad digits", "kind": "int", "def": 0 }
            ]
        },
        {
            "type": "SparklineGauge",
            "url": Qt.resolvedUrl("../gauges/SparklineGauge.qml"),
            "displayName": "Sparkline",
            "glyph": "∿",
            "defaultColSpan": 6, "defaultRowSpan": 2,
            "supportedKinds": ["*"],
            "editableProps": [
                { "key": "autoScale",  "label": "Auto-scale", "kind": "bool", "def": false },
                { "key": "fillBelow",  "label": "Area fill",  "kind": "bool", "def": true },
                { "key": "maxSamples", "label": "Samples",    "kind": "int",  "def": 60 }
            ]
        },
        {
            "type": "WarningLight",
            "url": Qt.resolvedUrl("../gauges/WarningLight.qml"),
            "displayName": "Warning",
            "glyph": "⚠",
            "defaultColSpan": 2, "defaultRowSpan": 2,
            "supportedKinds": ["*"],
            "editableProps": [
                { "key": "triggerAbove", "label": "Trigger above", "kind": "real", "def": null },
                { "key": "triggerBelow", "label": "Trigger below", "kind": "real", "def": null },
                { "key": "pulse",        "label": "Pulse",         "kind": "bool", "def": false }
            ]
        },
        // ── Self-binding widgets (supportedKinds: [] = no PID picker) ──
        {
            "type": "GForceGauge",
            "url": Qt.resolvedUrl("../gauges/GForceGauge.qml"),
            "displayName": "G-Force",
            "glyph": "◎",
            "defaultColSpan": 4, "defaultRowSpan": 4,
            "supportedKinds": [],
            "editableProps": [
                { "key": "maxG",      "label": "Max G",     "kind": "real", "def": 1.5 },
                { "key": "showTrail", "label": "Trail",     "kind": "bool", "def": true },
                { "key": "showValue", "label": "Readout",   "kind": "bool", "def": true }
            ]
        },
        {
            "type": "CompassGauge",
            "url": Qt.resolvedUrl("../gauges/CompassGauge.qml"),
            "displayName": "Compass",
            "glyph": "N",
            "defaultColSpan": 4, "defaultRowSpan": 4,
            "supportedKinds": [],
            "editableProps": [
                { "key": "showDegrees", "label": "Degrees", "kind": "bool", "def": true }
            ]
        },
        {
            "type": "NowPlayingWidget",
            "url": Qt.resolvedUrl("widgets/NowPlayingWidget.qml"),
            "displayName": "Now Playing",
            "glyph": "♪",
            "defaultColSpan": 6, "defaultRowSpan": 2,
            "supportedKinds": [],
            "editableProps": [
                { "key": "showArt",      "label": "Album art", "kind": "bool", "def": true },
                { "key": "showArtist",   "label": "Artist",    "kind": "bool", "def": true },
                { "key": "showProgress", "label": "Progress",  "kind": "bool", "def": true }
            ]
        },
        {
            "type": "MediaControlsWidget",
            "url": Qt.resolvedUrl("widgets/MediaControlsWidget.qml"),
            "displayName": "Media Keys",
            "glyph": "▶",
            "defaultColSpan": 4, "defaultRowSpan": 2,
            "supportedKinds": [],
            "editableProps": []
        }
    ]

    // type-string → entry, or null if unknown.
    function metaFor(typeName) {
        for (var i = 0; i < widgets.length; i++) {
            if (widgets[i].type === typeName)
                return widgets[i]
        }
        return null
    }

    // type-string → resolved QML url, or "" if unknown.
    function urlFor(typeName) {
        var m = metaFor(typeName)
        return m ? m.url : ""
    }

    // True if `typeName` is a supported primitive (whitelist check).
    function isKnownType(typeName) {
        return metaFor(typeName) !== null
    }
}
