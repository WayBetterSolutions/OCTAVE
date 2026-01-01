"""
Android Auto Protocol Message Handling

This module implements the AAP message framing, encryption,
and protocol buffer serialization/deserialization.

Frame format (based on aasdk):
- Byte 0: Channel ID
- Byte 1: Flags = FrameType (bits 0-1) | MessageType (bit 2) | EncryptionType (bit 3)
- Bytes 2-3: Frame size (uint16 big-endian) - SHORT format
- OR Bytes 2-7: Frame size (uint16) + Total size (uint32) - EXTENDED format
"""

import struct
import logging
from dataclasses import dataclass
from typing import Optional, Tuple, List
from enum import IntEnum

from .constants import (
    FrameType,
    FrameSizeType,
    EncryptionType,
    ChannelId,
    MessageType,
)

logger = logging.getLogger(__name__)


@dataclass
class FrameHeader:
    """
    AAP Frame Header.

    aasdk frame format:
    - Byte 0: Channel ID (0-255)
    - Byte 1: Flags = FrameType (bits 0-1) | MessageType (bit 2) | EncryptionType (bit 3)
    - Bytes 2+: Frame size (2 or 6 bytes depending on format)
    """
    channel_id: int
    frame_type: FrameType
    encryption_type: EncryptionType
    message_type: MessageType
    frame_size: int
    total_size: Optional[int] = None  # Only for EXTENDED format

    @classmethod
    def from_bytes(cls, data: bytes) -> Tuple['FrameHeader', int]:
        """
        Parse a frame header from bytes.

        Returns:
            Tuple of (FrameHeader, bytes_consumed)
        """
        if len(data) < 4:  # Minimum: 2 header + 2 size
            raise ValueError("Not enough data for frame header")

        channel_id = data[0]
        flags = data[1]

        # Parse flags byte
        # FrameType: bits 0-1 (mask 0x03)
        # MessageType: bit 2 (mask 0x04)
        # EncryptionType: bit 3 (mask 0x08)
        frame_type = FrameType(flags & 0x03)
        message_type = MessageType.CONTROL if (flags & 0x04) else MessageType.SPECIFIC
        encryption_type = EncryptionType.ENCRYPTED if (flags & 0x08) else EncryptionType.PLAIN

        # Parse frame size (always big-endian uint16)
        frame_size = struct.unpack('>H', data[2:4])[0]
        bytes_consumed = 4
        total_size = None

        # EXTENDED format is ONLY used for multi-frame messages (FIRST frame type)
        # BULK frames (single-frame) NEVER use extended format
        # Only check for extended format if this is a FIRST frame
        if frame_type == FrameType.FIRST and len(data) >= 8:
            # In extended format, bytes 4-7 contain total_size as uint32
            potential_total = struct.unpack('>I', data[4:8])[0]
            # total_size should be >= frame_size (it's the total across all frames)
            if potential_total >= frame_size:
                total_size = potential_total
                bytes_consumed = 8

        print(f"[AA Frame] Raw: {data[:8].hex() if len(data) >= 8 else data.hex()}")
        print(f"[AA Frame] channel={channel_id}, flags=0x{flags:02x}, frame_type={frame_type.name}, msg_type={message_type}, enc={encryption_type.name}, frame_size={frame_size}, header_bytes={bytes_consumed}")

        return cls(
            channel_id=channel_id,
            frame_type=frame_type,
            encryption_type=encryption_type,
            message_type=message_type,
            frame_size=frame_size,
            total_size=total_size
        ), bytes_consumed

    def to_bytes(self) -> bytes:
        """Serialize frame header to bytes."""
        # Build flags byte
        flags = (
            (self.frame_type & 0x03) |
            (0x04 if self.message_type == MessageType.CONTROL else 0) |
            (0x08 if self.encryption_type == EncryptionType.ENCRYPTED else 0)
        )

        header = bytes([self.channel_id, flags])

        # Add frame size (always 2 bytes, big-endian)
        header += struct.pack('>H', self.frame_size)

        # Add total size if extended format
        if self.total_size is not None:
            header += struct.pack('>I', self.total_size)

        return header

    @staticmethod
    def size_of(extended: bool = False) -> int:
        """Return the size of the header in bytes."""
        return 8 if extended else 4


