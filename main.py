import sys
import os
import platform
import argparse

# Force Qt Quick Controls to use Basic style (allows Slider customization)
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

# Parse command line arguments for debug mode
parser = argparse.ArgumentParser(description='OCTAVE Infotainment System')
parser.add_argument('--debug', action='store_true', help='Enable debug logging')
args, _ = parser.parse_known_args()

# Initialize logging FIRST (before other imports that might log)
from backend.logging_config import setup_logging, get_logger
setup_logging(debug=args.debug)
logger = get_logger(__name__)

# Check system type
system_name = platform.system()
logger.info(f"Detected operating system: {system_name}")

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
from backend.esp32_volume_manager import ESP32VolumeManager

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

# ESP32 Volume Manager - wireless rotary encoder volume control
esp32_volume_manager = ESP32VolumeManager()
esp32_volume_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("esp32VolumeManager", esp32_volume_manager)

# Connect ESP32 volume signals to volume control
# Accumulator for fractional volume changes (e.g., 0.25 per tick)
_volume_accumulator = 0.0

def handle_esp32_volume_change(delta):
    """Handle volume change from ESP32 rotary encoder."""
    global _volume_accumulator

    # Accumulate fractional changes
    _volume_accumulator += delta

    # Only apply when we have at least 1% change
    if abs(_volume_accumulator) >= 1.0:
        # Extract the integer portion to apply
        change = int(_volume_accumulator)
        _volume_accumulator -= change  # Keep the remainder

        current = settings_manager.currentVolume
        new_volume = max(0, min(100, current + change))
        settings_manager.setCurrentVolume(new_volume)

        # Apply logarithmic curve and set to media players
        log_volume = (new_volume / 100.0) ** 2.0
        media_manager.setVolume(log_volume)

        # Also apply to Spotify if connected
        if spotify_manager.is_connected():
            spotify_manager.set_volume(new_volume)

        # And phone mirror
        phone_mirror_manager.setVolume(log_volume)

        # Send volume update to ESP32 for LED display
        esp32_volume_manager.send_volume_update(new_volume)

def handle_esp32_mute_toggle():
    """Handle mute toggle from ESP32 button press."""
    media_manager.toggle_mute()
    # Send mute state to ESP32 for LED display
    esp32_volume_manager.send_mute_state(media_manager.is_muted())

esp32_volume_manager.volumeChangeRequested.connect(handle_esp32_volume_change)
esp32_volume_manager.muteToggleRequested.connect(handle_esp32_mute_toggle)

# Also send volume updates to ESP32 when volume changes from UI (not just encoder)
# This keeps the LED display in sync with the slider
def sync_volume_to_esp32(volume):
    """Send volume to ESP32 LEDs when changed from UI."""
    esp32_volume_manager.send_volume_update(volume)

settings_manager.currentVolumeChanged.connect(sync_volume_to_esp32)

# Sync theme color to ESP32 when album art colors change
import json

