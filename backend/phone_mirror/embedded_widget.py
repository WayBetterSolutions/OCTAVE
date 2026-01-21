"""
Embedded Scrcpy Widget for QML.

A QQuickItem that embeds a scrcpy window as a child window.
Works with PhoneMirrorManager which owns the scrcpy process.
"""

import platform
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QPointF, Qt
from PySide6.QtQuick import QQuickItem

from backend.logging_config import get_logger

logger = get_logger(__name__)

if platform.system() == "Windows":
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32

    # Constants
    GWL_STYLE = -16
    GWL_EXSTYLE = -20
    WS_CHILD = 0x40000000
    WS_VISIBLE = 0x10000000
    WS_POPUP = 0x80000000
    WS_CAPTION = 0x00C00000
    WS_THICKFRAME = 0x00040000
    WS_BORDER = 0x00800000
    WS_EX_APPWINDOW = 0x00040000
    WS_EX_TOOLWINDOW = 0x00000080
    SWP_FRAMECHANGED = 0x0020
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    SWP_NOSIZE = 0x0001
    SWP_NOMOVE = 0x0002
    SWP_SHOWWINDOW = 0x0040
    SW_HIDE = 0
    SW_SHOW = 5

    # Function signatures
    user32.SetParent.argtypes = [wintypes.HWND, wintypes.HWND]
    user32.SetParent.restype = wintypes.HWND
    user32.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.GetWindowLongW.restype = wintypes.LONG
    user32.SetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.LONG]
    user32.SetWindowLongW.restype = wintypes.LONG
    user32.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.UINT]
    user32.SetWindowPos.restype = wintypes.BOOL
    user32.MoveWindow.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.BOOL]
    user32.MoveWindow.restype = wintypes.BOOL
    user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.ShowWindow.restype = wintypes.BOOL
    user32.IsWindow.argtypes = [wintypes.HWND]
    user32.IsWindow.restype = wintypes.BOOL
    user32.GetParent.argtypes = [wintypes.HWND]
    user32.GetParent.restype = wintypes.HWND

    class RECT(ctypes.Structure):
        _fields_ = [
            ("left", wintypes.LONG),
            ("top", wintypes.LONG),
            ("right", wintypes.LONG),
            ("bottom", wintypes.LONG),
        ]

    user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(RECT)]
    user32.GetClientRect.restype = wintypes.BOOL


