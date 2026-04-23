# Android Build Setup (C++ / Qt 6)

**Status:** Toolchain setup guide — work through this once to prepare your Linux workstation to build the OCTAVE C++ backend into an Android APK. Companion doc to `BUILD.md`.

**Last updated:** 2026-04-20

## Goal

Get this machine ready to produce an installable debug APK of the **C++ / Qt 6** OCTAVE backend that runs on:

- Samsung Galaxy Tab S6 (`SM-T860` / `SM-T865`) — arm64-v8a, Android 11+
- Samsung Galaxy S22 Ultra — arm64-v8a, Android 12+

This is for **sideload testing first**. Play Store is a separate later milestone that builds on top of this setup.

Distribution plan: **LGPL Qt, dynamically linked, shared `.so`s bundled in APK.** Commercial Qt license is not required at this stage — see `BUILD.md` or ask if that changes.

**Scope note:** Spotify is **excluded from the Android build** (both C++ and Python APKs). The Spotify experience is desktop-only. This simplifies OAuth (no custom URI scheme gymnastics) and shrinks the dependency surface for Play Store review.

## Prerequisites (already on this box — verify only)

```bash
java -version          # expect OpenJDK 17.x
cmake --version        # expect 3.21+
qmake6 --version       # expect Qt 6.11.x (desktop Qt — Android Qt installs separately)
adb version            # if missing: sudo pacman -S android-tools
```

All four should report cleanly. JDK 17 is required by Android Gradle Plugin 8.x — do not use 11 or 21.

You'll need roughly **40–60 GB free** on the disk hosting `$HOME` (Qt for Android + SDK + NDK + build outputs).

## Step 1 — Install Qt for Android 6.7.3 (via aqtinstall)

We install **Qt 6.7.3**, not 6.11. Reason: Qt 6.8+ moved behind a login-gated channel (requires a Qt account), while 6.7.3 is available through aqtinstall's public-mirror CLI path. OCTAVE's CMakeLists doesn't pin a Qt version, so using 6.7.3 for Android is a no-op — desktop builds keep using system Qt 6.11.x independently.

```bash
# aqtinstall is a CLI Qt installer, no account required
pipx install aqtinstall

# Android target build (~1 GB)
aqt install-qt linux android 6.7.3 android_arm64_v8a -O ~/Qt \
    -m qtmultimedia qtnetworkauth qtserialport qtconnectivity qtsensors

# Desktop host tools Qt (needed for cross-compile, ~1 GB)
aqt install-qt linux desktop 6.7.3 linux_gcc_64 -O ~/Qt \
    -m qtmultimedia qtnetworkauth qtserialport qtconnectivity qtsensors
```

**OpenSSL for Android:** skipped at toolchain-install time. The public aqtinstall mirror no longer carries prebuilt Android OpenSSL. If we need HTTPS on Android at runtime (TBD — Spotify is excluded and downloads are OFF for Play Store), we'll wire it in at Phase 1 via KDAB's `android_openssl` CMake project.

**Verify:**
```bash
ls ~/Qt/6.7.3/android_arm64_v8a/bin/qt-cmake       # Android cross-compile wrapper
ls ~/Qt/6.7.3/gcc_64/bin/androiddeployqt           # APK packaging tool (runs on host)
```

### Alternative: official Qt online installer

If you need Qt 6.8+ specifically or prefer the GUI, use Qt's online installer instead. This requires a free Qt account. Current download path (may move — check `https://www.qt.io/download-qt-installer-oss` for latest):

```bash
mkdir -p ~/Downloads/qt-installer && cd ~/Downloads/qt-installer
curl -L -O "https://d13lb3tujbc8s0.cloudfront.net/onlineinstallers/qt-online-installer-linux-x64-4.11.0.run"
chmod +x qt-online-installer-linux-x64-4.11.0.run
./qt-online-installer-linux-x64-4.11.0.run
```

In the installer, pick Qt Open Source, install to `~/Qt`, and under the component tree check **Qt → Qt 6.x → Android arm64_v8a** plus any extra modules (Multimedia, Connectivity, Sensors, NetworkAuth, SerialPort). Skip other ABIs to save disk.

## Step 2 — Install Android SDK + NDK

Two routes. Pick one.

### Route A (recommended): Android Studio

Easiest and keeps SDK up to date.

```bash
yay -S android-studio
# or download from https://developer.android.com/studio
```

Launch Android Studio once, accept licenses, let it install the default SDK + platform-tools. Then:

- **SDK Manager → SDK Platforms:** install **Android 14 (API 34)**. (minSdk for Tab S6 is 30 but the platform JAR only needs to be ≥ minSdk, not exactly minSdk.)
- **SDK Manager → SDK Tools:** install **NDK (Side by side) — version 26.1.10909125** (what Qt 6.7.3 expects).
- **SDK Manager → SDK Tools:** install **Android SDK Command-line Tools (latest)** and **Android SDK Build-Tools 35.0.0** (or newer — 34.0.0 also works if present).

### Route B (lean, used in this walkthrough): cmdline-tools only

If you'd rather skip the IDE:

```bash
# Download page: https://developer.android.com/studio#command-line-tools-only
# Direct link rotates — current as of 2026-04:
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Downloads
curl -L -O "https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip"
unzip commandlinetools-linux-14742923_latest.zip
mv cmdline-tools ~/Android/Sdk/cmdline-tools/latest

# Accept licenses (the SDK root is ~/Android/Sdk/ — the wrapper dir above `cmdline-tools/`)
yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses

# Install required packages
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;35.0.0" \
    "ndk;26.1.10909125"
```

