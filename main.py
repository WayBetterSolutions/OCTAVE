import sys
import os
import platform

# Check system type
system_name = platform.system()
print(f"Detected operating system: {system_name}")

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtCore import QResource
from PySide6.QtWidgets import QApplication

# backend imports
from backend.clock import Clock
from backend.settings_manager import SettingsManager
from backend.media_manager import MediaManager
from backend.svg_manager import SVGManager
from backend.obd_manager import OBDManager
from backend.spotify_manager import SpotifyManager
from backend.android_auto import AndroidAutoManager, EmbeddedDhuItem
from backend.phone_mirror import PhoneMirrorManager, EmbeddedScrcpyItem, ScrcpyCapture, ScrcpyCaptureItem

app = QApplication(sys.argv)
engine = QQmlApplicationEngine()

# Register custom QML types
qmlRegisterType(EmbeddedDhuItem, "OCTAVE.AndroidAuto", 1, 0, "EmbeddedDhuItem")
qmlRegisterType(EmbeddedScrcpyItem, "OCTAVE.PhoneMirror", 1, 0, "EmbeddedScrcpyItem")
qmlRegisterType(ScrcpyCaptureItem, "OCTAVE.PhoneMirror", 1, 0, "ScrcpyCaptureItem")

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

# Phone Mirror Manager
phone_mirror_manager = PhoneMirrorManager()
engine.rootContext().setContextProperty("phoneMirrorManager", phone_mirror_manager)

# Scrcpy Capture for frame-based phone mirroring (works around SDL resize issues)
scrcpy_capture = ScrcpyCapture()
scrcpy_capture.setPhoneMirrorManager(phone_mirror_manager)  # Link to manager for ADB access
engine.rootContext().setContextProperty("scrcpyCapture", scrcpy_capture)
engine.addImageProvider("scrcpyframe", scrcpy_capture.frame_provider)

# Load saved scrcpy path from settings
saved_scrcpy_path = settings_manager.get_scrcpy_path()
if saved_scrcpy_path:
    phone_mirror_manager.setScrcpyPath(saved_scrcpy_path)

# Load audio setting and initial volume
phone_mirror_manager.setAudioEnabled(settings_manager.get_scrcpy_audio_enabled())
# Convert 0-100 volume to 0.0-1.0 with logarithmic curve (matching BottomBar.qml)
initial_volume = settings_manager.currentVolume / 100.0
phone_mirror_manager.setVolume(initial_volume ** 2.0)  # Apply log curve

# Connect setting changes to manager
settings_manager.scrcpyAudioEnabledChanged.connect(
    lambda enabled: phone_mirror_manager.setAudioEnabled(enabled)
)

# Add the cleanup connection after creating managers:
def cleanup_on_quit():
    """Save state and cleanup before app exits"""
    media_manager._save_playback_state()
    media_manager._clear_temp_files()
    spotify_manager.cleanup()
    android_auto_manager.cleanup()  # Full cleanup: stops DHU, ADB, and head unit server
    phone_mirror_manager.cleanup()  # Stop phone mirror if running

app.aboutToQuit.connect(cleanup_on_quit)

# Update the path to Main.qml
qml_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend", "Main.qml")
engine.load(QUrl.fromLocalFile(qml_file))

if not engine.rootObjects():
    sys.exit(-1)

sys.exit(app.exec())