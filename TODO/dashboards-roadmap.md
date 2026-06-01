# Dashboards Roadmap — "Tony Hawk Create-A-Park for OBD Dashboards"

**Status:** Phase 1 complete. Phase 2 (JSON-defined dashboards) substantially landed — `DashboardRenderer.qml` + `DashboardManager` (C++ **and** Python peers) + JSON presets shipped and wired into `OBDMenu.qml`. Remaining Phase 2 polish (validation, user-dir hot-reload, side-by-side visual parity check) and Phase 3 (in-app editor) deferred.
**Last updated:** 2026-05-24

---

## Vision

End goal: users build their own OBD dashboards from within the app, Tony-Hawk-create-a-park style. Drag gauge primitives onto a grid, wire them to PIDs, tweak thresholds and colors, save with a name. No code edits required.

Today: dashboards are **JSON specs** under `frontend/dashboards/presets/`, rendered by `frontend/dashboards/DashboardRenderer.qml` and enumerated by `DashboardManager` (C++ `src/managers/dashboardmanager.{h,cpp}` + Python `backend/dashboard_manager.py`), which populates `OBDMenu.qml`'s `dashboardRegistry`. Four built-ins ship: Sport, Minimal, Full Grid, Performance.

---

## Why phased

The editor (Phase 3) is only tractable on top of a data-driven dashboard format (Phase 2). Without that, every "save my custom dashboard" click would have to generate QML source, which is a mess. The hinge is turning dashboards into JSON. Phase 1 is independent groundwork that's low-risk and immediately useful on its own.

---

## Phase 1 — More primitives *(complete)*

Add gauge primitives to `frontend/gauges/` to widen what can be composed into a dashboard. Still hand-writing dashboard QML files; no new systems.

### Current primitives
- `CircularGauge` — arc + ticks + optional needle + readout
- `BarGauge` — horizontal/vertical filled bar with warn threshold
- `LinearGauge` — horizontal scale with bidirectional fill (for values that straddle zero)
- `DigitalReadout` — big number, no chrome

### Planned additions (this phase)
- [x] **`ArcGauge`** — half-circle (180°) meter, opens downward. Wide-aspect alternative to CircularGauge for compact speedometer/RPM layouts. *(delivered)*
- [x] **`SparklineGauge`** — rolling history line showing recent values. Great for boost, load, trim trends. Timer-sampled to keep the x-axis scale stable. *(delivered)*
- [x] **`WarningLight`** — binary indicator bound to a threshold condition (`triggerAbove` / `triggerBelow`). Small, composable, overlays nicely on other gauges. *(delivered)*

### Candidates deferred within Phase 1
Pick these up if a dashboard needs them — low priority until a concrete use case lands:

- **`SegmentedBar`** — staircase/boost-gauge style bar with discrete cells. Aesthetic; could be achieved with BarGauge + visual styling for now.
- **`MultiReadout`** — stacked mini digits for related PIDs (e.g. short/long fuel trim side-by-side). Niche; compose from multiple DigitalReadouts first.
- **`CompassGauge`** — rotation-based dial. Only useful once we have heading data; BerryIMU publishes magnetometer but there's no `HEADING` PID yet.

Each new primitive requires:
1. Implement in `frontend/gauges/` following the shared binding API (see `docs/GAUGE_AUTHORING.md` §3 and §7)
2. Update `docs/GAUGE_AUTHORING.md` in the same commit
3. Update `wiki/gauges-dashboards.html` + run `python wiki/build_search_index.py`

**Exit criteria for Phase 1:** at least one new hand-written dashboard showcasing each of the new primitives in use. Something like a `PerformanceDashboard.qml` with sparklines for load/boost/trim, an ArcGauge for speed, and WarningLights for overtemp/overrev.

---

## Phase 2 — JSON-defined dashboards *(substantially landed)*

**This is the hinge.** Do not attempt Phase 3 without this.

