"""
Platform detection for OCTAVE Android port.

All platform-conditional code should import IS_ANDROID from here
rather than doing its own detection.
"""

import sys
import os

IS_ANDROID = hasattr(sys, 'getandroidapilevel') or 'ANDROID_ROOT' in os.environ


def get_android_data_dir():
    """Return Android-appropriate app data directory.

    On Android via PySide6, the working directory is set to the app's
    internal files directory. We create an OCTAVE subdirectory there.
    """
    data_dir = os.path.join(os.getcwd(), "OCTAVE")
    os.makedirs(data_dir, exist_ok=True)
    return data_dir


def get_android_media_dir():
    """Return default music directory on Android.

    Uses /sdcard/Music/ which is accessible on rooted devices.
    """
    media_dir = "/sdcard/Music"
    os.makedirs(media_dir, exist_ok=True)
    return media_dir
