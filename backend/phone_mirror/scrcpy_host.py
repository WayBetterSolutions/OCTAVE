"""
Scrcpy Host for OCTAVE.

This module provides a QQuickItem that manages a floating QWidget overlay
for hosting the scrcpy window. The widget positions itself to match the
QQuickItem's position in the main window.
"""

import platform
from typing import Optional

from PySide6.QtCore import Qt, Signal, Slot, Property, QTimer, QPointF, QPoint, QObject
from PySide6.QtWidgets import QWidget, QApplication
from PySide6.QtQuick import QQuickItem
from PySide6.QtGui import QWindow

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
    WS_EX_NOACTIVATE = 0x08000000
    WS_EX_LAYERED = 0x00080000
    SW_HIDE = 0
    SW_SHOW = 5
    SW_SHOWNOACTIVATE = 4
    HWND_TOP = 0
    HWND_TOPMOST = -1
    SWP_NOACTIVATE = 0x0010
    SWP_NOZORDER = 0x0004
    SWP_SHOWWINDOW = 0x0040
    SWP_FRAMECHANGED = 0x0020

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
    user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.c_void_p]
    user32.GetWindowRect.restype = wintypes.BOOL
    user32.InvalidateRect.argtypes = [wintypes.HWND, ctypes.c_void_p, wintypes.BOOL]
    user32.InvalidateRect.restype = wintypes.BOOL
    user32.UpdateWindow.argtypes = [wintypes.HWND]
    user32.UpdateWindow.restype = wintypes.BOOL
    user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.SendMessageW.restype = wintypes.LPARAM
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.PostMessageW.restype = wintypes.BOOL

    # Window messages
    WM_SIZE = 0x0005
    WM_SIZING = 0x0214
    SIZE_RESTORED = 0

    class RECT(ctypes.Structure):
        _fields_ = [
            ("left", wintypes.LONG),
            ("top", wintypes.LONG),
            ("right", wintypes.LONG),
            ("bottom", wintypes.LONG),
        ]


