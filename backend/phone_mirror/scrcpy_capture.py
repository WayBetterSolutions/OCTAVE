"""
Scrcpy Screen Capture for OCTAVE.

Captures the scrcpy window content and provides frames for QML display.
This approach works around SDL's inability to handle resize when embedded
as a child window. The scrcpy window is kept off-screen and its content
is captured and displayed via QML Image element.
"""

import platform
import threading
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QPointF
from PySide6.QtGui import QImage
from PySide6.QtQuick import QQuickImageProvider, QQuickItem

if platform.system() == "Windows":
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32

    # Windows API constants
    SRCCOPY = 0x00CC0020
    DIB_RGB_COLORS = 0
    BI_RGB = 0
    PW_CLIENTONLY = 0x1
    PW_RENDERFULLCONTENT = 0x2

    # Window style constants
    GWL_EXSTYLE = -20
    WS_EX_LAYERED = 0x00080000
    WS_EX_TOOLWINDOW = 0x00000080
    WS_EX_APPWINDOW = 0x00040000
    LWA_ALPHA = 0x00000002
    SW_HIDE = 0
    SW_SHOW = 5
    SW_SHOWNOACTIVATE = 4
    SWP_NOSIZE = 0x0001
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    SWP_SHOWWINDOW = 0x0040

    # Mouse event constants
    WM_LBUTTONDOWN = 0x0201
    WM_LBUTTONUP = 0x0202
    WM_MOUSEMOVE = 0x0200
    MK_LBUTTON = 0x0001
    MOUSEEVENTF_LEFTDOWN = 0x0002
    MOUSEEVENTF_LEFTUP = 0x0004

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

    class POINT(ctypes.Structure):
        _fields_ = [
            ('x', wintypes.LONG),
            ('y', wintypes.LONG),
        ]

    # Function signatures
    user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(RECT)]
    user32.GetClientRect.restype = wintypes.BOOL
    user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(RECT)]
    user32.GetWindowRect.restype = wintypes.BOOL
    user32.GetDC.argtypes = [wintypes.HWND]
    user32.GetDC.restype = wintypes.HDC
    user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
    user32.ReleaseDC.restype = ctypes.c_int
    user32.PrintWindow.argtypes = [wintypes.HWND, wintypes.HDC, wintypes.UINT]
    user32.PrintWindow.restype = wintypes.BOOL
    user32.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.UINT]
    user32.SetWindowPos.restype = wintypes.BOOL
    user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.ShowWindow.restype = wintypes.BOOL
    user32.IsWindow.argtypes = [wintypes.HWND]
    user32.IsWindow.restype = wintypes.BOOL
    user32.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.GetWindowLongW.restype = wintypes.LONG
    user32.SetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.LONG]
    user32.SetWindowLongW.restype = wintypes.LONG
    user32.SetLayeredWindowAttributes.argtypes = [wintypes.HWND, wintypes.DWORD, wintypes.BYTE, wintypes.DWORD]
    user32.SetLayeredWindowAttributes.restype = wintypes.BOOL
    user32.GetForegroundWindow.argtypes = []
    user32.GetForegroundWindow.restype = wintypes.HWND
    user32.SetForegroundWindow.argtypes = [wintypes.HWND]
    user32.SetForegroundWindow.restype = wintypes.BOOL
    user32.GetCursorPos.argtypes = [ctypes.POINTER(POINT)]
    user32.GetCursorPos.restype = wintypes.BOOL
    user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
    user32.SetCursorPos.restype = wintypes.BOOL
    user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(POINT)]
    user32.ClientToScreen.restype = wintypes.BOOL
    user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.SendMessageW.restype = wintypes.LPARAM
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.PostMessageW.restype = wintypes.BOOL
    user32.mouse_event.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(wintypes.ULONG)]
    user32.GetSystemMetrics.argtypes = [ctypes.c_int]
    user32.GetSystemMetrics.restype = ctypes.c_int

    gdi32.CreateCompatibleDC.argtypes = [wintypes.HDC]
    gdi32.CreateCompatibleDC.restype = wintypes.HDC
    gdi32.CreateCompatibleBitmap.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int]
    gdi32.CreateCompatibleBitmap.restype = wintypes.HBITMAP
    gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
    gdi32.SelectObject.restype = wintypes.HGDIOBJ
    gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
    gdi32.DeleteObject.restype = wintypes.BOOL
    gdi32.DeleteDC.argtypes = [wintypes.HDC]
    gdi32.DeleteDC.restype = wintypes.BOOL
    gdi32.GetDIBits.argtypes = [wintypes.HDC, wintypes.HBITMAP, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.POINTER(BITMAPINFO), wintypes.UINT]
    gdi32.GetDIBits.restype = ctypes.c_int
    gdi32.BitBlt.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.HDC, ctypes.c_int, ctypes.c_int, wintypes.DWORD]
    gdi32.BitBlt.restype = wintypes.BOOL


