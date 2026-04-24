# C++ Filenames → snake_case (cross-backend convention parity)

**Status:** deferred — execute during a quiet window between risky changes.
**Last updated:** 2026-04-23

## Why this is parked here

C++ files under `src/` currently use smashed-lowercase (`mediamanager.cpp`), which is neither PEP-8-aligned with the Python peer (`media_manager.py`) nor the Qt convention (`MediaManager.cpp`). Since C++ has no enforced naming convention and half the OCTAVE codebase is Python where snake_case is mandatory, the project wins more from matching Python than from matching Qt norms.

The *decision* is locked: rename C++ source to snake_case. The *timing* is deferred because a mass rename touching every `.h`/`.cpp`, every `#include`, and the `CMakeLists.txt` source list while Android Phase 1 is still stabilizing is a merge-conflict factory. Do it when the tree is quiet.

## Scope

Rename the following files to snake_case. Class names do NOT change — only filenames and `#include` references.

### `src/managers/` (32 files)
- `androidautomanager.{cpp,h}` → `android_auto_manager.{cpp,h}`
- `audioanalyzer.{cpp,h}` → `audio_analyzer.{cpp,h}`
- `berryimumanager.{cpp,h}` → `berryimu_manager.{cpp,h}`
- `clock.{cpp,h}` → `clock.{cpp,h}` (no change)
- `dashboardmanager.{cpp,h}` → `dashboard_manager.{cpp,h}`
- `downloadmanager.{cpp,h}` → `download_manager.{cpp,h}`
- `elm327protocol.{cpp,h}` → `elm327_protocol.{cpp,h}`
- `esp32volumemanager.{cpp,h}` → `esp32_volume_manager.{cpp,h}`
- `gesturemanager.{cpp,h}` → `gesture_manager.{cpp,h}`
- `mediamanager.{cpp,h}` → `media_manager.{cpp,h}`
- `networkmanager.{cpp,h}` → `network_manager.{cpp,h}`
- `obdmanager.{cpp,h}` → `obd_manager.{cpp,h}`
- `phonemirrormanager.{cpp,h}` → `phone_mirror_manager.{cpp,h}`
- `settingsmanager.{cpp,h}` → `settings_manager.{cpp,h}`
- `spotifymanager.{cpp,h}` → `spotify_manager.{cpp,h}`
- `volumecontroller.{cpp,h}` → `volume_controller.{cpp,h}`

### `src/items/` (6 files)
- `embeddeddhuitem.{cpp,h}` → `embedded_dhu_item.{cpp,h}`
- `embeddedscrcpyitem.{cpp,h}` → `embedded_scrcpy_item.{cpp,h}`
- `scrcpycapture.{cpp,h}` → `scrcpy_capture.{cpp,h}`

### `src/platform/` (2 files)
- `androidmediabridge.h` → `android_media_bridge.h`
- `androidprocessadapter.h` → `android_process_adapter.h`

### Python-side parity tidy-ups to fold into the same commit
- `backend/volume_utils.py` → `backend/volume_controller.py` (matches new C++ peer, drops the "legacy" label noted in CLAUDE.md)

## Update targets

Every rename cascades into:
1. **`#include` statements** across all `.cpp`/`.h` files in `src/` — mechanical `sed`.
2. **`CMakeLists.txt`** — the `qt_add_executable(octave ...)` source list lists every file by name.
3. **`.gitignore`** — no impact (no rules reference individual source files).
4. **CI** — `.github/workflows/build.yml` doesn't reference individual source files, but re-run the build matrix after rename to catch anything missed.
5. **Wiki** — any `wiki/*.html` pages that cite filenames (e.g. `media-manager.html` probably references `mediamanager.cpp`). Grep for the old names.
6. **CLAUDE.md** — line 45 and nearby reference `src/managers/foo.{h,cpp}` pattern; update to reflect new names.
7. **Python imports** — for the `volume_utils` → `volume_controller` rename, update every `from backend.volume_utils import ...` call site and `main.py` instantiation.

## Prerequisites and blockers

- **Blocked on `TODO/android-cpp-port.md` Phase 1 being committed and verified on-device.** The current uncommitted Android work touches nearly every manager header — rename collisions would be painful.
- **Should happen BEFORE `TODO/god-object-splits.md`.** That refactor splits oversized managers into multiple files; renaming first means split outputs land with the correct convention from the start.
- **Avoid interleaving with active feature work.** Don't start this while `TODO/android-search-ytmusicapi.md` or `TODO/dashboards-roadmap.md` Phase 2 work is in flight.

## Recommended order of operations

1. Confirm the tree is quiet: no uncommitted feature work, no in-flight refactors, CI green on both backends.
2. Create a dedicated branch (`rename/cpp-snake-case`).
3. Rename files via `git mv` (preserves blame history — do NOT `rm + add`).
4. Run `sed` pass across `src/**/*.{cpp,h}` to update `#include` directives. Example:
   ```bash
   sed -i 's|"managers/mediamanager.h"|"managers/media_manager.h"|g' src/**/*.{cpp,h}
   ```
5. Update `CMakeLists.txt` source list in one pass.
6. Do the Python-side `volume_utils.py` → `volume_controller.py` rename + import updates in the same commit.
7. Build both backends: `cmake --build build -j` and `QT_QPA_PLATFORM=offscreen python -c "import main"`.
8. Run desktop + Android smoke build.
9. Grep the wiki for stale filenames, update those pages, rebuild search index (`python wiki/build_search_index.py`).
10. Update CLAUDE.md references.
11. Single commit. Merge to main.

## Cross-references

- `TODO/android-cpp-port.md` — must be past Phase 1 before this rename.
- `TODO/god-object-splits.md` — must come AFTER this rename.
- `CLAUDE.md` — documents the dual-backend parity rule that this rename reinforces.

## Delete this file when done

When every C++ file under `src/` uses snake_case, `backend/volume_controller.py` exists, and `cmake --build` succeeds on all desktop + Android targets, delete this TODO.
