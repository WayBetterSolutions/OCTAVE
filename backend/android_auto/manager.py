"""
Android Auto Manager

Main controller for Android Auto integration in OCTAVE.
Coordinates USB/TCP transport, message handling, SSL handshake,
video/audio streaming, and service channels.

Supports two connection modes:
1. USB Mode: Direct USB connection with AOAP handshake (requires certificates)
2. TCP Mode: Connect via phone's "head unit server" (developer mode, no certs needed)
"""

import logging
import threading
import subprocess
import os
import platform
import ctypes
from typing import Optional, Callable, Union
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtGui import QWindow

from .constants import ChannelId, ControlMessageType, AccessoryInfo
from .usb_transport import USBTransport, DeviceState
from .tcp_transport import TCPTransport, TCPState
from .message import Message, MessageAssembler, MessageRouter
from .ssl_handler import SSLHandler

logger = logging.getLogger(__name__)


class TransportMode(Enum):
    """Transport connection mode."""
    USB = "usb"      # Direct USB with AOAP (requires Google-signed certificate)
    TCP = "tcp"      # TCP via head unit server (DHU mode - no cert needed)


@dataclass
class HeadUnitInfo:
    """Head unit configuration."""
    make: str = "OCTAVE"
    model: str = "Head Unit"
    software_version: str = "1.0.0"

    # Display configuration
    display_width: int = 800
    display_height: int = 480
    display_density: int = 160

    # Video configuration
    video_width: int = 800
    video_height: int = 480
    video_fps: int = 30

    # Audio configuration
    audio_sample_rate: int = 48000
    audio_channels: int = 2
    audio_bits: int = 16


class AndroidAutoState:
    """Android Auto connection states."""
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    SSL_HANDSHAKE = "ssl_handshake"
    SERVICE_DISCOVERY = "service_discovery"
    CONNECTED = "connected"
    STREAMING = "streaming"
    ERROR = "error"


