# OCTAVE

## Overview
[OCTAVE](https://waybetter.solutions/octave/index.html) (Open-source Cross-platform Telematics for Augmented Vehicle Experience) is a solution to having a fully programmable infotainment center in your vehicle. While OCTAVE could theoretically work in any vehicle, it best suits older cars with dilapidated infotainment systems. We were always left seeking more from the infotainment systems in our vehicles, so we wanted to develop a solution that could be extremely feature rich. We also wanted to be able to see all the OBD-II data coming from the vehicle while still being able to play music and all that good stuff.

OCTAVE is cross-platform so that the installation into a vehicle is totally up to the user. Those utlizing OCTAVE most often use a Rasberry Pi (or equivalent). All you need from there is a proportionate touchscreen, a power source, a 3D printed mount for the screen and an interface into the speakers. OCTAVE is suitable for Windows, Mac or Linux, making the code and testing of new features simple.

This app was designed to be easy to work with, so it has a Python backend with a QML based front end. There's also a settings configuration JSON file that's used to capture all user made changes, so everything you change stays changed and you can rock the app exactly as you like.

Please feel free to reach out if you think this is cool or if you think its lame you can tell me all about it rob.degeorge@gmail.com

## Preview
<img src="frontend/assets/readme/display.gif" alt="OCTAVE Demo" width="400">

## System Requirements

- **Python**: 3.8 or higher
- **Operating System**: Windows 10+, macOS 10.14+, or Linux (Ubuntu/Debian, Raspberry Pi OS, others)


## Installation & Running

**First time setup:**
```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python setup.py
```

**Run the app:**
```bash
source venv/bin/activate    # Windows: venv\Scripts\activate
python main.py
```

The setup script automatically:
- Detects your OS
- Installs system dependencies (Linux)
- Creates a Python virtual environment
- Installs all required packages

**Optional:** For OBD-II Bluetooth on Linux: `sudo usermod -a -G dialout $USER`

## Building for Android

OCTAVE can be compiled as an Android APK using [Buildozer](https://github.com/kivy/buildozer) with the [python-for-android](https://github.com/kivy/python-for-android) Qt bootstrap.

### Prerequisites

- **Linux host** (building Android APKs requires Linux)
- **Python 3.11** (must match the PySide6 wheel ABI)
- **Android SDK** with platform tools installed
- **Android NDK r26b** (`26.1.10909125`) — install via Android Studio SDK Manager or:
  ```bash
  sdkmanager "ndk;26.1.10909125"
  ```
- **Buildozer** and **python-for-android** (`develop` branch):
  ```bash
  pip install buildozer
  pip install "python-for-android @ git+https://github.com/kivy/python-for-android@develop"
  ```

### PySide6 Android Wheels

The build requires pre-built PySide6 and shiboken6 wheels for Android aarch64. These are too large to include in the repo.

1. Download the following wheels from [Qt for Python releases](https://download.qt.io/official_releases/QtForPython/):
   - `pyside6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl`
   - `shiboken6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl`
2. Place them in `deployment/wheels/`

You can also set the `OCTAVE_WHEELS_DIR` environment variable to point to a different directory containing the wheels.

### Configure & Build

1. Edit `deployment/buildozer.spec` and set `android.ndk_path`, `android.sdk_path`, and the `--sdk-dir`/`--ndk-dir` values in `p4a.extra_args` to your local paths
2. Edit `pysidedeploy.spec` and set the `ndk_path`, `sdk_path`, and `python_path` fields
3. Build:
   ```bash
   cd deployment
   buildozer android debug
   ```
4. The APK will be output to `dist/`

### Known Issue: pip corruption in build venv

The python-for-android build venv ships with pip 24.0, which has a broken `resolvelib`. If the build fails during package installation, fix it by nuking the build venv so it gets recreated:

```bash
rm -rf deployment/.buildozer/android/platform/build-arm64-v8a/build/venv
```

Then re-run the build. If it still fails, manually bootstrap pip in the venv:

```bash
VENV=deployment/.buildozer/android/platform/build-arm64-v8a/build/venv
$VENV/bin/python /tmp/get-pip.py  # download get-pip.py from https://bootstrap.pypa.io/get-pip.py
```

## License
2026 [Way Better Solutions](https://waybetter.solutions/) - Follow our journey!

This software is released under the MIT License.
