#!/bin/bash
# OCTAVE macOS Build Script
# Creates .app bundle and .dmg installer

set -e  # Exit on error

echo "========================================"
echo "OCTAVE macOS Build Script"
echo "========================================"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 not found"
    exit 1
fi

echo "[1/6] Setting up virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo "[2/6] Installing dependencies..."
pip install -r requirements.txt --quiet
pip install pyinstaller --quiet

echo "[3/6] Cleaning previous builds..."
rm -rf build dist

echo "[4/6] Building application with PyInstaller..."
pyinstaller octave.spec --noconfirm

if [ $? -ne 0 ]; then
    echo "ERROR: PyInstaller build failed"
    exit 1
fi

echo "[5/6] App bundle created at: dist/OCTAVE.app"

# Create DMG installer
echo "[6/6] Creating DMG installer..."

DMG_NAME="OCTAVE_1.0.0"
DMG_DIR="dist/dmg"
DMG_PATH="dist/${DMG_NAME}.dmg"

# Clean up any existing DMG
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Create DMG directory structure
mkdir -p "$DMG_DIR"
cp -R "dist/OCTAVE.app" "$DMG_DIR/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
if command -v create-dmg &> /dev/null; then
    # Use create-dmg if available (brew install create-dmg)
    create-dmg \
        --volname "OCTAVE" \
        --volicon "build_resources/icon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "OCTAVE.app" 150 185 \
        --icon "Applications" 450 185 \
        --hide-extension "OCTAVE.app" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$DMG_DIR" 2>/dev/null || {
            # Fallback if create-dmg fails (e.g., no icon file)
            hdiutil create -volname "OCTAVE" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
        }
else
    # Use hdiutil (built-in)
    hdiutil create -volname "OCTAVE" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
fi

# Clean up temp directory
rm -rf "$DMG_DIR"

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo ""
echo "App Bundle: dist/OCTAVE.app"
echo "DMG Installer: $DMG_PATH"
echo ""
echo "To install: Open the DMG and drag OCTAVE to Applications"
