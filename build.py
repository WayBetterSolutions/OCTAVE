#!/usr/bin/env python3
"""
OCTAVE Cross-Platform Build Script
Unified build script that works on Windows, macOS, and Linux.

Usage:
    python build.py              # Build for current platform
    python build.py --clean      # Clean build artifacts
    python build.py --help       # Show help
"""

import os
import sys
import shutil
import subprocess
import platform
import argparse
from pathlib import Path


# Configuration
APP_NAME = "OCTAVE"
APP_VERSION = "1.0.0"
PROJECT_ROOT = Path(__file__).parent.absolute()

# Use temp directory for builds to avoid Dropbox sync issues
import tempfile
TEMP_BUILD_DIR = Path(tempfile.gettempdir()) / "OCTAVE_build"
TEMP_DIST_DIR = Path(tempfile.gettempdir()) / "OCTAVE_dist"


def get_platform():
    """Get current platform name."""
    system = platform.system().lower()
    if system == "darwin":
        return "macos"
    elif system == "windows":
        return "windows"
    else:
        return "linux"


def run_command(cmd, cwd=None, shell=False):
    """Run a command and handle errors."""
    print(f"  Running: {cmd if isinstance(cmd, str) else ' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or PROJECT_ROOT,
            shell=shell,
            check=True,
            capture_output=False
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ERROR: Command failed with exit code {e.returncode}")
        return False


def clean_build():
    """Remove build artifacts."""
    print("\n[Clean] Removing build artifacts...")

    dirs_to_remove = ["build", "dist", "__pycache__"]
    files_to_remove = []

    for dir_name in dirs_to_remove:
        dir_path = PROJECT_ROOT / dir_name
        if dir_path.exists():
            print(f"  Removing {dir_path}")
            shutil.rmtree(dir_path)

    # Clean __pycache__ recursively
    for pycache in PROJECT_ROOT.rglob("__pycache__"):
        print(f"  Removing {pycache}")
        shutil.rmtree(pycache)

    # Clean .pyc files
    for pyc in PROJECT_ROOT.rglob("*.pyc"):
        print(f"  Removing {pyc}")
        pyc.unlink()

    print("  Clean complete!")


def ensure_venv():
    """Ensure virtual environment exists and is activated."""
    venv_path = PROJECT_ROOT / "venv"

    if not venv_path.exists():
        print("\n[Setup] Creating virtual environment...")
        run_command([sys.executable, "-m", "venv", str(venv_path)])

    # Return path to python in venv
    if get_platform() == "windows":
        return str(venv_path / "Scripts" / "python.exe")
    else:
        return str(venv_path / "bin" / "python")


def install_dependencies(python_path):
    """Install required dependencies."""
    print("\n[Setup] Installing dependencies...")

    # Install runtime dependencies
    run_command([python_path, "-m", "pip", "install", "-r", "requirements.txt", "--quiet"])

    # Install PyInstaller
    run_command([python_path, "-m", "pip", "install", "pyinstaller", "--quiet"])


def build_executable(python_path):
    """Build the executable with PyInstaller."""
    print("\n[Build] Building executable with PyInstaller...")
    print(f"  Using temp build directory: {TEMP_BUILD_DIR}")

    spec_file = PROJECT_ROOT / "octave.spec"

    if not spec_file.exists():
        print(f"  ERROR: Spec file not found: {spec_file}")
        return False

    # Build to temp directory to avoid Dropbox sync issues
    return run_command([
        python_path, "-m", "PyInstaller", str(spec_file), "--noconfirm",
        "--distpath", str(TEMP_DIST_DIR),
        "--workpath", str(TEMP_BUILD_DIR)
    ])


def create_windows_installer():
    """Create Windows installer using Inno Setup."""
    print("\n[Installer] Creating Windows installer...")

    # Find Inno Setup compiler
    iscc_paths = [
        r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        r"C:\Program Files\Inno Setup 6\ISCC.exe",
    ]

    iscc_path = None
    for path in iscc_paths:
        if os.path.exists(path):
            iscc_path = path
            break

    if not iscc_path:
        print("  WARNING: Inno Setup not found. Skipping installer creation.")
        print("  Download from: https://jrsoftware.org/isdl.php")
        return True  # Not a failure, just skipped

    iss_file = PROJECT_ROOT / "build_scripts" / "installer_windows.iss"
    return run_command([iscc_path, str(iss_file)])


def create_macos_dmg():
    """Create macOS DMG installer."""
    print("\n[Installer] Creating macOS DMG...")

    app_path = TEMP_DIST_DIR / "OCTAVE.app"
    if not app_path.exists():
        print(f"  ERROR: App bundle not found: {app_path}")
        return False

    dmg_dir = TEMP_DIST_DIR / "dmg"
    dmg_path = TEMP_DIST_DIR / f"OCTAVE_{APP_VERSION}.dmg"

    # Clean up
    if dmg_dir.exists():
        shutil.rmtree(dmg_dir)
    if dmg_path.exists():
        dmg_path.unlink()

    # Create DMG directory
    dmg_dir.mkdir(parents=True)
    shutil.copytree(app_path, dmg_dir / "OCTAVE.app")

    # Create Applications symlink
    os.symlink("/Applications", dmg_dir / "Applications")

    # Create DMG with hdiutil
    success = run_command([
        "hdiutil", "create",
        "-volname", "OCTAVE",
        "-srcfolder", str(dmg_dir),
        "-ov", "-format", "UDZO",
        str(dmg_path)
    ])

    # Clean up temp directory
    shutil.rmtree(dmg_dir)

    return success


def create_linux_appimage():
    """Create Linux AppImage."""
    print("\n[Installer] Creating Linux AppImage...")

    dist_path = TEMP_DIST_DIR / "OCTAVE"
    if not dist_path.exists():
        print(f"  ERROR: Build output not found: {dist_path}")
        return False

    appdir = TEMP_DIST_DIR / "OCTAVE.AppDir"
    arch = platform.machine()

    # Clean up
    if appdir.exists():
        shutil.rmtree(appdir)

    # Create AppDir structure
    (appdir / "usr" / "bin").mkdir(parents=True)
    (appdir / "usr" / "share" / "applications").mkdir(parents=True)
    (appdir / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps").mkdir(parents=True)

    # Copy application files
    for item in dist_path.iterdir():
        dest = appdir / "usr" / "bin" / item.name
        if item.is_dir():
            shutil.copytree(item, dest)
        else:
            shutil.copy2(item, dest)

    # Create desktop entry
    desktop_content = """[Desktop Entry]
Type=Application
Name=OCTAVE
Comment=Open-source Cross-platform Telematics for Augmented Vehicle Experience
Exec=octave
Icon=octave
Categories=AudioVideo;Audio;Player;
Terminal=false
"""
    (appdir / "octave.desktop").write_text(desktop_content)
    shutil.copy2(appdir / "octave.desktop", appdir / "usr" / "share" / "applications" / "octave.desktop")

    # Create AppRun
    apprun_content = """#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/bin/:${LD_LIBRARY_PATH}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/bin/PySide6/Qt/plugins/platforms"
export QML2_IMPORT_PATH="${HERE}/usr/bin/PySide6/Qt/qml"
exec "${HERE}/usr/bin/octave" "$@"
"""
    apprun_path = appdir / "AppRun"
    apprun_path.write_text(apprun_content)
    os.chmod(apprun_path, 0o755)

    # Download appimagetool if needed
    appimagetool = PROJECT_ROOT / f"appimagetool-{arch}.AppImage"
    if not appimagetool.exists():
        print("  Downloading appimagetool...")
        url = f"https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-{arch}.AppImage"
        try:
            run_command(["wget", "-q", url, "-O", str(appimagetool)])
            os.chmod(appimagetool, 0o755)
        except:
            print("  WARNING: Could not download appimagetool")
            print(f"  AppDir ready at: {appdir}")
            return True

    # Create AppImage
    appimage_path = TEMP_DIST_DIR / f"OCTAVE-{arch}.AppImage"
    env = os.environ.copy()
    env["ARCH"] = arch

    return run_command([str(appimagetool), str(appdir), str(appimage_path)])


def build(args):
    """Main build function."""
    current_platform = get_platform()

    print("=" * 50)
    print(f"OCTAVE Build Script")
    print(f"Platform: {current_platform}")
    print(f"Version: {APP_VERSION}")
    print("=" * 50)

    if args.clean:
        clean_build()
        if not args.build_after_clean:
            return 0

    # Setup
    python_path = ensure_venv()
    install_dependencies(python_path)

    # Clean previous builds
    clean_build()

    # Build executable
    if not build_executable(python_path):
        print("\nERROR: Build failed!")
        return 1

    # Copy build output to project dist folder
    print("\n[Copy] Copying build output to project folder...")
    final_dist = PROJECT_ROOT / "dist"
    if final_dist.exists():
        shutil.rmtree(final_dist, ignore_errors=True)
    shutil.copytree(TEMP_DIST_DIR, final_dist)

    # Create platform-specific installer
    if current_platform == "windows":
        create_windows_installer()
        print("\n" + "=" * 50)
        print("Build complete!")
        print("=" * 50)
        print(f"\nExecutable: {final_dist / 'OCTAVE' / 'OCTAVE.exe'}")
        print(f"Installer: dist/OCTAVE_Setup_{APP_VERSION}.exe (if Inno Setup installed)")

    elif current_platform == "macos":
        create_macos_dmg()
        print("\n" + "=" * 50)
        print("Build complete!")
        print("=" * 50)
        print(f"\nApp Bundle: dist/OCTAVE.app")
        print(f"DMG: dist/OCTAVE_{APP_VERSION}.dmg")

    else:  # Linux
        create_linux_appimage()
        arch = platform.machine()
        print("\n" + "=" * 50)
        print("Build complete!")
        print("=" * 50)
        print(f"\nExecutable: dist/OCTAVE/octave")
        print(f"AppImage: dist/OCTAVE-{arch}.AppImage")

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="OCTAVE Cross-Platform Build Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python build.py              Build for current platform
    python build.py --clean      Clean build artifacts only
    python build.py --clean -b   Clean then build

Platform-specific outputs:
    Windows: dist/OCTAVE/OCTAVE.exe, dist/OCTAVE_Setup_X.X.X.exe
    macOS:   dist/OCTAVE.app, dist/OCTAVE_X.X.X.dmg
    Linux:   dist/OCTAVE/octave, dist/OCTAVE-ARCH.AppImage
        """
    )

    parser.add_argument(
        "--clean", "-c",
        action="store_true",
        help="Clean build artifacts"
    )

    parser.add_argument(
        "--build-after-clean", "-b",
        action="store_true",
        help="Build after cleaning (use with --clean)"
    )

    args = parser.parse_args()

    try:
        sys.exit(build(args))
    except KeyboardInterrupt:
        print("\nBuild cancelled.")
        sys.exit(1)
    except Exception as e:
        print(f"\nERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
