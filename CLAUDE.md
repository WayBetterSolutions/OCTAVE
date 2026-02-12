# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCTAVE (Open-source Cross-platform Telematics for Augmented Vehicle Experience) is a Python + QML infotainment system designed for vehicles. It runs on Windows, macOS, Linux, and Raspberry Pi.

## Commands

```bash
# First-time setup (creates venv, installs system deps on Linux)
python3 setup.py

# Run the app (activate venv first)
source venv/bin/activate
python3 main.py

# Setup + run in one command
python3 setup.py --run

# Debug mode (enables debug logging)
python3 main.py --debug

# Developer mode (simulated OBD data, keyboard controls for testing)
python3 dev/dev_main.py

# Build for distribution
python build_scripts/build.py
```

There is no automated test suite or linter configured.

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

Volume uses a **logarithmic curve** (`(volume/100)^2.0`) applied consistently across local media, Spotify, phone mirror, and ESP32 LED feedback. Changes from any source (UI slider, ESP32 knob, gesture sensor) sync to all outputs.

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

PyInstaller creates standalone executables. GitHub Actions (`.github/workflows/build.yml`) builds for Windows, macOS, and Linux on version tags (`v*`), producing platform-specific installers (Inno Setup, DMG, AppImage).

## Key Conventions

- Qt Quick Controls style is forced to `"Basic"` for full slider customization
- QML import path includes `frontend/` — QML files there are importable by name
- The `dev/` directory is gitignored and fully isolated from production code
- Backend modules use hierarchical loggers via `get_logger(__name__)`