def hex_to_rgb(hex_color):
    """Convert hex color string to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return r, g, b

def send_current_led_color():
    """Send the appropriate color to ESP32 based on color mode setting."""
    color_mode = settings_manager.esp32LedColorMode

    if color_mode == "static":
        # Use static color from settings
        static_color = settings_manager.esp32LedStaticColor
        try:
            r, g, b = hex_to_rgb(static_color)
            esp32_volume_manager.send_theme_color(r, g, b)
            logger.info(f"ESP32 LED: sent static color RGB({r},{g},{b})")
        except (ValueError, IndexError):
            # Fallback to cyan if color is invalid
            esp32_volume_manager.send_theme_color(0, 255, 255)
            logger.info("ESP32 LED: sent fallback cyan (static color invalid)")
    else:
        # Use theme color from album art
        colors_json = settings_manager.albumArtColors
        logger.info(f"ESP32 LED: theme mode - albumArtColors length={len(colors_json) if colors_json else 0}")
        if colors_json:
            try:
                colors = json.loads(colors_json)
                accent_hex = colors.get("accent", "#00FFFF")
                r, g, b = hex_to_rgb(accent_hex)
                esp32_volume_manager.send_theme_color(r, g, b)
                logger.info(f"ESP32 LED: sent theme color RGB({r},{g},{b}) from {accent_hex}")
            except (json.JSONDecodeError, ValueError, KeyError) as e:
                # Fallback to cyan if no valid theme color
                esp32_volume_manager.send_theme_color(0, 255, 255)
                logger.info(f"ESP32 LED: sent fallback cyan (theme parse error: {e})")
        else:
            # No album art colors yet, use default cyan
            esp32_volume_manager.send_theme_color(0, 255, 255)
            logger.info("ESP32 LED: sent fallback cyan (no album art colors)")

def sync_theme_to_esp32(colors_json):
    """Send accent color to ESP32 LEDs when theme changes."""
    # Only update if in theme mode
    color_mode = settings_manager.esp32LedColorMode
    logger.info(f"ESP32 LED: sync_theme called, mode={color_mode}, colors_len={len(colors_json) if colors_json else 0}")
    if color_mode != "theme":
        logger.info("ESP32 LED: skipping theme sync (not in theme mode)")
        return
    if not colors_json:
        logger.info("ESP32 LED: skipping theme sync (no colors_json)")
        return
    try:
        colors = json.loads(colors_json)
        accent_hex = colors.get("accent", "#00FFFF")  # Default cyan
        r, g, b = hex_to_rgb(accent_hex)
        esp32_volume_manager.send_theme_color(r, g, b)
        logger.info(f"ESP32 LED: theme sync sent RGB({r},{g},{b}) from {accent_hex}")
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        logger.info(f"ESP32 LED: theme sync failed: {e}")

settings_manager.albumArtColorsChanged.connect(sync_theme_to_esp32)

# Handle static color change
def on_static_color_changed(color):
    """Send new static color to ESP32 when setting changes."""
    logger.info(f"ESP32 LED: static color changed to {color}, mode={settings_manager.esp32LedColorMode}")
    if settings_manager.esp32LedColorMode == "static":
        try:
            r, g, b = hex_to_rgb(color)
            esp32_volume_manager.send_theme_color(r, g, b)
            logger.info(f"ESP32 LED: sent static color RGB({r},{g},{b})")
        except (ValueError, IndexError) as e:
            logger.error(f"ESP32 LED: failed to parse static color: {e}")

settings_manager.esp32LedStaticColorChanged.connect(on_static_color_changed)

# Handle color mode change
def on_color_mode_changed(mode):
    """Update ESP32 LED color when mode changes."""
    logger.info(f"ESP32 LED: color mode changed to {mode}")
    send_current_led_color()

settings_manager.esp32LedColorModeChanged.connect(on_color_mode_changed)

# When ESP32 connects, send current volume and theme color
def on_esp32_connection_changed(status):
    """Send current state to ESP32 when it connects."""
    logger.info(f"ESP32 connection status changed: {status}")
    if status == "Connected":
        # Small delay to let the connection stabilize
        from PySide6.QtCore import QTimer
        def send_initial_state():
            volume = settings_manager.currentVolume
            muted = media_manager.is_muted()
            logger.info(f"ESP32 LED: sending initial state - volume={volume}, muted={muted}")
            # Send current volume
            esp32_volume_manager.send_volume_update(volume)
            # Send mute state
            esp32_volume_manager.send_mute_state(muted)
            # Send current LED color based on mode
            send_current_led_color()
        QTimer.singleShot(500, send_initial_state)

esp32_volume_manager.connectionStatusChanged.connect(on_esp32_connection_changed)

# Add the cleanup connection after creating managers:
def cleanup_on_quit():
    """Save state and cleanup before app exits"""
    media_manager._save_playback_state()
    media_manager._clear_temp_files()
    spotify_manager.cleanup()
    android_auto_manager.cleanup()  # Full cleanup: stops DHU, ADB, and head unit server
    phone_mirror_manager.cleanup()  # Stop phone mirror if running
    esp32_volume_manager.cleanup()  # Disconnect ESP32 volume controller

app.aboutToQuit.connect(cleanup_on_quit)

# Update the path to Main.qml
qml_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend", "Main.qml")
engine.load(QUrl.fromLocalFile(qml_file))

if not engine.rootObjects():
    sys.exit(-1)

sys.exit(app.exec())