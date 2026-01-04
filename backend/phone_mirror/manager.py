"""
Phone Mirror Manager for OCTAVE.

Handles scrcpy-based phone screen mirroring setup and configuration.
Owns the singleton scrcpy process to prevent multiple instances.
"""

import subprocess
import shutil
import platform
import os
import time
from pathlib import Path
from threading import Thread
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot, Property

if platform.system() == "Windows":
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32

    # Function signatures for window enumeration
    user32.EnumWindows.argtypes = [ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM), wintypes.LPARAM]
    user32.EnumWindows.restype = wintypes.BOOL
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.IsWindowVisible.restype = wintypes.BOOL


class PhoneMirrorManager(QObject):
    """
    Manager for phone screen mirroring configuration in OCTAVE.

    Handles scrcpy path detection, ADB device checks, and OWNS the scrcpy process.
    Only one scrcpy instance can run at a time (singleton pattern).
    """

    # Signals
    scrcpyPathChanged = Signal()
    error = Signal(str)

    # Signals for scrcpy process state
    scrcpyStarted = Signal(int)  # Emits the window handle when scrcpy is ready
    scrcpyStopped = Signal()
    scrcpyError = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._scrcpy_path: Optional[str] = None
        self._custom_scrcpy_path: str = ""
        self._adb_path: Optional[str] = None

        # Singleton scrcpy process
        self._process: Optional[subprocess.Popen] = None
        self._scrcpy_hwnd: Optional[int] = None
        self._is_starting: bool = False

        # Find executables (auto-detect)
        self._scrcpy_path = self._find_scrcpy()
        self._adb_path = self._find_adb()

    @Property(bool, notify=scrcpyPathChanged)
    def isScrcpyInstalled(self) -> bool:
        return self._get_effective_scrcpy_path() is not None

    @Property(str, notify=scrcpyPathChanged)
    def scrcpyPath(self) -> str:
        return self._get_effective_scrcpy_path() or ""

    def _get_effective_scrcpy_path(self) -> Optional[str]:
        """Get the scrcpy path to use - custom if set, otherwise auto-detected."""
        if self._custom_scrcpy_path and self._check_scrcpy(self._custom_scrcpy_path):
            return self._custom_scrcpy_path
        return self._scrcpy_path

    @Slot(str)
    def setScrcpyPath(self, path: str):
        """Set a custom scrcpy path."""
        print(f"[PhoneMirror] Setting custom scrcpy path: {path}")
        old_effective = self._get_effective_scrcpy_path()
        self._custom_scrcpy_path = path.strip()

        if not self._custom_scrcpy_path:
            self._scrcpy_path = self._find_scrcpy()

        new_effective = self._get_effective_scrcpy_path()
        if old_effective != new_effective:
            self.scrcpyPathChanged.emit()
            print(f"[PhoneMirror] Effective scrcpy path: {new_effective}")

    def _find_scrcpy(self) -> Optional[str]:
        """Find scrcpy executable."""
        scrcpy_in_path = shutil.which("scrcpy")
        if scrcpy_in_path:
            return scrcpy_in_path

        if platform.system() == "Windows":
            common_paths = [
                r"C:\scrcpy\scrcpy.exe",
                r"C:\Program Files\scrcpy\scrcpy.exe",
                r"C:\Program Files (x86)\scrcpy\scrcpy.exe",
                str(Path.home() / "scrcpy" / "scrcpy.exe"),
                str(Path.home() / "Downloads" / "scrcpy-win64-v3.1" / "scrcpy.exe"),
                str(Path.home() / "Downloads" / "scrcpy" / "scrcpy.exe"),
            ]
        else:
            common_paths = [
                "/usr/bin/scrcpy",
                "/usr/local/bin/scrcpy",
                "/snap/bin/scrcpy",
                str(Path.home() / ".local" / "bin" / "scrcpy"),
            ]

        for path in common_paths:
            if self._check_scrcpy(path):
                return path

        return None

    def _check_scrcpy(self, path: str) -> bool:
        """Check if scrcpy executable exists and works."""
        try:
            creationflags = 0
            if platform.system() == "Windows":
                creationflags = subprocess.CREATE_NO_WINDOW

            result = subprocess.run(
                [path, "--version"],
                capture_output=True,
                text=True,
                timeout=5,
                creationflags=creationflags,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.SubprocessError, OSError):
            return False

    def _find_adb(self) -> Optional[str]:
        """Find ADB executable."""
        adb_in_path = shutil.which("adb")
        if adb_in_path:
            return adb_in_path

        if platform.system() == "Windows":
            common_paths = [
                r"C:\scrcpy\adb.exe",
                r"C:\Program Files\Android\platform-tools\adb.exe",
                r"C:\Program Files (x86)\Android\platform-tools\adb.exe",
                str(Path.home() / "scrcpy" / "adb.exe"),
                str(Path.home() / "AppData" / "Local" / "Android" / "Sdk" / "platform-tools" / "adb.exe"),
            ]
        else:
            common_paths = [
                "/usr/bin/adb",
                "/usr/local/bin/adb",
                str(Path.home() / "Android" / "Sdk" / "platform-tools" / "adb"),
            ]

        for path in common_paths:
            if os.path.exists(path):
                return path

        return None

    @Slot(result=bool)
    def hasConnectedDevice(self) -> bool:
        """Check if an Android device is connected via ADB."""
        if not self._adb_path:
            return False

        try:
            creationflags = 0
            if platform.system() == "Windows":
                creationflags = subprocess.CREATE_NO_WINDOW

            result = subprocess.run(
                [self._adb_path, "devices"],
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=creationflags,
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[1:]
                for line in lines:
                    if line.strip() and 'device' in line and 'offline' not in line:
                        return True
            return False
        except (subprocess.SubprocessError, OSError):
            return False

    @Slot(result=str)
    def getDeviceSerial(self) -> str:
        """Get the first connected device serial."""
        if not self._adb_path:
            return ""

        try:
            creationflags = 0
            if platform.system() == "Windows":
                creationflags = subprocess.CREATE_NO_WINDOW

            result = subprocess.run(
                [self._adb_path, "devices"],
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=creationflags,
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[1:]
                for line in lines:
                    if line.strip() and 'device' in line and 'offline' not in line:
                        parts = line.split()
                        if parts:
                            return parts[0]
            return ""
        except (subprocess.SubprocessError, OSError):
            return ""

    @Slot(result=str)
    def getDeviceName(self) -> str:
        """Get the connected device name."""
        if not self._adb_path:
            return ""

        try:
            creationflags = 0
            if platform.system() == "Windows":
                creationflags = subprocess.CREATE_NO_WINDOW

            result = subprocess.run(
                [self._adb_path, "shell", "getprop", "ro.product.model"],
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=creationflags,
            )

            if result.returncode == 0:
                return result.stdout.strip()
            return ""
        except (subprocess.SubprocessError, OSError):
            return ""

    @Property(bool, notify=scrcpyStarted)
    def isRunning(self) -> bool:
        """Check if scrcpy is currently running."""
        return self._process is not None and self._process.poll() is None

    @Property(int, notify=scrcpyStarted)
    def scrcpyWindowHandle(self) -> int:
        """Get the scrcpy window handle if available."""
        return self._scrcpy_hwnd or 0

    @Slot()
    def startScrcpy(self):
        """Start scrcpy process (singleton - only one instance allowed)."""
        # Already running?
        if self._process and self._process.poll() is None:
            print("[PhoneMirror] scrcpy already running, emitting existing handle")
            if self._scrcpy_hwnd:
                self.scrcpyStarted.emit(self._scrcpy_hwnd)
            return

        # Already starting?
        if self._is_starting:
            print("[PhoneMirror] scrcpy already starting, ignoring duplicate request")
            return

        scrcpy_path = self._get_effective_scrcpy_path()
        if not scrcpy_path:
            self.scrcpyError.emit("scrcpy not installed")
            return

        if not self.hasConnectedDevice():
            self.scrcpyError.emit("No Android device connected")
            return

        device_serial = self.getDeviceSerial()
        self._is_starting = True

        # Build command
        # Note: Don't use --max-size to allow scrcpy to render at full resolution
        # and scale dynamically when window is resized
        cmd = [
            scrcpy_path,
            "--video-codec=h264",
            "--no-audio",
            "--video-bit-rate=8M",
            "--max-fps=60",
            "--window-borderless",
            "--stay-awake",
        ]

        if device_serial:
            cmd.extend(["-s", device_serial])

        print(f"[PhoneMirror] Starting scrcpy: {' '.join(cmd)}")

        try:
            scrcpy_dir = str(Path(scrcpy_path).parent)
            self._process = subprocess.Popen(
                cmd,
                cwd=scrcpy_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

            # Start thread to find the window
            Thread(target=self._find_scrcpy_window, daemon=True).start()

        except Exception as e:
            print(f"[PhoneMirror] Failed to start scrcpy: {e}")
            self._is_starting = False
            self.scrcpyError.emit(str(e))

    def _find_scrcpy_window(self):
        """Find the scrcpy window after it starts (runs in background thread)."""
        if not self._process or platform.system() != "Windows":
            self._is_starting = False
            return

        pid = self._process.pid
        hwnd = None

        # Wait for window to appear (up to 10 seconds)
        for _ in range(100):
            if self._process.poll() is not None:
                stderr = self._process.stderr.read().decode() if self._process.stderr else ""
                print(f"[PhoneMirror] scrcpy exited: {stderr}")
                self._is_starting = False
                self.scrcpyError.emit(f"scrcpy failed: {stderr[:100]}")
                return

            hwnd = self._find_window_by_pid(pid)
            if hwnd:
                break
            time.sleep(0.1)

        if not hwnd:
            print("[PhoneMirror] Could not find scrcpy window")
            self._is_starting = False
            self.scrcpyError.emit("Could not find scrcpy window")
            return

        print(f"[PhoneMirror] Found scrcpy window: {hwnd}")
        self._scrcpy_hwnd = hwnd
        self._is_starting = False

        # Emit signal with the window handle
        self.scrcpyStarted.emit(hwnd)

    def _find_window_by_pid(self, target_pid: int) -> Optional[int]:
        """Find a window by process ID."""
        result = [None]

        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def enum_callback(hwnd, lparam):
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == target_pid and user32.IsWindowVisible(hwnd):
                result[0] = hwnd
                return False
            return True

        user32.EnumWindows(enum_callback, 0)
        return result[0]

    @Slot()
    def stopScrcpy(self):
        """Stop the scrcpy process."""
        print("[PhoneMirror] Stopping scrcpy...")

        self._scrcpy_hwnd = None
        self._is_starting = False

        if self._process:
            try:
                self._process.terminate()
                self._process.wait(timeout=2)
            except:
                try:
                    self._process.kill()
                except:
                    pass
            self._process = None

        self.scrcpyStopped.emit()

    @Slot()
    def cleanup(self):
        """Cleanup when OCTAVE is closing."""
        self.stopScrcpy()

    @Slot(result=str)
    def getInstallInstructions(self) -> str:
        """Get instructions for installing scrcpy."""
        if platform.system() == "Windows":
            return """To install scrcpy:

1. Download from: https://github.com/Genymobile/scrcpy/releases
2. Extract to C:\\scrcpy or your preferred location
3. Set the path in Settings > Phone Mirror
4. Restart OCTAVE

Note: scrcpy includes ADB. Enable USB debugging on your phone."""
        else:
            return """To install scrcpy:

Ubuntu/Debian: sudo apt install scrcpy
Arch Linux: sudo pacman -S scrcpy
macOS: brew install scrcpy

Make sure USB debugging is enabled on your phone."""
