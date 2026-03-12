.pragma library

// In-memory cache of expanded card states — avoids disk I/O during card creation.
// Loaded once from settingsManager, saved back on a debounce.
var states = {}
var _loaded = false

function load(settingsManager) {
    if (_loaded) return
    if (!settingsManager) return
    var saved = settingsManager.get_setting_with_default("expandedCards", {})
    if (saved && typeof saved === "object") {
        for (var key in saved) {
            states[key] = saved[key]
        }
    }
    _loaded = true
}

function isExpanded(cardId) {
    return states.hasOwnProperty(cardId) ? states[cardId] : false
}

function setExpanded(cardId, value) {
    states[cardId] = value
}

function save(settingsManager) {
    if (!settingsManager) return
    var copy = {}
    for (var key in states) {
        copy[key] = states[key]
    }
    settingsManager.save_setting("expandedCards", copy)
}
