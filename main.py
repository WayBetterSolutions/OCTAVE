import sys
import os
import platform
from datetime import datetime

# On Android, main.py may run from a temp dir — ensure the app directory is in sys.path
for _candidate in [
    os.environ.get('ANDROID_PRIVATE', ''),
    os.environ.get('ANDROID_APP_PATH', ''),
    '/data/user/0/org.octave.octave/files/app',
    '/data/data/org.octave.octave/files/app',
]:
    if _candidate and os.path.isdir(os.path.join(_candidate, 'backend')):
        if _candidate not in sys.path:
            sys.path.insert(0, _candidate)
        _sp = os.path.join(_candidate, '_python_bundle', 'site-packages')
        if os.path.isdir(_sp) and _sp not in sys.path:
            sys.path.insert(0, _sp)
        os.chdir(_candidate)
        break

from backend.platform_config import IS_ANDROID

# Force Qt Quick Controls to use Basic style (allows Slider customization)
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

# Android: force landscape fullscreen
if IS_ANDROID:
    os.environ["QT_ANDROID_SCREEN_ORIENTATION"] = "landscape"

# Parse command line arguments (not available on Android)
if IS_ANDROID:
    class _Args:
        debug = False
        profile = False
    args = _Args()
else:
    import argparse
    parser = argparse.ArgumentParser(description='OCTAVE Infotainment System')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    parser.add_argument('--profile', action='store_true', help='Enable performance monitor')
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

# backend imports — universal
from backend.clock import Clock
from backend.settings_manager import SettingsManager
from backend.media_manager import MediaManager
from backend.spotify_manager import SpotifyManager
from backend.audio_analyzer import AudioAnalyzer
from backend.network_manager import NetworkManager
from backend.download_manager import DownloadManager

# backend imports — platform-conditional (stubs on Android)
if IS_ANDROID:
    from backend.stubs import (
        StubOBDManager,
        StubBerryIMUManager,
        StubGestureManager as GestureManager,
        StubESP32VolumeManager as ESP32VolumeManager,
        StubPhoneMirrorManager as PhoneMirrorManager,
        StubAndroidAutoManager as AndroidAutoManager,
        StubScrcpyCapture as ScrcpyCapture,
        StubEmbeddedDhuItem as EmbeddedDhuItem,
        StubEmbeddedScrcpyItem as EmbeddedScrcpyItem,
        StubScrcpyCaptureItem as ScrcpyCaptureItem,
    )
    # Use Android Bluetooth OBD instead of stub
    try:
        from backend.android_obd_manager import AndroidOBDManager as OBDManager
        logger.info("Using Android Bluetooth OBD manager")
    except Exception:
        OBDManager = StubOBDManager
        logger.info("Android OBD unavailable, using stub")
    # Use Android device sensors instead of BerryIMU stub
    try:
        from backend.android_sensors import AndroidSensorManager as BerryIMUManager
        logger.info("Using Android device sensors for IMU")
    except Exception:
        BerryIMUManager = StubBerryIMUManager
        logger.info("Android sensors unavailable, using stub")
else:
    from backend.obd_manager import OBDManager
    from backend.android_auto import AndroidAutoManager, EmbeddedDhuItem
    from backend.phone_mirror import PhoneMirrorManager, EmbeddedScrcpyItem, ScrcpyCapture, ScrcpyCaptureItem
    from backend.esp32_volume_manager import ESP32VolumeManager
    from backend.berryimu_manager import BerryIMUManager
    from backend.gesture_manager import GestureManager

app = QApplication(sys.argv)

# Auto-detect screen size and calculate scale factor
screen = app.primaryScreen()
if screen:
    available = screen.availableSize()
    auto_scale = available.height() / 720.0
    auto_scale = max(0.4, min(3.0, auto_scale))  # Clamp to [0.4, 3.0]
    logger.info(f"Screen auto-detection: {available.width()}x{available.height()}, autoScale={auto_scale:.2f}")
