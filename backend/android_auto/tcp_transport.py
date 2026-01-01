"""
TCP Transport Layer for Android Auto Protocol (DHU Mode)

This module implements TCP transport for Android Auto,
connecting via the "Start head unit server" mode on the phone.
This bypasses USB certificate validation issues.

The phone's head unit server listens on port 5277 after:
1. Enabling Android Auto developer mode (tap version 10x)
2. Selecting "Start head unit server" from the menu

Use ADB port forwarding to connect:
    adb forward tcp:5277 tcp:5277
"""

import socket
import threading
import logging
import time
from typing import Optional, Callable
from enum import Enum

from PySide6.QtCore import QObject, Signal

logger = logging.getLogger(__name__)


class TCPState(Enum):
    """TCP connection states."""
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    ERROR = "error"


class TCPTransport(QObject):
    """
    TCP Transport layer for Android Auto (DHU mode).

    Connects to the phone's head unit server over TCP,
    typically via ADB port forwarding on port 5277.
    """

    # Signals (matching USBTransport interface)
    deviceConnected = Signal(object)  # Self, for compatibility
    deviceDisconnected = Signal()
    stateChanged = Signal(str)  # TCPState value
    dataReceived = Signal(bytes)
    error = Signal(str)

    # Default DHU port
    DEFAULT_PORT = 5277
    DEFAULT_HOST = "127.0.0.1"

    def __init__(self, host: str = None, port: int = None, parent=None):
        super().__init__(parent)

        self._host = host or self.DEFAULT_HOST
        self._port = port or self.DEFAULT_PORT
        self._socket: Optional[socket.socket] = None
        self._state = TCPState.DISCONNECTED
        self._running = False
        self._connect_thread: Optional[threading.Thread] = None
        self._read_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()

        # Reconnection settings
        self._auto_reconnect = True
        self._reconnect_delay = 2.0
        self._max_reconnect_attempts = 10

    @property
    def is_connected(self) -> bool:
        """Check if connected."""
        return self._state == TCPState.CONNECTED and self._socket is not None

    @property
    def state(self) -> TCPState:
        """Get current state."""
        return self._state

    def _set_state(self, state: TCPState):
        """Update state and emit signal."""
        if self._state != state:
            self._state = state
            self.stateChanged.emit(state.value)
            logger.info(f"TCP transport state: {state.value}")

    def start(self):
        """Start TCP transport and attempt connection."""
        if self._running:
            return

        self._running = True
        self._connect_thread = threading.Thread(target=self._connection_loop, daemon=True)
        self._connect_thread.start()
        logger.info(f"TCP transport started, connecting to {self._host}:{self._port}")

    def stop(self):
        """Stop TCP transport and disconnect."""
        self._running = False
        self._auto_reconnect = False

        if self._socket:
            try:
                self._socket.close()
            except Exception:
                pass
            self._socket = None

        if self._connect_thread:
            self._connect_thread.join(timeout=2.0)
            self._connect_thread = None

        if self._read_thread:
            self._read_thread.join(timeout=2.0)
            self._read_thread = None

        self._set_state(TCPState.DISCONNECTED)
        logger.info("TCP transport stopped")

    def _connection_loop(self):
        """Background thread to manage connection."""
        attempt = 0

        while self._running:
            if self._state == TCPState.CONNECTED:
                # Already connected, wait a bit before checking again
                time.sleep(1.0)
                continue

            attempt += 1
            print(f"[AA TCP] Connection attempt {attempt}/{self._max_reconnect_attempts}")

            if attempt > self._max_reconnect_attempts:
                print(f"[AA TCP] Max reconnection attempts reached")
                self.error.emit("Failed to connect to phone's head unit server")
                break

            try:
                self._connect()
                attempt = 0  # Reset on successful connection
            except Exception as e:
                print(f"[AA TCP] Connection failed: {e}")
                logger.error(f"TCP connection failed: {e}")

                if not self._auto_reconnect:
                    self.error.emit(f"Connection failed: {e}")
                    break

                time.sleep(self._reconnect_delay)

    def _connect(self):
        """Establish TCP connection."""
        self._set_state(TCPState.CONNECTING)
        print(f"[AA TCP] Connecting to {self._host}:{self._port}...")

        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.settimeout(5.0)  # Connection timeout

        try:
            self._socket.connect((self._host, self._port))
            self._socket.settimeout(1.0)  # Read timeout

            print(f"[AA TCP] Connected!")
            logger.info(f"TCP connected to {self._host}:{self._port}")

            self._set_state(TCPState.CONNECTED)
            self.deviceConnected.emit(self)

            # Start read thread
            self._read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self._read_thread.start()

        except socket.timeout:
            print(f"[AA TCP] Connection timeout")
            self._socket.close()
            self._socket = None
            raise Exception("Connection timeout - is ADB forwarding active?")
        except ConnectionRefusedError:
            print(f"[AA TCP] Connection refused")
            self._socket.close()
            self._socket = None
            raise Exception("Connection refused - start head unit server on phone")
        except Exception as e:
            print(f"[AA TCP] Connection error: {e}")
            if self._socket:
                self._socket.close()
                self._socket = None
            raise

    def _read_loop(self):
        """Background thread to read data from socket."""
        print(f"[AA TCP] Read loop started")
        error_count = 0
        max_errors = 5

        while self._running and self._state == TCPState.CONNECTED:
            try:
                if not self._socket:
                    break

                # Read data (16KB buffer like USB)
                data = self._socket.recv(16384)

                if not data:
                    # Connection closed by remote
                    print(f"[AA TCP] Connection closed by phone")
                    break

                print(f"[AA TCP] Received {len(data)} bytes")
                self.dataReceived.emit(data)
                error_count = 0

            except socket.timeout:
                # Timeout is normal, continue
                continue
            except ConnectionResetError:
                print(f"[AA TCP] Connection reset by phone")
                break
            except OSError as e:
                error_count += 1
                print(f"[AA TCP] Socket error ({error_count}/{max_errors}): {e}")

                if error_count >= max_errors:
                    break

                time.sleep(0.1)
            except Exception as e:
                print(f"[AA TCP] Unexpected error: {e}")
                logger.error(f"TCP read error: {e}")
                break

        print(f"[AA TCP] Read loop ended")
        self._disconnect()

    def _disconnect(self):
        """Handle disconnection."""
        with self._lock:
            if self._socket:
                try:
                    self._socket.close()
                except Exception:
                    pass
                self._socket = None

            if self._state != TCPState.DISCONNECTED:
                self._set_state(TCPState.DISCONNECTED)
                self.deviceDisconnected.emit()

    def write(self, data: bytes) -> bool:
        """Write data to the socket."""
        if not self.is_connected or not self._socket:
            print(f"[AA TCP] Write failed: not connected")
            return False

        try:
            total_sent = 0
            while total_sent < len(data):
                sent = self._socket.send(data[total_sent:])
                if sent == 0:
                    raise RuntimeError("Socket connection broken")
                total_sent += sent

            print(f"[AA TCP] Write: {total_sent}/{len(data)} bytes")
            return True

        except Exception as e:
            print(f"[AA TCP] Write error: {e}")
            logger.error(f"TCP write error: {e}")
            return False

    def set_host_port(self, host: str, port: int):
        """Update connection parameters (must call before start)."""
        self._host = host
        self._port = port