**Landed:** `DashboardRenderer.qml` (spec → grid); four JSON presets in `frontend/dashboards/presets/` (`sport`, `minimal`, `fullgrid`, `performance`) all carrying `"schema": 1`; `DashboardManager` shipped in **both** backends (`src/managers/dashboardmanager.{h,cpp}` and `backend/dashboard_manager.py`) and wired into `OBDMenu.qml` via `dashboardRegistry` / `_rebuildRegistry()`.
**Still to verify / finish:** spec validation against `OBDParameterModel` + the type whitelist (work item 5), the `"source"` QML-fallback field (item 6), user-dashboard dir hot-reload, and a side-by-side visual parity check vs. the old hand-written versions.

### Core idea

Stop hand-writing dashboard QML files. Define dashboards as data:

```json
{
  "id": "sport",
  "label": "Sport",
  "schema": 1,
  "gridColumns": 12,
  "gridRows": 6,
  "cells": [
    {
      "type": "DigitalReadout",
      "paramId": "SPEED",
      "col": 0, "row": 0, "colSpan": 6, "rowSpan": 4,
      "props": { "valueScale": 7.0, "padDigits": 3 }
    },
    {
      "type": "CircularGauge",
      "paramId": "RPM",
      "col": 6, "row": 0, "colSpan": 6, "rowSpan": 4,
      "props": { "showNeedle": true, "redlineStart": 6500 }
    },
    {
      "type": "BarGauge",
      "paramId": "COOLANT_TEMP",
      "col": 0, "row": 4, "colSpan": 3, "rowSpan": 2,
      "props": { "warnAbove": 105 }
    }
  ]
}
```

### Work items

1. **`frontend/dashboards/DashboardRenderer.qml`** — single component that takes a spec (JS object) and instantiates cells into a `GridLayout` via `Qt.createComponent`. Replace all three current dashboards' hand-written QML with this + a spec.
2. **Spec location split:**
   - Built-ins: `frontend/dashboards/presets/*.json` (read-only, shipped in the bundle)
   - User-defined: `~/.config/OCTAVE/dashboards/*.json` on Linux (or platform equivalent via `QStandardPaths::AppConfigLocation`) — writable, survives across installs; parallels the existing `settingsConfigure.json` persistence pattern in `src/managers/settingsmanager.cpp`
3. **Registry refactor in `OBDMenu.qml`:** instead of hardcoding `dashboardRegistry`, populate it from (built-in presets ∪ user dashboards). `src/managers/dashboardmanager.{h,cpp}` (C++ / Qt 6) enumerates both sources and exposes the list as a QML context property, with a parallel `backend/dashboard_manager.py` peer for the Python dev backend (dual-backend parity — see CLAUDE.md). *(shipped)*
4. **Schema versioning:** include `"schema": 1` in every spec so the format can evolve. If `DashboardRenderer` sees a newer schema than it supports, degrade gracefully (render a "this dashboard requires a newer OCTAVE" placeholder).
5. **Validation:** on load, verify every `paramId` exists in `OBDParameterModel.allParameters` and every `type` exists in a small whitelist (the primitives listed above). Skip invalid cells with a log warning rather than crashing the whole dashboard.
6. **Keep QML fallback:** a `"source": "path/to/Custom.qml"` field lets a dashboard bypass the JSON renderer entirely when someone needs to do something the grid can't express. Retains the current hand-written option for power users.

### Key design decisions already made
- **Grid over absolute positioning** — every current dashboard is grid-shaped anyway, and grids are dramatically easier to edit on a touchscreen. 12×6 is a reasonable default resolution.
- **`"schema": 1`** baked in from day one so future format changes don't strand existing files.
- **Built-in vs user** — built-ins are read-only; "Duplicate" on a built-in copies it to the user dir, fully editable.

