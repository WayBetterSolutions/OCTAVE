"""
Android Sensor Manager — reads accelerometer and magnetometer data
from sysfs on rooted Samsung devices.

Replaces BerryIMU on Android with the same signal interface.
"""

import math
import os
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer

from backend.logging_config import get_logger
logger = get_logger(__name__)

# Samsung sysfs sensor paths
ACCEL_PATH = "/sys/devices/virtual/sensors/accelerometer_sensor/raw_data"
MAG_PATH = "/sys/devices/virtual/sensors/magnetic_sensor/raw_data"

# LSM6DSO accelerometer: raw values in mg (milli-g), divide by 1000 for g, multiply by 9.81 for m/s²
# At default ±2g range, sensitivity is ~0.061 mg/LSB
ACCEL_SCALE = 0.00981  # raw → m/s² (raw * 0.001 * 9.81)


class AndroidSensorManager(QObject):
    """
    Reads Samsung device sensors via sysfs and emits the same signals as BerryIMUManager.
    """

    orientationChanged = Signal(float, float, float, float)
    pitchChanged = Signal(float)
    rollChanged = Signal(float)
    headingChanged = Signal(float)
    altitudeChanged = Signal(float)
    accelMagnitudeChanged = Signal(float)
    lateralGChanged = Signal(float)
    longitudinalGChanged = Signal(float)
    baroTempChanged = Signal(float)
    connectionStatusChanged = Signal(str)

    def __init__(self):
        super().__init__()
        self._connected = False
        self._enabled = False
        self._emit_rate = 30

        # Tare offsets
        self._tare_pitch = 0.0
        self._tare_roll = 0.0

        # Check if sensors are accessible
        self._has_accel = os.path.isfile(ACCEL_PATH)
        self._has_mag = os.path.isfile(MAG_PATH)

        if self._has_accel:
            self._connected = True
            self._enabled = True
            logger.info("Android sysfs sensors found (accel=%s, mag=%s)", self._has_accel, self._has_mag)
            self.connectionStatusChanged.emit("Connected")
        else:
            logger.warning("No sysfs accelerometer found at %s", ACCEL_PATH)
            self.connectionStatusChanged.emit("Unavailable")

        # Polling timer
        self._timer = QTimer()
        self._timer.timeout.connect(self._poll_sensors)
        if self._connected:
            self._timer.start(int(1000 / self._emit_rate))

    def _read_sensor(self, path):
        """Read comma-separated x,y,z from a sysfs file."""
        try:
            with open(path, 'r') as f:
                parts = f.read().strip().split(',')
                return [float(parts[0]), float(parts[1]), float(parts[2])]
        except Exception:
            return None

    def _poll_sensors(self):
        """Read sensors and emit signals."""
        raw_accel = self._read_sensor(ACCEL_PATH)
        if raw_accel is None:
            return

        # Convert raw to m/s²
        ax = raw_accel[0] * ACCEL_SCALE
        ay = raw_accel[1] * ACCEL_SCALE
        az = raw_accel[2] * ACCEL_SCALE

        # G-force magnitude (1.0 = normal gravity)
        g_total = math.sqrt(ax * ax + ay * ay + az * az) / 9.81
        self.accelMagnitudeChanged.emit(round(g_total, 3))

        # Lateral and longitudinal G
        self.lateralGChanged.emit(round(ax / 9.81, 3))
        self.longitudinalGChanged.emit(round(ay / 9.81, 3))

        # Pitch and roll
        pitch = math.degrees(math.atan2(ay, math.sqrt(ax * ax + az * az)))
        roll = math.degrees(math.atan2(-ax, az))
        pitch -= self._tare_pitch
        roll -= self._tare_roll

        self.pitchChanged.emit(round(pitch, 2))
        self.rollChanged.emit(round(roll, 2))

        # Heading from magnetometer
        if self._has_mag:
            raw_mag = self._read_sensor(MAG_PATH)
            if raw_mag:
                mx, my = raw_mag[0], raw_mag[1]
                heading = math.degrees(math.atan2(my, mx))
                if heading < 0:
                    heading += 360
                self.headingChanged.emit(round(heading, 1))

        # No barometer
        self.altitudeChanged.emit(0.0)
        self.baroTempChanged.emit(0.0)

    @Property(bool, notify=connectionStatusChanged)
    def connected(self):
        return self._connected

    @Slot(result=str)
    def getConnectionStatus(self):
        return "Connected" if self._connected else "Unavailable"

    @Slot(bool)
    def setEnabled(self, enabled):
        self._enabled = enabled
        if enabled and self._connected and not self._timer.isActive():
            self._timer.start(int(1000 / self._emit_rate))
        elif not enabled:
            self._timer.stop()

    @Slot(result=bool)
    def isEnabled(self):
        return self._enabled

    @Slot(int)
    def setEmitRate(self, hz):
        self._emit_rate = max(1, min(120, hz))
        if self._timer.isActive():
            self._timer.setInterval(int(1000 / self._emit_rate))

    @Slot()
    def calibrateTare(self):
        raw = self._read_sensor(ACCEL_PATH)
        if raw:
            ax, ay, az = raw[0] * ACCEL_SCALE, raw[1] * ACCEL_SCALE, raw[2] * ACCEL_SCALE
            self._tare_pitch = math.degrees(math.atan2(ay, math.sqrt(ax * ax + az * az)))
            self._tare_roll = math.degrees(math.atan2(-ax, az))
            logger.info(f"Tare calibrated: pitch={self._tare_pitch:.1f}, roll={self._tare_roll:.1f}")

    @Slot()
    def resetTare(self):
        self._tare_pitch = 0.0
        self._tare_roll = 0.0

    @Slot()
    def cleanup(self):
        self._timer.stop()
        self._connected = False

    def connect_settings_manager(self, settings_manager):
        pass
