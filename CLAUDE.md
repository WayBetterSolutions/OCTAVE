# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCTAVE (Open-source Cross-platform Telematics for Augmented Vehicle Experience) is a Python + QML infotainment system designed for vehicles. It runs on Windows, macOS, Linux, and Raspberry Pi.

## Commands

```bash
# First-time setup + run (creates venv, installs deps, launches app)
python setup.py

# Setup only, don't launch
python setup.py --no-run

# Run the app directly (activate venv first)
source venv/bin/activate
python main.py

# Debug mode (enables debug logging)
python main.py --debug

# Developer mode (simulated OBD data, keyboard controls for testing)
python dev/dev_main.py

# Build for distribution
python build_scripts/build.py

# Lint (ruff — configured in pyproject.toml)
source venv/bin/activate
ruff check .

# Smoke tests (headless — imports + safe manager instantiation)
QT_QPA_PLATFORM=offscreen pytest tests/
```

A minimal smoke test suite lives in `tests/` and runs in CI on every push and PR to `main`. Ruff runs in warn-only mode during Phase 1 cleanup — see the TODO in `.github/workflows/build.yml` for when to flip critical rules (E722, F821) to blocking.

## Architecture

**Python backend + QML frontend** communicating via Qt Signals/Slots (PySide6).

### Backend (`backend/`)

Each feature is a Python **manager class** inheriting from `QObject`. Managers expose state to QML via `Signal`, `Slot`, and `Property` decorators. All managers are instantiated in `main.py` and registered as QML context properties.

Key managers:
- `settings_manager.py` — Central settings store, persists to `settingsConfigure.json` in OS-specific config dirs
- `media_manager.py` — Local MP3 playback via QMediaPlayer
- `spotify_manager.py` — Spotify API integration (spotipy), credentials stored in OS keychain
- `obd_manager.py` — OBD-II vehicle diagnostics with threaded connection worker
- `esp32_volume_manager.py` — Wireless rotary encoder volume control over serial
- `berryimu_manager.py` — I2C accelerometer/gyro/magnetometer/barometer sensor
- `gesture_manager.py` — PAJ7620U2 I2C gesture sensor for touchless control
- `audio_analyzer.py` — FFT waveform visualization from audio files
- `android_auto/` — Android Auto via Google Desktop Head Unit (DHU)
- `phone_mirror/` — Phone screen mirroring via scrcpy

### Frontend (`frontend/`)

QML files using Qt Quick 2.15. Entry point is `Main.qml`.

- Top-level QML files are full views/pages (e.g., `MediaPlayer.qml`, `CarMenu.qml`, `OBDMenu.qml`)
- `BottomBar.qml` — Persistent navigation and volume control
- `EnvironmentTheme.qml` — Dynamic theming system (colors adapt to album art)
- `Style.qml` / `Spacing.qml` — Design tokens
- `settings/` — Settings pages and reusable settings UI components (cards, toggles, sliders, etc.)

### Communication Pattern

Backend managers are registered as QML context properties in `main.py`:
```python
engine.rootContext().setContextProperty("mediaManager", media_manager)
```

QML accesses them directly:
```qml
mediaManager.next_track()
```

Custom QML types (for embedded video frames) are registered with `qmlRegisterType` under `OCTAVE.AndroidAuto` and `OCTAVE.PhoneMirror` modules.

### Volume System

Volume uses a **quadratic curve** (`(volume/100)^2.0`) for the UI percent → linear audio mapping. `backend/volume_utils.py` owns the curve math and the `VolumeController` QObject, which is the single entry point for routing a 0–100 percent to every output (local media, Spotify, phone mirror, ESP32 LED). Both Python handlers (gesture sensor, ESP32 knob) and QML slider widgets call `volume_controller.applyVolume(percent)` — never touch the individual manager `setVolume` methods or hardcode the curve. Changing the curve only requires editing `to_linear()` in one place.

### Threading

Heavy I/O runs on worker threads to avoid blocking the UI:
- OBD connection uses a dedicated `QThread` worker with progress signals
- Spotify API calls use `ThreadPoolExecutor`
- Sensor polling (BerryIMU, gesture, ESP32) uses `QTimer`-based intervals

### Image Providers

