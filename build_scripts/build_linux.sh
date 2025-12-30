#!/bin/bash
# OCTAVE Linux Build Script
# Creates standalone executable and AppImage

set -e  # Exit on error

echo "========================================"
echo "OCTAVE Linux Build Script"
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

echo "[1/7] Setting up virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo "[2/7] Installing dependencies..."
pip install -r requirements.txt --quiet
pip install pyinstaller --quiet

echo "[3/7] Cleaning previous builds..."
rm -rf build dist

echo "[4/7] Building executable with PyInstaller..."
pyinstaller octave.spec --noconfirm

if [ $? -ne 0 ]; then
    echo "ERROR: PyInstaller build failed"
    exit 1
fi

echo "[5/7] Executable created at: dist/OCTAVE/octave"

# Create AppImage
echo "[6/7] Setting up AppImage structure..."

APPDIR="dist/OCTAVE.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy application files
cp -r dist/OCTAVE/* "$APPDIR/usr/bin/"

# Create desktop entry
cat > "$APPDIR/octave.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=OCTAVE
Comment=Open-source Cross-platform Telematics for Augmented Vehicle Experience
Exec=octave
Icon=octave
Categories=AudioVideo;Audio;Player;
Terminal=false
EOF

# Copy desktop file to standard location too
cp "$APPDIR/octave.desktop" "$APPDIR/usr/share/applications/"

# Create a simple icon if none exists
if [ -f "build_resources/icon.png" ]; then
    cp "build_resources/icon.png" "$APPDIR/octave.png"
    cp "build_resources/icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/octave.png"
else
    # Create a placeholder icon (solid color square)
    echo "NOTE: No icon found at build_resources/icon.png, using placeholder"
    # Create simple SVG as placeholder
    cat > "$APPDIR/octave.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
  <rect width="256" height="256" fill="#2196F3" rx="32"/>
  <text x="128" y="160" text-anchor="middle" font-family="sans-serif" font-size="120" font-weight="bold" fill="white">O</text>
</svg>
SVGEOF
    # Also link it as png location
    cp "$APPDIR/octave.svg" "$APPDIR/usr/share/icons/hicolor/256x256/apps/"
fi

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/bin/:${LD_LIBRARY_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/bin/PySide6/Qt/plugins/platforms"
export QML2_IMPORT_PATH="${HERE}/usr/bin/PySide6/Qt/qml"
exec "${HERE}/usr/bin/octave" "$@"
EOF
chmod +x "$APPDIR/AppRun"

echo "[7/7] Creating AppImage..."

# Download appimagetool if not present
ARCH=$(uname -m)
APPIMAGETOOL="appimagetool-${ARCH}.AppImage"

if [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/${APPIMAGETOOL}" -O "$APPIMAGETOOL" || {
        echo ""
        echo "NOTE: Could not download appimagetool."
        echo "You can manually download it from:"
        echo "https://github.com/AppImage/AppImageKit/releases"
        echo ""
        echo "The AppDir is ready at: $APPDIR"
        echo "To create AppImage manually, run:"
        echo "  ./appimagetool-${ARCH}.AppImage $APPDIR"
        exit 0
    }
    chmod +x "$APPIMAGETOOL"
fi

# Create AppImage
ARCH=$ARCH ./"$APPIMAGETOOL" "$APPDIR" "dist/OCTAVE-${ARCH}.AppImage"

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo ""
echo "Executable: dist/OCTAVE/octave"
echo "AppImage: dist/OCTAVE-${ARCH}.AppImage"
echo ""
echo "To run the AppImage:"
echo "  chmod +x dist/OCTAVE-${ARCH}.AppImage"
echo "  ./dist/OCTAVE-${ARCH}.AppImage"