class ScrcpyFrameProvider(QQuickImageProvider):
    """Provides captured scrcpy frames to QML."""

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        self._current_image: Optional[QImage] = None
        self._lock = threading.Lock()

    def requestImage(self, id: str, size, requestedSize):
        """Return the current frame image."""
        with self._lock:
            if self._current_image and not self._current_image.isNull():
                return self._current_image
            # Return placeholder if no frame yet
            return QImage(720, 1280, QImage.Format_RGB32)

    def update_frame(self, image: QImage):
        """Update the current frame."""
        with self._lock:
            self._current_image = image

    @property
    def has_frame(self) -> bool:
        with self._lock:
            return self._current_image is not None and not self._current_image.isNull()


class ScrcpyCapture(QObject):
    """
    Captures the scrcpy window and provides frames for QML display.
    Also handles input forwarding to the scrcpy window.

    This class keeps the scrcpy window off-screen and captures its content
    at a high frame rate, providing the frames via QQuickImageProvider.
    """

    frameReady = Signal()
    captureStarted = Signal()
    captureStopped = Signal()
    error = Signal(str)
    frameSizeChanged = Signal(int, int)  # width, height

    def __init__(self, parent=None):
        super().__init__(parent)
        self._hwnd: int = 0
        self._capturing = False
        self._capture_timer: Optional[QTimer] = None
        self._frame_provider = ScrcpyFrameProvider()
        self._target_fps = 60  # Higher FPS for phone mirror
        self._last_width = 0
        self._last_height = 0
        self._frame_count = 0
        self._input_state = None  # Track window state during touch

    @property
    def frame_provider(self) -> ScrcpyFrameProvider:
        """Get the image provider for QML."""
        return self._frame_provider

    @Property(bool, notify=captureStarted)
    def isCapturing(self) -> bool:
        return self._capturing

    @Property(int)
    def windowHandle(self) -> int:
        return self._hwnd

    @Property(int)
    def frameWidth(self) -> int:
        return self._last_width

    @Property(int)
    def frameHeight(self) -> int:
        return self._last_height

    @Slot(int)
    def setWindowHandle(self, hwnd: int):
        """Set the scrcpy window handle to capture."""
        self._hwnd = hwnd
        print(f"[ScrcpyCapture] Window handle set to: {hwnd}")

        if platform.system() == "Windows" and hwnd:
            # Move window off-screen immediately
            self._position_window_offscreen(hwnd)

    def _position_window_offscreen(self, hwnd: int):
        """Position the scrcpy window off-screen for capture."""
        if not user32.IsWindow(hwnd):
            return

        # Hide from taskbar
        ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        ex_style = (ex_style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
        user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style)

        # Move off-screen
        user32.SetWindowPos(hwnd, 0, -3000, -3000, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)

        # Show window (needed for capture to work)
        user32.ShowWindow(hwnd, SW_SHOWNOACTIVATE)

        print(f"[ScrcpyCapture] Window positioned off-screen")

    @Slot()
    def startCapture(self):
        """Start capturing the scrcpy window."""
        if self._capturing:
            return

        if not self._hwnd:
            self.error.emit("No window handle set")
            return

        if platform.system() != "Windows":
            self.error.emit("Screen capture only supported on Windows")
            return

        print(f"[ScrcpyCapture] Starting capture of window {self._hwnd} at {self._target_fps} FPS")
        self._capturing = True
        self._frame_count = 0

        # Ensure window is positioned correctly
        self._position_window_offscreen(self._hwnd)

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

        print(f"[ScrcpyCapture] Stopping capture (captured {self._frame_count} frames)")
        self._capturing = False

        if self._capture_timer:
            self._capture_timer.stop()
            self._capture_timer = None

        self.captureStopped.emit()

    def _capture_frame(self):
        """Capture a single frame from the scrcpy window."""
        if not self._capturing or not self._hwnd:
            return

        if platform.system() != "Windows":
            return

        if not user32.IsWindow(self._hwnd):
            print("[ScrcpyCapture] Window no longer exists")
            self.stopCapture()
            self.error.emit("Scrcpy window closed")
            return

        try:
            # Get client area dimensions
            rect = RECT()
            if not user32.GetClientRect(self._hwnd, ctypes.byref(rect)):
                return

            width = rect.right - rect.left
            height = rect.bottom - rect.top

            if width <= 0 or height <= 0:
                return

            # Check if size changed
            if width != self._last_width or height != self._last_height:
                self._last_width = width
                self._last_height = height
                self.frameSizeChanged.emit(width, height)
                print(f"[ScrcpyCapture] Frame size: {width}x{height}")

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

                        # Capture using PrintWindow for best results with hardware-accelerated content
                        # PW_RENDERFULLCONTENT works better for DirectX/OpenGL windows
                        result = user32.PrintWindow(self._hwnd, mem_dc, PW_RENDERFULLCONTENT)

                        if not result:
                            # Fallback to BitBlt if PrintWindow fails
                            gdi32.BitBlt(mem_dc, 0, 0, width, height, hwnd_dc, 0, 0, SRCCOPY)

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
                        self._frame_count += 1
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
            print(f"[ScrcpyCapture] Capture error: {e}")

    @Slot(float, float, bool)
    def sendTouchEvent(self, rel_x: float, rel_y: float, pressed: bool):
        """
        Send a touch event to scrcpy using real mouse input.
        Uses the captured frame dimensions for coordinate mapping.

        Args:
            rel_x, rel_y: Relative position (0.0 to 1.0) within the display
            pressed: Whether this is a press (True) or release (False)
        """
        if not self._hwnd or not self._capturing:
            return

        if platform.system() != "Windows":
            return

        # Use captured frame size (not live window size which may change)
        if self._last_width <= 0 or self._last_height <= 0:
            print("[ScrcpyCapture] No frame size yet, ignoring touch")
            return

        import time

        try:
            # Convert relative position to client pixels using captured frame size
            client_x = int(rel_x * self._last_width)
            client_y = int(rel_y * self._last_height)
            client_x = max(0, min(client_x, self._last_width - 1))
            client_y = max(0, min(client_y, self._last_height - 1))

            if pressed:
                # Save cursor and foreground
                old_cursor = POINT()
                user32.GetCursorPos(ctypes.byref(old_cursor))
                old_foreground = user32.GetForegroundWindow()

                # Get current window rect to know where it is
                window_rect = RECT()
                user32.GetWindowRect(self._hwnd, ctypes.byref(window_rect))

                # Get screen size
                screen_w = user32.GetSystemMetrics(0)
                screen_h = user32.GetSystemMetrics(1)

                # Calculate where to position window (bottom-right corner)
                win_w = window_rect.right - window_rect.left
                win_h = window_rect.bottom - window_rect.top
                temp_x = screen_w - win_w
                temp_y = screen_h - win_h

                # Calculate final screen position for click
                # (temp window position + client offset)
                screen_x = temp_x + client_x
                screen_y = temp_y + client_y

                # Make window nearly invisible
                old_style = user32.GetWindowLongW(self._hwnd, GWL_EXSTYLE)
                user32.SetWindowLongW(self._hwnd, GWL_EXSTYLE, old_style | WS_EX_LAYERED)
                user32.SetLayeredWindowAttributes(self._hwnd, 0, 1, LWA_ALPHA)

                # Move window on-screen
                user32.SetWindowPos(self._hwnd, 0, temp_x, temp_y, 0, 0,
                                   SWP_NOSIZE | SWP_SHOWWINDOW | SWP_NOZORDER | SWP_NOACTIVATE)

                # Activate and click
                user32.SetForegroundWindow(self._hwnd)
                time.sleep(0.02)

                user32.SetCursorPos(screen_x, screen_y)
                time.sleep(0.01)
                user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, None)

                # Save state for release
                self._input_state = {
                    'old_cursor': old_cursor,
                    'old_foreground': old_foreground,
                    'old_style': old_style,
                    'temp_x': temp_x,
                    'temp_y': temp_y,
                }

                print(f"[ScrcpyCapture] Touch DOWN at client ({client_x}, {client_y}), screen ({screen_x}, {screen_y})")

            else:
                # Release
                if self._input_state:
                    # Calculate screen position using saved window position
                    screen_x = self._input_state['temp_x'] + client_x
                    screen_y = self._input_state['temp_y'] + client_y

                    user32.SetCursorPos(screen_x, screen_y)
                    time.sleep(0.01)

                user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, None)
                print(f"[ScrcpyCapture] Touch UP at client ({client_x}, {client_y})")

                time.sleep(0.02)

                # Restore everything
                if self._input_state:
                    # Restore opacity
                    user32.SetLayeredWindowAttributes(self._hwnd, 0, 255, LWA_ALPHA)

                    # Move window back off-screen
                    user32.SetWindowPos(self._hwnd, 0, -3000, -3000, 0, 0,
                                       SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)

                    # Restore cursor
                    user32.SetCursorPos(self._input_state['old_cursor'].x,
                                       self._input_state['old_cursor'].y)

                    # Restore focus
                    if self._input_state['old_foreground']:
                        user32.SetForegroundWindow(self._input_state['old_foreground'])

                    self._input_state = None

        except Exception as e:
            print(f"[ScrcpyCapture] Touch event error: {e}")
            import traceback
            traceback.print_exc()
            # Try to restore on error
            if self._input_state:
                try:
                    user32.SetLayeredWindowAttributes(self._hwnd, 0, 255, LWA_ALPHA)
                    user32.SetWindowPos(self._hwnd, 0, -3000, -3000, 0, 0,
                                       SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
                except:
                    pass
                self._input_state = None

    @Slot(float, float)
    def sendTouchMove(self, rel_x: float, rel_y: float):
        """
        Send a touch move event for drag operations.

        Args:
            rel_x, rel_y: Relative position (0.0 to 1.0) within the display
        """
        if not self._hwnd or not self._capturing or not self._input_state:
            return

        if platform.system() != "Windows":
            return

        if self._last_width <= 0 or self._last_height <= 0:
            return

        try:
            # Convert relative position using captured frame size
            client_x = int(rel_x * self._last_width)
            client_y = int(rel_y * self._last_height)
            client_x = max(0, min(client_x, self._last_width - 1))
            client_y = max(0, min(client_y, self._last_height - 1))

            # Calculate screen position using saved window position
            screen_x = self._input_state['temp_x'] + client_x
            screen_y = self._input_state['temp_y'] + client_y

            user32.SetCursorPos(screen_x, screen_y)

        except Exception as e:
            print(f"[ScrcpyCapture] Touch move error: {e}")


class ScrcpyCaptureItem(QQuickItem):
    """
    A QQuickItem that displays captured scrcpy frames and handles input.

    This item connects to PhoneMirrorManager and ScrcpyCapture to:
    1. Start capture when scrcpy launches
    2. Refresh the QML Image when new frames are available
    3. Forward touch/mouse input to the scrcpy window
    """

    # Signals
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)
    frameRefresh = Signal()  # Triggers QML image refresh

    def __init__(self, parent=None):
        super().__init__(parent)
        self._manager = None
        self._capture: Optional[ScrcpyCapture] = None
        self._frame_counter = 0  # For triggering QML image refresh

        # Accept mouse events
        self.setAcceptedMouseButtons(Qt.LeftButton)

        print("[ScrcpyCaptureItem] Created")

    @Property(int, notify=frameRefresh)
    def frameCounter(self) -> int:
        """Counter that increments on each frame, used to refresh QML Image."""
        return self._frame_counter

    @Property(int, notify=streamStarted)
    def frameWidth(self) -> int:
        if self._capture:
            return self._capture.frameWidth
        return 0

    @Property(int, notify=streamStarted)
    def frameHeight(self) -> int:
        if self._capture:
            return self._capture.frameHeight
        return 0

    @Property(bool, notify=streamStarted)
    def isStreaming(self) -> bool:
        return self._capture is not None and self._capture.isCapturing

    def setCapture(self, capture: ScrcpyCapture):
        """Set the ScrcpyCapture instance to use."""
        self._capture = capture
        if capture:
            capture.frameReady.connect(self._on_frame_ready)
            capture.error.connect(self._on_capture_error)

    @Slot(QObject)
    def connectToManager(self, manager):
        """Connect to PhoneMirrorManager."""
        if self._manager:
            try:
                self._manager.scrcpyStarted.disconnect(self._on_scrcpy_started)
                self._manager.scrcpyStopped.disconnect(self._on_scrcpy_stopped)
                self._manager.scrcpyError.disconnect(self._on_scrcpy_error)
            except:
                pass

        self._manager = manager
        if manager:
            print("[ScrcpyCaptureItem] Connecting to manager")
            from PySide6.QtCore import Qt
            manager.scrcpyStarted.connect(self._on_scrcpy_started, Qt.QueuedConnection)
            manager.scrcpyStopped.connect(self._on_scrcpy_stopped, Qt.QueuedConnection)
            manager.scrcpyError.connect(self._on_scrcpy_error, Qt.QueuedConnection)

            # If already running, start capture
            if manager.isRunning and manager.scrcpyWindowHandle:
                print(f"[ScrcpyCaptureItem] Manager has running scrcpy")
                QTimer.singleShot(100, lambda: self._on_scrcpy_started(manager.scrcpyWindowHandle))

    @Slot(int)
    def _on_scrcpy_started(self, hwnd: int):
        """Called when scrcpy window is ready."""
        print(f"[ScrcpyCaptureItem] Scrcpy started, hwnd={hwnd}")

        if not self._capture:
            print("[ScrcpyCaptureItem] No capture instance set!")
            return

        # Set window handle and start capture
        self._capture.setWindowHandle(hwnd)
        QTimer.singleShot(200, self._capture.startCapture)  # Small delay for window to be ready

        self.streamStarted.emit()

    @Slot()
    def _on_scrcpy_stopped(self):
        """Called when scrcpy stops."""
        print("[ScrcpyCaptureItem] Scrcpy stopped")
        if self._capture:
            self._capture.stopCapture()
        self.streamStopped.emit()

    @Slot(str)
    def _on_scrcpy_error(self, error: str):
        """Called on scrcpy error."""
        print(f"[ScrcpyCaptureItem] Error: {error}")
        if self._capture:
            self._capture.stopCapture()
        self.errorOccurred.emit(error)

    @Slot()
    def _on_frame_ready(self):
        """Called when a new frame is captured."""
        self._frame_counter += 1
        self.frameRefresh.emit()

    @Slot(str)
    def _on_capture_error(self, error: str):
        """Called on capture error."""
        self.errorOccurred.emit(error)

    @Slot()
    def detach(self):
        """Pause capture when view is deactivated."""
        print("[ScrcpyCaptureItem] Detaching (pausing capture)")
        if self._capture:
            self._capture.stopCapture()

    @Slot()
    def reattach(self):
        """Resume capture when view is reactivated."""
        print("[ScrcpyCaptureItem] Reattaching (resuming capture)")
        if self._manager and self._manager.isRunning and self._capture:
            hwnd = self._manager.scrcpyWindowHandle
            if hwnd:
                self._capture.setWindowHandle(hwnd)
                self._capture.startCapture()
                self.streamStarted.emit()

    # Mouse event handlers for touch input
    def mousePressEvent(self, event):
        """Handle mouse press."""
        if self._capture and self._capture.isCapturing:
            pos = event.position()
            self._capture.sendMouseEvent(
                int(pos.x()), int(pos.y()), True,
                int(self.width()), int(self.height())
            )
        event.accept()

    def mouseReleaseEvent(self, event):
        """Handle mouse release."""
        if self._capture and self._capture.isCapturing:
            pos = event.position()
            self._capture.sendMouseEvent(
                int(pos.x()), int(pos.y()), False,
                int(self.width()), int(self.height())
            )
        event.accept()

    def mouseMoveEvent(self, event):
        """Handle mouse move (for drag)."""
        if self._capture and self._capture.isCapturing:
            pos = event.position()
            self._capture.sendMouseMove(
                int(pos.x()), int(pos.y()),
                int(self.width()), int(self.height())
            )
        event.accept()

    @Slot(float, float)
    def handleClick(self, x: float, y: float):
        """Handle a click from QML."""
        if self._capture and self._capture.isCapturing:
            self._capture.sendClick(
                int(x), int(y),
                int(self.width()), int(self.height())
            )

    def componentComplete(self):
        """Called when QML component is fully loaded."""
        super().componentComplete()
        print("[ScrcpyCaptureItem] Component complete")
