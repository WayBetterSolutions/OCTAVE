#!/usr/bin/env python3
"""
Android Auto Connection Test

This script tests the Android Auto USB connection flow:
1. Detects USB devices
2. Checks for Android phones
3. Attempts AOAP handshake
4. Reports connection status

Run with your Android phone connected via USB.
Make sure USB debugging is enabled on your phone.
"""

import sys
import time
import os

# Add backend to path
sys.path.insert(0, '.')


def setup_libusb():
    """Configure libusb backend for Windows."""
    import platform

    try:
        import libusb
        pkg_dir = os.path.dirname(libusb.__file__)

        # Determine architecture
        arch = platform.machine().lower()
        if arch in ('amd64', 'x86_64'):
            dll_subdir = 'x86_64'
        elif arch in ('arm64', 'aarch64'):
            dll_subdir = 'arm64'
        else:
            dll_subdir = 'x86'

        dll_path = os.path.join(pkg_dir, '_platform', 'windows', dll_subdir)
        if os.path.exists(dll_path):
            os.environ['PATH'] = dll_path + os.pathsep + os.environ.get('PATH', '')
            print(f"[Setup] Added libusb path: {dll_path}")
            return True

    except ImportError:
        pass

    # Alternative: try to find libusb DLL manually
    possible_paths = [
        r"C:\Windows\System32\libusb-1.0.dll",
        r"C:\Windows\SysWOW64\libusb-1.0.dll",
    ]

    for path in possible_paths:
        if os.path.exists(path):
            os.environ['PATH'] = os.path.dirname(path) + os.pathsep + os.environ.get('PATH', '')
            return True

    return False


def test_usb_detection():
    """Test basic USB device detection."""
    print("=" * 60)
    print("OCTAVE Android Auto Connection Test")
    print("=" * 60)
    print()

    try:
        import usb.core
        import usb.util
    except ImportError:
        print("ERROR: pyusb not installed!")
        print("Run: pip install pyusb")
        return False

    print("[1] Scanning USB devices...")
    print()

    # Find all USB devices
    devices = list(usb.core.find(find_all=True))
    print(f"Found {len(devices)} USB devices total")
    print()

    # Known Android vendor IDs
    android_vendors = {
        0x18D1: "Google",
        0x04E8: "Samsung",
        0x22B8: "Motorola",
        0x0BB4: "HTC",
        0x12D1: "Huawei",
        0x2717: "Xiaomi",
        0x1949: "OnePlus",
        0x2A70: "OnePlus",
        0x0FCE: "Sony",
        0x1004: "LG",
        0x0B05: "Asus",
    }

    # AOAP IDs
    GOOGLE_VENDOR_ID = 0x18D1
    AOAP_PRODUCT_ID = 0x2D00
    AOAP_WITH_ADB_PRODUCT_ID = 0x2D01

    android_devices = []
    aoap_devices = []

    for dev in devices:
        vendor_name = android_vendors.get(dev.idVendor, None)

        # Check for AOAP mode
        if dev.idVendor == GOOGLE_VENDOR_ID and dev.idProduct in (AOAP_PRODUCT_ID, AOAP_WITH_ADB_PRODUCT_ID):
            aoap_devices.append(dev)
            print(f"  [AOAP MODE] VID:0x{dev.idVendor:04X} PID:0x{dev.idProduct:04X}")

        elif vendor_name:
            android_devices.append((dev, vendor_name))
            print(f"  [Android - {vendor_name}] VID:0x{dev.idVendor:04X} PID:0x{dev.idProduct:04X}")

    print()

    if aoap_devices:
        print("[SUCCESS] Device already in Android Auto (AOAP) mode!")
        print("Ready to start Android Auto communication.")
        return True

    if not android_devices:
        print("[WARNING] No Android devices found!")
        print()
        print("Troubleshooting:")
        print("  1. Make sure your phone is connected via USB")
        print("  2. Enable USB debugging in Developer Options")
        print("  3. Try a different USB cable (data cable, not charge-only)")
        print("  4. On Windows, you may need to install USB drivers")
        return False

    return android_devices


