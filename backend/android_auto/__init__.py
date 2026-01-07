"""
OCTAVE Android Auto Module (DHU Mode)

This module provides Android Auto integration using Google's Desktop Head Unit (DHU).
The DHU handles all protocol communication - we launch it, embed its window,
and forward user input.

Usage:
    from backend.android_auto import AndroidAutoManager, EmbeddedDhuItem

    manager = AndroidAutoManager()
    manager.launchDhuSeamless()  # Launch DHU
    # Use EmbeddedDhuItem in QML to embed the DHU window
"""

__version__ = "1.0.0"

from .manager import AndroidAutoManager
from .dhu_capture import DhuCapture, DhuFrameProvider
from .embedded_dhu import EmbeddedDhuItem

__all__ = [
    "AndroidAutoManager",
    "DhuCapture",
    "DhuFrameProvider",
    "EmbeddedDhuItem",
]