class AndroidAutoManager(QObject):
    """
    Main Android Auto manager for OCTAVE.

    This class coordinates all Android Auto functionality:
    - USB/TCP device detection and connection
    - AOAP handshake (USB mode)
    - SSL/TLS encryption
    - Service discovery and channel management
    - Video and audio streaming
    - Input forwarding
    - Sensor data integration

    Usage:
        # USB mode (default - requires certificate)
        manager = AndroidAutoManager()
        manager.start()

        # TCP mode (no certificate needed)
        manager = AndroidAutoManager()
        manager.startTcp()  # Requires: adb forward tcp:5277 tcp:5277
    """

    # Signals
    stateChanged = Signal(str)
    transportModeChanged = Signal(str)  # TransportMode value
    connectionProgress = Signal(str)  # Human-readable status
    videoFrameReady = Signal(object)  # Video frame data
    audioDataReady = Signal(bytes, int)  # Audio data, stream type
    navigationUpdate = Signal(object)  # Navigation data
    phoneStatusChanged = Signal(object)  # Phone status
    mediaStatusChanged = Signal(object)  # Media playback status
    error = Signal(str)
    dhuWindowReady = Signal(int)  # Emits window handle when DHU window is found
    dhuEmbeddedChanged = Signal(bool)  # Emits when DHU embedding state changes

    def __init__(self, head_unit_info: Optional[HeadUnitInfo] = None, parent=None):
        super().__init__(parent)

        self._head_unit_info = head_unit_info or HeadUnitInfo()
        self._state = AndroidAutoState.DISCONNECTED
        self._running = False
        self._transport_mode = TransportMode.USB

        # Transport layers (create both, use one at a time)
        self._usb_transport = USBTransport(self)
        self._tcp_transport = TCPTransport(parent=self)
        self._active_transport: Union[USBTransport, TCPTransport, None] = None

        # Message handling
        self._message_assembler = MessageAssembler()
        self._message_router = MessageRouter()

        # SSL handler for encrypted communication
        self._ssl_handler = SSLHandler()
        self._ssl_established = False

        # Service states
        self._services_discovered = False
        self._video_channel_open = False
        self._audio_channels_open = {}

        # Connect USB transport signals
        self._usb_transport.stateChanged.connect(self._on_usb_state_changed)
        self._usb_transport.deviceConnected.connect(self._on_device_connected)
        self._usb_transport.deviceDisconnected.connect(self._on_device_disconnected)
        self._usb_transport.dataReceived.connect(self._on_data_received)
        self._usb_transport.error.connect(self._on_transport_error)

        # Connect TCP transport signals
        self._tcp_transport.stateChanged.connect(self._on_tcp_state_changed)
        self._tcp_transport.deviceConnected.connect(self._on_device_connected)
        self._tcp_transport.deviceDisconnected.connect(self._on_device_disconnected)
        self._tcp_transport.dataReceived.connect(self._on_data_received)
        self._tcp_transport.error.connect(self._on_transport_error)

        # Register channel handlers
        self._setup_channel_handlers()

        # DHU window embedding/capture
        self._dhu_process: Optional[subprocess.Popen] = None
        self._dhu_hwnd: int = 0  # Windows handle to DHU window
        self._dhu_embedded = False

        # DHU capture for seamless integration
        from .dhu_capture import DhuCapture
        self._dhu_capture = DhuCapture(self)
        self._dhu_capture.frameReady.connect(self._on_dhu_frame_ready)
        self._dhu_capture.error.connect(self._on_dhu_capture_error)

    def _setup_channel_handlers(self):
        """Set up message handlers for each channel."""
        self._message_router.register_handler(ChannelId.CONTROL, self._handle_control_message)
        self._message_router.register_handler(ChannelId.VIDEO, self._handle_video_data)
        self._message_router.register_handler(ChannelId.MEDIA_AUDIO, self._handle_audio_data)
        self._message_router.register_handler(ChannelId.SPEECH_AUDIO, self._handle_audio_data)
        self._message_router.register_handler(ChannelId.SYSTEM_AUDIO, self._handle_audio_data)
        self._message_router.register_handler(ChannelId.NAVIGATION, self._handle_navigation_data)
        self._message_router.register_handler(ChannelId.PHONE_STATUS, self._handle_phone_status)
        self._message_router.register_handler(ChannelId.MEDIA_STATUS, self._handle_media_status)
        self._message_router.register_handler(ChannelId.INPUT, self._handle_input_feedback)

    # Properties for QML binding
    @Property(str, notify=stateChanged)
    def state(self) -> str:
        return self._state

    @Property(bool, notify=stateChanged)
    def isConnected(self) -> bool:
        return self._state in (AndroidAutoState.CONNECTED, AndroidAutoState.STREAMING)

    @Property(bool, notify=stateChanged)
    def isStreaming(self) -> bool:
        return self._state == AndroidAutoState.STREAMING

    @Property(str, notify=transportModeChanged)
    def transportMode(self) -> str:
        return self._transport_mode.value

    # Public methods
    @Slot()
    def start(self):
        """Start Android Auto service in USB mode (default)."""
        self.startUsb()

    @Slot()
    def startUsb(self):
        """Start Android Auto service in USB mode."""
        if self._running:
            self.stop()

        logger.info("Starting Android Auto manager (USB mode)")
        print("[AA Manager] Starting in USB mode")
        self._running = True
        self._transport_mode = TransportMode.USB
        self._active_transport = self._usb_transport
        self.transportModeChanged.emit(self._transport_mode.value)
        self._set_state(AndroidAutoState.DISCONNECTED)
        self._usb_transport.start()
        self.connectionProgress.emit("Waiting for Android device (USB)...")

    @Slot()
    def startTcp(self, host: str = "127.0.0.1", port: int = 5277):
        """
        Start Android Auto service in TCP mode (DHU mode).

        This connects via the phone's "head unit server" mode.

        Prerequisites:
        1. Enable Android Auto developer mode on phone (tap version 10x)
        2. Select "Start head unit server" on phone
        3. Run: adb forward tcp:5277 tcp:5277
        4. Call this method
        """
        if self._running:
            self.stop()

        logger.info(f"Starting Android Auto manager (TCP mode: {host}:{port})")
        print(f"[AA Manager] Starting in TCP mode ({host}:{port})")
        self._running = True
        self._transport_mode = TransportMode.TCP
        self._active_transport = self._tcp_transport
        self._tcp_transport.set_host_port(host, port)
        self.transportModeChanged.emit(self._transport_mode.value)
        self._set_state(AndroidAutoState.DISCONNECTED)
        self._tcp_transport.start()
        self.connectionProgress.emit(f"Connecting to phone (TCP {host}:{port})...")

    @Slot()
    def stop(self):
        """Stop Android Auto service."""
        if not self._running:
            return

        logger.info("Stopping Android Auto manager")
        self._running = False

        # Stop the active transport
        if self._transport_mode == TransportMode.USB:
            self._usb_transport.stop()
        else:
            self._tcp_transport.stop()

        self._active_transport = None
        self._set_state(AndroidAutoState.DISCONNECTED)

    @Slot()
    def cleanup(self):
        """
        Full cleanup when OCTAVE is closing.
        Stops DHU, cleans up ADB connections, and stops head unit server on phone.
        """
        print("[AA Manager] Cleaning up Android Auto...")

        # Close any running DHU
        self.closeDhu()

        # Stop the manager
        self.stop()

        # Stop head unit server and clean up ADB
        adb_path = self._find_adb_path()
        if adb_path:
            # Remove port forwards
            subprocess.run(
                [str(adb_path), "forward", "--remove-all"],
                capture_output=True,
                text=True,
                timeout=10
            )
            # Stop head unit server on phone
            self._stop_headunit_server(adb_path)
            print("[AA Manager] Cleanup complete")

    @Slot(int, int)
    def sendTouchEvent(self, x: int, y: int):
        """Send touch event to the phone."""
        if not self.isConnected:
            return

        # TODO: Implement touch input forwarding
        logger.debug(f"Touch event: ({x}, {y})")

    @Slot(int, bool)
    def sendKeyEvent(self, key_code: int, pressed: bool):
        """Send key event to the phone."""
        if not self.isConnected:
            return

        # TODO: Implement key input forwarding
        logger.debug(f"Key event: {key_code}, pressed={pressed}")

    @Slot()
    def requestVideoFocus(self):
        """Request video focus from the phone."""
        if not self.isConnected:
            return

        # TODO: Implement video focus request
        logger.debug("Requesting video focus")

    @Slot()
    def releaseVideoFocus(self):
        """Release video focus."""
        if not self.isConnected:
            return

        # TODO: Implement video focus release
        logger.debug("Releasing video focus")

    # Google DHU methods
    @Property(bool, constant=True)
    def isDhuInstalled(self) -> bool:
        """Check if Google's Desktop Head Unit is installed."""
        return self._find_dhu_path() is not None

    @Property(str, constant=True)
    def dhuPath(self) -> str:
        """Get the path to Google's Desktop Head Unit."""
        path = self._find_dhu_path()
        return str(path) if path else ""

    def _find_dhu_path(self) -> Optional[Path]:
        """Find the Google DHU executable path."""
        system = platform.system()

        # Common SDK locations
        if system == "Windows":
            sdk_locations = [
                Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk",
                Path(os.environ.get("USERPROFILE", "")) / "AppData" / "Local" / "Android" / "Sdk",
                Path("C:/Android/Sdk"),
                Path("C:/Users") / os.environ.get("USERNAME", "") / "Android" / "Sdk",
            ]
            dhu_name = "desktop-head-unit.exe"
        else:
            sdk_locations = [
                Path.home() / "Android" / "Sdk",
                Path.home() / "Library" / "Android" / "sdk",
                Path("/opt/android-sdk"),
                Path("/usr/local/android-sdk"),
            ]
            dhu_name = "desktop-head-unit"

        # Check each SDK location
        for sdk_path in sdk_locations:
            dhu_path = sdk_path / "extras" / "google" / "auto" / dhu_name
            if dhu_path.exists():
                return dhu_path

        return None

    def _find_adb_path(self) -> Optional[Path]:
        """Find ADB executable path."""
        system = platform.system()

        # Check common locations
        if system == "Windows":
            adb_name = "adb.exe"
            search_paths = [
                # Downloaded platform-tools
                Path(os.environ.get("USERPROFILE", "")) / "Downloads" / "platform-tools" / adb_name,
                # Android SDK
                Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / adb_name,
                Path(os.environ.get("USERPROFILE", "")) / "AppData" / "Local" / "Android" / "Sdk" / "platform-tools" / adb_name,
            ]
        else:
            adb_name = "adb"
            search_paths = [
                Path.home() / "Android" / "Sdk" / "platform-tools" / adb_name,
                Path.home() / "Library" / "Android" / "sdk" / "platform-tools" / adb_name,
                Path("/usr/bin") / adb_name,
                Path("/usr/local/bin") / adb_name,
            ]

        for path in search_paths:
            if path.exists():
                return path

        return None

    def _is_headunit_server_running(self, adb_path) -> bool:
        """Check if the head unit server is already running on the phone."""
        try:
            result = subprocess.run(
                [str(adb_path), "shell", "dumpsys", "activity", "services",
                 "com.google.android.projection.gearhead/.companion.DeveloperHeadUnitNetworkService"],
                capture_output=True,
                text=True,
                timeout=5
            )
            # If the service is running, it will show up in the output
            return "ServiceRecord" in result.stdout
        except Exception:
            return False

    def _start_headunit_server(self, adb_path) -> bool:
        """Start the head unit server on the phone via ADB."""
        import time

        try:
            print("[AA Manager] Starting head unit server on phone...")
            self.connectionProgress.emit("Starting head unit server on phone...")

            # Method 1: Try starting via activity (opens Android Auto and triggers server)
            result = subprocess.run(
                [str(adb_path), "shell", "am", "start",
                 "-n", "com.google.android.projection.gearhead/.companion.MainActivity",
                 "-a", "com.google.android.gms.car.action.START_HEAD_UNIT_SERVER"],
                capture_output=True,
                text=True,
                timeout=10
            )

            # Give it a moment to initialize
            time.sleep(2)

            # Check if it worked
            if self._is_headunit_server_running(adb_path):
                print("[AA Manager] Head unit server started successfully")
                return True

            # Method 2: Try direct service start (works on some Android versions)
            result = subprocess.run(
                [str(adb_path), "shell", "am", "startservice",
                 "-n", "com.google.android.projection.gearhead/.companion.DeveloperHeadUnitNetworkService"],
                capture_output=True,
                text=True,
                timeout=10
            )

            time.sleep(1)

            if self._is_headunit_server_running(adb_path):
                print("[AA Manager] Head unit server started successfully")
                return True

            print("[AA Manager] Could not auto-start head unit server")
            return False

        except Exception as e:
            print(f"[AA Manager] Error starting head unit server: {e}")
            return False

    def _stop_headunit_server(self, adb_path) -> bool:
        """Stop the head unit server on the phone."""
        try:
            print("[AA Manager] Stopping head unit server on phone...")
            result = subprocess.run(
                [str(adb_path), "shell", "am", "force-stop", "com.google.android.projection.gearhead"],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0
        except Exception as e:
            print(f"[AA Manager] Error stopping head unit server: {e}")
            return False

    def _has_stale_connections(self, adb_path) -> bool:
        """Check if there are stale CLOSE_WAIT connections on port 5277."""
        try:
            result = subprocess.run(
                [str(adb_path), "shell", "netstat -tn 2>/dev/null | grep 5277 | grep -c CLOSE_WAIT || echo 0"],
                capture_output=True,
                text=True,
                timeout=5
            )
            count = int(result.stdout.strip() or "0")
            if count > 3:  # More than a few stale connections
                print(f"[AA Manager] Found {count} stale CLOSE_WAIT connections")
                return True
            return False
        except Exception:
            return False  # If we can't check, assume no stale connections

    def _cleanup_adb_connections(self, force_restart: bool = False) -> bool:
        """
        Clean up stale ADB connections.
        Only force-stops Android Auto if there are many stale CLOSE_WAIT sockets
        or if force_restart is True.
        """
        adb_path = self._find_adb_path()
        if not adb_path:
            return False

        try:
            print("[AA Manager] Cleaning up ADB connections...")
            self.connectionProgress.emit("Preparing connection...")

            # Remove all existing port forwards
            subprocess.run(
                [str(adb_path), "forward", "--remove-all"],
                capture_output=True,
                text=True,
                timeout=10
            )
            print("[AA Manager] Removed existing port forwards")

            # Only force-stop if we detect stale connections or explicitly requested
            needs_restart = force_restart or self._has_stale_connections(adb_path)

            if needs_restart:
                print("[AA Manager] Stale connections detected, restarting Android Auto on phone...")
                self.connectionProgress.emit("Clearing stale connections...")
                self._stop_headunit_server(adb_path)

                # Brief pause to let sockets clean up
                import time
                time.sleep(1)

                # Restart the head unit server
                self._start_headunit_server(adb_path)

            return True

        except subprocess.TimeoutExpired:
            print("[AA Manager] ADB cleanup timed out")
            return False
        except Exception as e:
            print(f"[AA Manager] ADB cleanup error: {e}")
            return False

    def _setup_adb_forward(self) -> bool:
        """Setup ADB port forwarding for DHU."""
        adb_path = self._find_adb_path()

        if not adb_path:
            print("[AA Manager] ADB not found")
            return False

        try:
            print(f"[AA Manager] Running ADB forward: {adb_path}")
            result = subprocess.run(
                [str(adb_path), "forward", "tcp:5277", "tcp:5277"],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0:
                print(f"[AA Manager] ADB forward successful: {result.stdout.strip()}")
                return True
            else:
                print(f"[AA Manager] ADB forward failed: {result.stderr.strip()}")
                return False

        except subprocess.TimeoutExpired:
            print("[AA Manager] ADB forward timed out")
            return False
        except Exception as e:
            print(f"[AA Manager] ADB forward error: {e}")
            return False

    def _prepare_adb_connection(self) -> bool:
        """
        Full ADB preparation: cleanup stale connections, setup forwarding, and start head unit server.
        Returns True if successful.
        """
        adb_path = self._find_adb_path()
        if not adb_path:
            print("[AA Manager] ADB not found - cannot prepare connection")
            self.error.emit("ADB not found. Install Android SDK platform-tools.")
            return False

        # Check if phone is connected
        try:
            result = subprocess.run(
                [str(adb_path), "devices"],
                capture_output=True,
                text=True,
                timeout=10
            )
            lines = result.stdout.strip().split('\n')
            devices = [l for l in lines[1:] if l.strip() and 'device' in l]
            if not devices:
                print("[AA Manager] No Android device connected")
                self.error.emit("No Android device connected. Connect your phone via USB.")
                return False
            print(f"[AA Manager] Found {len(devices)} connected device(s)")
        except Exception as e:
            print(f"[AA Manager] Failed to check devices: {e}")
            return False

        # Clean up any stale connections (will auto-restart server if needed)
        self._cleanup_adb_connections()

        # Setup fresh port forwarding
        self.connectionProgress.emit("Setting up ADB port forwarding...")
        if not self._setup_adb_forward():
            self.error.emit("Failed to setup ADB port forwarding")
            return False

        # Check if head unit server is running
        if not self._is_headunit_server_running(adb_path):
            # Try to start it (may fail due to permissions)
            if not self._start_headunit_server(adb_path):
                # Can't auto-start, prompt user and wait
                print("[AA Manager] Please start 'Head unit server' manually on your phone")
                self.connectionProgress.emit("Please start 'Head unit server' in Android Auto developer settings...")

                # Wait for user to start the server (poll for up to 60 seconds)
                import time
                for i in range(60):
                    if self._is_headunit_server_running(adb_path):
                        print("[AA Manager] Head unit server detected!")
                        self.connectionProgress.emit("Head unit server started!")
                        time.sleep(0.5)  # Brief pause to let it fully initialize
                        break
                    time.sleep(1)
                    # Update message every 5 seconds
                    if i > 0 and i % 5 == 0:
                        remaining = 60 - i
                        self.connectionProgress.emit(f"Waiting for head unit server... ({remaining}s)")
                else:
                    # Timed out
                    print("[AA Manager] Timed out waiting for head unit server")
                    self.error.emit("Head unit server not started. Please start it and try again.")
                    return False
        else:
            print("[AA Manager] Head unit server already running")

        return True

    @Slot(result=bool)
    def launchGoogleDhu(self) -> bool:
        """
        Launch Google's official Desktop Head Unit in external window.
        Automatically handles ADB cleanup and port forwarding.

        Returns True if successfully launched, False otherwise.
        """
        dhu_path = self._find_dhu_path()

        if not dhu_path:
            print("[AA Manager] Google DHU not found. Install via Android Studio SDK Manager.")
            self.error.emit("Google DHU not installed. Install 'Android Auto Desktop Head Unit Emulator' via Android Studio SDK Manager.")
            return False

        try:
            # Full ADB preparation: cleanup stale connections and setup fresh forwarding
            if not self._prepare_adb_connection():
                # Error already emitted by _prepare_adb_connection
                return False

            print(f"[AA Manager] Launching Google DHU: {dhu_path}")
            self.connectionProgress.emit("Launching Google Desktop Head Unit...")

            # Launch DHU as separate process
            if platform.system() == "Windows":
                subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent),
                    creationflags=subprocess.CREATE_NEW_CONSOLE
                )
            else:
                subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent),
                    start_new_session=True
                )

            self.connectionProgress.emit("Google DHU launched. Start 'Head unit server' on your phone.")
            return True

        except Exception as e:
            print(f"[AA Manager] Failed to launch Google DHU: {e}")
            self.error.emit(f"Failed to launch Google DHU: {e}")
            return False

    @Slot(result=str)
    def getDhuInstallInstructions(self) -> str:
        """Get instructions for installing Google DHU."""
        return """To install Google's Desktop Head Unit:

1. Open Android Studio
2. Go to Tools → SDK Manager
3. Select the "SDK Tools" tab
4. Check "Android Auto Desktop Head Unit Emulator"
5. Click "Apply" to install

After installation, click "Launch Google DHU" button."""

    # DHU Window Embedding
    @Property(bool, notify=dhuEmbeddedChanged)
    def isDhuEmbedded(self) -> bool:
        """Check if DHU window is currently embedded."""
        return self._dhu_embedded

    @Property(int, notify=dhuWindowReady)
    def dhuWindowHandle(self) -> int:
        """Get the DHU window handle."""
        return self._dhu_hwnd

    def _find_dhu_window(self) -> int:
        """Find the DHU window handle using Windows API."""
        if platform.system() != "Windows":
            return 0

        try:
            # Windows API functions
            user32 = ctypes.windll.user32
            EnumWindows = user32.EnumWindows
            GetWindowTextW = user32.GetWindowTextW
            GetWindowTextLengthW = user32.GetWindowTextLengthW
            IsWindowVisible = user32.IsWindowVisible

            WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int))

            found_hwnd = [0]

            def enum_callback(hwnd, lParam):
                # Convert hwnd pointer to int for API calls
                hwnd_int = ctypes.cast(hwnd, ctypes.c_void_p).value or 0
                if IsWindowVisible(hwnd_int):
                    length = GetWindowTextLengthW(hwnd_int)
                    if length > 0:
                        buffer = ctypes.create_unicode_buffer(length + 1)
                        GetWindowTextW(hwnd_int, buffer, length + 1)
                        title = buffer.value
                        # DHU window title contains "Desktop Head Unit" or similar
                        if "Desktop Head Unit" in title or "Android Auto" in title:
                            found_hwnd[0] = hwnd_int
                            print(f"[AA Manager] Found DHU window: '{title}' (hwnd={hwnd_int})")
                            return False  # Stop enumeration
                return True  # Continue enumeration

            EnumWindows(WNDENUMPROC(enum_callback), 0)
            return found_hwnd[0]

        except Exception as e:
            print(f"[AA Manager] Error finding DHU window: {e}")
            return 0

    @Slot(result=bool)
    def launchGoogleDhuEmbedded(self) -> bool:
        """
        Launch Google's DHU and prepare for embedding.
        Returns True if successfully launched.
        """
        # Close any existing DHU first
        if self._dhu_process or self._dhu_embedded:
            self.closeDhu()

        dhu_path = self._find_dhu_path()

        if not dhu_path:
            print("[AA Manager] Google DHU not found.")
            self.error.emit("Google DHU not installed.")
            return False

        try:
            # Setup ADB forwarding first
            self.connectionProgress.emit("Setting up ADB port forwarding...")
            adb_success = self._setup_adb_forward()
            if not adb_success:
                self.connectionProgress.emit("ADB forward failed - make sure phone is connected via USB")

            print(f"[AA Manager] Launching Google DHU for embedding: {dhu_path}")
            self.connectionProgress.emit("Launching Google Desktop Head Unit...")

            # Launch DHU as subprocess (not in new console, so we can track it)
            if platform.system() == "Windows":
                # Don't create new console - we want to embed the window
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = 1  # SW_SHOWNORMAL

                self._dhu_process = subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent),
                    startupinfo=startupinfo
                )
            else:
                self._dhu_process = subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent)
                )

            # Start a timer to find the window after DHU starts
            QTimer.singleShot(2000, self._try_find_dhu_window)

            self.connectionProgress.emit("Waiting for DHU window...")
            return True

        except Exception as e:
            print(f"[AA Manager] Failed to launch Google DHU: {e}")
            self.error.emit(f"Failed to launch Google DHU: {e}")
            return False

    @Slot()
    def _try_find_dhu_window(self):
        """Try to find the DHU window after launch."""
        hwnd = self._find_dhu_window()
        if hwnd:
            self._dhu_hwnd = hwnd
            print(f"[AA Manager] DHU window found: {hwnd}")
            self.dhuWindowReady.emit(hwnd)
            self.connectionProgress.emit("DHU window ready for embedding")
        else:
            # Retry a few times
            if self._dhu_process and self._dhu_process.poll() is None:
                print("[AA Manager] DHU window not found yet, retrying...")
                QTimer.singleShot(1000, self._try_find_dhu_window)
            else:
                print("[AA Manager] DHU process ended before window was found")
                self.error.emit("DHU closed before window could be found")

    @Slot(result=bool)
    def launchDhuSeamless(self) -> bool:
        """
        Launch DHU and capture its output seamlessly into OCTAVE.
        The DHU window is hidden and its content is captured and displayed in QML.
        Automatically handles ADB cleanup and connection setup.
        """
        # Close any existing DHU first
        if self._dhu_process or self._dhu_embedded:
            self.closeDhu()

        dhu_path = self._find_dhu_path()

        if not dhu_path:
            print("[AA Manager] Google DHU not found.")
            self.error.emit("Google DHU not installed.")
            return False

        try:
            # Full ADB preparation: cleanup stale connections and setup fresh forwarding
            if not self._prepare_adb_connection():
                # Error already emitted by _prepare_adb_connection
                return False

            # Prompt user to start head unit server
            self.connectionProgress.emit("Please start 'Head unit server' on your phone...")

            print(f"[AA Manager] Launching DHU for seamless capture: {dhu_path}")

            # Launch DHU
            if platform.system() == "Windows":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = 1  # SW_SHOWNORMAL initially

                self._dhu_process = subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent),
                    startupinfo=startupinfo
                )
            else:
                self._dhu_process = subprocess.Popen(
                    [str(dhu_path)],
                    cwd=str(dhu_path.parent)
                )

            # Start timer to find window and begin capture
            QTimer.singleShot(2000, self._setup_seamless_capture)

            self.connectionProgress.emit("Starting Android Auto...")
            return True

        except Exception as e:
            print(f"[AA Manager] Failed to launch DHU: {e}")
            self.error.emit(f"Failed to launch DHU: {e}")
            return False

    @Slot()
    def _setup_seamless_capture(self):
        """Find DHU window and start seamless capture."""
        hwnd = self._find_dhu_window()
        if hwnd:
            self._dhu_hwnd = hwnd
            print(f"[AA Manager] DHU window found for capture: {hwnd}")

            # Hide the DHU window (move off-screen or minimize)
            if platform.system() == "Windows":
                SW_HIDE = 0
                # Don't fully hide - just move off screen so capture still works
                user32 = ctypes.windll.user32
                # Move window off-screen but keep it "visible" for capture
                user32.SetWindowPos(hwnd, 0, -2000, -2000, 0, 0, 0x0001 | 0x0004)  # SWP_NOSIZE | SWP_NOZORDER

            # Start capturing
            self._dhu_capture.setWindowHandle(hwnd)
            self._dhu_capture.startCapture()

            self._dhu_embedded = True
            self.dhuEmbeddedChanged.emit(True)
            self.dhuWindowReady.emit(hwnd)
            self.connectionProgress.emit("Android Auto running")

        else:
            # Retry
            if self._dhu_process and self._dhu_process.poll() is None:
                print("[AA Manager] DHU window not found yet, retrying...")
                QTimer.singleShot(1000, self._setup_seamless_capture)
            else:
                print("[AA Manager] DHU process ended")
                self.error.emit("DHU closed unexpectedly")

    @Slot()
    def _on_dhu_frame_ready(self):
        """Called when a new DHU frame is captured."""
        # This signal can be used by QML to refresh the image
        pass

    @Slot(str)
    def _on_dhu_capture_error(self, error_msg: str):
        """Handle capture errors."""
        print(f"[AA Manager] Capture error: {error_msg}")
        self.error.emit(error_msg)

    @Property(QObject, constant=True)
    def dhuCapture(self):
        """Get the DHU capture object for QML."""
        return self._dhu_capture

    @Slot(int, int)
    def sendDhuClick(self, x: int, y: int):
        """Send a click to the DHU at the given coordinates."""
        self._dhu_capture.sendMouseClick(x, y)

    @Slot()
    def closeDhu(self):
        """Close the embedded DHU."""
        # Stop capture first
        self._dhu_capture.stopCapture()

        if self._dhu_process:
            try:
                self._dhu_process.terminate()
                self._dhu_process.wait(timeout=5)
            except Exception as e:
                print(f"[AA Manager] Error closing DHU: {e}")
                try:
                    self._dhu_process.kill()
                except:
                    pass
            self._dhu_process = None

        self._dhu_hwnd = 0
        self._dhu_embedded = False
        self.dhuEmbeddedChanged.emit(False)

    # Private methods
    def _set_state(self, state: str):
        """Update state and emit signal."""
        if self._state != state:
            self._state = state
            self.stateChanged.emit(state)
            logger.info(f"Android Auto state: {state}")

    @Slot(str)
    def _on_usb_state_changed(self, state: str):
        """Handle USB transport state changes."""
        if self._transport_mode != TransportMode.USB:
            return  # Ignore if not using USB transport

        if state == DeviceState.DISCONNECTED.value:
            self._set_state(AndroidAutoState.DISCONNECTED)
            self.connectionProgress.emit("Waiting for Android device (USB)...")
        elif state == DeviceState.DETECTED.value:
            self._set_state(AndroidAutoState.CONNECTING)
            self.connectionProgress.emit("Android device detected...")
        elif state == DeviceState.AOAP_HANDSHAKE.value:
            self.connectionProgress.emit("Switching to Android Auto mode...")
        elif state == DeviceState.AOAP_MODE.value:
            self.connectionProgress.emit("Setting up connection...")

    @Slot(str)
    def _on_tcp_state_changed(self, state: str):
        """Handle TCP transport state changes."""
        if self._transport_mode != TransportMode.TCP:
            return  # Ignore if not using TCP transport

        if state == TCPState.DISCONNECTED.value:
            self._set_state(AndroidAutoState.DISCONNECTED)
            self.connectionProgress.emit("Disconnected from phone (TCP)")
        elif state == TCPState.CONNECTING.value:
            self._set_state(AndroidAutoState.CONNECTING)
            self.connectionProgress.emit("Connecting to phone (TCP)...")
        elif state == TCPState.CONNECTED.value:
            self.connectionProgress.emit("TCP connected, starting handshake...")

    @Slot(object)
    def _on_device_connected(self, device):
        """Handle device connection."""
        logger.info(f"Device connected: {device}")
        print(f"[AA Manager] Device connected, starting protocol handshake...")
        self._set_state(AndroidAutoState.SSL_HANDSHAKE)
        self.connectionProgress.emit("Establishing secure connection...")

        # Start SSL handshake
        self._initiate_ssl_handshake()

    @Slot()
    def _on_device_disconnected(self):
        """Handle device disconnection."""
        logger.info("Device disconnected")
        self._ssl_established = False
        self._services_discovered = False
        self._video_channel_open = False
        self._audio_channels_open.clear()
        self._set_state(AndroidAutoState.DISCONNECTED)
        self.connectionProgress.emit("Device disconnected")

    @Slot(bytes)
    def _on_data_received(self, data: bytes):
        """Handle incoming USB data."""
        print(f"[AA Manager] Received {len(data)} bytes: {data.hex()}")

        # Try to detect version response directly using correct frame format:
        # Byte 0: Channel ID (0 for control)
        # Byte 1: Flags (0x03 = BULK frame)
        # Bytes 2-3: Frame size (big-endian)
        # Bytes 4-5: Message ID (0x0002 = VERSION_RESPONSE)
        # Bytes 6+: Payload (version info)
        if len(data) >= 6:
            channel_id = data[0]
            flags = data[1]
            frame_size = (data[2] << 8) | data[3]
            msg_id = (data[4] << 8) | data[5]

            print(f"[AA Manager] Frame: channel={channel_id}, flags=0x{flags:02x}, size={frame_size}, msg_id={msg_id}")

            if channel_id == 0 and msg_id == ControlMessageType.VERSION_RESPONSE:
                print(f"[AA Manager] Detected VERSION_RESPONSE!")
                # Parse version from payload (bytes 6-9)
                if len(data) >= 10:
                    import struct
                    major = struct.unpack('>H', data[6:8])[0]
                    minor = struct.unpack('>H', data[8:10])[0]
                    print(f"[AA Manager] Phone AAP version: {major}.{minor}")
                self._handle_version_response_raw(data)
                return

        # Parse frames and route messages
        messages = self._message_assembler.feed(data)
        print(f"[AA Manager] Parsed {len(messages)} messages")

        for message in messages:
            print(f"[AA Manager] Message: channel={message.channel_id}, id={message.message_id}, payload_len={len(message.payload)}")

            # Decrypt if necessary
            if message.encrypted and self._ssl_established:
                # TODO: Implement SSL decryption
                pass

            self._message_router.route(message)

    def _handle_version_response_raw(self, data: bytes):
        """Handle raw version response data."""
        print(f"[AA Manager] Processing version response, proceeding with SSL handshake")

        # Cancel the timeout timer since we got a response
        if hasattr(self, '_version_response_timer') and self._version_response_timer:
            self._version_response_timer.stop()
            self._version_response_timer = None

        self.connectionProgress.emit("Version exchange complete, starting SSL...")

        # Initialize SSL handler
        if not self._ssl_handler.initialize():
            print(f"[AA Manager] Failed to initialize SSL handler")
            self.error.emit("Failed to initialize SSL")
            self._set_state(AndroidAutoState.ERROR)
            return

        print(f"[AA Manager] SSL handler initialized, starting handshake")
        self._set_state(AndroidAutoState.SSL_HANDSHAKE)

        # Start SSL handshake - send initial ClientHello
        self._do_ssl_handshake()

    @Slot(str)
    def _on_transport_error(self, error_msg: str):
        """Handle transport errors (USB or TCP)."""
        logger.error(f"Transport error: {error_msg}")
        self._set_state(AndroidAutoState.ERROR)
        self.error.emit(error_msg)

    def _initiate_ssl_handshake(self):
        """Initiate SSL/TLS handshake with the phone."""
        # Send version request first to get protocol version from phone
        self._send_version_request()

        # Start a timeout timer - if no response in 5 seconds, connection is stale
        self._version_response_timer = QTimer()
        self._version_response_timer.setSingleShot(True)
        self._version_response_timer.timeout.connect(self._on_version_timeout)
        self._version_response_timer.start(5000)  # 5 second timeout

    @Slot()
    def _on_version_timeout(self):
        """Handle timeout waiting for version response."""
        if self._state == AndroidAutoState.SSL_HANDSHAKE and not self._ssl_established:
            print(f"[AA Manager] Timeout waiting for version response - phone may not be ready")

            if self._transport_mode == TransportMode.USB:
                print(f"[AA Manager] Try: 1) Unplug and replug phone, or 2) Open Android Auto app on phone")
                self.connectionProgress.emit("No response - try unplugging and replugging phone")
                self.error.emit("Phone not responding. Unplug and replug phone, or open Android Auto app.")
                # Trigger disconnect to force retry
                self._usb_transport._handle_stale_device()
            else:
                print(f"[AA Manager] TCP: Phone not responding - check head unit server is running")
                self.connectionProgress.emit("No response - check head unit server on phone")
                self.error.emit("Phone not responding. Start head unit server on phone.")

    def _send_version_request(self):
        """Send version request to initiate protocol negotiation.

        The version request payload contains:
        - Bytes 0-1: Major version (uint16 big-endian) = 1
        - Bytes 2-3: Minor version (uint16 big-endian) = 1
        """
        import struct

        print(f"[AA Manager] Sending version request...")

        # aasdk uses version 1.1
        AASDK_MAJOR = 1
        AASDK_MINOR = 1

        # Build version payload: major (uint16 BE) + minor (uint16 BE)
        version_payload = struct.pack('>HH', AASDK_MAJOR, AASDK_MINOR)
        print(f"[AA Manager] Version payload: {version_payload.hex()} (v{AASDK_MAJOR}.{AASDK_MINOR})")

        message = Message(
            channel_id=ChannelId.CONTROL,
            message_id=ControlMessageType.VERSION_REQUEST,
            payload=version_payload,
            encrypted=False
        )

        success = self._send_message(message)
        print(f"[AA Manager] Version request sent: success={success}")
        logger.debug("Sent version request")

    def _send_message(self, message: Message) -> bool:
        """Send a message through the active transport."""
        if not self._active_transport:
            print(f"[AA Manager] Cannot send: no active transport")
            return False

        frame_data = message.create_frame_data()
        print(f"[AA Manager] Sending {len(frame_data)} bytes: {frame_data[:20].hex()}...")
        return self._active_transport.write(frame_data)

    def _handle_control_message(self, message: Message):
        """Handle control channel messages."""
        logger.debug(f"Control message received: ID={message.message_id}")

        if message.message_id == ControlMessageType.VERSION_RESPONSE:
            self._handle_version_response(message)
        elif message.message_id == ControlMessageType.SSL_HANDSHAKE:
            self._handle_ssl_data(message)
        elif message.message_id == ControlMessageType.SERVICE_DISCOVERY_RESPONSE:
            self._handle_service_discovery_response(message)
        elif message.message_id == ControlMessageType.CHANNEL_OPEN_RESPONSE:
            self._handle_channel_open_response(message)
        elif message.message_id == ControlMessageType.PING_REQUEST:
            self._handle_ping_request(message)
        elif message.message_id == ControlMessageType.NAV_FOCUS_NOTIFICATION:
            self._handle_nav_focus_notification(message)
        elif message.message_id == ControlMessageType.AUDIO_FOCUS_REQUEST:
            self._handle_audio_focus_request(message)

    def _handle_version_response(self, message: Message):
        """Handle version response from phone."""
        logger.info("Received version response, proceeding with SSL handshake")
        # TODO: Parse version response and validate compatibility
        # For now, proceed with SSL handshake

    def _do_ssl_handshake(self):
        """Perform SSL handshake step."""
        try:
            # Process handshake with empty data to get initial ClientHello
            outgoing_data, complete = self._ssl_handler.process_handshake_data(b'')

            if outgoing_data:
                print(f"[AA Manager] Sending SSL handshake data: {len(outgoing_data)} bytes")
                # Send as SSL_HANDSHAKE message on control channel
                message = Message(
                    channel_id=ChannelId.CONTROL,
                    message_id=ControlMessageType.SSL_HANDSHAKE,
                    payload=outgoing_data,
                    encrypted=False
                )
                self._send_message(message)

            if complete:
                self._on_ssl_handshake_complete()

        except Exception as e:
            print(f"[AA Manager] SSL handshake error: {e}")
            import traceback
            traceback.print_exc()
            self.error.emit(f"SSL handshake failed: {e}")
            self._set_state(AndroidAutoState.ERROR)

    def _handle_ssl_data(self, message: Message):
        """Handle SSL handshake data from phone."""
        print(f"[AA Manager] Received SSL handshake data: {len(message.payload)} bytes")

        try:
            # Feed data to SSL handler and get response
            outgoing_data, complete = self._ssl_handler.process_handshake_data(message.payload)

            if outgoing_data:
                print(f"[AA Manager] Sending SSL response: {len(outgoing_data)} bytes")
                response = Message(
                    channel_id=ChannelId.CONTROL,
                    message_id=ControlMessageType.SSL_HANDSHAKE,
                    payload=outgoing_data,
                    encrypted=False
                )
                self._send_message(response)

            if complete:
                self._on_ssl_handshake_complete()

        except Exception as e:
            print(f"[AA Manager] SSL handshake error: {e}")
            import traceback
            traceback.print_exc()
            self.error.emit(f"SSL handshake failed: {e}")
            self._set_state(AndroidAutoState.ERROR)

    def _on_ssl_handshake_complete(self):
        """Called when SSL handshake is complete."""
        print(f"[AA Manager] SSL handshake complete!")
        self._ssl_established = True
        self.connectionProgress.emit("SSL handshake complete, authenticating...")

        # Send AUTH_COMPLETE message
        self._send_auth_complete()

    def _send_auth_complete(self):
        """Send AUTH_COMPLETE to proceed with service discovery."""
        print(f"[AA Manager] Sending AUTH_COMPLETE")
        message = Message(
            channel_id=ChannelId.CONTROL,
            message_id=ControlMessageType.AUTH_COMPLETE,
            payload=b'',  # Empty payload for auth complete
            encrypted=False  # AUTH_COMPLETE is sent before encryption starts
        )
        success = self._send_message(message)
        print(f"[AA Manager] AUTH_COMPLETE sent: success={success}")

        # Now start service discovery
        self._set_state(AndroidAutoState.SERVICE_DISCOVERY)
        self.connectionProgress.emit("Discovering services...")
        self._send_service_discovery_request()

    def _send_service_discovery_request(self):
        """Send service discovery request to phone."""
        print(f"[AA Manager] Sending service discovery request")

        try:
            from .proto.aap_protobuf.service.control.message import ServiceDiscoveryRequest_pb2
            request = ServiceDiscoveryRequest_pb2.ServiceDiscoveryRequest()
            payload = request.SerializeToString()
        except ImportError:
            payload = b''  # Empty payload if proto not available

        message = Message(
            channel_id=ChannelId.CONTROL,
            message_id=ControlMessageType.SERVICE_DISCOVERY_REQUEST,
            payload=payload,
            encrypted=self._ssl_established
        )
        self._send_message(message)

    def _handle_service_discovery_response(self, message: Message):
        """Handle service discovery response."""
        logger.info("Received service discovery response")
        self._services_discovered = True

        # Parse available services
        try:
            from .proto.aap_protobuf.service.control.message import ServiceDiscoveryResponse_pb2
            response = ServiceDiscoveryResponse_pb2.ServiceDiscoveryResponse()
            response.ParseFromString(message.payload)
            logger.info(f"Services available: {len(response.channels)}")
        except Exception as e:
            logger.warning(f"Could not parse service discovery response: {e}")

        # Request video channel
        self._request_channel_open(ChannelId.VIDEO)

        self._set_state(AndroidAutoState.CONNECTED)
        self.connectionProgress.emit("Connected to Android Auto")

    def _handle_channel_open_response(self, message: Message):
        """Handle channel open response."""
        logger.debug(f"Channel open response received")
        # TODO: Parse response and track open channels

    def _handle_ping_request(self, message: Message):
        """Handle ping request and send response."""
        # Send ping response
        response = Message(
            channel_id=ChannelId.CONTROL,
            message_id=ControlMessageType.PING_RESPONSE,
            payload=message.payload,
            encrypted=message.encrypted
        )
        self._send_message(response)

    def _handle_nav_focus_notification(self, message: Message):
        """Handle navigation focus notification."""
        logger.debug("Navigation focus notification received")

    def _handle_audio_focus_request(self, message: Message):
        """Handle audio focus request from phone."""
        logger.debug("Audio focus request received")
        # TODO: Handle audio focus management

    def _request_channel_open(self, channel_id: int):
        """Request to open a service channel."""
        try:
            from .proto.aap_protobuf.service.control.message import ChannelOpenRequest_pb2
            request = ChannelOpenRequest_pb2.ChannelOpenRequest()
            # request.channel_id = channel_id
            # request.priority = 0

            message = Message(
                channel_id=ChannelId.CONTROL,
                message_id=ControlMessageType.CHANNEL_OPEN_REQUEST,
                payload=request.SerializeToString(),
                encrypted=self._ssl_established
            )
            self._send_message(message)
            logger.debug(f"Requested channel open: {channel_id}")

        except Exception as e:
            logger.warning(f"Could not send channel open request: {e}")

    def _handle_video_data(self, message: Message):
        """Handle incoming video frame data."""
        # This is H.264 encoded video data
        self.videoFrameReady.emit(message.payload)

        if self._state != AndroidAutoState.STREAMING:
            self._set_state(AndroidAutoState.STREAMING)

    def _handle_audio_data(self, message: Message):
        """Handle incoming audio data."""
        # This is PCM audio data
        stream_type = message.channel_id
        self.audioDataReady.emit(message.payload, stream_type)

    def _handle_navigation_data(self, message: Message):
        """Handle navigation status updates."""
        self.navigationUpdate.emit(message.payload)

    def _handle_phone_status(self, message: Message):
        """Handle phone status updates."""
        self.phoneStatusChanged.emit(message.payload)

    def _handle_media_status(self, message: Message):
        """Handle media playback status updates."""
        self.mediaStatusChanged.emit(message.payload)

    def _handle_input_feedback(self, message: Message):
        """Handle input feedback from phone."""
        logger.debug("Input feedback received")