else:
    auto_scale = 1.0
    logger.warning("No primary screen detected, using autoScale=1.0")

engine = QQmlApplicationEngine()

# Expose auto-scale to QML
engine.rootContext().setContextProperty("screenAutoScale", auto_scale)

# Register custom QML types
qmlRegisterType(EmbeddedDhuItem, "OCTAVE.AndroidAuto", 1, 0, "EmbeddedDhuItem")
qmlRegisterType(EmbeddedScrcpyItem, "OCTAVE.PhoneMirror", 1, 0, "EmbeddedScrcpyItem")
qmlRegisterType(ScrcpyCaptureItem, "OCTAVE.PhoneMirror", 1, 0, "ScrcpyCaptureItem")

engine.addImportPath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend"))

# Expose platform flag to QML
engine.rootContext().setContextProperty("isAndroid", IS_ANDROID)

# Settings Manager
settings_manager = SettingsManager()
engine.rootContext().setContextProperty("settingsManager", settings_manager)

# Hide hardware-only settings sections on Android (OBD works via Bluetooth)
if IS_ANDROID:
    settings_manager.save_settings_section_visibility("phoneDockSettings", False)
    settings_manager.save_settings_section_visibility("accessoriesSettings", False)

# Clock
clock = Clock(settings_manager)
engine.rootContext().setContextProperty("clock", clock)

# Media Manager
media_manager = MediaManager()
media_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("mediaManager", media_manager)

# Audio Analyzer for waveform visualization
audio_analyzer = AudioAnalyzer()
audio_analyzer.set_quality(settings_manager.visualizerQuality)
settings_manager.visualizerQualityChanged.connect(audio_analyzer.set_quality)
engine.rootContext().setContextProperty("audioAnalyzer", audio_analyzer)

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

# Phone mirror settings (desktop only)
if not IS_ANDROID:
    saved_scrcpy_path = settings_manager.get_scrcpy_path()
    if saved_scrcpy_path:
        phone_mirror_manager.setScrcpyPath(saved_scrcpy_path)
    phone_mirror_manager.setAudioEnabled(settings_manager.get_scrcpy_audio_enabled())
    initial_volume = settings_manager.currentVolume / 100.0
    phone_mirror_manager.setVolume(initial_volume ** 2.0)
    settings_manager.scrcpyAudioEnabledChanged.connect(
        lambda enabled: phone_mirror_manager.setAudioEnabled(enabled)
    )

# ESP32 Volume Manager - wireless rotary encoder volume control
esp32_volume_manager = ESP32VolumeManager()
esp32_volume_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("esp32VolumeManager", esp32_volume_manager)

# BerryIMU v3 Manager - live accelerometer/gyro/mag/baro for CarMenu
berryimu_manager = BerryIMUManager()
berryimu_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("berryIMU", berryimu_manager)

# Gesture Sensor Manager - PAJ7620U2 gesture recognition
gesture_manager = GestureManager()
gesture_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("gestureSensor", gesture_manager)

# Network Manager — WiFi status and update checking
network_manager = NetworkManager()
engine.rootContext().setContextProperty("networkManager", network_manager)

# Download Manager — music search and download via music_dl
download_manager = DownloadManager()
download_manager.connect_settings_manager(settings_manager)
engine.rootContext().setContextProperty("downloadManager", download_manager)

# Auto-rescan library when a download completes
download_manager.downloadComplete.connect(
    lambda name, path: media_manager.scan_library(reset_display_names=False)
)

