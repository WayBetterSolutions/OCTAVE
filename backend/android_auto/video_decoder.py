"""
H.264 Video Decoder for Android Auto

This module decodes H.264 video streams from Android Auto
and provides frames ready for display in Qt/QML.
"""

import av
import logging
import threading
from typing import Optional, Callable
from collections import deque

from PySide6.QtCore import QObject, Signal, QByteArray
from PySide6.QtGui import QImage

logger = logging.getLogger(__name__)


class VideoDecoder(QObject):
    """
    H.264 video decoder for Android Auto streams.

    Uses PyAV (FFmpeg) for decoding H.264 NAL units and converts
    frames to QImage for display in QML.
    """

    # Signals
    frameReady = Signal(QImage)
    decodingStarted = Signal()
    decodingStopped = Signal()
    error = Signal(str)

    def __init__(self, width: int = 800, height: int = 480, parent=None):
        super().__init__(parent)

        self._width = width
        self._height = height
        self._running = False

        # Decoder state
        self._codec: Optional[av.Codec] = None
        self._codec_context: Optional[av.CodecContext] = None
        self._buffer = b''

        # Frame queue for async processing
        self._frame_queue: deque = deque(maxlen=3)
        self._decode_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()

        self._init_decoder()

    def _init_decoder(self):
        """Initialize the H.264 decoder."""
        try:
            self._codec = av.Codec('h264', 'r')
            self._codec_context = self._codec.create()

            # Configure decoder
            self._codec_context.width = self._width
            self._codec_context.height = self._height
            self._codec_context.pix_fmt = 'yuv420p'

            # Open decoder
            self._codec_context.open()

            logger.info(f"H.264 decoder initialized ({self._width}x{self._height})")

        except Exception as e:
            logger.error(f"Failed to initialize H.264 decoder: {e}")
            self.error.emit(f"Decoder initialization failed: {e}")

    def start(self):
        """Start the decoder."""
        if self._running:
            return

        self._running = True
        self._decode_thread = threading.Thread(target=self._decode_loop, daemon=True)
        self._decode_thread.start()
        self.decodingStarted.emit()
        logger.info("Video decoder started")

    def stop(self):
        """Stop the decoder."""
        self._running = False

        if self._decode_thread:
            self._decode_thread.join(timeout=1.0)
            self._decode_thread = None

        self._frame_queue.clear()
        self._buffer = b''
        self.decodingStopped.emit()
        logger.info("Video decoder stopped")

    def feed(self, data: bytes):
        """
        Feed H.264 NAL unit data to the decoder.

        Args:
            data: H.264 encoded video data
        """
        with self._lock:
            self._frame_queue.append(data)

    def _decode_loop(self):
        """Background thread for decoding video frames."""
        while self._running:
            data = None

            with self._lock:
                if self._frame_queue:
                    data = self._frame_queue.popleft()

            if data:
                self._decode_frame(data)
            else:
                # Wait a bit if no data
                threading.Event().wait(0.001)

    def _decode_frame(self, data: bytes):
        """Decode a single frame from H.264 data."""
        if not self._codec_context:
            return

        try:
            # Create packet from data
            packet = av.Packet(data)

            # Decode
            for frame in self._codec_context.decode(packet):
                # Convert to RGB
                rgb_frame = frame.to_rgb()

                # Convert to QImage
                qimage = self._frame_to_qimage(rgb_frame)

                if qimage:
                    self.frameReady.emit(qimage)

        except av.AVError as e:
            logger.debug(f"Decode error (may be incomplete frame): {e}")
        except Exception as e:
            logger.error(f"Unexpected decode error: {e}")

    def _frame_to_qimage(self, frame: av.VideoFrame) -> Optional[QImage]:
        """Convert an AV frame to QImage."""
        try:
            # Get frame data as numpy array
            array = frame.to_ndarray(format='rgb24')

            # Create QImage from numpy array
            height, width, channels = array.shape
            bytes_per_line = channels * width

            qimage = QImage(
                array.data,
                width,
                height,
                bytes_per_line,
                QImage.Format.Format_RGB888
            )

            # Make a copy since the array data may be reused
            return qimage.copy()

        except Exception as e:
            logger.error(f"Frame conversion error: {e}")
            return None

    def flush(self):
        """Flush the decoder to output any buffered frames."""
        if not self._codec_context:
            return

        try:
            # Send None packet to flush
            for frame in self._codec_context.decode(None):
                rgb_frame = frame.to_rgb()
                qimage = self._frame_to_qimage(rgb_frame)
                if qimage:
                    self.frameReady.emit(qimage)

        except Exception as e:
            logger.debug(f"Flush error: {e}")

    def reset(self):
        """Reset the decoder state."""
        self.stop()
        self._buffer = b''

        # Reinitialize decoder
        if self._codec_context:
            self._codec_context.close()

        self._init_decoder()

    @property
    def is_running(self) -> bool:
        """Check if decoder is running."""
        return self._running


class VideoFrameProvider(QObject):
    """
    Provides decoded video frames for QML display.

    This class wraps VideoDecoder and provides a QML-friendly
    interface for displaying Android Auto video.
    """

    frameUpdated = Signal()
    sizeChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        self._decoder: Optional[VideoDecoder] = None
        self._current_frame: Optional[QImage] = None
        self._width = 800
        self._height = 480

    def setDecoder(self, decoder: VideoDecoder):
        """Set the video decoder to use."""
        if self._decoder:
            self._decoder.frameReady.disconnect(self._on_frame_ready)

        self._decoder = decoder
        self._decoder.frameReady.connect(self._on_frame_ready)

    def _on_frame_ready(self, frame: QImage):
        """Handle new frame from decoder."""
        self._current_frame = frame

        if frame.width() != self._width or frame.height() != self._height:
            self._width = frame.width()
            self._height = frame.height()
            self.sizeChanged.emit()

        self.frameUpdated.emit()

    @property
    def currentFrame(self) -> Optional[QImage]:
        """Get the current video frame."""
        return self._current_frame

    @property
    def width(self) -> int:
        """Get frame width."""
        return self._width

    @property
    def height(self) -> int:
        """Get frame height."""
        return self._height
