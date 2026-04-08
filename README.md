# OCTAVE

**Open-source Cross-platform Telematics for Augmented Vehicle Experience**

A fully programmable infotainment system for vehicles. Built with Python and QML, OCTAVE runs on Windows, macOS, Linux, Raspberry Pi, and Android.

<img src="frontend/assets/readme/display.gif" alt="OCTAVE Demo" width="400">

## Features

- Local media player (MP3, M4A, FLAC) with album art carousel and FFT waveform visualizer
- Spotify integration with OAuth2 and device control
- OBD-II vehicle diagnostics (50+ parameters via ELM327)
- Phone screen mirroring (scrcpy) and Android Auto (Google DHU)
- Music search and download (Spotify metadata + YouTube audio)
- ESP32 wireless volume knob with LED sync
- BerryIMU 9DOF sensor fusion (accelerometer, gyro, magnetometer, barometer)
- PAJ7620U2 gesture recognition for touchless control
- Dynamic theming that adapts to album art colors
- 100+ configurable settings

## Quick Start

```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python setup.py
```

The setup script detects your OS, installs dependencies, creates a virtual environment, and launches the app. Use `--no-run` to install without launching.

```bash
# Run manually after setup
source venv/bin/activate    # Windows: venv\Scripts\activate
python main.py

# Debug mode
python main.py --debug

# Developer mode (simulated OBD, keyboard controls)
python dev/dev_main.py
```

## System Requirements

- **Python** 3.8+
- **OS:** Windows 10+, macOS 10.14+, Linux (Debian/Arch/Fedora), Raspberry Pi OS

## Wiki

For comprehensive documentation — architecture, every backend manager, every frontend page, settings reference, hardware setup, build guides, and more — see the **[OCTAVE Wiki](wiki/index.html)**.

## License

2026 [Way Better Solutions](https://waybetter.solutions/) — MIT License