# Hardware signal wiring (desktop only — gesture, ESP32, phone mirror)
if not IS_ANDROID:
    def handle_gesture_action(action):
        if action == "next_track":
            media_manager.next_track()
        elif action == "previous_track":
            media_manager.previous_track()
        elif action == "play_pause":
            media_manager.toggle_play()
        elif action == "mute_toggle":
            media_manager.toggle_mute()
        elif action == "volume_up":
            step = settings_manager.gestureVolumeStep
            current = settings_manager.currentVolume
            new_volume = min(100, current + step)
            settings_manager.setCurrentVolume(new_volume)
            log_volume = (new_volume / 100.0) ** 2.0
            media_manager.setVolume(log_volume)
            if spotify_manager.is_connected():
                spotify_manager.set_volume(new_volume)
            phone_mirror_manager.setVolume(log_volume)
            esp32_volume_manager.send_volume_update(new_volume)
        elif action == "volume_down":
            step = settings_manager.gestureVolumeStep
            current = settings_manager.currentVolume
            new_volume = max(0, current - step)
            settings_manager.setCurrentVolume(new_volume)
            log_volume = (new_volume / 100.0) ** 2.0
            media_manager.setVolume(log_volume)
            if spotify_manager.is_connected():
                spotify_manager.set_volume(new_volume)
            phone_mirror_manager.setVolume(log_volume)
            esp32_volume_manager.send_volume_update(new_volume)

    gesture_manager.actionTriggered.connect(handle_gesture_action)

    _volume_accumulator = 0.0

    def handle_esp32_volume_change(delta):
        global _volume_accumulator
        _volume_accumulator += delta
        if abs(_volume_accumulator) >= 1.0:
            change = int(_volume_accumulator)
            _volume_accumulator -= change
            current = settings_manager.currentVolume
            new_volume = max(0, min(100, current + change))
            settings_manager.setCurrentVolume(new_volume)
            log_volume = (new_volume / 100.0) ** 2.0
            media_manager.setVolume(log_volume)
            if spotify_manager.is_connected():
                spotify_manager.set_volume(new_volume)
            phone_mirror_manager.setVolume(log_volume)
            esp32_volume_manager.send_volume_update(new_volume)

    def handle_esp32_mute_toggle():
        media_manager.toggle_mute()
        esp32_volume_manager.send_mute_state(media_manager.is_muted())

    esp32_volume_manager.volumeChangeRequested.connect(handle_esp32_volume_change)
    esp32_volume_manager.muteToggleRequested.connect(handle_esp32_mute_toggle)

    def sync_volume_to_esp32(volume):
        esp32_volume_manager.send_volume_update(volume)

    settings_manager.currentVolumeChanged.connect(sync_volume_to_esp32)

    import json

    def hex_to_rgb(hex_color):
        hex_color = hex_color.lstrip('#')
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return r, g, b

    def send_current_led_color():
        color_mode = settings_manager.esp32LedColorMode
        if color_mode == "static":
            static_color = settings_manager.esp32LedStaticColor
            try:
                r, g, b = hex_to_rgb(static_color)
                esp32_volume_manager.send_theme_color(r, g, b)
            except (ValueError, IndexError):
                esp32_volume_manager.send_theme_color(0, 255, 255)
        else:
            colors_json = settings_manager.albumArtColors
            if colors_json:
                try:
                    colors = json.loads(colors_json)
                    accent_hex = colors.get("accent", "#00FFFF")
                    r, g, b = hex_to_rgb(accent_hex)
                    esp32_volume_manager.send_theme_color(r, g, b)
                except (json.JSONDecodeError, ValueError, KeyError):
                    esp32_volume_manager.send_theme_color(0, 255, 255)
            else:
                esp32_volume_manager.send_theme_color(0, 255, 255)

    def sync_theme_to_esp32(colors_json):
        if settings_manager.esp32LedColorMode != "theme" or not colors_json:
            return
        try:
            colors = json.loads(colors_json)
            accent_hex = colors.get("accent", "#00FFFF")
            r, g, b = hex_to_rgb(accent_hex)
            esp32_volume_manager.send_theme_color(r, g, b)
        except (json.JSONDecodeError, ValueError, KeyError):
            pass

    settings_manager.albumArtColorsChanged.connect(sync_theme_to_esp32)

    def on_static_color_changed(color):
        if settings_manager.esp32LedColorMode == "static":
            try:
                r, g, b = hex_to_rgb(color)
                esp32_volume_manager.send_theme_color(r, g, b)
            except (ValueError, IndexError):
                pass

    settings_manager.esp32LedStaticColorChanged.connect(on_static_color_changed)

    def on_color_mode_changed(mode):
        send_current_led_color()

    settings_manager.esp32LedColorModeChanged.connect(on_color_mode_changed)

    def on_esp32_connection_changed(status):
        if status == "Connected":
            from PySide6.QtCore import QTimer
            def send_initial_state():
                esp32_volume_manager.send_volume_update(settings_manager.currentVolume)
                esp32_volume_manager.send_mute_state(media_manager.is_muted())
                send_current_led_color()
            QTimer.singleShot(500, send_initial_state)

    esp32_volume_manager.connectionStatusChanged.connect(on_esp32_connection_changed)

