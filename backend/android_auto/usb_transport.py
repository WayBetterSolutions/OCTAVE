"""
USB Transport Layer for Android Auto Protocol

This module implements the USB transport layer for Android Auto,
handling device detection, AOAP handshake, and data transfer.

Based on the Android Open Accessory Protocol 2.0 specification
and the aasdk library implementation.
"""

import os
import sys
import time
import platform
import threading
import logging
import traceback
from typing import Optional, Callable, List, Tuple
from enum import Enum

from PySide6.QtCore import QObject, Signal, QThread

logger = logging.getLogger(__name__)

# Setup libusb for Windows before importing usb modules
def _setup_libusb_backend():
    """Configure libusb backend for Windows."""
    if platform.system() != 'Windows':
        return True

    try:
        import libusb
        pkg_dir = os.path.dirname(libusb.__file__)
        arch = platform.machine().lower()
        if arch in ('amd64', 'x86_64'):
            dll_subdir = 'x86_64'
        elif arch in ('arm64', 'aarch64'):
            dll_subdir = 'arm64'
        else:
            dll_subdir = 'x86'

        dll_path = os.path.join(pkg_dir, '_platform', 'windows', dll_subdir)
        if os.path.exists(dll_path):
            # Add to PATH so usb.core can find it
            os.environ['PATH'] = dll_path + os.pathsep + os.environ.get('PATH', '')
            logger.info(f"libusb configured: {dll_path}")
            return True
    except ImportError:
        logger.warning("libusb package not installed")

    return False

# Initialize libusb before importing usb
_libusb_available = _setup_libusb_backend()

_backend = None

try:
    import usb.core
    import usb.util
    import usb.backend.libusb1
    _usb_available = True

    # Try to get a backend explicitly
    if platform.system() == 'Windows':
        try:
            _backend = usb.backend.libusb1.get_backend()
            if _backend is None:
                logger.warning("libusb1 backend not found")
                _usb_available = False
            else:
                logger.info("libusb1 backend loaded successfully")
        except Exception as e:
            logger.warning(f"Failed to load libusb1 backend: {e}")
            _usb_available = False
except ImportError as e:
    logger.error(f"Failed to import usb modules: {e}")
    _usb_available = False

    # Create dummy module to prevent errors
    class _DummyUSB:
        class core:
            class NoBackendError(Exception):
                pass
            @staticmethod
            def find(*args, **kwargs):
                return None
        class util:
            pass
    usb = _DummyUSB()

from .constants import (
    USBIds,
    AOAPRequest,
    AOAPStringType,
    AccessoryInfo,
    USBConstants,
)


class DeviceState(Enum):
    """USB device connection states."""
    DISCONNECTED = "disconnected"
    DETECTED = "detected"
    AOAP_HANDSHAKE = "aoap_handshake"
    AOAP_MODE = "aoap_mode"
    CONNECTED = "connected"
    ERROR = "error"


class USBDevice:
    """Represents a connected Android device."""

    def __init__(self, device: usb.core.Device):
        self.device = device
        self.vendor_id = device.idVendor
        self.product_id = device.idProduct
        self.state = DeviceState.DETECTED

        # Endpoints for data transfer (set after AOAP mode)
        self.in_endpoint: Optional[usb.core.Endpoint] = None
        self.out_endpoint: Optional[usb.core.Endpoint] = None

    @property
    def is_aoap_mode(self) -> bool:
        """Check if device is in AOAP mode."""
        return (
            self.vendor_id == USBIds.GOOGLE_VENDOR_ID and
            self.product_id in (USBIds.AOAP_PRODUCT_ID, USBIds.AOAP_WITH_ADB_PRODUCT_ID)
        )

    def __repr__(self) -> str:
        return f"USBDevice(vendor=0x{self.vendor_id:04x}, product=0x{self.product_id:04x}, state={self.state.value})"