def test_aoap_support(device, vendor_name):
    """Test if device supports AOAP."""
    import usb.core

    print(f"[2] Testing AOAP support for {vendor_name} device...")
    print()

    # AOAP constants
    ACC_REQ_GET_PROTOCOL = 51
    USB_TYPE_VENDOR = 0x40
    ENDPOINT_IN = 0x80

    try:
        # Try to detach kernel driver (Linux)
        try:
            if device.is_kernel_driver_active(0):
                device.detach_kernel_driver(0)
                print("  Detached kernel driver")
        except (usb.core.USBError, NotImplementedError):
            pass

        # Query AOAP protocol version
        version = device.ctrl_transfer(
            ENDPOINT_IN | USB_TYPE_VENDOR,
            ACC_REQ_GET_PROTOCOL,
            0,
            0,
            2,
            1000
        )

        if len(version) >= 2:
            protocol_version = version[0] | (version[1] << 8)
            print(f"  AOAP Protocol Version: {protocol_version}")

            if protocol_version >= 1:
                print("  [SUCCESS] Device supports Android Auto!")
                return protocol_version
            else:
                print("  [WARNING] Protocol version too old")
                return None

    except usb.core.USBError as e:
        print(f"  [ERROR] Could not query AOAP support: {e}")
        print()
        print("  This might mean:")
        print("    - USB debugging is not enabled")
        print("    - You need to accept the USB debugging prompt on your phone")
        print("    - The device doesn't support Android Auto")
        return None

    return None


def test_aoap_handshake(device):
    """Attempt AOAP handshake to switch device to accessory mode."""
    import usb.core

    print()
    print("[3] Attempting AOAP handshake...")
    print()

    # AOAP constants
    ACC_REQ_SEND_STRING = 52
    ACC_REQ_START = 53
    USB_TYPE_VENDOR = 0x40
    ENDPOINT_OUT = 0x00

    # Accessory strings
    strings = [
        (0, "OCTAVE"),                    # Manufacturer
        (1, "OCTAVE Head Unit"),          # Model
        (2, "Android Auto Head Unit"),    # Description
        (3, "1.0.0"),                     # Version
        (4, "https://octave.app"),        # URI
        (5, "OCTAVE-001"),                # Serial
    ]

    try:
        for string_index, string_value in strings:
            data = string_value.encode('utf-8') + b'\x00'
            device.ctrl_transfer(
                ENDPOINT_OUT | USB_TYPE_VENDOR,
                ACC_REQ_SEND_STRING,
                0,
                string_index,
                data,
                1000
            )
            print(f"  Sent: {string_value}")

        # Send start command
        device.ctrl_transfer(
            ENDPOINT_OUT | USB_TYPE_VENDOR,
            ACC_REQ_START,
            0,
            0,
            None,
            1000
        )
        print()
        print("  [SUCCESS] AOAP start command sent!")
        print()
        print("  The device should now disconnect and reconnect in AOAP mode.")
        print("  This may take a few seconds...")
        print()
        print("  Look for a prompt on your phone to start Android Auto.")

        return True

    except usb.core.USBError as e:
        print(f"  [ERROR] AOAP handshake failed: {e}")
        return False


def wait_for_aoap_device():
    """Wait for device to reconnect in AOAP mode."""
    import usb.core

    GOOGLE_VENDOR_ID = 0x18D1
    AOAP_PRODUCT_ID = 0x2D00
    AOAP_WITH_ADB_PRODUCT_ID = 0x2D01

    print("[4] Waiting for device to reconnect in AOAP mode...")
    print()

    for i in range(10):
        time.sleep(1)
        print(f"  Checking... ({i+1}/10)")

        device = usb.core.find(idVendor=GOOGLE_VENDOR_ID, idProduct=AOAP_PRODUCT_ID)
        if device:
            print()
            print("  [SUCCESS] Device reconnected in AOAP mode!")
            return device

        device = usb.core.find(idVendor=GOOGLE_VENDOR_ID, idProduct=AOAP_WITH_ADB_PRODUCT_ID)
        if device:
            print()
            print("  [SUCCESS] Device reconnected in AOAP mode (with ADB)!")
            return device

    print()
    print("  [TIMEOUT] Device did not reconnect in AOAP mode")
    print()
    print("  Possible reasons:")
    print("    - Phone may have shown an Android Auto prompt - check your phone")
    print("    - Android Auto app may not be installed on phone")
    print("    - Phone may have rejected the accessory")
    return None


def main():
    # Setup libusb first
    setup_libusb()

    result = test_usb_detection()

    if result is True:
        # Already in AOAP mode
        print()
        print("Next step: Run OCTAVE with Android Auto enabled")
        return

    if result is False:
        # No devices found
        return

    # Found Android device(s)
    android_devices = result

    print("-" * 60)

    # Test first Android device
    device, vendor_name = android_devices[0]

    protocol = test_aoap_support(device, vendor_name)

    if protocol:
        print()
        print("-" * 60)

        response = input("Do you want to attempt AOAP handshake? (y/n): ")
        if response.lower() == 'y':
            if test_aoap_handshake(device):
                print()
                print("-" * 60)
                aoap_device = wait_for_aoap_device()

                if aoap_device:
                    print()
                    print("=" * 60)
                    print("Android Auto connection ready!")
                    print("You can now run OCTAVE with Android Auto support.")
                    print("=" * 60)


if __name__ == "__main__":
    main()
