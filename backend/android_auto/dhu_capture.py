"""
DHU Screen Capture

Captures the Google DHU window content and provides it as frames
that can be displayed in QML. Also handles input forwarding.
"""

import platform
from typing import Optional
import threading
import time

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QByteArray, QBuffer
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtQuick import QQuickImageProvider

if platform.system() == "Windows":
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32

    # Windows API constants
    SRCCOPY = 0x00CC0020
    DIB_RGB_COLORS = 0
    BI_RGB = 0

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [
            ('biSize', wintypes.DWORD),
            ('biWidth', wintypes.LONG),
            ('biHeight', wintypes.LONG),
            ('biPlanes', wintypes.WORD),
            ('biBitCount', wintypes.WORD),
            ('biCompression', wintypes.DWORD),
            ('biSizeImage', wintypes.DWORD),
            ('biXPelsPerMeter', wintypes.LONG),
            ('biYPelsPerMeter', wintypes.LONG),
            ('biClrUsed', wintypes.DWORD),
            ('biClrImportant', wintypes.DWORD),
        ]

    class BITMAPINFO(ctypes.Structure):
        _fields_ = [
            ('bmiHeader', BITMAPINFOHEADER),
            ('bmiColors', wintypes.DWORD * 3),
        ]

    class RECT(ctypes.Structure):
        _fields_ = [
            ('left', wintypes.LONG),
            ('top', wintypes.LONG),
            ('right', wintypes.LONG),
            ('bottom', wintypes.LONG),
        ]


class DhuFrameProvider(QQuickImageProvider):
    """Provides captured DHU frames to QML."""

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        self._current_image: Optional[QImage] = None
        self._lock = threading.Lock()

    def requestImage(self, id: str, size, requestedSize):
        with self._lock:
            if self._current_image:
                # PySide6 expects just the QImage, not a tuple
                return self._current_image
            # Return empty image if no frame yet
            return QImage(800, 480, QImage.Format_RGB32)

    def update_frame(self, image: QImage):
        with self._lock:
            self._current_image = image


