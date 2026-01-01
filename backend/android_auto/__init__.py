"""
OCTAVE Android Auto Module

This module implements the Android Auto Protocol (AAP) for head unit integration.
It provides:
- USB/TCP transport layer for phone connection
- Protocol Buffer message handling
- H.264 video stream decoding
- Audio channel management
- Touch input forwarding
- Sensor data integration (connects to OBD manager)

Architecture:
- Phase 1 (Current): Pure Python implementation of AAP
- Phase 2 (Future): Performance optimization with optional C++ bindings

Usage:
    from backend.android_auto import AndroidAutoManager

    manager = AndroidAutoManager()
    manager.stateChanged.connect(on_state_change)
    manager.videoFrameReady.connect(on_video_frame)
    manager.start()

Author: OCTAVE Team
License: GPLv3
"""

__version__ = "0.1.0"

from .manager import AndroidAutoManager, HeadUnitInfo, AndroidAutoState, TransportMode
from .usb_transport import USBTransport, USBDevice, DeviceState
from .tcp_transport import TCPTransport, TCPState
from .message import Message, MessageAssembler, MessageRouter, FrameHeader
from .video_decoder import VideoDecoder, VideoFrameProvider
from .window_container import WindowContainer
from .dhu_capture import DhuCapture, DhuFrameProvider
from .constants import (
    ChannelId,
    VideoResolution,
    VideoFrameRate,
    AudioStreamType,
    AccessoryInfo,
)

__all__ = [
    # Main manager
    "AndroidAutoManager",
    "HeadUnitInfo",
    "AndroidAutoState",
    "TransportMode",

    # Transport
    "USBTransport",
    "USBDevice",
    "DeviceState",
    "TCPTransport",
    "TCPState",

    # Messaging
    "Message",
    "MessageAssembler",
    "MessageRouter",
    "FrameHeader",

    # Video
    "VideoDecoder",
    "VideoFrameProvider",

    # Window embedding
    "WindowContainer",

    # DHU capture
    "DhuCapture",
    "DhuFrameProvider",

    # Constants
    "ChannelId",
    "VideoResolution",
    "VideoFrameRate",
    "AudioStreamType",
    "AccessoryInfo",
]
