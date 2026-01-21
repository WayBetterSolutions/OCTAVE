"""
Scrcpy Container Widget for OCTAVE.

A QWidget-based container that hosts scrcpy as a child window.
Uses WA_NativeWindow to get its own native window handle for proper clipping.
"""

import platform
from typing import Optional

from PySide6.QtCore import Qt, Signal, Slot, QTimer
from PySide6.QtWidgets import QWidget

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
    WS_CLIPSIBLINGS = 0x04000000
    WS_CLIPCHILDREN = 0x02000000
    WS_EX_APPWINDOW = 0x00040000
    WS_EX_TOOLWINDOW = 0x00000080
    SWP_FRAMECHANGED = 0x0020
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    SW_HIDE = 0
    SW_SHOW = 5

    # Function signatures
    user32.SetParent.argtypes = [wintypes.HWND, wintypes.HWND]
    user32.SetParent.restype = wintypes.HWND
    user32.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.GetWindowLongW.restype = wintypes.LONG
    user32.SetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.LONG]
    user32.SetWindowLongW.restype = wintypes.LONG
    user32.MoveWindow.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.BOOL]
    user32.MoveWindow.restype = wintypes.BOOL
    user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.ShowWindow.restype = wintypes.BOOL
    user32.IsWindow.argtypes = [wintypes.HWND]
    user32.IsWindow.restype = wintypes.BOOL
    user32.GetParent.argtypes = [wintypes.HWND]
    user32.GetParent.restype = wintypes.HWND
    user32.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.UINT]
    user32.SetWindowPos.restype = wintypes.BOOL