class USBTransport(QObject):
    """
    USB Transport layer for Android Auto.

    Handles:
    - Device detection and hotplug
    - AOAP handshake to switch device to accessory mode
    - Bulk data transfer for AAP communication
    """

    # Signals
    deviceConnected = Signal(object)  # USBDevice
    deviceDisconnected = Signal()
    stateChanged = Signal(str)  # DeviceState value
    dataReceived = Signal(bytes)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._device: Optional[USBDevice] = None
        self._running = False
        self._monitor_thread: Optional[threading.Thread] = None
        self._read_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()

        # Track failed connection attempts to avoid infinite retries
        self._aoap_fail_count = 0
        self._max_aoap_fails = 3

    @property
    def device(self) -> Optional[USBDevice]:
        """Get the currently connected device."""
        return self._device

    @property
    def is_connected(self) -> bool:
        """Check if a device is connected and ready."""
        return self._device is not None and self._device.state == DeviceState.CONNECTED

    def start(self):
        """Start USB device monitoring."""
        if self._running:
            return

        self._running = True
        self._monitor_thread = threading.Thread(target=self._monitor_devices, daemon=True)
        self._monitor_thread.start()
        logger.info("USB transport started")

    def stop(self):
        """Stop USB device monitoring and disconnect."""
        self._running = False

        if self._device:
            self._disconnect_device()

        if self._monitor_thread:
            self._monitor_thread.join(timeout=2.0)
            self._monitor_thread = None

        logger.info("USB transport stopped")

    def _monitor_devices(self):
        """Background thread to monitor USB device connections."""
        print(f"[AA] Monitor thread started. _usb_available={_usb_available}, _backend={_backend}")

        if not _usb_available:
            logger.error("USB not available - libusb not properly configured")
            self.error.emit("USB not available - libusb not configured")
            return

        while self._running:
            try:
                self._scan_for_devices()
            except usb.core.NoBackendError:
                logger.error("No USB backend available - need libusb")
                self.error.emit("No USB backend - install libusb")
                threading.Event().wait(5.0)  # Wait longer before retry
            except Exception as e:
                logger.error(f"Error scanning USB devices: {e}")

            # Wait before next scan
            threading.Event().wait(1.0)

    def _scan_for_devices(self):
        """Scan for Android devices."""
        with self._lock:
            if self._device is not None:
                # Already have a device, check if still connected
                try:
                    # Try to get device descriptor to verify connection
                    _ = self._device.device.bcdDevice
                except usb.core.USBError:
                    logger.info("Device disconnected")
                    self._disconnect_device()
                return

            # Check if we've failed too many times with AOAP device
            if self._aoap_fail_count >= self._max_aoap_fails:
                print(f"[AA] Too many AOAP failures ({self._aoap_fail_count}). Please unplug and replug phone.")
                print(f"[AA] TIP: Open Android Auto app on phone before plugging in USB")
                self.error.emit("Phone stuck in AOAP mode. Open Android Auto app on phone, then replug USB.")
                # Wait longer before trying again
                threading.Event().wait(10.0)
                return

            # IMPORTANT: Look for fresh Android devices FIRST (not in AOAP mode)
            # This allows us to do a clean AOAP handshake which triggers the AA app
            device = self._find_android_device()
            if device:
                print(f"[AA] Found fresh Android device (not in AOAP mode): {device}")
                logger.info(f"Found Android device: {device}")
                self._device = device
                # Reset fail count when we see a fresh Android device
                self._aoap_fail_count = 0
                self._initiate_aoap_handshake()
                return

            # Only look for AOAP devices if no fresh Android device found
            # A device already in AOAP mode may be stale from a previous session
            device = self._find_aoap_device()
            if device:
                if self._aoap_fail_count > 0:
                    # We've had failures before, this might be a stale AOAP device
                    print(f"[AA] Found AOAP device but had previous failures - might be stale")
                    print(f"[AA] TIP: Try opening Android Auto app on phone first")
                print(f"[AA] Found device in AOAP mode: {device}")
                logger.info(f"Found device in AOAP mode: {device}")
                self._device = device
                self._connect_aoap_device()
                return

    def _find_aoap_device(self) -> Optional[USBDevice]:
        """Find a device already in AOAP mode."""
        # On Windows, we need to get a fresh backend in each thread
        if platform.system() == 'Windows':
            try:
                backend = usb.backend.libusb1.get_backend()
            except Exception as e:
                print(f"[AA] Failed to get backend in thread: {e}")
                backend = None
        else:
            backend = None

        device = usb.core.find(
            idVendor=USBIds.GOOGLE_VENDOR_ID,
            idProduct=USBIds.AOAP_PRODUCT_ID,
            backend=backend
        )
        if device:
            return USBDevice(device)

        device = usb.core.find(
            idVendor=USBIds.GOOGLE_VENDOR_ID,
            idProduct=USBIds.AOAP_WITH_ADB_PRODUCT_ID,
            backend=backend
        )
        if device:
            return USBDevice(device)

        return None

    def _reset_usb_device(self, device) -> bool:
        """Reset USB device to force re-enumeration."""
        try:
            print(f"[AA] Attempting USB device reset...")
            device.reset()
            print(f"[AA] USB device reset successful")
            return True
        except usb.core.USBError as e:
            print(f"[AA] USB reset failed: {e}")
            return False
        except Exception as e:
            print(f"[AA] USB reset error: {e}")
            return False

    def _find_android_device(self) -> Optional[USBDevice]:
        """Find an Android device that supports AOAP."""
        # On Windows, we need to get a fresh backend in each thread
        if platform.system() == 'Windows':
            try:
                backend = usb.backend.libusb1.get_backend()
            except Exception as e:
                print(f"[AA] Failed to get backend in thread: {e}")
                backend = None
        else:
            backend = None

        # Common Android device vendor IDs
        android_vendors = [
            0x18D1,  # Google
            0x04E8,  # Samsung
            0x22B8,  # Motorola
            0x0BB4,  # HTC
            0x12D1,  # Huawei
            0x2717,  # Xiaomi
            0x1949,  # OnePlus (some models)
            0x2A70,  # OnePlus
            0x05C6,  # Qualcomm (various Android devices)
            0x0FCE,  # Sony
            0x2916,  # Yota
            0x1004,  # LG
            0x0502,  # Acer
            0x0B05,  # Asus
            0x2A96,  # Fairphone
            0x19D2,  # ZTE
            0x1782,  # Spreadtrum
        ]

        for vendor_id in android_vendors:
            devices = usb.core.find(find_all=True, idVendor=vendor_id, backend=backend)
            for device in devices:
                # Skip if already in AOAP mode
                if device.idProduct in (USBIds.AOAP_PRODUCT_ID, USBIds.AOAP_WITH_ADB_PRODUCT_ID):
                    continue

                # Check if device supports AOAP
                if self._check_aoap_support(device):
                    return USBDevice(device)

        return None

    def _check_aoap_support(self, device: usb.core.Device) -> bool:
        """Check if a device supports AOAP by querying protocol version."""
        try:
            # Detach kernel driver if necessary (Linux only - skip on Windows)
            if platform.system() != 'Windows':
                try:
                    if device.is_kernel_driver_active(0):
                        device.detach_kernel_driver(0)
                except (usb.core.USBError, NotImplementedError):
                    pass

            # Query AOAP protocol version
            version = device.ctrl_transfer(
                USBConstants.ENDPOINT_IN | USBConstants.TYPE_VENDOR,
                AOAPRequest.GET_PROTOCOL,
                0,
                0,
                2,
                USBConstants.TIMEOUT_MS
            )

            if len(version) >= 2:
                protocol_version = version[0] | (version[1] << 8)
                print(f"[AA] Device AOAP protocol version: {protocol_version}")
                logger.info(f"Device AOAP protocol version: {protocol_version}")
                return protocol_version >= 1

        except usb.core.USBError as e:
            print(f"[AA] Device does not support AOAP: {e}")
            logger.debug(f"Device does not support AOAP: {e}")

        return False

    def _initiate_aoap_handshake(self):
        """Perform AOAP handshake to switch device to accessory mode."""
        if not self._device:
            return

        device = self._device.device
        self._device.state = DeviceState.AOAP_HANDSHAKE
        self.stateChanged.emit(DeviceState.AOAP_HANDSHAKE.value)

        try:
            logger.info("Starting AOAP handshake...")

            # Detach kernel driver if necessary (Linux only)
            if platform.system() != 'Windows':
                try:
                    if device.is_kernel_driver_active(0):
                        device.detach_kernel_driver(0)
                except (usb.core.USBError, NotImplementedError):
                    pass

            # Send accessory identification strings
            strings = [
                (AOAPStringType.MANUFACTURER, AccessoryInfo.MANUFACTURER),
                (AOAPStringType.MODEL, AccessoryInfo.MODEL),
                (AOAPStringType.DESCRIPTION, AccessoryInfo.DESCRIPTION),
                (AOAPStringType.VERSION, AccessoryInfo.VERSION),
                (AOAPStringType.URI, AccessoryInfo.URI),
                (AOAPStringType.SERIAL, AccessoryInfo.SERIAL),
            ]

            for string_type, value in strings:
                data = value.encode('utf-8') + b'\x00'
                device.ctrl_transfer(
                    USBConstants.ENDPOINT_OUT | USBConstants.TYPE_VENDOR,
                    AOAPRequest.SEND_STRING,
                    0,
                    string_type,
                    data,
                    USBConstants.TIMEOUT_MS
                )
                logger.debug(f"Sent AOAP string {string_type.name}: {value}")

            # Send start command
            device.ctrl_transfer(
                USBConstants.ENDPOINT_OUT | USBConstants.TYPE_VENDOR,
                AOAPRequest.START,
                0,
                0,
                None,
                USBConstants.TIMEOUT_MS
            )
            logger.info("AOAP start command sent, device will reconnect in accessory mode")

            # Device will disconnect and reconnect in AOAP mode
            self._device = None
            self.stateChanged.emit(DeviceState.DISCONNECTED.value)

        except usb.core.USBError as e:
            logger.error(f"AOAP handshake failed: {e}")
            self._device.state = DeviceState.ERROR
            self.error.emit(f"AOAP handshake failed: {e}")

    def _connect_aoap_device(self):
        """Connect to a device in AOAP mode and set up endpoints."""
        if not self._device or not self._device.is_aoap_mode:
            return

        device = self._device.device
        self._device.state = DeviceState.AOAP_MODE
        self.stateChanged.emit(DeviceState.AOAP_MODE.value)

        try:
            print(f"[AA] Connecting to AOAP device...")

            # On Windows, we may need to wait for the device to be ready
            time.sleep(0.5)

            # Set configuration
            try:
                device.set_configuration()
                print(f"[AA] Configuration set")
            except usb.core.USBError as e:
                # Configuration may already be set
                print(f"[AA] set_configuration: {e} (may already be set)")

            # Get configuration
            cfg = device.get_active_configuration()
            print(f"[AA] Active configuration: {cfg.bConfigurationValue}")

            # Find the AOAP interface (usually interface 0)
            intf = cfg[(0, 0)]
            print(f"[AA] Interface: {intf.bInterfaceNumber}")

            # On Windows, try to claim the interface
            if platform.system() == 'Windows':
                try:
                    usb.util.claim_interface(device, intf)
                    print(f"[AA] Interface claimed")
                except usb.core.USBError as e:
                    print(f"[AA] Could not claim interface: {e}")

            # Find bulk endpoints
            for ep in intf:
                ep_type = usb.util.endpoint_type(ep.bmAttributes)
                ep_dir = usb.util.endpoint_direction(ep.bEndpointAddress)
                print(f"[AA] Endpoint 0x{ep.bEndpointAddress:02x}: type={ep_type}, dir={ep_dir}")

                if ep_type == usb.util.ENDPOINT_TYPE_BULK:
                    if ep_dir == usb.util.ENDPOINT_IN:
                        self._device.in_endpoint = ep
                        logger.info(f"Found IN endpoint: 0x{ep.bEndpointAddress:02x}")
                        print(f"[AA] Found IN endpoint: 0x{ep.bEndpointAddress:02x}")
                    else:
                        self._device.out_endpoint = ep
                        logger.info(f"Found OUT endpoint: 0x{ep.bEndpointAddress:02x}")
                        print(f"[AA] Found OUT endpoint: 0x{ep.bEndpointAddress:02x}")

            if self._device.in_endpoint and self._device.out_endpoint:
                # Test if device is responsive with a quick read attempt
                print(f"[AA] Testing device responsiveness...")
                try:
                    # Try a quick read to see if device is stale
                    # A stale device will timeout immediately or return nothing
                    self._device.in_endpoint.read(64, timeout=500)
                except usb.core.USBTimeoutError:
                    # Timeout is OK - just means no data pending
                    print(f"[AA] Device responsive (no pending data)")
                except usb.core.USBError as e:
                    # USB error might mean device is stale
                    print(f"[AA] Device test failed: {e}")
                    raise Exception(f"Device appears stale: {e}")

                # Mark as connected - the manager will handle protocol handshake
                self._device.state = DeviceState.CONNECTED
                self.stateChanged.emit(DeviceState.CONNECTED.value)
                self.deviceConnected.emit(self._device)

                # Start read thread
                self._start_read_thread()

                logger.info("Device connected and ready for Android Auto")
                print(f"[AA] Device connected and ready!")
            else:
                raise Exception("Could not find required bulk endpoints")

        except Exception as e:
            logger.error(f"Failed to connect AOAP device: {e}")
            print(f"[AA] Failed to connect AOAP device: {e}")
            traceback.print_exc()
            self._device.state = DeviceState.ERROR
            self.error.emit(f"Failed to connect: {e}")

    def _start_read_thread(self):
        """Start background thread for reading data from device."""
        if self._read_thread and self._read_thread.is_alive():
            return

        self._read_thread = threading.Thread(target=self._read_loop, daemon=True)
        self._read_thread.start()

    def _read_loop(self):
        """Background thread to read data from USB device."""
        print(f"[AA] Read loop started")
        error_count = 0
        max_errors = 5

        while self._running and self._device and self._device.state == DeviceState.CONNECTED:
            try:
                if not self._device or not self._device.in_endpoint:
                    break

                # Read data (16KB buffer)
                data = self._device.in_endpoint.read(16384, timeout=1000)
                if data:
                    print(f"[AA] Received {len(data)} bytes")
                    self.dataReceived.emit(bytes(data))
                    error_count = 0  # Reset on success

            except usb.core.USBTimeoutError:
                # Timeout is normal, just continue
                continue
            except usb.core.USBError as e:
                error_count += 1
                print(f"[AA] USB read error ({error_count}/{max_errors}): {e}")
                logger.error(f"USB read error: {e}")

                if error_count >= max_errors:
                    print(f"[AA] Too many errors, disconnecting")
                    if self._running:
                        self._disconnect_device()
                    break

                # Wait a bit before retrying
                time.sleep(0.1)

            except Exception as e:
                logger.error(f"Unexpected error in read loop: {e}")
                print(f"[AA] Unexpected error in read loop: {e}")
                traceback.print_exc()
                break

        print(f"[AA] Read loop ended")

    def write(self, data: bytes, retries: int = 3) -> bool:
        """Write data to the connected device with retry logic."""
        if not self.is_connected or not self._device or not self._device.out_endpoint:
            print(f"[AA] Write failed: not connected")
            return False

        for attempt in range(retries):
            try:
                bytes_written = self._device.out_endpoint.write(data, timeout=USBConstants.TIMEOUT_MS)
                print(f"[AA] Write: {bytes_written}/{len(data)} bytes")
                return bytes_written == len(data)
            except usb.core.USBTimeoutError as e:
                print(f"[AA] USB write timeout (attempt {attempt + 1}/{retries}): {e}")
                logger.warning(f"USB write timeout: {e}")
                if attempt < retries - 1:
                    # Try to reset the endpoint before retry
                    try:
                        self._device.out_endpoint.clear_halt()
                        print(f"[AA] Cleared endpoint halt, retrying...")
                        time.sleep(0.1)
                    except Exception:
                        pass
                else:
                    # Last attempt failed - device may be stale
                    print(f"[AA] Write failed after {retries} attempts - device may be stale")
                    self._handle_stale_device()
                    return False
            except usb.core.USBError as e:
                print(f"[AA] USB write error: {e}")
                logger.error(f"USB write error: {e}")
                return False
        return False

    def _handle_stale_device(self):
        """Handle a stale/unresponsive device by forcing re-enumeration."""
        self._aoap_fail_count += 1
        print(f"[AA] Handling stale device (fail count: {self._aoap_fail_count}/{self._max_aoap_fails})")
        logger.warning(f"Device appears stale, fail count: {self._aoap_fail_count}")

        if self._aoap_fail_count >= self._max_aoap_fails:
            print(f"[AA] *** PHONE NOT RESPONDING ***")
            print(f"[AA] The phone is in AOAP mode but Android Auto app isn't running.")
            print(f"[AA] ")
            print(f"[AA] To fix this:")
            print(f"[AA]   1. Unplug the USB cable")
            print(f"[AA]   2. Open Android Auto app on your phone")
            print(f"[AA]   3. Plug the USB cable back in")
            print(f"[AA]   4. Accept any prompts on your phone")
            print(f"[AA] ")
            self.error.emit("Phone not responding. Unplug USB, open Android Auto app on phone, then plug back in.")

        if self._device and self._device.device:
            # Try to reset the USB device to force phone out of AOAP mode
            if self._reset_usb_device(self._device.device):
                print(f"[AA] USB reset done, waiting for device to re-enumerate...")
                time.sleep(2.0)  # Give device time to reset

        # Disconnect the device - this will trigger re-detection
        self._disconnect_device()

        # The monitor thread will detect the device again and try to reconnect

    def _disconnect_device(self):
        """Disconnect the current device."""
        with self._lock:
            if self._device:
                try:
                    usb.util.dispose_resources(self._device.device)
                except Exception:
                    pass

                self._device = None
                self.stateChanged.emit(DeviceState.DISCONNECTED.value)
                self.deviceDisconnected.emit()