Custom `QQuickImageProvider` subclasses stream video frames directly to QML for Android Auto (`dhuframe`) and phone mirror (`scrcpyframe`), avoiding file I/O.

### Settings Persistence

User settings stored in `settingsConfigure.json` at OS-specific paths:
- Windows: `%APPDATA%/OCTAVE/`
- macOS: `~/Library/Application Support/OCTAVE/`
- Linux: `~/.config/OCTAVE/`

### Logging

Rotating log files in `logs/` subdirectory of the config path:
- `octave.log` — General (5 MB, 3 backups)
- `octave-error.log` — Errors only (2 MB, 5 backups)
- `octave-debug.log` — Debug mode only via `--debug` flag

### Build & CI

PyInstaller creates standalone executables. GitHub Actions (`.github/workflows/build.yml`) runs `lint` (ruff) and `test` (headless pytest smoke suite) on every push and PR to `main`, and builds for Windows, macOS, and Linux on version tags (`v*`) or manual dispatch, producing platform-specific installers (Inno Setup, DMG, AppImage). Build jobs depend on lint + test passing.

## Key Conventions

- Qt Quick Controls style is forced to `"Basic"` for full slider customization
- QML import path includes `frontend/` — QML files there are importable by name
- The `dev/` directory is gitignored and fully isolated from production code
- Backend modules use hierarchical loggers via `get_logger(__name__)`

## Wiki Maintenance

The project wiki lives in `wiki/` (static HTML pages — `architecture.html`, `development.html`, `media-manager.html`, `spotify-manager.html`, `obd-manager.html`, etc., plus `index.html` as the entry point and `search-index.js` for full-text search).

**Whenever a code change affects documented behavior, update the corresponding wiki page in the same commit.** This includes:

- Adding, removing, or renaming a backend manager or its public Slots/Signals/Properties → update the relevant manager page and `signals-slots-reference.html`
- Changing the settings schema or adding a new setting → update `settings-reference.html` and `settings-manager.html`
- New build/test/lint commands or CI changes → update `development.html` and `building.html`
- New dev tools, keyboard shortcuts, or MCP capabilities → update `development.html`
- New QML components or view-level changes → update `components.html` / `pages.html` / `frontend-overview.html`
- New hardware support (sensors, controllers, protocols) → update `hardware-managers.html` and `hardware-setup.html`
- Theme, style token, or animation system changes → update `theme-system.html`

If you are unsure which page to update, `wiki/index.html` lists all pages. Rebuild the search index if wiki content changes: `python wiki/build_search_index.py`. The wiki is the user-facing reference — stale docs are worse than missing docs, so treat wiki updates as part of "done" for any feature or refactor.

## TODO folder

The `TODO/` directory at the repo root holds standalone plans for work that has been **intentionally deferred** — things we know we want to do eventually but aren't committing to right now. Each plan is a single markdown file that can be picked up cold by a future session (yours, mine, or a collaborator's) without needing conversation history.

**What belongs in `TODO/`:**
- Refactors that are risky, scoped, and require setup before they're safe to do (e.g. splitting oversized manager files)
- Feature work that's been scoped but deprioritized (e.g. in-app error notification UI)
- Time-sensitive maintenance with a known deadline (e.g. third-party API migrations)
- Test-suite expansions we know we want but haven't committed to
- Anything the user said "let's come back to this later" about

**What does NOT belong in `TODO/`:**
- Active in-progress work (that's what tasks/plans/branches are for)
- Bug reports (file those as issues)
- General ideas or wishlists — only plans concrete enough that someone could act on them
- Notes about things we already did

**Format for new TODO files:**
- Lead with a `**Status:**` line (deferred / parked / time-sensitive) and a `**Last updated:**` date in ISO format
- Explain **why it's parked**, not just what it is — future-you needs to know whether the rationale still applies
- Include enough context, file paths, and line numbers that someone could start work without re-investigating
- Call out prerequisites and dependencies between TODO items (e.g. "don't split `obd_manager.py` until the ELM327 test suite exists")
- End with a recommended order of operations and a "delete this file when done" reminder

**When the user parks something:** offer to write it up as a TODO file. When you write a TODO file, mention any cross-references to other TODO items so the folder stays internally consistent. When a TODO item is completed, **delete the file** — stale TODOs rot faster than stale code.
