"""
Window Container for embedding external windows in Qt/QML.

This module provides a QQuickItem that can embed external Windows applications
(like Google DHU) into a QML interface.
"""

import platform
from typing import Optional

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtGui import QWindow
from PySide6.QtQuick import QQuickItem
from PySide6.QtWidgets import QWidget

if platform.system() == "Windows":
    import ctypes
    from ctypes import wintypes

    # Windows API constants
    GWL_STYLE = -16
    GWL_EXSTYLE = -20
    WS_CHILD = 0x40000000
    WS_POPUP = 0x80000000
    WS_CAPTION = 0x00C00000
    WS_THICKFRAME = 0x00040000
    WS_BORDER = 0x00800000
    WS_SYSMENU = 0x00080000
    WS_MAXIMIZEBOX = 0x00010000
    WS_MINIMIZEBOX = 0x00020000
    WS_EX_WINDOWEDGE = 0x00000100
    WS_EX_CLIENTEDGE = 0x00000200
    WS_EX_DLGMODALFRAME = 0x00000001
    SWP_FRAMECHANGED = 0x0020
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    SWP_SHOWWINDOW = 0x0040

    user32 = ctypes.windll.user32


class WindowContainer(QQuickItem):
    """
    A QQuickItem that can embed an external window by its handle.

    Usage in QML:
        WindowContainer {
            id: dhuContainer
            anchors.fill: parent
            windowHandle: androidAutoManager.dhuWindowHandle
        }
    """

    windowHandleChanged = Signal(int)
    embeddedChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._window_handle: int = 0
        self._embedded = False
        self._original_style: int = 0
        self._original_ex_style: int = 0
        self._original_parent: int = 0
        self._container_window: Optional[QWindow] = None

        # Connect to geometry changes
        self.widthChanged.connect(self._update_embedded_window)
        self.heightChanged.connect(self._update_embedded_window)
        self.xChanged.connect(self._update_embedded_window)
        self.yChanged.connect(self._update_embedded_window)
        self.visibleChanged.connect(self._on_visible_changed)

    def _get_window_handle(self) -> int:
        return self._window_handle

    def _set_window_handle(self, hwnd: int):
        if self._window_handle != hwnd:
            # Unembed old window if any
            if self._embedded:
                self._unembed_window()

            self._window_handle = hwnd
            self.windowHandleChanged.emit(hwnd)

            # Embed new window
            if hwnd and self.isVisible():
                QTimer.singleShot(100, self._embed_window)

    windowHandle = Property(int, _get_window_handle, _set_window_handle, notify=windowHandleChanged)

    @Property(bool, notify=embeddedChanged)
    def isEmbedded(self) -> bool:
        return self._embedded

    def _get_qt_window_handle(self) -> int:
        """Get the native window handle of our Qt window."""
        item = self
        while item:
            if hasattr(item, 'window') and callable(item.window):
                qwindow = item.window()
                if qwindow:
                    return int(qwindow.winId())
            item = item.parentItem()
        return 0

    @Slot()
    def _embed_window(self):
        """Embed the external window as a child of our Qt window."""
        if platform.system() != "Windows":
            print("[WindowContainer] Window embedding only supported on Windows")
            return

        if not self._window_handle:
            return

        try:
            hwnd = self._window_handle
            parent_hwnd = self._get_qt_window_handle()

            if not parent_hwnd:
                print("[WindowContainer] Could not get parent window handle")
                return

            print(f"[WindowContainer] Embedding window {hwnd} into {parent_hwnd}")

            # Save original window style
            self._original_style = user32.GetWindowLongW(hwnd, GWL_STYLE)
            self._original_ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            self._original_parent = user32.GetParent(hwnd)

            # Remove window decorations and make it a child window
            new_style = self._original_style
            new_style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER | WS_SYSMENU | WS_MAXIMIZEBOX | WS_MINIMIZEBOX)
            new_style |= WS_CHILD

            new_ex_style = self._original_ex_style
            new_ex_style &= ~(WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_DLGMODALFRAME)

            user32.SetWindowLongW(hwnd, GWL_STYLE, new_style)
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, new_ex_style)

            # Set parent window
            user32.SetParent(hwnd, parent_hwnd)

            # Position and size the window
            self._update_embedded_window()

            self._embedded = True
            self.embeddedChanged.emit(True)
            print(f"[WindowContainer] Window embedded successfully")

        except Exception as e:
            print(f"[WindowContainer] Error embedding window: {e}")
            import traceback
            traceback.print_exc()

    def _unembed_window(self):
        """Restore the window to its original state."""
        if platform.system() != "Windows":
            return

        if not self._window_handle or not self._embedded:
            return

        try:
            hwnd = self._window_handle

            # Restore original style
            user32.SetWindowLongW(hwnd, GWL_STYLE, self._original_style)
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, self._original_ex_style)

            # Restore original parent
            user32.SetParent(hwnd, self._original_parent)

            # Trigger redraw
            user32.SetWindowPos(
                hwnd, 0, 100, 100, 800, 600,
                SWP_FRAMECHANGED | SWP_NOZORDER | SWP_SHOWWINDOW
            )

            self._embedded = False
            self.embeddedChanged.emit(False)
            print(f"[WindowContainer] Window unembedded")

        except Exception as e:
            print(f"[WindowContainer] Error unembedding window: {e}")

    @Slot()
    def _update_embedded_window(self):
        """Update the position and size of the embedded window."""
        if platform.system() != "Windows":
            return

        if not self._window_handle or not self._embedded:
            return

        try:
            # Get our position in window coordinates
            scene_pos = self.mapToScene(self.position())
            x = int(scene_pos.x())
            y = int(scene_pos.y())
            width = int(self.width())
            height = int(self.height())

            if width > 0 and height > 0:
                user32.SetWindowPos(
                    self._window_handle, 0,
                    x, y, width, height,
                    SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW
                )

        except Exception as e:
            print(f"[WindowContainer] Error updating window position: {e}")

    def _on_visible_changed(self):
        """Handle visibility changes."""
        if self.isVisible() and self._window_handle and not self._embedded:
            QTimer.singleShot(100, self._embed_window)
        elif not self.isVisible() and self._embedded:
            # Hide the embedded window
            if platform.system() == "Windows" and self._window_handle:
                user32.ShowWindow(self._window_handle, 0)  # SW_HIDE

    def componentComplete(self):
        """Called when the QML component is fully loaded."""
        super().componentComplete()
        if self._window_handle and self.isVisible():
            QTimer.singleShot(500, self._embed_window)
