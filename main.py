import sys
import os
import platform

# Check system type FIRST
system_name = platform.system()
print(f"Detected operating system: {system_name}")

# Setup libusb for Android Auto (Windows) - MUST happen before importing android_auto
def setup_libusb():
    try:
        import libusb
        pkg_dir = os.path.dirname(libusb.__file__)
        arch = platform.machine().lower()
        if arch in ('amd64', 'x86_64'):
            dll_subdir = 'x86_64'
        elif arch in ('arm64', 'aarch64'):
            dll_subdir = 'arm64'
        else:
            dll_subdir = 'x86'
        dll_path = os.path.join(pkg_dir, '_platform', 'windows', dll_subdir)
        if os.path.exists(dll_path):
            os.environ['PATH'] = dll_path + os.pathsep + os.environ.get('PATH', '')
            print("Android Auto: libusb configured")
            return True
    except ImportError:
        print("Android Auto: libusb not available")
    return False

if system_name == 'Windows':
    setup_libusb()

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtCore import QResource
from PySide6.QtWidgets import QApplication

# backend imports - AndroidAutoManager MUST be imported AFTER libusb setup
from backend.clock import Clock
from backend.settings_manager import SettingsManager
from backend.media_manager import MediaManager
from backend.svg_manager import SVGManager
from backend.obd_manager import OBDManager
from backend.spotify_manager import SpotifyManager
from backend.android_auto import AndroidAutoManager, WindowContainer

app = QApplication(sys.argv)
engine = QQmlApplicationEngine()

# Register custom QML types
qmlRegisterType(WindowContainer, "OCTAVE.AndroidAuto", 1, 0, "WindowContainer")

engine.addImportPath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend"))

# Settings Manager
settings_manager = SettingsManager()
engine.rootContext().setContextProperty("settingsManager", settings_manager)

# Clock
clock = Clock(settings_manager)
engine.rootContext().setContextProperty("clock", clock)

# Media Manager
media_manager = MediaManager()
media_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("mediaManager", media_manager)

# SVG Manager
svg_manager = SVGManager()
engine.rootContext().setContextProperty("svgManager", svg_manager)

# OBD Manager
obd_manager = OBDManager(settings_manager)
engine.rootContext().setContextProperty("obdManager", obd_manager)

# Spotify Manager
spotify_manager = SpotifyManager()
spotify_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("spotifyManager", spotify_manager)

# Android Auto Manager
android_auto_manager = AndroidAutoManager()
engine.rootContext().setContextProperty("androidAutoManager", android_auto_manager)

# Register DHU frame provider for seamless Android Auto display
engine.addImageProvider("dhuframe", android_auto_manager._dhu_capture.frame_provider)

# Add the cleanup connection after creating managers:
def cleanup_on_quit():
    """Save state and cleanup before app exits"""
    media_manager._save_playback_state()
    media_manager._clear_temp_files()
    spotify_manager.cleanup()
    android_auto_manager.cleanup()  # Full cleanup: stops DHU, ADB, and head unit server

app.aboutToQuit.connect(cleanup_on_quit)

# Update the path to Main.qml
qml_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend", "Main.qml")
engine.load(QUrl.fromLocalFile(qml_file))

if not engine.rootObjects():
    sys.exit(-1)

sys.exit(app.exec())