**Important:** `cmdline-tools/` must live at `~/Android/Sdk/cmdline-tools/latest/`, not `~/Android/cmdline-tools/latest/`. The parent dir of `cmdline-tools/` is what sdkmanager treats as the SDK root, and wrong nesting produces "inconsistent location" warnings.

## Step 3 — Environment variables

Add to `~/.bashrc` (or `~/.zshrc`):

```bash
# OCTAVE Android build toolchain
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/26.1.10909125"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export QT_ANDROID_ROOT="$HOME/Qt/6.7.3/android_arm64_v8a"
export QT_HOST_PATH="$HOME/Qt/6.7.3/gcc_64"
export PATH="$QT_ANDROID_ROOT/bin:$QT_HOST_PATH/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

`QT_HOST_PATH` is required — `qt-cmake` uses it to locate the host toolchain during cross-compile. Without it, `find_package(Qt6 ...)` will set `Qt6_FOUND=FALSE` at configure time.

Reload: `source ~/.bashrc` then verify:

```bash
echo $ANDROID_SDK_ROOT  # non-empty
echo $ANDROID_NDK_ROOT  # non-empty, points to NDK dir
echo $JAVA_HOME         # non-empty
ls $ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake   # must exist
ls $QT_ANDROID_ROOT/lib/cmake/Qt6/qt.toolchain.cmake       # must exist
```

All four must pass or Step 5 will fail.

## Step 4 — Enable USB debugging on devices

### Tab S6 (`SM-T860` / `SM-T865`)

1. **Settings → About tablet → Software information** → tap **Build number** 7 times.
2. Back out to Settings. **Developer options** now appears.
3. **Developer options → USB debugging → ON.**
4. Plug in USB cable, accept the "Allow USB debugging?" prompt (check "Always allow").

### S22 Ultra

Same flow — **Settings → About phone → Software information** → 7 taps on Build number, then Developer options → USB debugging.

### Verify both devices

```bash
adb devices
# expect two lines with "device" (not "unauthorized")
```

If a device shows `unauthorized`, unplug/replug and accept the prompt on the device screen.

## Step 5 — Smoke-test the Android toolchain (no app build yet)

Standalone sample verifies the full toolchain pipeline before we wire the repo for Android:

```bash
TMPDIR=$(mktemp -d); cd "$TMPDIR"
cat > CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.21)
project(hello_qt)
find_package(Qt6 REQUIRED COMPONENTS Core)
message(STATUS "Qt version: ${Qt6_VERSION}")
EOF
qt-cmake -S . -B build-android \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-30
```

Expect: `-- Qt version: 6.7.3` and `-- Configuring done`.

If you see `Qt6_FOUND to FALSE`, your `QT_HOST_PATH` isn't set — re-check Step 3.

When the repo is Android-ready, the full configure command will look like:

```bash
qt-cmake -S . -B build-android \
  -DCMAKE_BUILD_TYPE=Debug \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-30 \
  -DOCTAVE_ENABLE_DOWNLOADS=OFF \
  -DQT_ANDROID_SIGN_APK=OFF

cmake --build build-android --target apk
adb install build-android/android-build/build/outputs/apk/debug/android-build-debug.apk
```

(Exact target name depends on how we wire `qt_add_executable` — final command will land in `BUILD.md` once Phase 1 of the Android port is merged.)

## Troubleshooting

### `qt-cmake: command not found`
Your `QT_ANDROID_ROOT/bin` isn't on PATH. Re-check Step 3 and `source ~/.bashrc`.

### `Could not find NDK`
`ANDROID_NDK_ROOT` points to a version that isn't installed. `ls ~/Android/Sdk/ndk/` to see what you have and update the env var, or install the version Qt wants.

### `Could not find Java 17`
`update-alternatives --config java` on Arch, or explicitly set `JAVA_HOME` to the 17 install path.

### `adb devices` shows device as `unauthorized`
The trust prompt on the device was dismissed. Unplug, replug, and watch the device screen carefully — the dialog is easy to miss.

### `INSTALL_FAILED_UPDATE_INCOMPATIBLE` on `adb install`
A release-signed APK of the same package name is already installed. `adb uninstall org.OCTAVE` first.

### Qt online installer refuses to let you select "Qt Open Source"
The installer defaults to commercial trial. Scroll down in the account step — there's an "Open source user" radio button under the license type. You may need to accept an additional LGPL-obligations-acknowledgement checkbox.

### Gradle complains about JDK 21
Something on your PATH resolved to 21. `update-alternatives` or uninstall JDK 21 if you don't need it elsewhere.

## What's next

Once this setup is done, hand back to Claude with "toolchain is ready" and we'll start **Phase 1 — CMake Android wiring and Android-minimum build target**. That phase will:

1. Add an `android/` directory at repo root with `AndroidManifest.xml`.
2. Modify `CMakeLists.txt` to conditionally exclude hardware-only managers when `ANDROID` is set.
3. Stub the excluded managers so QML bindings continue to resolve.
4. Ship the first debug APK sideloadable to both devices.

Phases 2–4 are: platform gating, OBD over Bluetooth, sideload polish. Play Store is a later milestone.
