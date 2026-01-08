# OCTAVE

## Overview
[OCTAVE](https://waybetter.solutions/octave/index.html) (Open-source Cross-platform Telematics for Augmented Vehicle Experience) is a solution to having a fully programmable infotainment center in your vehicle. While OCTAVE could theoretically work in any vehicle, it best suits older cars with dilapidated infotainment systems. We were always left seeking more from the infotainment systems in our vehicles, so we wanted to develop a solution that could be extremely feature rich. We also wanted to be able to see all the OBD-II data coming from the vehicle while still being able to play music and all that good stuff.

OCTAVE is cross-platform so that the installation into a vehicle is totally up to the user. Those utlizing OCTAVE most often use a Rasberry Pi (or equivalent). All you need from there is a proportionate touchscreen, a power source, a 3D printed mount for the screen and an interface into the speakers. OCTAVE is suitable for Windows, Mac or Linux, making the code and testing of new features simple.

This app was designed to be easy to work with, so it has a Python backend with a QML based front end. There's also a settings configuration JSON file that's used to capture all user made changes, so everything you change stays changed and you can rock the app exactly as you like.

Please feel free to reach out if you think this is cool or if you think its lame you can tell me all about it rob.degeorge@gmail.com

## Features
- **Media Player**: Play MP3 files, switch between playlists, music library stats, shuffle songs, metadata and album art
- **Spotify Integration**: Control Spotify playback on any connected device (phone, desktop, etc.)
- **OBD-II Integration**: Real-time vehicle diagnostics with customizable dashboards
- **Customizable UI**: Built-in themes with ability to create your own, SVG-based icons, UI scaling
- **Cross-Platform**: Compatible with Windows, Linux, and macOS

## Preview
![OCTAVE Demo](frontend/assets/readme/display.gif)

## System Requirements

- **Python**: 3.8 or higher
- **Operating System**: Windows 10+, macOS 10.14+, or Linux (Ubuntu/Debian, Raspberry Pi OS, others)


## Installation & Running

**First time setup:**
```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python3 setup.py        # Windows: use 'python' instead of 'python3'
```

**Run the app:**
```bash
source venv/bin/activate    # Windows: venv\Scripts\activate
python3 main.py             # Windows: python main.py
```

**Or do both in one command:**
```bash
python3 setup.py --run
```

The setup script automatically:
- Detects your OS
- Installs system dependencies (Linux)
- Creates a Python virtual environment
- Installs all required packages

**Optional:** For OBD-II Bluetooth on Linux: `sudo usermod -a -G dialout $USER`

## License
Copyright © 2025 [Way Better Solutions](https://waybetter.solutions/) - Follow our journey!

This software is released under the MIT License.
