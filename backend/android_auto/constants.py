"""
Android Auto Protocol Constants

These constants are derived from the Android Open Accessory Protocol (AOAP)
specification and the aasdk library implementation.
"""

from enum import IntEnum, auto


# USB Vendor and Product IDs
class USBIds:
    """USB Vendor and Product IDs for Android Auto."""
    GOOGLE_VENDOR_ID = 0x18D1
    AOAP_PRODUCT_ID = 0x2D00
    AOAP_WITH_ADB_PRODUCT_ID = 0x2D01


# Android Open Accessory Protocol request codes
class AOAPRequest(IntEnum):
    """AOAP USB control transfer request codes."""
    GET_PROTOCOL = 51
    SEND_STRING = 52
    START = 53


# String type indices for AOAP SEND_STRING request
class AOAPStringType(IntEnum):
    """Index values for AOAP accessory string types."""
    MANUFACTURER = 0
    MODEL = 1
    DESCRIPTION = 2
    VERSION = 3
    URI = 4
    SERIAL = 5


# Accessory identification strings for Android Auto
# These must match what Android Auto expects to trigger the AA app
class AccessoryInfo:
    """Accessory identification strings sent during AOAP handshake."""
    MANUFACTURER = "Android"
    MODEL = "Android Auto"
    DESCRIPTION = "Android Auto"
    VERSION = "2.0.1"
    URI = "https://developer.android.com/auto"
    SERIAL = "HU-AAAAAA001"


# USB constants
class USBConstants:
    """USB protocol constants."""
    TYPE_VENDOR = 0x40
    ENDPOINT_IN = 0x80
    ENDPOINT_OUT = 0x00
    TIMEOUT_MS = 5000  # Increased for slow phone response
    CONTROL_TRANSFER_TIMEOUT_MS = 5000


# AAP Frame constants (from aasdk)
# Frame header format:
#   Byte 0: Channel ID (0-255)
#   Byte 1: Flags = FrameType (bits 0-1) | MessageType (bit 2) | EncryptionType (bit 3)
#   Bytes 2-3: Frame size (uint16 big-endian)
#   Bytes 4-7: Total size (uint32, only for EXTENDED/multi-frame)

class FrameType(IntEnum):
    """Android Auto Protocol frame types (bits 0-1 of flags byte)."""
    MIDDLE = 0          # 0b00 - Middle frame of multi-frame message
    FIRST = 1           # 0b01 - First frame of multi-frame message
    LAST = 2            # 0b10 - Last frame of multi-frame message
    BULK = 3            # 0b11 - Single frame message (FIRST | LAST)
    FIRST_AND_LAST = 3  # Alias for BULK


class FrameSizeType(IntEnum):
    """Frame size type indicator."""
    SHORT = 0       # 2 bytes: frame size only
    EXTENDED = 1    # 6 bytes: frame size + total size


class EncryptionType(IntEnum):
    """Encryption type for AAP messages (bit 3 of flags byte)."""
    PLAIN = 0       # 0b0000 - No encryption
    ENCRYPTED = 8   # 0b1000 - TLS encrypted (1 << 3)


# Channel IDs for Android Auto services
class ChannelId(IntEnum):
    """Android Auto service channel identifiers."""
    CONTROL = 0
    INPUT = 1
    SENSOR = 2
    VIDEO = 3
    MEDIA_AUDIO = 4
    SPEECH_AUDIO = 5
    SYSTEM_AUDIO = 6
    AV_INPUT = 7
    BLUETOOTH = 8
    NAVIGATION = 9
    PHONE_STATUS = 10
    MEDIA_STATUS = 11
    NOTIFICATION = 12
    WIFI_PROJECTION = 13
    VENDOR_EXTENSION = 14


# Video configuration
class VideoResolution(IntEnum):
    """Supported video resolutions."""
    RES_480P = 1
    RES_720P = 2
    RES_1080P = 3


class VideoFrameRate(IntEnum):
    """Supported video frame rates."""
    FPS_30 = 1
    FPS_60 = 2


# Audio configuration
class AudioStreamType(IntEnum):
    """Audio stream types."""
    MEDIA = 1
    GUIDANCE = 2
    SYSTEM = 3
    CALL = 4


class AudioCodec(IntEnum):
    """Supported audio codecs."""
    PCM_16 = 1
    AAC_LC = 2


# Message types (bit 2 of flags byte)
class MessageType(IntEnum):
    """AAP message types (bit 2 of flags byte)."""
    SPECIFIC = 0    # 0b0000 - Channel-specific message
    CONTROL = 4     # 0b0100 - Control message (1 << 2)


# Control message types
class ControlMessageType(IntEnum):
    """Control channel message types."""
    VERSION_REQUEST = 1
    VERSION_RESPONSE = 2
    SSL_HANDSHAKE = 3
    AUTH_COMPLETE = 4
    SERVICE_DISCOVERY_REQUEST = 5
    SERVICE_DISCOVERY_RESPONSE = 6
    CHANNEL_OPEN_REQUEST = 7
    CHANNEL_OPEN_RESPONSE = 8
    CHANNEL_CLOSE = 9
    PING_REQUEST = 10
    PING_RESPONSE = 11
    NAV_FOCUS_REQUEST = 12
    NAV_FOCUS_NOTIFICATION = 13
    BYEBYE_REQUEST = 14
    BYEBYE_RESPONSE = 15
    VOICE_SESSION_NOTIFICATION = 16
    AUDIO_FOCUS_REQUEST = 17
    AUDIO_FOCUS_NOTIFICATION = 18