class DhuCapture(QObject):
    """
    Captures the DHU window and provides frames for display in QML.
    Also handles input forwarding to the DHU window.
    """

    frameReady = Signal()  # Emitted when a new frame is available
    captureStarted = Signal()
    captureStopped = Signal()
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._hwnd: int = 0
        self._capturing = False
        self._capture_timer: Optional[QTimer] = None
        self._frame_provider = DhuFrameProvider()
        self._target_fps = 30
        self._last_width = 0
        self._last_height = 0

    @property
    def frame_provider(self) -> DhuFrameProvider:
        """Get the image provider for QML."""
        return self._frame_provider

    @Property(bool, notify=captureStarted)
    def isCapturing(self) -> bool:
        return self._capturing

    @Property(int)
    def windowHandle(self) -> int:
        return self._hwnd

    @windowHandle.setter
    def windowHandle(self, hwnd: int):
        self._hwnd = hwnd

    @Slot(int)
    def setWindowHandle(self, hwnd: int):
        """Set the window handle to capture."""
        self._hwnd = hwnd
        print(f"[DhuCapture] Window handle set to: {hwnd}")

    @Slot()
    def startCapture(self):
        """Start capturing the DHU window."""
        if self._capturing:
            return

        if not self._hwnd:
            self.error.emit("No window handle set")
            return

        if platform.system() != "Windows":
            self.error.emit("Screen capture only supported on Windows")
            return

        print(f"[DhuCapture] Starting capture of window {self._hwnd}")
        self._capturing = True

        # Start capture timer
        self._capture_timer = QTimer()
        self._capture_timer.timeout.connect(self._capture_frame)
        self._capture_timer.start(1000 // self._target_fps)

        self.captureStarted.emit()

    @Slot()
    def stopCapture(self):
        """Stop capturing."""
        if not self._capturing:
            return

        print("[DhuCapture] Stopping capture")
        self._capturing = False

        if self._capture_timer:
            self._capture_timer.stop()
            self._capture_timer = None

        self.captureStopped.emit()

    def _capture_frame(self):
        """Capture a single frame from the DHU window."""
        if not self._capturing or not self._hwnd:
            return

        try:
            # Get window dimensions
            rect = RECT()
            if not user32.GetClientRect(self._hwnd, ctypes.byref(rect)):
                return

            width = rect.right - rect.left
            height = rect.bottom - rect.top

            if width <= 0 or height <= 0:
                return

            # Get window DC
            hwnd_dc = user32.GetDC(self._hwnd)
            if not hwnd_dc:
                return

            try:
                # Create compatible DC and bitmap
                mem_dc = gdi32.CreateCompatibleDC(hwnd_dc)
                if not mem_dc:
                    return

                try:
                    bitmap = gdi32.CreateCompatibleBitmap(hwnd_dc, width, height)
                    if not bitmap:
                        return

                    try:
                        # Select bitmap into memory DC
                        old_bitmap = gdi32.SelectObject(mem_dc, bitmap)

                        # Copy window content to memory DC
                        # Use PrintWindow for better compatibility with some windows
                        PW_CLIENTONLY = 0x1
                        user32.PrintWindow(self._hwnd, mem_dc, PW_CLIENTONLY)

                        # Get bitmap data
                        bmi = BITMAPINFO()
                        bmi.bmiHeader.biSize = ctypes.sizeof(BITMAPINFOHEADER)
                        bmi.bmiHeader.biWidth = width
                        bmi.bmiHeader.biHeight = -height  # Negative for top-down
                        bmi.bmiHeader.biPlanes = 1
                        bmi.bmiHeader.biBitCount = 32
                        bmi.bmiHeader.biCompression = BI_RGB

                        # Allocate buffer for pixel data
                        buffer_size = width * height * 4
                        buffer = (ctypes.c_ubyte * buffer_size)()

                        # Get bitmap bits
                        gdi32.GetDIBits(
                            mem_dc, bitmap, 0, height,
                            buffer, ctypes.byref(bmi), DIB_RGB_COLORS
                        )

                        # Create QImage from buffer (BGRA format)
                        image = QImage(
                            bytes(buffer), width, height,
                            width * 4, QImage.Format_ARGB32
                        ).copy()  # Copy to own the data

                        # Update the frame provider
                        self._frame_provider.update_frame(image)
                        self.frameReady.emit()

                        # Restore old bitmap
                        gdi32.SelectObject(mem_dc, old_bitmap)

                    finally:
                        gdi32.DeleteObject(bitmap)
                finally:
                    gdi32.DeleteDC(mem_dc)
            finally:
                user32.ReleaseDC(self._hwnd, hwnd_dc)

        except Exception as e:
            print(f"[DhuCapture] Capture error: {e}")

    @Slot(int, int)
    def sendMouseClick(self, x: int, y: int):
        """Send a mouse click to the DHU window at the given coordinates."""
        if not self._hwnd:
            return

        if platform.system() != "Windows":
            return

        try:
            import time

            # Save current cursor position to restore later
            old_cursor = wintypes.POINT()
            user32.GetCursorPos(ctypes.byref(old_cursor))

            # Save current foreground window to restore focus
            old_foreground = user32.GetForegroundWindow()

            # Get DHU client area size to scale coordinates properly
            client_rect = RECT()
            user32.GetClientRect(self._hwnd, ctypes.byref(client_rect))
            dhu_client_w = client_rect.right
            dhu_client_h = client_rect.bottom

            # Scale x,y from 800x480 to actual DHU client size
            # QML sends 800x480 coords, but DHU might be different size
            if dhu_client_w > 0 and dhu_client_h > 0:
                scaled_x = int(x * dhu_client_w / 800)
                scaled_y = int(y * dhu_client_h / 480)
            else:
                scaled_x, scaled_y = x, y

            # Get window position info
            window_rect = RECT()
            user32.GetWindowRect(self._hwnd, ctypes.byref(window_rect))

            screen_w = user32.GetSystemMetrics(0)
            screen_h = user32.GetSystemMetrics(1)

            win_w = window_rect.right - window_rect.left
            win_h = window_rect.bottom - window_rect.top

            # Position off the visible screen edge but technically on-screen
            # Use coordinates just at the edge so it's minimally visible
            temp_x = screen_w - win_w
            temp_y = screen_h - win_h

            # Make window nearly invisible using layered window
            GWL_EXSTYLE = -20
            WS_EX_LAYERED = 0x00080000
            LWA_ALPHA = 0x00000002

            old_style = user32.GetWindowLongW(self._hwnd, GWL_EXSTYLE)
            user32.SetWindowLongW(self._hwnd, GWL_EXSTYLE, old_style | WS_EX_LAYERED)
            user32.SetLayeredWindowAttributes(self._hwnd, 0, 1, LWA_ALPHA)

            # Move window on-screen
            SWP_NOSIZE = 0x0001
            SWP_SHOWWINDOW = 0x0040
            SWP_NOZORDER = 0x0004
            user32.SetWindowPos(self._hwnd, 0, temp_x, temp_y, 0, 0,
                               SWP_NOSIZE | SWP_SHOWWINDOW | SWP_NOZORDER)

            # Brief activation
            user32.SetForegroundWindow(self._hwnd)
            time.sleep(0.02)

            # Convert scaled client coords to screen coords
            point = wintypes.POINT(scaled_x, scaled_y)
            user32.ClientToScreen(self._hwnd, ctypes.byref(point))

            # Click
            user32.SetCursorPos(point.x, point.y)
            MOUSEEVENTF_LEFTDOWN = 0x0002
            MOUSEEVENTF_LEFTUP = 0x0004
            user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
            time.sleep(0.02)

            # Restore opacity for screen capture
            user32.SetLayeredWindowAttributes(self._hwnd, 0, 255, LWA_ALPHA)

            # Move window back off-screen
            user32.SetWindowPos(self._hwnd, 0, -2000, -2000, 0, 0, SWP_NOSIZE | SWP_NOZORDER)

            # Restore cursor position
            user32.SetCursorPos(old_cursor.x, old_cursor.y)

            # Restore focus to OCTAVE
            if old_foreground:
                user32.SetForegroundWindow(old_foreground)

            print(f"[DhuCapture] Click ({x},{y}) -> scaled ({scaled_x},{scaled_y}) -> screen ({point.x},{point.y})")

        except Exception as e:
            print(f"[DhuCapture] Mouse click error: {e}")

    @Slot(int, int, bool)
    def sendMouseEvent(self, x: int, y: int, pressed: bool):
        """Send a mouse event to the DHU window."""
        if not self._hwnd:
            return

        if platform.system() != "Windows":
            return

        try:
            WM_LBUTTONDOWN = 0x0201
            WM_LBUTTONUP = 0x0202
            MK_LBUTTON = 0x0001

            lparam = (y << 16) | (x & 0xFFFF)

            if pressed:
                user32.SendMessageW(self._hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lparam)
            else:
                user32.SendMessageW(self._hwnd, WM_LBUTTONUP, 0, lparam)

        except Exception as e:
            print(f"[DhuCapture] Mouse event error: {e}")