@dataclass
class Message:
    """
    AAP Message.

    A complete message consists of:
    - Message ID (2 bytes, big-endian)
    - Payload (protobuf data)
    """
    channel_id: int
    message_id: int
    payload: bytes
    encrypted: bool = False

    @classmethod
    def from_frames(cls, channel_id: int, frames: List[bytes], encrypted: bool = False) -> 'Message':
        """Assemble a message from one or more frames."""
        data = b''.join(frames)

        if len(data) < 2:
            raise ValueError("Message too short")

        message_id = struct.unpack('>H', data[:2])[0]
        payload = data[2:]

        return cls(
            channel_id=channel_id,
            message_id=message_id,
            payload=payload,
            encrypted=encrypted
        )

    def to_frames(self, max_frame_size: int = 16384) -> List[bytes]:
        """
        Split message into frames for transmission.

        Args:
            max_frame_size: Maximum size of each frame payload

        Returns:
            List of frame payloads (without headers)
        """
        data = struct.pack('>H', self.message_id) + self.payload

        if len(data) <= max_frame_size:
            return [data]

        frames = []
        for i in range(0, len(data), max_frame_size):
            frames.append(data[i:i + max_frame_size])

        return frames

    def create_frame_data(self, max_frame_size: int = 16384) -> bytes:
        """
        Create complete frame data (header + payload) for transmission.

        Returns:
            Bytes ready to send over USB
        """
        frames = self.to_frames(max_frame_size)
        result = b''
        total_size = sum(len(f) for f in frames)

        for i, frame_payload in enumerate(frames):
            # Determine frame type
            is_first = (i == 0)
            is_last = (i == len(frames) - 1)

            if is_first and is_last:
                frame_type = FrameType.BULK  # FIRST_AND_LAST = BULK in aasdk
            elif is_first:
                frame_type = FrameType.FIRST
            elif is_last:
                frame_type = FrameType.LAST
            else:
                frame_type = FrameType.MIDDLE

            # Create header
            # Use EXTENDED format only for multi-frame messages
            use_extended = len(frames) > 1 and is_first

            header = FrameHeader(
                channel_id=self.channel_id,
                frame_type=frame_type,
                encryption_type=EncryptionType.ENCRYPTED if self.encrypted else EncryptionType.PLAIN,
                message_type=MessageType.SPECIFIC,
                frame_size=len(frame_payload),
                total_size=total_size if use_extended else None
            )

            result += header.to_bytes() + frame_payload

        return result


class MessageAssembler:
    """
    Assembles complete messages from incoming frame data.

    Handles multi-frame messages and buffering of incomplete data.
    """

    def __init__(self):
        self._buffer = b''
        self._current_frames: dict[int, List[bytes]] = {}  # channel_id -> frames

    def feed(self, data: bytes) -> List[Message]:
        """
        Feed incoming data and return any complete messages.

        Args:
            data: Incoming bytes from USB

        Returns:
            List of complete Message objects
        """
        self._buffer += data
        messages = []

        while True:
            try:
                msg = self._try_extract_message()
                if msg:
                    messages.append(msg)
                else:
                    break
            except ValueError as e:
                logger.warning(f"Error parsing frame: {e}")
                # Skip a byte and try again
                self._buffer = self._buffer[1:]
                if not self._buffer:
                    break

        return messages

    def _try_extract_message(self) -> Optional[Message]:
        """Try to extract a complete message from the buffer."""
        if len(self._buffer) < 4:  # Minimum header size
            return None

        try:
            header, header_size = FrameHeader.from_bytes(self._buffer)
        except ValueError:
            return None

        total_frame_size = header_size + header.frame_size

        if len(self._buffer) < total_frame_size:
            return None

        # Extract frame payload
        payload = self._buffer[header_size:total_frame_size]
        self._buffer = self._buffer[total_frame_size:]

        channel_id = header.channel_id

        # Handle multi-frame messages
        if header.frame_type == FrameType.BULK:
            # Single frame message (FIRST_AND_LAST)
            return Message.from_frames(
                channel_id,
                [payload],
                encrypted=(header.encryption_type == EncryptionType.ENCRYPTED)
            )

        elif header.frame_type == FrameType.FIRST:
            # Start of multi-frame message
            self._current_frames[channel_id] = [payload]
            return None

        elif header.frame_type == FrameType.MIDDLE:
            # Middle of multi-frame message
            if channel_id in self._current_frames:
                self._current_frames[channel_id].append(payload)
            return None

        elif header.frame_type == FrameType.LAST:
            # End of multi-frame message
            if channel_id in self._current_frames:
                frames = self._current_frames.pop(channel_id)
                frames.append(payload)
                return Message.from_frames(
                    channel_id,
                    frames,
                    encrypted=(header.encryption_type == EncryptionType.ENCRYPTED)
                )
            return None

        return None


class MessageRouter:
    """
    Routes messages to appropriate channel handlers.
    """

    def __init__(self):
        self._handlers: dict[int, callable] = {}

    def register_handler(self, channel_id: int, handler: callable):
        """Register a handler for a specific channel."""
        self._handlers[channel_id] = handler

    def unregister_handler(self, channel_id: int):
        """Unregister a channel handler."""
        self._handlers.pop(channel_id, None)

    def route(self, message: Message):
        """Route a message to its handler."""
        handler = self._handlers.get(message.channel_id)
        if handler:
            try:
                handler(message)
            except Exception as e:
                logger.error(f"Error handling message on channel {message.channel_id}: {e}")
        else:
            logger.debug(f"No handler for channel {message.channel_id}, message ID {message.message_id}")