class ScrcpyHostWidget(QWidget):
    """
    A frameless QWidget that hosts the scrcpy window.

    This widget has its own native window handle via WA_NativeWindow.
    Scrcpy is embedded as a child of this widget, providing proper clipping.
    """

    def __init__(self, parent=None):
        super().__init__(parent)

        # Critical: Get our own native window handle
        self.setAttribute(Qt.WA_NativeWindow, True)
        self.setAttribute(Qt.WA_DontCreateNativeAncestors, True)
        self.setAttribute(Qt.WA_ShowWithoutActivating, True)

        # Frameless tool window (no taskbar) - removed WindowStaysOnTopHint
        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.Tool
        )

        # Black background
        self.setAutoFillBackground(True)
        palette = self.palette()
        palette.setColor(self.backgroundRole(), Qt.black)
        self.setPalette(palette)

        self._scrcpy_hwnd: Optional[int] = None
        self._embedded = False
        self._host_hwnd: Optional[int] = None
        self._last_size = (0, 0)  # Track size changes

        print("[ScrcpyHost] Widget created")

    def showEvent(self, event):
        super().showEvent(event)
        self._host_hwnd = int(self.winId())
        print(f"[ScrcpyHost] Show event, hwnd={self._host_hwnd}, size={self.width()}x{self.height()}")

        # Embed pending scrcpy
        if self._scrcpy_hwnd and not self._embedded:
            QTimer.singleShot(50, self._embed_scrcpy)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._update_scrcpy_size()

    def embed_scrcpy(self, hwnd: int):
        """Set the scrcpy window handle to embed."""
        print(f"[ScrcpyHost] Request to embed scrcpy hwnd={hwnd}")
        self._scrcpy_hwnd = hwnd

        if self.isVisible() and self._host_hwnd:
            QTimer.singleShot(50, self._embed_scrcpy)

    def _embed_scrcpy(self):
        """Actually embed the scrcpy window."""
        if platform.system() != "Windows":
            return

        if not self._scrcpy_hwnd:
            return

        if not user32.IsWindow(self._scrcpy_hwnd):
            print("[ScrcpyHost] Scrcpy window no longer exists")
            self._scrcpy_hwnd = None
            return

        if not self._host_hwnd:
            self._host_hwnd = int(self.winId())

        if not self._host_hwnd:
            print("[ScrcpyHost] No host hwnd available")
            return

        print(f"[ScrcpyHost] Embedding scrcpy {self._scrcpy_hwnd} into host {self._host_hwnd}")

        # Check if already our child
        current_parent = user32.GetParent(self._scrcpy_hwnd)

        if current_parent != self._host_hwnd:
            # Remove decorations and make child
            style = user32.GetWindowLongW(self._scrcpy_hwnd, GWL_STYLE)
            style = style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER)
            style = style | WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_CLIPCHILDREN
            user32.SetWindowLongW(self._scrcpy_hwnd, GWL_STYLE, style)

            # Remove from taskbar
            ex_style = user32.GetWindowLongW(self._scrcpy_hwnd, GWL_EXSTYLE)
            ex_style = (ex_style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
            user32.SetWindowLongW(self._scrcpy_hwnd, GWL_EXSTYLE, ex_style)

            # Set parent
            user32.SetParent(self._scrcpy_hwnd, self._host_hwnd)

        self._embedded = True

        # Get size
        w = self.width()
        h = self.height()

        if w > 0 and h > 0:
            # Position and size the window
            user32.SetWindowPos(
                self._scrcpy_hwnd,
                0,  # HWND_TOP
                0, 0, w, h,
                SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
            )

            # Send WM_SIZE message to notify SDL
            lparam = (h << 16) | (w & 0xFFFF)
            user32.PostMessageW(self._scrcpy_hwnd, WM_SIZE, SIZE_RESTORED, lparam)

            self._last_size = (w, h)

        # Show scrcpy
        user32.ShowWindow(self._scrcpy_hwnd, SW_SHOW)

        print(f"[ScrcpyHost] Scrcpy embedded at size {w}x{h}")

    def _update_scrcpy_size(self):
        """Update scrcpy to fill the host widget."""
        if not self._scrcpy_hwnd or not self._embedded:
            return

        if platform.system() != "Windows":
            return

        if not user32.IsWindow(self._scrcpy_hwnd):
            return

        w = self.width()
        h = self.height()

        # Only update if size actually changed
        if (w, h) == self._last_size:
            return

        self._last_size = (w, h)

        if w > 0 and h > 0:
            # Use SetWindowPos to resize
            user32.SetWindowPos(
                self._scrcpy_hwnd,
                0,  # HWND_TOP
                0, 0, w, h,
                SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
            )

            # Send WM_SIZE message to notify SDL of the resize
            # LPARAM contains width in low word and height in high word
            lparam = (h << 16) | (w & 0xFFFF)
            user32.PostMessageW(self._scrcpy_hwnd, WM_SIZE, SIZE_RESTORED, lparam)

    def hide_scrcpy(self):
        """Hide the scrcpy window."""
        if platform.system() == "Windows" and self._scrcpy_hwnd:
            if user32.IsWindow(self._scrcpy_hwnd):
                user32.ShowWindow(self._scrcpy_hwnd, SW_HIDE)
                # Also move off-screen to be safe
                user32.SetWindowPos(
                    self._scrcpy_hwnd, 0,
                    -10000, -10000, 0, 0,
                    SWP_NOACTIVATE | SWP_NOZORDER | 0x0001  # SWP_NOSIZE = 0x0001
                )

    def show_scrcpy(self):
        """Show the scrcpy window."""
        if platform.system() == "Windows" and self._scrcpy_hwnd and self._embedded:
            if user32.IsWindow(self._scrcpy_hwnd):
                # Reset size tracking so next update resizes properly
                self._last_size = (0, 0)
                # Update size first
                self._update_scrcpy_size()
                # Then show
                user32.ShowWindow(self._scrcpy_hwnd, SW_SHOW)

    def clear_scrcpy(self):
        """Clear the scrcpy reference (process stopped)."""
        self._scrcpy_hwnd = None
        self._embedded = False


class ScrcpyHostItem(QQuickItem):
    """
    A QQuickItem that manages a ScrcpyHostWidget overlay.

    This item doesn't render anything itself - it creates and manages
    a floating QWidget that positions itself to match this item's
    position in the QML scene.
    """

    # Signals
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._host_widget: Optional[ScrcpyHostWidget] = None
        self._manager = None
        self._main_window: Optional[QWindow] = None
        self._is_active = False

        # Timer for position tracking
        self._position_timer = QTimer(self)
        self._position_timer.timeout.connect(self._update_host_position)

        # Connect to geometry changes for immediate updates
        self.widthChanged.connect(self._update_host_position)
        self.heightChanged.connect(self._update_host_position)
        self.xChanged.connect(self._update_host_position)
        self.yChanged.connect(self._update_host_position)
        self.visibleChanged.connect(self._on_visible_changed)

        print("[ScrcpyHostItem] Created")

    def _ensure_host_widget(self):
        """Create the host widget if needed."""
        if self._host_widget is None:
            self._host_widget = ScrcpyHostWidget()
            print("[ScrcpyHostItem] Created host widget")

    def _get_main_window(self) -> Optional[QWindow]:
        """Get the QWindow containing this item."""
        if self._main_window:
            return self._main_window

        item = self
        while item:
            if hasattr(item, 'window') and callable(item.window):
                qwindow = item.window()
                if qwindow:
                    self._main_window = qwindow
                    return qwindow
            item = item.parentItem()
        return None

    @Property(bool, notify=streamStarted)
    def isStreaming(self) -> bool:
        return self._host_widget is not None and self._host_widget._embedded

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
            print("[ScrcpyHostItem] Connecting to manager")
            manager.scrcpyStarted.connect(self._on_scrcpy_started, Qt.QueuedConnection)
            manager.scrcpyStopped.connect(self._on_scrcpy_stopped, Qt.QueuedConnection)
            manager.scrcpyError.connect(self._on_scrcpy_error, Qt.QueuedConnection)

            # If already running, embed it
            if manager.isRunning and manager.scrcpyWindowHandle:
                print(f"[ScrcpyHostItem] Manager has running scrcpy")
                QTimer.singleShot(100, lambda: self._on_scrcpy_started(manager.scrcpyWindowHandle))

    @Slot(int)
    def _on_scrcpy_started(self, hwnd: int):
        """Called when scrcpy window is ready."""
        print(f"[ScrcpyHostItem] Scrcpy started, hwnd={hwnd}")

        if platform.system() != "Windows":
            return

        # Hide immediately to prevent flicker
        user32.ShowWindow(hwnd, SW_HIDE)

        self._ensure_host_widget()

        # Position host widget
        self._update_host_position()

        # Show host widget
        self._host_widget.show()

        # Embed scrcpy into host
        QTimer.singleShot(100, lambda: self._embed_and_show(hwnd))

    def _embed_and_show(self, hwnd: int):
        """Embed scrcpy and show everything."""
        if not self._host_widget:
            return

        self._host_widget.embed_scrcpy(hwnd)
        self._is_active = True

        # Start position tracking
        self._position_timer.start(16)  # ~60fps

        self.streamStarted.emit()
        print("[ScrcpyHostItem] Stream started")

    @Slot()
    def _on_scrcpy_stopped(self):
        """Called when scrcpy stops."""
        print("[ScrcpyHostItem] Scrcpy stopped")
        self._cleanup()
        self.streamStopped.emit()

    @Slot(str)
    def _on_scrcpy_error(self, error: str):
        """Called on scrcpy error."""
        print(f"[ScrcpyHostItem] Error: {error}")
        self._cleanup()
        self.errorOccurred.emit(error)

    def _cleanup(self):
        """Clean up host widget."""
        self._position_timer.stop()
        self._is_active = False

        if self._host_widget:
            self._host_widget.clear_scrcpy()
            self._host_widget.hide()

    def _on_visible_changed(self):
        """Handle visibility changes."""
        if not self._host_widget:
            return

        if self.isVisible() and self._is_active:
            self._update_host_position()
            self._host_widget.show()
            self._host_widget.show_scrcpy()
            self._position_timer.start(16)
        else:
            self._host_widget.hide()
            self._position_timer.stop()

    @Slot()
    def _update_host_position(self):
        """Update host widget position to match this item."""
        if not self._host_widget:
            return

        main_window = self._get_main_window()
        if not main_window:
            return

        # Get item position in scene coordinates
        scene_pos = self.mapToScene(QPointF(0, 0))

        # Get main window position
        window_pos = main_window.position()

        # Calculate global position
        global_x = int(window_pos.x() + scene_pos.x())
        global_y = int(window_pos.y() + scene_pos.y())
        width = int(self.width())
        height = int(self.height())

        if width > 0 and height > 0:
            self._host_widget.setGeometry(global_x, global_y, width, height)

    @Slot()
    def detach(self):
        """Hide when view is deactivated."""
        print("[ScrcpyHostItem] Detaching")
        self._position_timer.stop()

        if self._host_widget:
            self._host_widget.hide()
            self._host_widget.hide_scrcpy()

    @Slot()
    def reattach(self):
        """Show when view is reactivated."""
        print("[ScrcpyHostItem] Reattaching")

        if self._manager and self._manager.isRunning:
            hwnd = self._manager.scrcpyWindowHandle
            if hwnd and self._host_widget:
                self._update_host_position()
                self._host_widget.show()

                # Re-embed if needed
                if not self._host_widget._embedded:
                    self._host_widget.embed_scrcpy(hwnd)
                else:
                    self._host_widget.show_scrcpy()

                self._is_active = True
                self._position_timer.start(16)
                self.streamStarted.emit()
        else:
            print("[ScrcpyHostItem] No running scrcpy to reattach")

    def componentComplete(self):
        """Called when QML component is fully loaded."""
        super().componentComplete()
        print("[ScrcpyHostItem] Component complete")
