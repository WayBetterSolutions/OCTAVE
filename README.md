# OCTAVE

## Overview
[OCTAVE](https://waybetter.solutions/octave/index.html) (Open-source Cross-platform Telematics for Augmented Vehicle Experience) is a solution to having a fully programmable infotainment center in your vehicle. While OCTAVE could theoretically work in any vehicle, it best suits older cars with dilapidated infotainment systems. We were always left seeking more from the infotainment systems in our vehicles, so we wanted to develop a solution that could be extremely feature rich. We also wanted to be able to see all the OBD-II data coming from the vehicle while still being able to play music and all that good stuff.

OCTAVE is cross-platform so that the installation into a vehicle is totally up to the user. Those utlizing OCTAVE most often use a Rasberry Pi (or equivalent). All you need from there is a proportionate touchscreen, a power source, a 3D printed mount for the screen and an interface into the speakers. OCTAVE is suitable for Windows, Mac or Linux, making the code and testing of new features simple.

This app was designed to be easy to work with, so it has a Python backend with a QML based front end. There's also a settings configuration JSON file that's used to capture all user made changes, so everything you change stays changed and you can rock the app exactly as you like.

Please feel free to reach out if you think this is cool or if you think its lame you can tell me all about it rob.degeorge@gmail.com

## Quick Start

```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python3 setup.py --run
```

That's it! The setup script automatically detects your OS, installs system dependencies (Linux), creates a virtual environment, installs Python packages, and launches the app.

On Windows, use `python` instead of `python3`.

## Features
- **Media Player**: Play MP3 files, switch between playlists, music library stats, shuffle songs, metadata and album art
- **Spotify Integration**: Control Spotify playback on any connected device (phone, desktop, etc.)
- **OBD-II Integration**: Real-time vehicle diagnostics with customizable dashboards
- **Customizable UI**: Built-in themes with ability to create your own, SVG-based icons, UI scaling
- **Cross-Platform**: Compatible with Windows, Linux, and macOS

## Screenshots
![Home Page](frontend/assets/readme/home_page.png)
![Media Page](frontend/assets/readme/media_room.png)
![OBD Page](frontend/assets/readme/obd_page.png)

## System Requirements

- **Python**: 3.8 or higher
- **Operating System**: Windows 10+, macOS 10.14+, or Linux (Ubuntu 20.04+, Raspberry Pi OS Bookworm)
- **Display**: Touchscreen recommended for in-vehicle use
- **Tested Hardware**: Raspberry Pi 3/4/5 running Bookworm

## Installation

The recommended way to install is using the setup scripts (see [Quick Start](#quick-start)).

<details>
<summary><strong>Manual Installation (click to expand)</strong></summary>

### Windows
```cmd
git clone https://github.com/waybettersolutions/octave.git
cd octave
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

### Linux (Ubuntu/Debian/Raspberry Pi)
```bash
# Install system dependencies first
sudo apt update
sudo apt install -y python3 python3-venv python3-pip \
    libpulse0 libegl1 libxkbcommon0 libxcb-cursor0 \
    libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 \
    libgl1-mesa-dri libgl1-mesa-glx

# Clone and setup
git clone https://github.com/waybettersolutions/octave.git
cd octave
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 main.py
```

**Optional:** For OBD-II Bluetooth support: `sudo usermod -a -G dialout $USER` (log out and back in after)

### macOS
```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 main.py
```

</details>

---

## Troubleshooting

<details>
<summary><strong>Linux: Missing library errors (click to expand)</strong></summary>

**"cannot open shared object file" errors:**
```bash
sudo apt install libpulse0 libegl1 libxkbcommon0 libxcb-cursor0
```

**Qt platform plugin "xcb" errors:**
```bash
sudo apt install libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 libxcb-cursor0 libgl1-mesa-dri libgl1-mesa-glx
```

**"python: command not found"** - Use `python3` instead of `python`

**"ensurepip is not available":**
```bash
sudo apt install python3-venv
```

</details>

<details>
<summary><strong>WSL (Windows Subsystem for Linux)</strong></summary>

1. **Clone to your home directory** (not /mnt/c/...) to avoid permission issues:
   ```bash
   cd ~
   git clone https://github.com/waybettersolutions/octave.git
   ```

2. **GUI support** - WSL2 with WSLg supports GUI apps. Without WSLg, install an X server (VcXsrv) and set `export DISPLAY=:0`

3. **Audio** - May need PulseAudio configured to connect to Windows

</details>

<details>
<summary><strong>NumPy/Pint compatibility</strong></summary>

If you see `AttributeError: module 'numpy' has no attribute 'cumproduct'`:
```bash
pip install --upgrade pint
```

</details>

---

## Spotify Setup

OCTAVE can control Spotify playback on any of your connected devices (phone, computer, etc.). Here's how to set it up:

### Step 1: Create a Spotify Developer App

1. Log in with your Spotify account
2. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
3. Click **Create App**
4. Fill in the details:
   - **App name**: OCTAVE (or whatever you like)
   - **App description**: Car infotainment controller
   - **Redirect URI**: `http://127.0.0.1:8888/callback` *(important: enter this exactly)*
5. Check the box to agree to the terms
6. Click **Save**

### Step 2: Get Your Credentials

1. Open your newly created app in the dashboard
2. Click **Settings**
3. Copy your **Client ID** and **Client Secret**

### Step 3: Configure OCTAVE

1. Open OCTAVE and go to **Settings**
2. Scroll down to the **Spotify** section
3. Paste your **Client ID** and **Client Secret**
4. Click **Connect to Spotify**
5. A browser window will open - log in and authorize the app

### Step 4: Start Playing

1. Open Spotify on your phone or computer and start playing music
2. In OCTAVE, go to the **Media Room**
3. Click the **Local/Spotify** toggle button to switch to Spotify mode
4. Use the playback controls to control your music

**Note**: OCTAVE acts as a remote controller for Spotify. The music plays on your connected Spotify device (phone, desktop app, etc.), not through OCTAVE directly.

---

## Contributors
Special thanks to Robert DeGeorge and Marquis Johnson for their significant contributions to this project.

Visit us at [WayBetter Solutions](https://waybetter.solutions/) to follow our journey.

---

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository  
2. Create your feature branch:  
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Commit your changes:  
   ```bash
   git commit -m "Add some amazing feature"
   ```
4. Push to the branch:  
   ```bash
   git push origin feature/amazing-feature
   ```
5. Open a Pull Request  

---


## License
Copyright © 2025 Way Better Solutions 
This software is released under the MIT License.