class EmbeddedScrcpyItem(QQuickItem):
    """
    A QQuickItem that embeds a scrcpy window.

    The item connects to PhoneMirrorManager to receive the window handle
    and handles embedding and position updates.
    """

    # Signals
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._scrcpy_hwnd: Optional[int] = None
        self._embedded = False
        self._manager = None
        self._parent_hwnd: Optional[int] = None
        self._is_hidden = False  # Track if we've hidden the window (for detach/reattach)

        # Update timer for repositioning embedded window
        self._update_timer = QTimer(self)
        self._update_timer.timeout.connect(self._update_embedded_window)

        # Connect to geometry changes
        self.widthChanged.connect(self._update_embedded_window)
        self.heightChanged.connect(self._update_embedded_window)
        self.xChanged.connect(self._update_embedded_window)
        self.yChanged.connect(self._update_embedded_window)

    @Property(bool, notify=streamStarted)
    def isStreaming(self) -> bool:
        return self._embedded and self._scrcpy_hwnd is not None and not self._is_hidden

    def _get_qt_window_handle(self) -> int:
        """Get the native window handle of the Qt window containing this item."""
        item = self
        while item:
            if hasattr(item, 'window') and callable(item.window):
                qwindow = item.window()
                if qwindow:
                    return int(qwindow.winId())
            item = item.parentItem()
        return 0

    @Slot(QObject)
    def connectToManager(self, manager):
        """Connect to the PhoneMirrorManager to receive window handle signals."""
        if self._manager:
            try:
                self._manager.scrcpyStarted.disconnect(self._on_scrcpy_started)
                self._manager.scrcpyStopped.disconnect(self._on_scrcpy_stopped)
                self._manager.scrcpyError.disconnect(self._on_scrcpy_error)
            except:
                pass

        self._manager = manager
        if manager:
            logger.debug("Connecting to manager")
            manager.scrcpyStarted.connect(self._on_scrcpy_started, Qt.QueuedConnection)
            manager.scrcpyStopped.connect(self._on_scrcpy_stopped, Qt.QueuedConnection)
            manager.scrcpyError.connect(self._on_scrcpy_error, Qt.QueuedConnection)

            # If manager already has a running scrcpy, embed it
            if manager.isRunning and manager.scrcpyWindowHandle:
                logger.debug(f" Manager already has scrcpy running, hwnd={manager.scrcpyWindowHandle}")
                QTimer.singleShot(100, lambda: self._embed_or_show(manager.scrcpyWindowHandle))

    def _embed_or_show(self, hwnd: int):
        """Either embed a new window or show an already-embedded one."""
        if platform.system() != "Windows":
            return

        if not user32.IsWindow(hwnd):
            logger.debug("Window no longer exists")
            self.errorOccurred.emit("scrcpy window no longer exists")
            return

        self._parent_hwnd = self._get_qt_window_handle()
        if not self._parent_hwnd:
            logger.debug("Could not get parent window handle")
            self.errorOccurred.emit("Could not get parent window handle")
            return

        # Check current parent
        current_parent = user32.GetParent(hwnd)

        # Always ensure it's parented to us
        if current_parent != self._parent_hwnd:
            logger.debug(f" Embedding window {hwnd} into {self._parent_hwnd}")

            # Hide first
            user32.ShowWindow(hwnd, SW_HIDE)

            # Remove window decorations and make it a child
            style = user32.GetWindowLongW(hwnd, GWL_STYLE)
            style = style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER)
            style = style | WS_CHILD | WS_VISIBLE
            user32.SetWindowLongW(hwnd, GWL_STYLE, style)

            # Remove from taskbar
            ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            ex_style = (ex_style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style)

            # Set parent
            user32.SetParent(hwnd, self._parent_hwnd)
        else:
            logger.debug(f" Window {hwnd} already parented correctly, just showing")

        self._scrcpy_hwnd = hwnd
        self._embedded = True
        self._is_hidden = False

        # Get dimensions
        scene_pos = self.mapToScene(QPointF(0, 0))
        x = int(scene_pos.x())
        y = int(scene_pos.y())
        width = int(self.width())
        height = int(self.height())

        logger.debug(f" Positioning window at ({x}, {y}) size {width}x{height}")

        # Position and resize explicitly
        if width > 0 and height > 0:
            user32.MoveWindow(hwnd, x, y, width, height, True)

        # Show the window
        user32.ShowWindow(hwnd, SW_SHOW)

        # Start update timer for continuous repositioning
        self._update_timer.start(16)

        self.streamStarted.emit()
        logger.debug("Window embedded/shown successfully")

    @Slot(int)
    def _on_scrcpy_started(self, hwnd: int):
        """Called when manager reports scrcpy window is ready."""
        logger.debug(f" Received scrcpy started signal, hwnd={hwnd}")

        if platform.system() != "Windows":
            return

        # Hide window immediately to prevent flicker
        user32.ShowWindow(hwnd, SW_HIDE)
        user32.SetWindowPos(hwnd, 0, -5000, -5000, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)

        # Wait a moment for window to be ready, then embed
        self._scrcpy_hwnd = hwnd
        QTimer.singleShot(200, lambda: self._embed_or_show(hwnd))

    @Slot()
    def _on_scrcpy_stopped(self):
        """Called when manager reports scrcpy stopped."""
        logger.debug("scrcpy stopped")
        self._cleanup()
        self.streamStopped.emit()

    @Slot(str)
    def _on_scrcpy_error(self, error: str):
        """Called when manager reports an error."""
        logger.debug(f" Error: {error}")
        self._cleanup()
        self.errorOccurred.emit(error)

    def _cleanup(self):
        """Full cleanup - scrcpy process has stopped."""
        self._update_timer.stop()
        self._scrcpy_hwnd = None
        self._embedded = False
        self._parent_hwnd = None
        self._is_hidden = False

    @Slot()
    def _update_embedded_window(self):
        """Update the position/size of the embedded window."""
        if not self._scrcpy_hwnd or not self._embedded or self._is_hidden:
            return

        if platform.system() != "Windows":
            return

        # Get our position in window coordinates
        scene_pos = self.mapToScene(QPointF(0, 0))

        x = int(scene_pos.x())
        y = int(scene_pos.y())
        width = int(self.width())
        height = int(self.height())

        if width <= 0 or height <= 0:
            return

        # Move and resize the scrcpy window
        user32.MoveWindow(self._scrcpy_hwnd, x, y, width, height, True)

    @Slot()
    def detach(self):
        """Hide the embedded window temporarily (for when view is deactivated)."""
        logger.debug("Detaching (hiding)...")

        self._update_timer.stop()
        self._is_hidden = True

        if platform.system() == "Windows" and self._scrcpy_hwnd and user32.IsWindow(self._scrcpy_hwnd):
            user32.ShowWindow(self._scrcpy_hwnd, SW_HIDE)

    @Slot()
    def reattach(self):
        """Show the embedded window again (for when view is reactivated)."""
        logger.debug("Reattaching (showing)...")

        if self._manager and self._manager.isRunning:
            hwnd = self._manager.scrcpyWindowHandle
            if hwnd:
                # Small delay to let QML layout settle
                QTimer.singleShot(50, lambda: self._embed_or_show(hwnd))
        else:
            logger.debug("No running scrcpy to reattach")

    def componentComplete(self):
        """Called when the QML component is fully loaded."""
        super().componentComplete()
        logger.debug("Component complete")