class ScrcpyContainerWidget(QWidget):
    """
    A QWidget that hosts scrcpy as a child window.

    This widget has WA_NativeWindow set, giving it its own native window handle.
    When scrcpy is set as a child of this widget's handle, it gets proper
    clipping and positioning within the widget bounds.
    """

    # Signals
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        # Critical: This gives us our own native window handle
        self.setAttribute(Qt.WA_NativeWindow, True)
        self.setAttribute(Qt.WA_DontCreateNativeAncestors, True)

        # Make background black
        self.setAutoFillBackground(True)
        palette = self.palette()
        palette.setColor(self.backgroundRole(), Qt.black)
        self.setPalette(palette)

        self._scrcpy_hwnd: Optional[int] = None
        self._embedded = False
        self._manager = None
        self._container_hwnd: Optional[int] = None

        # Timer for continuous position updates
        self._update_timer = QTimer(self)
        self._update_timer.timeout.connect(self._update_scrcpy_position)

        logger.debug("Widget created")

    def showEvent(self, event):
        """Called when widget becomes visible."""
        super().showEvent(event)
        logger.debug(f" Show event, size: {self.width()}x{self.height()}")

        # Get our native window handle
        self._container_hwnd = int(self.winId())
        logger.debug(f" Container HWND: {self._container_hwnd}")

        # If we have a pending scrcpy window, embed it now
        if self._scrcpy_hwnd and not self._embedded:
            QTimer.singleShot(100, self._embed_scrcpy)

    def hideEvent(self, event):
        """Called when widget is hidden."""
        super().hideEvent(event)
        logger.debug("Hide event")
        self._update_timer.stop()

        # Hide scrcpy window but don't detach it
        if platform.system() == "Windows" and self._scrcpy_hwnd:
            if user32.IsWindow(self._scrcpy_hwnd):
                user32.ShowWindow(self._scrcpy_hwnd, SW_HIDE)

    def resizeEvent(self, event):
        """Called when widget is resized."""
        super().resizeEvent(event)
        self._update_scrcpy_position()

    def connectToManager(self, manager):
        """Connect to PhoneMirrorManager to receive window handle signals."""
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

            # If manager already has running scrcpy, embed it
            if manager.isRunning and manager.scrcpyWindowHandle:
                logger.debug(f" Manager has running scrcpy, hwnd={manager.scrcpyWindowHandle}")
                self._scrcpy_hwnd = manager.scrcpyWindowHandle
                QTimer.singleShot(100, self._embed_scrcpy)

    @Slot(int)
    def _on_scrcpy_started(self, hwnd: int):
        """Called when manager reports scrcpy window is ready."""
        logger.debug(f" Scrcpy started signal, hwnd={hwnd}")

        if platform.system() != "Windows":
            return

        # Hide and move off-screen immediately to prevent flicker
        user32.ShowWindow(hwnd, SW_HIDE)

        self._scrcpy_hwnd = hwnd

        # Wait a moment then embed
        QTimer.singleShot(200, self._embed_scrcpy)

    def _embed_scrcpy(self):
        """Embed the scrcpy window into this container."""
        if platform.system() != "Windows":
            return

        if not self._scrcpy_hwnd:
            logger.debug("No scrcpy hwnd to embed")
            return

        if not user32.IsWindow(self._scrcpy_hwnd):
            logger.debug("Scrcpy window no longer exists")
            self._scrcpy_hwnd = None
            self.errorOccurred.emit("scrcpy window no longer exists")
            return

        # Get our container's native window handle
        if not self._container_hwnd:
            self._container_hwnd = int(self.winId())

        if not self._container_hwnd:
            logger.debug("Could not get container window handle")
            self.errorOccurred.emit("Could not get container window handle")
            return

        logger.debug(f" Embedding scrcpy {self._scrcpy_hwnd} into container {self._container_hwnd}")

        # Check if already parented to us
        current_parent = user32.GetParent(self._scrcpy_hwnd)

        if current_parent != self._container_hwnd:
            # Remove window decorations and make it a child
            style = user32.GetWindowLongW(self._scrcpy_hwnd, GWL_STYLE)
            style = style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER)
            style = style | WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_CLIPCHILDREN
            user32.SetWindowLongW(self._scrcpy_hwnd, GWL_STYLE, style)

            # Remove from taskbar
            ex_style = user32.GetWindowLongW(self._scrcpy_hwnd, GWL_EXSTYLE)
            ex_style = (ex_style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
            user32.SetWindowLongW(self._scrcpy_hwnd, GWL_EXSTYLE, ex_style)

            # Set parent to our container
            user32.SetParent(self._scrcpy_hwnd, self._container_hwnd)
            logger.debug("Set parent complete")
        else:
            logger.debug("Already parented to container")

        self._embedded = True

        # Position scrcpy to fill our container
        width = self.width()
        height = self.height()

        logger.debug(f" Positioning scrcpy at (0, 0) size {width}x{height}")

        if width > 0 and height > 0:
            user32.MoveWindow(self._scrcpy_hwnd, 0, 0, width, height, True)

        # Show the window
        user32.ShowWindow(self._scrcpy_hwnd, SW_SHOW)

        # Start position update timer
        self._update_timer.start(16)  # ~60fps updates

        self.streamStarted.emit()
        logger.debug("Scrcpy embedded successfully")

    def _update_scrcpy_position(self):
        """Update scrcpy position to fill container."""
        if not self._scrcpy_hwnd or not self._embedded:
            return

        if platform.system() != "Windows":
            return

        if not user32.IsWindow(self._scrcpy_hwnd):
            logger.debug("Scrcpy window disappeared")
            self._cleanup()
            self.streamStopped.emit()
            return

        width = self.width()
        height = self.height()

        if width > 0 and height > 0:
            # Position at (0,0) relative to container - container handles the global positioning
            user32.MoveWindow(self._scrcpy_hwnd, 0, 0, width, height, True)

    @Slot()
    def _on_scrcpy_stopped(self):
        """Called when manager reports scrcpy stopped."""
        logger.debug("Scrcpy stopped")
        self._cleanup()
        self.streamStopped.emit()

    @Slot(str)
    def _on_scrcpy_error(self, error: str):
        """Called when manager reports an error."""
        logger.debug(f" Error: {error}")
        self._cleanup()
        self.errorOccurred.emit(error)

    def _cleanup(self):
        """Clean up when scrcpy stops."""
        self._update_timer.stop()
        self._scrcpy_hwnd = None
        self._embedded = False

    def detach(self):
        """Hide the scrcpy window (for when view is deactivated)."""
        logger.debug("Detaching...")
        self._update_timer.stop()

        if platform.system() == "Windows" and self._scrcpy_hwnd:
            if user32.IsWindow(self._scrcpy_hwnd):
                user32.ShowWindow(self._scrcpy_hwnd, SW_HIDE)

    def reattach(self):
        """Show the scrcpy window again (for when view is reactivated)."""
        logger.debug("Reattaching...")

        if self._manager and self._manager.isRunning:
            hwnd = self._manager.scrcpyWindowHandle
            if hwnd:
                self._scrcpy_hwnd = hwnd
                QTimer.singleShot(50, self._embed_scrcpy)
        else:
            logger.debug("No running scrcpy to reattach")

    @property
    def isStreaming(self) -> bool:
        """Check if scrcpy is currently streaming."""
        return self._embedded and self._scrcpy_hwnd is not None
