"""
Phone Mirror module for OCTAVE.

Provides phone screen mirroring via scrcpy.
"""

from .manager import PhoneMirrorManager
from .scrcpy_host import ScrcpyHostItem
from .scrcpy_capture import ScrcpyCapture, ScrcpyCaptureItem, ScrcpyFrameProvider

# Legacy export for backwards compatibility
EmbeddedScrcpyItem = ScrcpyHostItem

__all__ = [
    'PhoneMirrorManager',
    'ScrcpyHostItem',
    'EmbeddedScrcpyItem',
    'ScrcpyCapture',
    'ScrcpyCaptureItem',
    'ScrcpyFrameProvider',
]
