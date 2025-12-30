# OCTAVE Build Guide

This guide explains how to compile OCTAVE into standalone executables and installers for Windows, macOS, and Linux.

## Quick Start

The simplest way to build is using the unified build script:

```bash
python build.py
```

This will automatically:
1. Create/activate a virtual environment
2. Install dependencies
3. Build the executable with PyInstaller
4. Create a platform-specific installer (if tools are available)

## Platform-Specific Instructions

### Windows

**Requirements:**
- Python 3.8+
- (Optional) [Inno Setup 6](https://jrsoftware.org/isdl.php) for creating the installer

**Build:**
```batch
# Option 1: Use unified script
python build.py

# Option 2: Use Windows batch file
build_scripts\build_windows.bat
```

**Output:**
- `dist\OCTAVE\OCTAVE.exe` - Standalone executable (portable)
- `dist\OCTAVE_Setup_1.0.0.exe` - Installer (if Inno Setup is installed)

**Distribution:**
- With installer: Distribute `OCTAVE_Setup_1.0.0.exe`
- Without installer: Zip the entire `dist\OCTAVE` folder

---

### macOS

**Requirements:**
- Python 3.8+
- Xcode Command Line Tools (`xcode-select --install`)
- (Optional) `create-dmg` for prettier DMG (`brew install create-dmg`)

**Build:**
```bash
# Option 1: Use unified script
python build.py

# Option 2: Use shell script
chmod +x build_scripts/build_macos.sh
./build_scripts/build_macos.sh
```

**Output:**
- `dist/OCTAVE.app` - Application bundle
- `dist/OCTAVE_1.0.0.dmg` - DMG installer

**Distribution:**
- Distribute the `.dmg` file
- Users open DMG and drag OCTAVE to Applications

**Code Signing (Optional):**
For distribution outside the App Store, you may want to sign the app:
```bash
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" dist/OCTAVE.app
```

---

### Linux

**Requirements:**
- Python 3.8+
- Build essentials (`sudo apt install build-essential`)
- (Optional) `wget` for automatic appimagetool download

**Build:**
```bash
# Option 1: Use unified script
python build.py

# Option 2: Use shell script
chmod +x build_scripts/build_linux.sh
./build_scripts/build_linux.sh
```

**Output:**
- `dist/OCTAVE/octave` - Standalone executable
- `dist/OCTAVE-x86_64.AppImage` - AppImage (portable, single-file)

**Distribution:**
- Distribute the `.AppImage` file
- Users make it executable and run: `chmod +x OCTAVE-*.AppImage && ./OCTAVE-*.AppImage`

---

## Build Options

```bash
# Clean build artifacts
python build.py --clean

# Clean and rebuild
python build.py --clean --build-after-clean

# Show help
python build.py --help
```

## Adding an App Icon

For professional distribution, add platform-specific icons:

1. Create a `build_resources` folder (already created)
2. Add your icons:
   - `build_resources/icon.ico` - Windows (256x256, .ico format)
   - `build_resources/icon.icns` - macOS (.icns format)
   - `build_resources/icon.png` - Linux (256x256 PNG)

**Creating icons:**
- Start with a 1024x1024 PNG
- Windows: Use an online converter or GIMP to create .ico
- macOS: Use `iconutil` or online converter for .icns
- Linux: Use 256x256 PNG directly

## Troubleshooting

### "DLL not found" errors on Windows
Install the Visual C++ Redistributable:
https://aka.ms/vs/17/release/vc_redist.x64.exe

### "App is damaged" on macOS
The app isn't signed. Users can bypass with:
```bash
xattr -cr /Applications/OCTAVE.app
```

### Missing Qt plugins
Ensure PySide6 is the same version in requirements.txt and the build environment.

### AppImage won't run on Linux
Make sure it's executable:
```bash
chmod +x OCTAVE-x86_64.AppImage
```

If FUSE isn't available, extract and run:
```bash
./OCTAVE-x86_64.AppImage --appimage-extract
./squashfs-root/AppRun
```

## CI/CD Integration

For automated builds, you can use GitHub Actions. Example workflow:

```yaml
name: Build OCTAVE

on:
  push:
    tags:
      - 'v*'

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: python build.py
      - uses: actions/upload-artifact@v4
        with:
          name: OCTAVE-Windows
          path: dist/OCTAVE/

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: python build.py
      - uses: actions/upload-artifact@v4
        with:
          name: OCTAVE-macOS
          path: dist/*.dmg

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: python build.py
      - uses: actions/upload-artifact@v4
        with:
          name: OCTAVE-Linux
          path: dist/*.AppImage
```

## File Structure

After running the build, your project will have:

```
OCTAVE/
├── build.py                    # Unified build script
├── octave.spec                 # PyInstaller configuration
├── requirements-build.txt      # Build dependencies
├── build_scripts/
│   ├── build_windows.bat       # Windows build script
│   ├── build_macos.sh          # macOS build script
│   ├── build_linux.sh          # Linux build script
│   └── installer_windows.iss   # Inno Setup script
├── build_resources/
│   ├── icon.ico                # Windows icon (add this)
│   ├── icon.icns               # macOS icon (add this)
│   └── icon.png                # Linux icon (add this)
├── dist/                       # Build output (generated)
│   ├── OCTAVE/                 # Executable folder
│   └── OCTAVE_Setup_*.exe      # Installer (Windows)
└── build/                      # Temp build files (generated)
```