### Dependencies
- Phase 1 gauge primitives stabilized (don't want to rename props mid-migration)
- No backend dependencies

### Exit criteria for Phase 2
- All three built-in dashboards converted to JSON specs
- `DashboardRenderer` renders them identically to the current hand-written versions (side-by-side visual comparison)
- Dropping a new JSON file in the user dashboards dir (no code changes, no restart hook yet) shows up in the chooser after reopening the app

---

## Phase 3 — In-app editor ("create-a-park mode") *(deferred)*

Only meaningful once Phase 2 is in place. The editor is fundamentally "a GUI for the Phase 2 JSON format."

### UX sketch

- Chooser popup (`OBDMenu.qml` currently) gets three new actions:
  - **"New"** button pinned at the top — opens editor on a blank spec
  - **"Duplicate"** on long-press of any built-in card — clones to user dir, opens editor
  - **"Edit"** on long-press of any user card — opens editor on existing spec
  - **"Delete"** on long-press of user cards (built-ins can't be deleted)
- Editor = full-screen page (new `frontend/dashboards/DashboardEditor.qml`), StackView-pushed from the chooser:
  - **Canvas** (center, majority) — live grid showing current spec, renders in real time
  - **Palette** (left side) — scrollable list of primitive types. Drag-drop onto canvas.
  - **Properties panel** (right side) — appears when a cell is selected; PID picker, range overrides, color overrides, threshold props
  - **Top bar** — name field, Save, Cancel, Delete (if editing existing)
- Interaction model:
  - **Tap cell** to select (properties panel populates)
  - **Long-press-drag** to move (avoids fighting the scroll-to-pan Flickable gesture used elsewhere)
  - **Resize handles** on selected cell, snap to grid
  - **Tap empty grid cell** to add a new cell (opens palette)

### Work items

1. `frontend/dashboards/DashboardEditor.qml` — the editor page itself
2. `frontend/dashboards/editor/` subfolder with:
   - `Palette.qml` — draggable primitive list
   - `PropertiesPanel.qml` — inspector for selected cell
   - `CanvasGrid.qml` — the editable grid (shares rendering with `DashboardRenderer` but adds selection/drag affordances)
   - `PIDPicker.qml` — searchable list of all 93 PIDs grouped by category
3. Backend additions to `src/managers/dashboardmanager.{h,cpp}` (C++):
   - `Q_INVOKABLE saveDashboard(QVariantMap spec) -> QString id` — writes JSON to user dir
   - `Q_INVOKABLE deleteDashboard(QString id)` — removes user JSON (no-op on built-ins)
   - `Q_INVOKABLE duplicateDashboard(QString sourceId, QString newName) -> QString id` — copies built-in/user to a new user file

### Dependencies
- Phase 2 complete (obviously)
- Consider whether the touchscreen drag gesture conflicts with the Flickable touch-scroll added to the chooser popup — long-press-to-pick-up is the standard resolution and should work here too

### Exit criteria for Phase 3
- A new user can tap "New," drag three gauges onto the canvas, bind each to a PID, name the dashboard, save, and see it appear in the chooser alongside the built-ins — all without touching a file

---

## Cross-references

- `TODO/god-object-splits.md` — if `OBDMenu.qml` is on the split list, coordinate: the chooser popup and dashboard registry logic will move during Phase 2 and would interact with any split plan.

---

## Order of operations

1. Phase 1 (in progress — see commits). Primitives + GAUGE_AUTHORING.md + wiki.
2. Ship at least one new dashboard showcasing the new primitives (Phase 1 exit criteria).
3. Phase 2 JSON spec. Migrate existing dashboards, add `DashboardRenderer`, add user dashboards dir.
4. Ship Phase 2 for a release; let user dashboards (authored by hand-editing JSON) exist in the wild for a bit so real-world pain points show up before building the editor on top.
5. Phase 3 editor.

---

**Delete this file when Phase 3 ships.** Until then, keep it updated as each phase's state changes.