# Add the cleanup connection after creating managers:
def cleanup_on_quit():
    """Save state and cleanup before app exits"""
    media_manager._save_playback_state_now()
    media_manager._clear_temp_files()
    spotify_manager.cleanup()
    android_auto_manager.cleanup()  # Full cleanup: stops DHU, ADB, and head unit server
    phone_mirror_manager.cleanup()  # Stop phone mirror if running
    esp32_volume_manager.cleanup()  # Disconnect ESP32 volume controller
    berryimu_manager.cleanup()  # Stop BerryIMU sensor reading
    gesture_manager.cleanup()  # Stop gesture sensor reading
    network_manager.cleanup()  # Stop network polling
    download_manager.cleanup()  # Clean up download engine

app.aboutToQuit.connect(cleanup_on_quit)

# Update the path to Main.qml
qml_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend", "Main.qml")
engine.load(QUrl.fromLocalFile(qml_file))

if not engine.rootObjects():
    sys.exit(-1)

# Performance monitor (--profile flag, desktop only)
perf_monitor = None
if not IS_ANDROID and args.profile:
    from backend.perf_monitor import PerfMonitor
    perf_stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    perf_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dev", "perf", "logs")
    os.makedirs(perf_dir, exist_ok=True)
    csv_path = os.path.join(perf_dir, f"perf_{perf_stamp}.csv")
    log_path = os.path.join(perf_dir, f"perf_{perf_stamp}.log")
    perf_monitor = PerfMonitor(csv_path=csv_path, log_path=log_path)
    engine.rootContext().setContextProperty("perfMonitor", perf_monitor)
    perf_monitor.start()

    # Command server for MCP/remote control
    from backend.command_server import CommandServer
    cmd_server = CommandServer()
    cmd_server.start(
        managers={
            "media": media_manager,
            "spotify": spotify_manager,
            "obd": obd_manager,
            "settings": settings_manager,
        },
        perf_monitor=perf_monitor,
        engine=engine,
    )

    def stop_cmd_server():
        cmd_server.stop()

    app.aboutToQuit.connect(stop_cmd_server)

    # Instrument hot paths
    from backend.perf_patches import apply_patches
    apply_patches(
        media_manager=media_manager,
        audio_analyzer=audio_analyzer,
        spotify_manager=spotify_manager,
        obd_manager=obd_manager,
        berryimu_manager=berryimu_manager,
        gesture_manager=gesture_manager,
        scrcpy_capture=scrcpy_capture,
        esp32_volume_manager=esp32_volume_manager,
        settings_manager=settings_manager,
    )

    def stop_perf_monitor():
        perf_monitor.stop()
        print(f"\n\033[1;36m[PERF]\033[0m  Log saved to {log_path}")
        print(f"\033[1;36m[PERF]\033[0m  CSV saved to {csv_path}")
        print(perf_monitor.getDetailedReport())

    app.aboutToQuit.connect(stop_perf_monitor)

sys.exit(app.exec())