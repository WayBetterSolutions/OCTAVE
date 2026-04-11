"""
Embedded DHU Widget for QML.

A QQuickItem that embeds the DHU window as a child window inside OCTAVE.
This makes Android Auto appear seamlessly as part of the OCTAVE interface.
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
    WS_SYSMENU = 0x00080000
    WS_MINIMIZEBOX = 0x00020000
    WS_MAXIMIZEBOX = 0x00010000
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
    SW_RESTORE = 9

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


class EmbeddedDhuItem(QQuickItem):
    """
    A QQuickItem that embeds the DHU window.

    The item connects to AndroidAutoManager to receive the window handle
    and handles embedding and position updates.
    """

    # Signals
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._dhu_hwnd: Optional[int] = None
        self._embedded = False
        self._manager = None
        self._parent_hwnd: Optional[int] = None
        self._is_hidden = False

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
        return self._embedded and self._dhu_hwnd is not None and not self._is_hidden

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
        """Connect to the AndroidAutoManager to receive window handle signals."""
        if self._manager:
            try:
                self._manager.dhuWindowReady.disconnect(self._on_dhu_started)
                self._manager.dhuEmbeddedChanged.disconnect(self._on_dhu_state_changed)
            except (RuntimeError, TypeError):
                pass  # Signals may already be disconnected

        self._manager = manager
        if manager:
            logger.debug("Connecting to manager")
            manager.dhuWindowReady.connect(self._on_dhu_started, Qt.QueuedConnection)
            manager.dhuEmbeddedChanged.connect(self._on_dhu_state_changed, Qt.QueuedConnection)

            # If manager already has a running DHU, embed it
            if manager.isDhuEmbedded and manager.dhuWindowHandle:
                logger.debug(f"Manager already has DHU running, hwnd={manager.dhuWindowHandle}")
                QTimer.singleShot(100, lambda: self._embed_window(manager.dhuWindowHandle))

    def _embed_window(self, hwnd: int):
        """Embed the DHU window as a child of OCTAVE."""
        if platform.system() != "Windows":
            return

        if not user32.IsWindow(hwnd):
            logger.debug("Window no longer exists")
            self.errorOccurred.emit("DHU window no longer exists")
            return

        self._parent_hwnd = self._get_qt_window_handle()
        if not self._parent_hwnd:
            logger.debug("Could not get parent window handle")
            self.errorOccurred.emit("Could not get parent window handle")
            return

        # Check current parent
        current_parent = user32.GetParent(hwnd)

        # Embed if not already parented to us
        if current_parent != self._parent_hwnd:
            logger.debug(f"Embedding window {hwnd} into {self._parent_hwnd}")

            # First restore from minimized if needed
            user32.ShowWindow(hwnd, SW_RESTORE)

            # Hide first to prevent flicker
            user32.ShowWindow(hwnd, SW_HIDE)

            # Remove window decorations and make it a child
            style = user32.GetWindowLongW(hwnd, GWL_STYLE)
            style = style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)
            style = style | WS_CHILD | WS_VISIBLE
            user32.SetWindowLongW(hwnd, GWL_STYLE, style)

            # Remove from taskbar
            ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            ex_style = (ex_style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style)

            # Set parent - this is the key step that embeds the window
            user32.SetParent(hwnd, self._parent_hwnd)

            # Apply style changes
            user32.SetWindowPos(hwnd, 0, 0, 0, 0, 0,
                               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED)
        else:
            logger.debug(f"Window {hwnd} already parented correctly, just showing")

        self._dhu_hwnd = hwnd
        self._embedded = True
        self._is_hidden = False

        # Get dimensions
        scene_pos = self.mapToScene(QPointF(0, 0))
        x = int(scene_pos.x())
        y = int(scene_pos.y())
        width = int(self.width())
        height = int(self.height())

        logger.debug(f"Positioning window at ({x}, {y}) size {width}x{height}")

        # Position and resize
        if width > 0 and height > 0:
            user32.MoveWindow(hwnd, x, y, width, height, True)

        # Show the window
        user32.ShowWindow(hwnd, SW_SHOW)

        # Start update timer for continuous repositioning
        self._update_timer.start(16)  # ~60fps updates

        self.streamStarted.emit()
        logger.debug("Window embedded successfully")

    @Slot(int)
    def _on_dhu_started(self, hwnd: int):
        """Called when manager reports DHU window is ready."""
        logger.debug(f"Received DHU started signal, hwnd={hwnd}")

        if platform.system() != "Windows":
            return

        # Hide window immediately to prevent flicker
        user32.ShowWindow(hwnd, SW_HIDE)

        # Wait a moment for window to be ready, then embed
        self._dhu_hwnd = hwnd
        QTimer.singleShot(200, lambda: self._embed_window(hwnd))

    @Slot(bool)
    def _on_dhu_state_changed(self, embedded: bool):
        """Called when manager reports DHU embedding state changed."""
        if not embedded:
            logger.debug("DHU stopped")
            self._cleanup()
            self.streamStopped.emit()

    def _cleanup(self):
        """Full cleanup - DHU process has stopped."""
        self._update_timer.stop()
        self._dhu_hwnd = None
        self._embedded = False
        self._parent_hwnd = None
        self._is_hidden = False

    @Slot()
    def _update_embedded_window(self):
        """Update the position/size of the embedded window."""
        if not self._dhu_hwnd or not self._embedded or self._is_hidden:
            return

        if platform.system() != "Windows":
            return

        if not user32.IsWindow(self._dhu_hwnd):
            logger.debug("Window no longer exists, cleaning up")
            self._cleanup()
            self.streamStopped.emit()
            return

        # Get our position in window coordinates
        scene_pos = self.mapToScene(QPointF(0, 0))

        x = int(scene_pos.x())
        y = int(scene_pos.y())
        width = int(self.width())
        height = int(self.height())

        if width <= 0 or height <= 0:
            return

        # Move and resize the DHU window
        user32.MoveWindow(self._dhu_hwnd, x, y, width, height, True)

    @Slot()
    def detach(self):
        """Hide the embedded window temporarily (for when view is deactivated)."""
        logger.debug("Detaching (hiding)...")

        self._update_timer.stop()
        self._is_hidden = True

        if platform.system() == "Windows" and self._dhu_hwnd and user32.IsWindow(self._dhu_hwnd):
            user32.ShowWindow(self._dhu_hwnd, SW_HIDE)

    @Slot()
    def reattach(self):
        """Show the embedded window again (for when view is reactivated)."""
        logger.debug("Reattaching (showing)...")

        if self._manager and self._manager.isDhuEmbedded:
            hwnd = self._manager.dhuWindowHandle
            if hwnd:
                # Small delay to let QML layout settle
                QTimer.singleShot(50, lambda: self._embed_window(hwnd))
        else:
            logger.debug("No running DHU to reattach")

    def componentComplete(self):
        """Called when the QML component is fully loaded."""
        super().componentComplete()
        logger.debug("Component complete")
