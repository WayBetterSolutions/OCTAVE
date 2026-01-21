"""
OBD Manager for OCTAVE
Handles OBD-II connection, parameter monitoring, and vehicle diagnostics.

Refactored to use a data-driven parameter registry instead of repetitive code.
"""

from PySide6.QtCore import QObject, Signal, Slot, QTimer, QThread
import obd
from obd import OBDStatus
import time
import os
import sys
import threading
import glob

from backend.logging_config import get_logger
logger = get_logger(__name__)


# =============================================================================
# OBD Parameter Registry - Data-driven approach to eliminate copy-paste code
# =============================================================================

# Each parameter is defined once with all its metadata.
# Format: "PARAM_NAME": {
#     "command": OBD command name (string, resolved at runtime),
#     "signal": signal name for QML,
#     "attr": internal attribute name,
#     "default_enabled": whether enabled by default,
#     "convert": optional conversion function (e.g., km/h to mph),
# }

OBD_PARAMETERS = {
    # Original 18 parameters (enabled by default)
    "COOLANT_TEMP": {"command": "COOLANT_TEMP", "signal": "coolantTempChanged", "attr": "_coolant_temp", "default_enabled": True},
    "CONTROL_MODULE_VOLTAGE": {"command": "CONTROL_MODULE_VOLTAGE", "signal": "voltageChanged", "attr": "_voltage", "default_enabled": True},
    "ENGINE_LOAD": {"command": "ENGINE_LOAD", "signal": "engineLoadChanged", "attr": "_engine_load", "default_enabled": True},
    "THROTTLE_POS": {"command": "THROTTLE_POS", "signal": "throttlePositionChanged", "attr": "_throttle_pos", "default_enabled": True},
    "INTAKE_TEMP": {"command": "INTAKE_TEMP", "signal": "intakeAirTempChanged", "attr": "_intake_temp", "default_enabled": True},
    "TIMING_ADVANCE": {"command": "TIMING_ADVANCE", "signal": "timingAdvanceChanged", "attr": "_timing_advance", "default_enabled": True, "also_emit": [("ignitionTimingChanged", "_ignition_timing")]},
    "MAF": {"command": "MAF", "signal": "massAirFlowChanged", "attr": "_mass_airflow", "default_enabled": True},
    "SPEED": {"command": "SPEED", "signal": "speedMPHChanged", "attr": "_speed_mph", "default_enabled": True, "convert": lambda v: v.to("mph").magnitude},
    "RPM": {"command": "RPM", "signal": "rpmChanged", "attr": "_rpm", "default_enabled": True},
    "COMMANDED_EQUIV_RATIO": {"command": "COMMANDED_EQUIV_RATIO", "signal": "airFuelRatioChanged", "attr": "_air_fuel_ratio", "default_enabled": True, "convert": lambda v: v.magnitude * 14.7},
    "FUEL_LEVEL": {"command": "FUEL_LEVEL", "signal": "fuelLevelChanged", "attr": "_fuel_level", "default_enabled": True},
    "INTAKE_PRESSURE": {"command": "INTAKE_PRESSURE", "signal": "intakeManifoldPressureChanged", "attr": "_intake_pressure", "default_enabled": True},
    "SHORT_FUEL_TRIM_1": {"command": "SHORT_FUEL_TRIM_1", "signal": "shortTermFuelTrimChanged", "attr": "_short_term_fuel_trim", "default_enabled": True},
    "LONG_FUEL_TRIM_1": {"command": "LONG_FUEL_TRIM_1", "signal": "longTermFuelTrimChanged", "attr": "_long_term_fuel_trim", "default_enabled": True},
    "O2_B1S1": {"command": "O2_B1S1", "signal": "oxygenSensorVoltageChanged", "attr": "_o2_sensor_voltage", "default_enabled": True},
    "FUEL_PRESSURE": {"command": "FUEL_PRESSURE", "signal": "fuelPressureChanged", "attr": "_fuel_pressure", "default_enabled": True},
    "OIL_TEMP": {"command": "OIL_TEMP", "signal": "engineOilTempChanged", "attr": "_oil_temp", "default_enabled": True},

    # Additional parameters (disabled by default)
    "RUN_TIME": {"command": "RUN_TIME", "signal": "runTimeChanged", "attr": "_run_time", "default_enabled": False},
    "DISTANCE_W_MIL": {"command": "DISTANCE_W_MIL", "signal": "distanceWithMILChanged", "attr": "_distance_with_mil", "default_enabled": False},
    "FUEL_RAIL_PRESSURE_VAC": {"command": "FUEL_RAIL_PRESSURE_VAC", "signal": "fuelRailPressureChanged", "attr": "_fuel_rail_pressure", "default_enabled": False},
    "FUEL_RAIL_PRESSURE_DIRECT": {"command": "FUEL_RAIL_PRESSURE_DIRECT", "signal": "fuelRailPressureDirectChanged", "attr": "_fuel_rail_pressure_direct", "default_enabled": False},
    "BAROMETRIC_PRESSURE": {"command": "BAROMETRIC_PRESSURE", "signal": "barometricPressureChanged", "attr": "_barometric_pressure", "default_enabled": False},
    "AMBIANT_AIR_TEMP": {"command": "AMBIANT_AIR_TEMP", "signal": "ambientAirTempChanged", "attr": "_ambient_air_temp", "default_enabled": False},
    "RELATIVE_THROTTLE_POS": {"command": "RELATIVE_THROTTLE_POS", "signal": "relativeThrottlePosChanged", "attr": "_relative_throttle_pos", "default_enabled": False},
    "THROTTLE_POS_B": {"command": "THROTTLE_POS_B", "signal": "absoluteThrottlePosBChanged", "attr": "_absolute_throttle_pos_b", "default_enabled": False},
    "ACCELERATOR_POS_D": {"command": "ACCELERATOR_POS_D", "signal": "acceleratorPosChanged", "attr": "_accelerator_pos", "default_enabled": False},
    "CATALYST_TEMP_B1S1": {"command": "CATALYST_TEMP_B1S1", "signal": "catalystTempB1S1Changed", "attr": "_catalyst_temp_b1s1", "default_enabled": False},
    "CATALYST_TEMP_B1S2": {"command": "CATALYST_TEMP_B1S2", "signal": "catalystTempB1S2Changed", "attr": "_catalyst_temp_b1s2", "default_enabled": False},
    "EVAP_VAPOR_PRESSURE": {"command": "EVAP_VAPOR_PRESSURE", "signal": "evapVaporPressureChanged", "attr": "_evap_vapor_pressure", "default_enabled": False},
    "SHORT_FUEL_TRIM_2": {"command": "SHORT_FUEL_TRIM_2", "signal": "shortFuelTrim2Changed", "attr": "_short_fuel_trim_2", "default_enabled": False},
    "LONG_FUEL_TRIM_2": {"command": "LONG_FUEL_TRIM_2", "signal": "longFuelTrim2Changed", "attr": "_long_fuel_trim_2", "default_enabled": False},
    "O2_B1S2": {"command": "O2_B1S2", "signal": "o2SensorB1S2Changed", "attr": "_o2_sensor_b1s2", "default_enabled": False},
    "O2_B2S1": {"command": "O2_B2S1", "signal": "o2SensorB2S1Changed", "attr": "_o2_sensor_b2s1", "default_enabled": False},
    "O2_B2S2": {"command": "O2_B2S2", "signal": "o2SensorB2S2Changed", "attr": "_o2_sensor_b2s2", "default_enabled": False},
    "DISTANCE_SINCE_DTC_CLEAR": {"command": "DISTANCE_SINCE_DTC_CLEAR", "signal": "distanceSinceCodesCleared", "attr": "_distance_since_codes_cleared", "default_enabled": False},
    "WARMUPS_SINCE_DTC_CLEAR": {"command": "WARMUPS_SINCE_DTC_CLEAR", "signal": "warmupsSinceCodesCleared", "attr": "_warmups_since_codes_cleared", "default_enabled": False},
    "ABSOLUTE_LOAD": {"command": "ABSOLUTE_LOAD", "signal": "absoluteLoadChanged", "attr": "_absolute_load", "default_enabled": False},
    "COMMANDED_EGR": {"command": "COMMANDED_EGR", "signal": "commandedEGRChanged", "attr": "_commanded_egr", "default_enabled": False},
    "EGR_ERROR": {"command": "EGR_ERROR", "signal": "egrErrorChanged", "attr": "_egr_error", "default_enabled": False},
    "ETHANOL_PERCENT": {"command": "ETHANOL_PERCENT", "signal": "ethanoPercentChanged", "attr": "_ethanol_percent", "default_enabled": False},

    # Additional O2 sensors
    "O2_B1S3": {"command": "O2_B1S3", "signal": "o2SensorB1S3Changed", "attr": "_o2_sensor_b1s3", "default_enabled": False},
    "O2_B1S4": {"command": "O2_B1S4", "signal": "o2SensorB1S4Changed", "attr": "_o2_sensor_b1s4", "default_enabled": False},
    "O2_B2S3": {"command": "O2_B2S3", "signal": "o2SensorB2S3Changed", "attr": "_o2_sensor_b2s3", "default_enabled": False},
    "O2_B2S4": {"command": "O2_B2S4", "signal": "o2SensorB2S4Changed", "attr": "_o2_sensor_b2s4", "default_enabled": False},

    # Wide-range O2 sensors voltage
    "O2_S1_WR_VOLTAGE": {"command": "O2_S1_WR_VOLTAGE", "signal": "o2S1WRVoltageChanged", "attr": "_o2_s1_wr_voltage", "default_enabled": False},
    "O2_S2_WR_VOLTAGE": {"command": "O2_S2_WR_VOLTAGE", "signal": "o2S2WRVoltageChanged", "attr": "_o2_s2_wr_voltage", "default_enabled": False},
    "O2_S3_WR_VOLTAGE": {"command": "O2_S3_WR_VOLTAGE", "signal": "o2S3WRVoltageChanged", "attr": "_o2_s3_wr_voltage", "default_enabled": False},
    "O2_S4_WR_VOLTAGE": {"command": "O2_S4_WR_VOLTAGE", "signal": "o2S4WRVoltageChanged", "attr": "_o2_s4_wr_voltage", "default_enabled": False},
    "O2_S5_WR_VOLTAGE": {"command": "O2_S5_WR_VOLTAGE", "signal": "o2S5WRVoltageChanged", "attr": "_o2_s5_wr_voltage", "default_enabled": False},
    "O2_S6_WR_VOLTAGE": {"command": "O2_S6_WR_VOLTAGE", "signal": "o2S6WRVoltageChanged", "attr": "_o2_s6_wr_voltage", "default_enabled": False},
    "O2_S7_WR_VOLTAGE": {"command": "O2_S7_WR_VOLTAGE", "signal": "o2S7WRVoltageChanged", "attr": "_o2_s7_wr_voltage", "default_enabled": False},
    "O2_S8_WR_VOLTAGE": {"command": "O2_S8_WR_VOLTAGE", "signal": "o2S8WRVoltageChanged", "attr": "_o2_s8_wr_voltage", "default_enabled": False},

    # Wide-range O2 sensors current
    "O2_S1_WR_CURRENT": {"command": "O2_S1_WR_CURRENT", "signal": "o2S1WRCurrentChanged", "attr": "_o2_s1_wr_current", "default_enabled": False},
    "O2_S2_WR_CURRENT": {"command": "O2_S2_WR_CURRENT", "signal": "o2S2WRCurrentChanged", "attr": "_o2_s2_wr_current", "default_enabled": False},
    "O2_S3_WR_CURRENT": {"command": "O2_S3_WR_CURRENT", "signal": "o2S3WRCurrentChanged", "attr": "_o2_s3_wr_current", "default_enabled": False},
    "O2_S4_WR_CURRENT": {"command": "O2_S4_WR_CURRENT", "signal": "o2S4WRCurrentChanged", "attr": "_o2_s4_wr_current", "default_enabled": False},
    "O2_S5_WR_CURRENT": {"command": "O2_S5_WR_CURRENT", "signal": "o2S5WRCurrentChanged", "attr": "_o2_s5_wr_current", "default_enabled": False},
    "O2_S6_WR_CURRENT": {"command": "O2_S6_WR_CURRENT", "signal": "o2S6WRCurrentChanged", "attr": "_o2_s6_wr_current", "default_enabled": False},
    "O2_S7_WR_CURRENT": {"command": "O2_S7_WR_CURRENT", "signal": "o2S7WRCurrentChanged", "attr": "_o2_s7_wr_current", "default_enabled": False},
    "O2_S8_WR_CURRENT": {"command": "O2_S8_WR_CURRENT", "signal": "o2S8WRCurrentChanged", "attr": "_o2_s8_wr_current", "default_enabled": False},

    # Bank 2 catalyst temps
    "CATALYST_TEMP_B2S1": {"command": "CATALYST_TEMP_B2S1", "signal": "catalystTempB2S1Changed", "attr": "_catalyst_temp_b2s1", "default_enabled": False},
    "CATALYST_TEMP_B2S2": {"command": "CATALYST_TEMP_B2S2", "signal": "catalystTempB2S2Changed", "attr": "_catalyst_temp_b2s2", "default_enabled": False},

    # Additional throttle/accelerator
    "THROTTLE_POS_C": {"command": "THROTTLE_POS_C", "signal": "throttlePosCChanged", "attr": "_throttle_pos_c", "default_enabled": False},
    "ACCELERATOR_POS_E": {"command": "ACCELERATOR_POS_E", "signal": "acceleratorPosEChanged", "attr": "_accelerator_pos_e", "default_enabled": False},
    "ACCELERATOR_POS_F": {"command": "ACCELERATOR_POS_F", "signal": "acceleratorPosFChanged", "attr": "_accelerator_pos_f", "default_enabled": False},
    "THROTTLE_ACTUATOR": {"command": "THROTTLE_ACTUATOR", "signal": "throttleActuatorChanged", "attr": "_throttle_actuator", "default_enabled": False},

    # Fuel system
    "EVAPORATIVE_PURGE": {"command": "EVAPORATIVE_PURGE", "signal": "evaporativePurgeChanged", "attr": "_evaporative_purge", "default_enabled": False},
    "FUEL_RAIL_PRESSURE_ABS": {"command": "FUEL_RAIL_PRESSURE_ABS", "signal": "fuelRailPressureAbsChanged", "attr": "_fuel_rail_pressure_abs", "default_enabled": False},
    "FUEL_INJECT_TIMING": {"command": "FUEL_INJECT_TIMING", "signal": "fuelInjectTimingChanged", "attr": "_fuel_inject_timing", "default_enabled": False},
    "FUEL_RATE": {"command": "FUEL_RATE", "signal": "fuelRateChanged", "attr": "_fuel_rate", "default_enabled": False},

    # Time-based
    "RUN_TIME_MIL": {"command": "RUN_TIME_MIL", "signal": "runTimeMILChanged", "attr": "_run_time_mil", "default_enabled": False},
    "TIME_SINCE_DTC_CLEARED": {"command": "TIME_SINCE_DTC_CLEARED", "signal": "timeSinceDTCClearedChanged", "attr": "_time_since_dtc_cleared", "default_enabled": False},

    # Other
    "MAX_MAF": {"command": "MAX_MAF", "signal": "maxMAFChanged", "attr": "_max_maf", "default_enabled": False},
    "FUEL_TYPE": {"command": "FUEL_TYPE", "signal": "fuelTypeChanged", "attr": "_fuel_type", "default_enabled": False},
    "EVAP_VAPOR_PRESSURE_ABS": {"command": "EVAP_VAPOR_PRESSURE_ABS", "signal": "evapVaporPressureAbsChanged", "attr": "_evap_vapor_pressure_abs", "default_enabled": False},
    "EVAP_VAPOR_PRESSURE_ALT": {"command": "EVAP_VAPOR_PRESSURE_ALT", "signal": "evapVaporPressureAltChanged", "attr": "_evap_vapor_pressure_alt", "default_enabled": False},
    "SHORT_O2_TRIM_B1": {"command": "SHORT_O2_TRIM_B1", "signal": "shortO2TrimB1Changed", "attr": "_short_o2_trim_b1", "default_enabled": False},
    "LONG_O2_TRIM_B1": {"command": "LONG_O2_TRIM_B1", "signal": "longO2TrimB1Changed", "attr": "_long_o2_trim_b1", "default_enabled": False},
    "SHORT_O2_TRIM_B2": {"command": "SHORT_O2_TRIM_B2", "signal": "shortO2TrimB2Changed", "attr": "_short_o2_trim_b2", "default_enabled": False},
    "LONG_O2_TRIM_B2": {"command": "LONG_O2_TRIM_B2", "signal": "longO2TrimB2Changed", "attr": "_long_o2_trim_b2", "default_enabled": False},
    "RELATIVE_ACCEL_POS": {"command": "RELATIVE_ACCEL_POS", "signal": "relativeAccelPosChanged", "attr": "_relative_accel_pos", "default_enabled": False},
    "HYBRID_BATTERY_REMAINING": {"command": "HYBRID_BATTERY_REMAINING", "signal": "hybridBatteryRemainingChanged", "attr": "_hybrid_battery_remaining", "default_enabled": False},
    "ELM_VOLTAGE": {"command": "ELM_VOLTAGE", "signal": "elmVoltageChanged", "attr": "_elm_voltage", "default_enabled": False},
}


# =============================================================================
# Connection Worker - Handles blocking OBD connection in separate thread
# =============================================================================

class OBDConnectionWorker(QObject):
    """Worker that runs OBD connection in a separate thread to avoid blocking UI"""

    connectionComplete = Signal(object, object)  # (connection, status)
    connectionProgress = Signal(int, str)  # (progress, message)
    connectionError = Signal(str)

    def __init__(self):
        super().__init__()
        self._port = None
        self._fast_mode = True
        self._timeout = 5
        self._cached_protocol = None

    def set_params(self, port, fast_mode, timeout, cached_protocol=None):
        self._port = port
        self._fast_mode = fast_mode
        self._timeout = timeout
        self._cached_protocol = cached_protocol

    def do_connect(self):
        """Perform the actual OBD connection - runs in worker thread"""
        try:
            if self._cached_protocol:
                self.connectionProgress.emit(20, f"Connecting with cached protocol...")
                logger.debug(f"Attempting connection with cached protocol: {self._cached_protocol}")
            else:
                self.connectionProgress.emit(20, "Initializing OBD adapter...")

            connection = obd.Async(
                portstr=self._port,
                fast=self._fast_mode,
                timeout=self._timeout
            )

            self.connectionProgress.emit(80, "Checking connection status...")
            status = connection.status()
            self.connectionComplete.emit(connection, status)

        except Exception as e:
            self.connectionError.emit(str(e))


# =============================================================================
# OBD Manager - Main class for OBD-II communication
# =============================================================================

def _create_obd_manager_class():
    """
    Factory function that creates the OBDManager class with dynamically generated signals.
    This allows us to create signals from the parameter registry at class definition time.
    """

    # Build the signals dictionary for the class
    signals = {}

    # Parameter signals (from registry)
    for param_name, param_info in OBD_PARAMETERS.items():
        signals[param_info["signal"]] = Signal(float)
        # Handle additional signals for parameters that emit multiple values
        if "also_emit" in param_info:
            for extra_signal, _ in param_info["also_emit"]:
                signals[extra_signal] = Signal(float)

    # Connection status signals
    signals["connectionStatusChanged"] = Signal(str)
    signals["connectionStatusDetailChanged"] = Signal(str)
    signals["connectionProgressChanged"] = Signal(int)
    signals["devicePresenceChanged"] = Signal(bool)
    signals["availablePortsChanged"] = Signal(list)
    signals["supportedCommandsChanged"] = Signal(list)
    signals["scanProgressChanged"] = Signal(int, str)
    signals["scanCompleteChanged"] = Signal(list)

    # Diagnostic signals
    signals["dtcCodesChanged"] = Signal(list)
    signals["dtcCountChanged"] = Signal(int)
    signals["milStatusChanged"] = Signal(bool)
    signals["dtcClearResult"] = Signal(bool, str)
    signals["freezeFrameChanged"] = Signal(list)

    # Internal signals for thread-safe emission
    signals["_emitDtcCodes"] = Signal(list)
    signals["_emitDtcCount"] = Signal(int)
    signals["_emitMilStatus"] = Signal(bool)
    signals["_emitDtcClearResult"] = Signal(bool, str)
    signals["_emitFreezeFrame"] = Signal(list)

    class OBDManagerImpl(QObject):
        # Signals are added dynamically below

        def __init__(self, settings_manager=None):
            super().__init__()
            self._connection = None
            self._connected = False
            self._settings_manager = settings_manager
            self._lock = threading.Lock()

            # Initialize all parameter values to 0.0
            self._param_values = {info["attr"]: 0.0 for info in OBD_PARAMETERS.values()}
            # Also initialize any additional attributes from also_emit
            for info in OBD_PARAMETERS.values():
                if "also_emit" in info:
                    for _, attr in info["also_emit"]:
                        self._param_values[attr] = 0.0

            # Supported commands detected from vehicle
            self._supported_commands = []
            self._is_scanning = False

            # Diagnostic data
            self._dtc_codes = []
            self._dtc_count = 0
            self._mil_status = False
            self._freeze_frame_dtcs = []
            self._diagnostic_mode = False
            self._diagnostic_sync_conn = None
            self._diagnostic_mode_lock = threading.Lock()
            self._diagnostic_mode_transitioning = False

            # Connection management
            self._connection_attempts = 0
            self._connection_status = "Not Connected"
            self._connection_detail = "Waiting for startup..."
            self._is_connecting = False
            self._last_reconnect_time = 0
            self._last_successful_protocol = None
            self._auto_reconnect_delay = 5.0
            self._force_stop_reconnect = False
            self._connection_timeout = 5

            # Connection monitor thread
            self._monitor_thread = None
            self._stop_monitor = False

            # Data watchdog
            self._last_data_received = 0
            self._data_watchdog_timeout = 30.0
            self._has_active_watchers = False
            self._data_watchdog_timer = QTimer()
            self._data_watchdog_timer.setInterval(5000)
            self._data_watchdog_timer.timeout.connect(self._check_data_watchdog)

            # Worker thread for non-blocking connections
            self._worker_thread = None
            self._worker = None

            # Device discovery
            self._available_ports = []
            self._last_device_scan = 0
            self._device_scan_interval = 10.0

            # Background device scanner timer
            self._device_scanner_timer = QTimer()
            self._device_scanner_timer.setInterval(10000)
            self._device_scanner_timer.timeout.connect(self._scan_for_devices)

            # Debounce timer for settings changes
            self._port_change_timer = QTimer()
            self._port_change_timer.setSingleShot(True)
            self._port_change_timer.setInterval(1000)
            self._port_change_timer.timeout.connect(self._on_port_changed)
            self._pending_port = None

            # Startup timer
            self._startup_timer = QTimer()
            self._startup_timer.setSingleShot(True)
            self._startup_timer.setInterval(500)
            self._startup_timer.timeout.connect(self._initial_connect)
            self._startup_timer.start()

            # Connect internal signals for thread-safe emission
            self._emitDtcCodes.connect(self._forwardDtcCodes)
            self._emitDtcCount.connect(self._forwardDtcCount)
            self._emitMilStatus.connect(self._forwardMilStatus)
            self._emitDtcClearResult.connect(self._forwardDtcClearResult)
            self._emitFreezeFrame.connect(self._forwardFreezeFrame)

            # Connect to settings changes
            if self._settings_manager:
                self._settings_manager.obdBluetoothPortChanged.connect(self._schedule_port_change)
                self._settings_manager.obdParametersChanged.connect(self._refresh_watchers)

        # ==================== Parameter Value Access ====================

        def _get_param_value(self, attr):
            """Get a parameter value by attribute name"""
            return self._param_values.get(attr, 0.0)

        def _set_param_value(self, attr, value):
            """Set a parameter value by attribute name"""
            self._param_values[attr] = value

        # ==================== Generic Parameter Callback ====================

        def _create_param_callback(self, param_name):
            """Create a callback function for a parameter"""
            param_info = OBD_PARAMETERS[param_name]
            attr = param_info["attr"]
            signal_name = param_info["signal"]
            convert = param_info.get("convert")
            also_emit = param_info.get("also_emit", [])

            def callback(r):
                self._mark_data_received()
                if not r.is_null():
                    if convert:
                        value = float(convert(r.value))
                    else:
                        value = float(r.value.magnitude)

                    self._set_param_value(attr, value)
                    getattr(self, signal_name).emit(value)

                    # Handle additional emissions (e.g., timing advance -> ignition timing)
                    for extra_signal, extra_attr in also_emit:
                        self._set_param_value(extra_attr, value)
                        getattr(self, extra_signal).emit(value)

            return callback

        # ==================== Platform Detection ====================

        def _get_platform(self):
            """Detect the current platform"""
            if sys.platform.startswith('win'):
                return 'windows'
            elif sys.platform.startswith('darwin'):
                return 'macos'
            return 'linux'

        def _get_max_reconnect_attempts(self):
            """Get max reconnect attempts from settings (0 = disabled)"""
            if self._settings_manager:
                return self._settings_manager.obdAutoReconnectAttempts
            return 0

        def _is_auto_reconnect_enabled(self):
            """Check if auto-reconnect is enabled based on settings"""
            return self._get_max_reconnect_attempts() > 0

        # ==================== Device Discovery ====================

        def _scan_for_devices(self):
            """Scan for available OBD/serial ports based on platform"""
            platform = self._get_platform()
            ports = []

            try:
                if platform == 'windows':
                    import serial.tools.list_ports
                    for port in serial.tools.list_ports.comports():
                        desc_lower = port.description.lower()
                        if any(keyword in desc_lower for keyword in ['bluetooth', 'obd', 'elm', 'serial', 'usb']):
                            ports.append(port.device)
                        elif port.device.startswith('COM'):
                            ports.append(port.device)

                elif platform == 'macos':
                    ports.extend(glob.glob('/dev/tty.OBD*'))
                    ports.extend(glob.glob('/dev/tty.Bluetooth*'))
                    ports.extend(glob.glob('/dev/cu.OBD*'))
                    ports.extend(glob.glob('/dev/cu.Bluetooth*'))
                    ports.extend(glob.glob('/dev/tty.usbserial*'))
                    ports.extend(glob.glob('/dev/cu.usbserial*'))
                    ports.extend(glob.glob('/dev/tty.*ELM*'))
                    ports.extend(glob.glob('/dev/cu.*ELM*'))

                else:  # Linux
                    ports.extend(glob.glob('/dev/rfcomm*'))
                    ports.extend(glob.glob('/dev/ttyUSB*'))
                    ports.extend(glob.glob('/dev/ttyACM*'))
                    ports.extend(glob.glob('/dev/ttyS*'))

                ports = sorted(list(set(ports)))

                if ports != self._available_ports:
                    self._available_ports = ports
                    self.availablePortsChanged.emit(ports)
                    logger.info(f"Discovered ports: {ports}")

                    if ports and not self._connected and not self._is_connecting:
                        configured_port = self._get_configured_port()
                        if configured_port in ports:
                            logger.info(f"Configured port {configured_port} is now available, attempting connection...")
                            self._connection_attempts = 0
                            self._start_connection()
                        elif ports:
                            self.connectionStatusDetailChanged.emit(f"Device at {configured_port} not found. Available: {', '.join(ports)}")

            except Exception as e:
                logger.error(f"Error scanning for devices: {e}")

            self._last_device_scan = time.time()

        def _get_configured_port(self):
            """Get the configured port from settings, with platform-appropriate default"""
            if self._settings_manager:
                port = self._settings_manager.obdBluetoothPort
                if port:
                    return port

            platform = self._get_platform()
            if platform == 'windows':
                return 'COM3'
            elif platform == 'macos':
                return '/dev/tty.OBD'
            return '/dev/rfcomm0'

        def _check_port_exists(self, port):
            """Check if a port exists, cross-platform"""
            platform = self._get_platform()

            if platform == 'windows':
                try:
                    import serial.tools.list_ports
                    available = [p.device for p in serial.tools.list_ports.comports()]
                    return port in available
                except (ImportError, OSError) as e:
                    logger.debug(f"Port check fallback: {e}")
                    return True
            return os.path.exists(port)

        # ==================== Connection Management ====================

        def _schedule_port_change(self):
            """Schedule a port change with debouncing"""
            new_port = self._settings_manager.obdBluetoothPort if self._settings_manager else None
            if new_port and new_port != self._pending_port:
                self._pending_port = new_port
                self._port_change_timer.start()
                logger.debug(f"Port change scheduled: {new_port}")

        def _on_port_changed(self):
            """Handle port change after debounce"""
            if self._pending_port:
                logger.info(f"Port changed to: {self._pending_port}")
                self._connection_attempts = 0
                self.reconnect()
                self._pending_port = None

        def _initial_connect(self):
            """Initial connection attempt on startup"""
            logger.info("Starting initial connection...")
            self._scan_for_devices()
            self._device_scanner_timer.start()
            self._start_connection()

        def _start_connection(self):
            """Start a non-blocking connection attempt"""
            with self._lock:
                if self._is_connecting:
                    logger.debug("Already connecting - skipping")
                    return
                self._is_connecting = True

            self._connection_attempts += 1
            logger.info(f"Starting connection attempt #{self._connection_attempts}")

            self.connectionStatusChanged.emit("Connecting")
            self.connectionStatusDetailChanged.emit(f"Attempt {self._connection_attempts}...")
            self.connectionProgressChanged.emit(10)

            port = self._get_configured_port()
            fast_mode = self._settings_manager.obdFastMode if self._settings_manager else True

            if not self._check_port_exists(port):
                self._connected = False
                self.connectionStatusChanged.emit("Device Not Found")
                self.connectionStatusDetailChanged.emit(f"Port {port} not available")
                self.connectionProgressChanged.emit(0)
                self.devicePresenceChanged.emit(False)
                logger.warning(f"Port {port} not found")
                with self._lock:
                    self._is_connecting = False
                self._schedule_auto_reconnect()
                return

            self.devicePresenceChanged.emit(True)
            self.connectionProgressChanged.emit(15)
            self.connectionStatusDetailChanged.emit(f"Found {port}, connecting...")

            if self._worker_thread is not None and self._worker_thread.isRunning():
                self._worker_thread.quit()
                self._worker_thread.wait(1000)

            self._worker = OBDConnectionWorker()
            self._worker.set_params(port, fast_mode, self._connection_timeout, self._last_successful_protocol)

            self._worker_thread = QThread()
            self._worker.moveToThread(self._worker_thread)

            self._worker.connectionProgress.connect(self._on_connection_progress)
            self._worker.connectionComplete.connect(self._on_connection_complete)
            self._worker.connectionError.connect(self._on_connection_error)

            self._worker_thread.started.connect(self._worker.do_connect)
            self._worker_thread.start()

        def _on_connection_progress(self, progress, message):
            """Handle connection progress updates from worker"""
            self.connectionProgressChanged.emit(progress)
            self.connectionStatusDetailChanged.emit(message)

        def _on_connection_complete(self, connection, status):
            """Handle connection result on main thread"""
            logger.info(f"Connection complete, status: {status}")

            if status == OBDStatus.CAR_CONNECTED:
                self._connection = connection
                self._connected = True
                self._connection_attempts = 0

                try:
                    self._last_successful_protocol = connection.protocol_name()
                    logger.debug(f"Caching successful protocol: {self._last_successful_protocol}")
                except Exception:
                    pass

                self.connectionStatusChanged.emit("Connected")
                self.connectionStatusDetailChanged.emit("OBD interface connected successfully")
                self.connectionProgressChanged.emit(100)

                self._setup_watchers()
                self._connection.start()
                self._start_connection_monitor()

                self._last_data_received = time.time()
                self._data_watchdog_timer.start()
                logger.debug("Data watchdog started")

                self._device_scanner_timer.stop()

            elif status == OBDStatus.ELM_CONNECTED:
                self._connection = connection
                self._connected = False

                self.connectionStatusChanged.emit("No Vehicle")
                self.connectionStatusDetailChanged.emit("Connected to adapter, waiting for vehicle...")
                self.connectionProgressChanged.emit(50)

                self._schedule_auto_reconnect()

            else:
                self._connected = False
                if connection:
                    try:
                        connection.close()
                    except Exception:
                        pass

                self.connectionStatusChanged.emit("Connection Failed")
                self.connectionStatusDetailChanged.emit("Could not connect to OBD adapter")
                self.connectionProgressChanged.emit(0)
                self._schedule_auto_reconnect()

            with self._lock:
                self._is_connecting = False

            self._cleanup_worker_thread()

        def _cleanup_worker_thread(self):
            """Clean up the worker thread after connection attempt"""
            if self._worker_thread is not None and self._worker_thread.isRunning():
                self._worker_thread.quit()
                self._worker_thread.wait(2000)
            self._worker_thread = None
            self._worker = None

        def _on_connection_error(self, error_msg):
            """Handle connection error on main thread"""
            logger.error(f"Connection error: {error_msg}")
            self._connected = False

            self.connectionStatusChanged.emit("Error")
            self.connectionStatusDetailChanged.emit(f"Error: {error_msg}")
            self.connectionProgressChanged.emit(0)

            with self._lock:
                self._is_connecting = False

            self._cleanup_worker_thread()
            self._schedule_auto_reconnect()

        def _schedule_auto_reconnect(self):
            """Schedule an automatic reconnection attempt"""
            if self._force_stop_reconnect:
                logger.debug("Reconnect stopped by force flag")
                return

            max_attempts = self._get_max_reconnect_attempts()

            if not self._is_auto_reconnect_enabled():
                logger.info("Auto-reconnect disabled, switching to passive scanning")
                self.connectionStatusDetailChanged.emit("Auto-reconnect disabled")
                self._device_scanner_timer.start()
                return

            if self._connection_attempts >= max_attempts:
                logger.warning(f"Max attempts ({max_attempts}) reached, switching to passive scanning")
                self.connectionStatusDetailChanged.emit("Max retries reached. Scanning...")
                self._device_scanner_timer.start()
                return

            delay = min(10, 2 + (self._connection_attempts * 2))
            self.connectionStatusDetailChanged.emit(f"Retry in {delay}s... ({self._connection_attempts}/{max_attempts})")
            logger.info(f"Auto-reconnect in {delay}s (attempt {self._connection_attempts + 1}/{max_attempts})")

            QTimer.singleShot(int(delay * 1000), self._start_connection)

        def _start_connection_monitor(self):
            """Start a thread to monitor connection status"""
            if self._monitor_thread and self._monitor_thread.is_alive():
                self._stop_monitor = True
                self._monitor_thread.join(timeout=1.0)

            self._stop_monitor = False
            self._monitor_thread = threading.Thread(target=self._monitor_connection, daemon=True)
            self._monitor_thread.start()

        def _monitor_connection(self):
            """Thread function to monitor connection status"""
            check_interval = 2.0
            last_status = self._connection.status() if self._connection else None

            while not self._stop_monitor and self._connection:
                try:
                    current_status = self._connection.status()

                    if current_status != last_status:
                        if current_status != OBDStatus.CAR_CONNECTED and last_status == OBDStatus.CAR_CONNECTED:
                            with self._lock:
                                self._connected = False
                            QTimer.singleShot(0, lambda: self.connectionStatusChanged.emit("Disconnected"))
                            QTimer.singleShot(0, lambda: self.connectionStatusDetailChanged.emit("Connection to vehicle lost"))
                            QTimer.singleShot(0, lambda: self.connectionProgressChanged.emit(0))
                            QTimer.singleShot(0, self._schedule_auto_reconnect)
                            QTimer.singleShot(0, self._device_scanner_timer.start)

                        last_status = current_status

                    port = self._get_configured_port()
                    if not self._check_port_exists(port):
                        with self._lock:
                            self._connected = False
                        QTimer.singleShot(0, lambda: self.connectionStatusChanged.emit("Device Lost"))
                        QTimer.singleShot(0, lambda: self.connectionStatusDetailChanged.emit("Bluetooth device disconnected"))
                        QTimer.singleShot(0, lambda: self.connectionProgressChanged.emit(0))
                        QTimer.singleShot(0, lambda: self.devicePresenceChanged.emit(False))
                        QTimer.singleShot(0, self._schedule_auto_reconnect)
                        QTimer.singleShot(0, self._device_scanner_timer.start)
                        break

                except Exception as e:
                    logger.error(f"Monitor error: {e}")

                time.sleep(check_interval)

        def _check_data_watchdog(self):
            """Check if data is still being received - detect stale connections"""
            if not self._connected or not self._connection:
                return

            if not self._has_active_watchers:
                return

            current_time = time.time()
            time_since_data = current_time - self._last_data_received

            if self._last_data_received > 0 and time_since_data > self._data_watchdog_timeout:
                logger.warning(f"Data watchdog triggered - no data for {time_since_data:.1f}s, reconnecting...")
                self.connectionStatusChanged.emit("Stale Connection")
                self.connectionStatusDetailChanged.emit("No data received, reconnecting...")
                self._data_watchdog_timer.stop()
                QTimer.singleShot(100, self._trigger_watchdog_reconnect)

        def _trigger_watchdog_reconnect(self):
            """Handle reconnect from watchdog timeout"""
            self._cleanup_connection()
            self._connection_attempts = 0
            self._start_connection()

        def _mark_data_received(self):
            """Called by data callbacks to mark that fresh data was received"""
            self._last_data_received = time.time()

        def _refresh_watchers(self):
            """Refresh OBD watchers when parameters change"""
            if not self._connection or not self._connected:
                logger.debug("Cannot refresh watchers - not connected")
                return

            logger.info("Refreshing watchers for parameter changes...")

            try:
                self._connection.stop()
                self._connection.unwatch_all()
                self._setup_watchers()
                self._connection.start()
                logger.info("Watchers refreshed successfully")
            except Exception as e:
                logger.error(f"Error refreshing watchers: {e}")

        def _setup_watchers(self):
            """Set up watchers based on settings using the parameter registry"""
            if not self._connection:
                return

            watcher_count = 0

            for param_name, param_info in OBD_PARAMETERS.items():
                should_watch = param_info["default_enabled"]
                if self._settings_manager:
                    should_watch = self._settings_manager.get_obd_parameter_enabled(param_name, param_info["default_enabled"])

                if should_watch:
                    try:
                        command = getattr(obd.commands, param_info["command"])
                        callback = self._create_param_callback(param_name)
                        self._connection.watch(command, callback=callback)
                        watcher_count += 1
                        logger.debug(f"Watching: {param_name}")
                    except Exception as e:
                        logger.warning(f"Could not watch {param_name}: {e}")

            self._has_active_watchers = watcher_count > 0
            logger.info(f"Set up {watcher_count} watchers")

        def _cleanup_connection(self):
            """Clean up existing connection before reconnecting"""
            self._data_watchdog_timer.stop()
            self._last_data_received = 0

            self._stop_monitor = True
            if self._monitor_thread and self._monitor_thread.is_alive():
                self._monitor_thread.join(timeout=1.0)
            if self._connection:
                try:
                    self._connection.stop()
                    self._connection.close()
                except Exception:
                    pass
                self._connection = None
            self._connected = False

        # ==================== Public Slots ====================

        @Slot()
        def reconnect(self):
            """Attempt to reconnect to the OBD device"""
            logger.info("Manual reconnect requested")
            self._cleanup_connection()
            self._connection_attempts = 0
            self._start_connection()

        @Slot()
        def force_connect(self):
            """Force a connection attempt, bypassing backoff and resetting attempt counter"""
            logger.info("Force connect requested")
            self._connection_attempts = 0
            self._cleanup_connection()
            self._start_connection()

        @Slot(result=bool)
        def is_connected(self):
            """Return current connection status"""
            return self._connected

        @Slot(result=str)
        def get_connection_status(self):
            """Get detailed connection status"""
            if not self._connection:
                return "No Connection"
            return str(self._connection.status())

        @Slot()
        def close(self):
            """Cleanup connection"""
            self._force_stop_reconnect = True
            self._device_scanner_timer.stop()
            self._cleanup_connection()

        @Slot()
        def reset_connection(self):
            """Hard reset the connection, resetting the attempt counter"""
            self.force_connect()

        @Slot(result=bool)
        def check_device_presence(self):
            """Check if the configured device is present"""
            port = self._get_configured_port()
            device_present = self._check_port_exists(port)
            self.devicePresenceChanged.emit(device_present)
            return device_present

        @Slot(result=list)
        def get_available_ports(self):
            """Get list of available serial/OBD ports"""
            self._scan_for_devices()
            return self._available_ports

        @Slot(bool)
        def set_auto_reconnect(self, enabled):
            """Deprecated: Auto-reconnect is now controlled via settings"""
            logger.warning("set_auto_reconnect() is deprecated. Use Settings > OBD > Auto-Reconnect Attempts instead.")

        @Slot(int)
        def set_connection_timeout(self, timeout_seconds):
            """Set the connection timeout"""
            self._connection_timeout = max(5, min(60, timeout_seconds))

        # ==================== Parameter Getters ====================
        # These provide backwards compatibility for QML access

        @Slot(result=float)
        def coolantTemp(self):
            return self._get_param_value("_coolant_temp")

        @Slot(result=float)
        def voltage(self):
            return self._get_param_value("_voltage")

        @Slot(result=float)
        def engineLoad(self):
            return self._get_param_value("_engine_load")

        @Slot(result=float)
        def throttlePosition(self):
            return self._get_param_value("_throttle_pos")

        @Slot(result=float)
        def intakeTemp(self):
            return self._get_param_value("_intake_temp")

        @Slot(result=float)
        def timingAdvance(self):
            return self._get_param_value("_timing_advance")

        @Slot(result=float)
        def massAirFlow(self):
            return self._get_param_value("_mass_airflow")

        @Slot(result=float)
        def speedMPH(self):
            return self._get_param_value("_speed_mph")

        @Slot(result=float)
        def rpm(self):
            return self._get_param_value("_rpm")

        @Slot(result=float)
        def airFuelRatio(self):
            return self._get_param_value("_air_fuel_ratio")

        @Slot(result=float)
        def fuelLevel(self):
            return self._get_param_value("_fuel_level")

        @Slot(result=float)
        def intakeManifoldPressure(self):
            return self._get_param_value("_intake_pressure")

        @Slot(result=float)
        def shortTermFuelTrim(self):
            return self._get_param_value("_short_term_fuel_trim")

        @Slot(result=float)
        def longTermFuelTrim(self):
            return self._get_param_value("_long_term_fuel_trim")

        @Slot(result=float)
        def oxygenSensorVoltage(self):
            return self._get_param_value("_o2_sensor_voltage")

        @Slot(result=float)
        def fuelPressure(self):
            return self._get_param_value("_fuel_pressure")

        @Slot(result=float)
        def engineOilTemp(self):
            return self._get_param_value("_oil_temp")

        @Slot(result=float)
        def ignitionTiming(self):
            return self._get_param_value("_ignition_timing")

        # ==================== Vehicle Scan Functions ====================

        @Slot(result=list)
        def get_all_parameter_names(self):
            """Get list of all parameter names that OCTAVE supports"""
            return list(OBD_PARAMETERS.keys())

        @Slot(result=list)
        def get_supported_commands(self):
            """Get list of commands supported by the connected vehicle"""
            return self._supported_commands

        @Slot(result=bool)
        def is_scanning(self):
            """Check if a vehicle scan is currently in progress"""
            return self._is_scanning

        @Slot()
        def scan_vehicle(self):
            """Scan the connected vehicle for supported OBD commands."""
            if not self._connection or not self._connected:
                logger.warning("Cannot scan - not connected to vehicle")
                self.scanProgressChanged.emit(0, "Not connected to vehicle")
                return

            if self._is_scanning:
                logger.debug("Scan already in progress")
                return

            self._is_scanning = True
            self.scanProgressChanged.emit(0, "Starting vehicle scan...")

            scan_thread = threading.Thread(target=self._do_vehicle_scan, daemon=True)
            scan_thread.start()

        def _do_vehicle_scan(self):
            """Perform the actual vehicle scan (runs in background thread)"""
            sync_conn = None
            use_diagnostic_conn = self._diagnostic_mode and self._diagnostic_sync_conn
            try:
                if use_diagnostic_conn:
                    sync_conn = self._diagnostic_sync_conn
                else:
                    self._connection.stop()
                    sync_conn = self._create_sync_connection()

                if not sync_conn:
                    logger.error("Failed to get sync connection for vehicle scan")
                    QTimer.singleShot(0, lambda: self.scanProgressChanged.emit(0, "Connection failed"))
                    QTimer.singleShot(0, lambda: self.scanCompleteChanged.emit([]))
                    return

                supported = sync_conn.supported_commands

                if not supported:
                    QTimer.singleShot(0, lambda: self.scanProgressChanged.emit(100, "No supported commands found"))
                    QTimer.singleShot(0, lambda: self.scanCompleteChanged.emit([]))
                    return

                supported_names = []
                total = len(OBD_PARAMETERS)

                for i, (param_name, param_info) in enumerate(OBD_PARAMETERS.items()):
                    progress = int((i / total) * 100)
                    QTimer.singleShot(0, lambda p=progress, n=param_name: self.scanProgressChanged.emit(p, f"Checking {n}..."))

                    try:
                        command = getattr(obd.commands, param_info["command"])
                        if command in supported:
                            supported_names.append(param_name)
                            logger.debug(f"Vehicle supports: {param_name}")
                    except AttributeError:
                        pass

                self._supported_commands = supported_names

                QTimer.singleShot(0, lambda: self.scanProgressChanged.emit(100, f"Found {len(supported_names)} supported parameters"))
                QTimer.singleShot(0, lambda: self.supportedCommandsChanged.emit(supported_names))
                QTimer.singleShot(0, lambda: self.scanCompleteChanged.emit(supported_names))

                logger.info(f"Vehicle scan complete: {len(supported_names)} supported parameters")

            except Exception as e:
                logger.error(f"Scan error: {e}")
                QTimer.singleShot(0, lambda: self.scanProgressChanged.emit(0, f"Scan error: {e}"))

            finally:
                self._is_scanning = False
                if not use_diagnostic_conn:
                    if sync_conn:
                        sync_conn.close()
                    if self._connection:
                        self._connection.start()

        @Slot(list)
        def enable_scanned_parameters(self, param_names):
            """Enable all the parameters found during scan"""
            if not self._settings_manager:
                return

            for param in param_names:
                self._settings_manager.save_obd_parameter_enabled(param, True)

            logger.info(f"Enabled {len(param_names)} scanned parameters")

        @Slot()
        def enable_all_supported(self):
            """Enable all parameters that the vehicle supports"""
            if self._supported_commands:
                self.enable_scanned_parameters(self._supported_commands)

        # ==================== Diagnostic Mode Management ====================

        @Slot()
        def enter_diagnostic_mode(self):
            """Enter diagnostic mode - pauses async polling and creates a persistent sync connection."""
            with self._diagnostic_mode_lock:
                if self._diagnostic_mode:
                    logger.debug("Already in diagnostic mode")
                    return

                if self._diagnostic_mode_transitioning:
                    logger.debug("Diagnostic mode transition already in progress, ignoring")
                    return

                if not self._connection or not self._connected:
                    logger.warning("Cannot enter diagnostic mode - not connected")
                    return

                self._diagnostic_mode_transitioning = True

            logger.info("Entering diagnostic mode - pausing async polling...")

            try:
                self._data_watchdog_timer.stop()
                logger.debug("Data watchdog paused for diagnostic mode")

                self._connection.stop()
                time.sleep(0.2)

                with self._diagnostic_mode_lock:
                    if not self._diagnostic_mode_transitioning:
                        logger.debug("Diagnostic mode entry cancelled")
                        self._connection.start()
                        self._last_data_received = time.time()
                        self._data_watchdog_timer.start()
                        return

                port = self._get_configured_port()
                logger.debug(f"Creating diagnostic sync connection on port: {port}")
                try:
                    self._diagnostic_sync_conn = obd.OBD(port, fast=False, timeout=10)
                    if self._diagnostic_sync_conn.is_connected():
                        logger.info(f"Diagnostic mode active - sync connection ready on {port}")
                    else:
                        logger.warning(f"Diagnostic sync connection failed on {port}")
                        self._diagnostic_sync_conn.close()
                        self._diagnostic_sync_conn = None
                except Exception as e:
                    logger.error(f"Error creating diagnostic sync connection: {e}")
                    self._diagnostic_sync_conn = None

                with self._diagnostic_mode_lock:
                    self._diagnostic_mode = True
                    self._diagnostic_mode_transitioning = False

            except Exception as e:
                logger.error(f"Error entering diagnostic mode: {e}")
                with self._diagnostic_mode_lock:
                    self._diagnostic_mode_transitioning = False
                if self._connection:
                    try:
                        self._connection.start()
                        self._last_data_received = time.time()
                        self._data_watchdog_timer.start()
                    except Exception:
                        pass

        @Slot()
        def exit_diagnostic_mode(self):
            """Exit diagnostic mode - closes sync connection and resumes async polling."""
            with self._diagnostic_mode_lock:
                if not self._diagnostic_mode and not self._diagnostic_mode_transitioning:
                    logger.debug("Not in diagnostic mode")
                    return

                if self._diagnostic_mode_transitioning and not self._diagnostic_mode:
                    logger.debug("Cancelling diagnostic mode entry in progress")
                    self._diagnostic_mode_transitioning = False
                    return

                self._diagnostic_mode_transitioning = True

            logger.info("Exiting diagnostic mode - resuming async polling...")

            try:
                if self._diagnostic_sync_conn:
                    try:
                        self._diagnostic_sync_conn.close()
                    except Exception as e:
                        logger.error(f"Error closing diagnostic sync connection: {e}")
                    self._diagnostic_sync_conn = None

                with self._diagnostic_mode_lock:
                    self._diagnostic_mode = False
                    self._diagnostic_mode_transitioning = False

                was_connected = self._connected
                if self._connection or was_connected:
                    logger.info("Performing full reconnect after diagnostic mode...")
                    if self._connection:
                        try:
                            self._connection.close()
                        except Exception as e:
                            logger.error(f"Error closing old async connection: {e}")
                        self._connection = None

                    self._connected = False
                    self.connectionStatusChanged.emit("Reconnecting")
                    self.connectionStatusDetailChanged.emit("Reconnecting after diagnostic mode...")

                    time.sleep(0.2)

                    self._connection_attempts = 0
                    self._start_connection()
                    logger.info("Fresh async connection initiated")
                else:
                    logger.debug("No connection to resume")

            except Exception as e:
                logger.error(f"Error exiting diagnostic mode: {e}")
                with self._diagnostic_mode_lock:
                    self._diagnostic_mode = False
                    self._diagnostic_mode_transitioning = False
                try:
                    self._connection_attempts = 0
                    self._start_connection()
                except Exception:
                    pass

        @Slot(result=bool)
        def is_diagnostic_mode(self):
            """Check if currently in diagnostic mode"""
            return self._diagnostic_mode

        # ==================== Diagnostic Commands ====================

        def _create_sync_connection(self):
            """Create a temporary synchronous OBD connection for diagnostic queries."""
            port = self._get_configured_port()
            try:
                time.sleep(0.2)
                sync_conn = obd.OBD(port, fast=False, timeout=10)
                if sync_conn.is_connected():
                    return sync_conn
                else:
                    logger.warning(f"Sync connection failed to connect on {port}")
                    sync_conn.close()
                    return None
            except Exception as e:
                logger.error(f"Error creating sync connection: {e}")
                return None

        def _run_diagnostic_query(self, command, process_fn, error_emissions=None):
            """
            Generic diagnostic query runner - eliminates duplicate try/except/finally blocks.

            Args:
                command: The OBD command to run
                process_fn: Callable(response) that processes results and emits signals
                error_emissions: List of (signal, value) tuples to emit on error
            """
            sync_conn = None
            use_diagnostic_conn = self._diagnostic_mode and self._diagnostic_sync_conn

            try:
                if use_diagnostic_conn:
                    sync_conn = self._diagnostic_sync_conn
                else:
                    self._connection.stop()
                    sync_conn = self._create_sync_connection()

                if not sync_conn:
                    logger.error(f"Failed to get sync connection for {command.name}")
                    if error_emissions:
                        for signal, value in error_emissions:
                            signal.emit(value) if not isinstance(value, tuple) else signal.emit(*value)
                    return

                response = sync_conn.query(command)
                process_fn(response)

            except Exception as e:
                logger.error(f"Error running {command.name}: {e}")
                if error_emissions:
                    for signal, value in error_emissions:
                        signal.emit(value) if not isinstance(value, tuple) else signal.emit(*value)
            finally:
                if not use_diagnostic_conn:
                    if sync_conn:
                        sync_conn.close()
                    if self._connection:
                        self._connection.start()

        # ==================== Diagnostic Commands ====================

        @Slot()
        def read_dtc(self):
            """Read Diagnostic Trouble Codes from the vehicle"""
            if not self._connection or not self._connected:
                logger.warning("Cannot read DTCs - not connected")
                self.dtcCodesChanged.emit([])
                return

            logger.info("Reading DTCs...")
            threading.Thread(target=self._do_read_dtc, daemon=True).start()

        def _do_read_dtc(self):
            """Read DTCs in background thread"""
            def process(response):
                if response.is_null():
                    logger.info("No DTCs found (null response)")
                    self._dtc_codes = []
                    self._dtc_count = 0
                    self._emitDtcCodes.emit([])
                    self._emitDtcCount.emit(0)
                    return

                dtcs = response.value or []
                dtc_list = [{"code": code, "description": desc} for code, desc in dtcs]
                self._dtc_codes = dtc_list
                self._dtc_count = len(dtc_list)

                logger.info(f"Found {len(dtc_list)} DTCs: {dtc_list}")
                self._emitDtcCodes.emit(dtc_list)
                self._emitDtcCount.emit(len(dtc_list))

            self._run_diagnostic_query(
                obd.commands.GET_DTC,
                process,
                error_emissions=[(self._emitDtcCodes, [])]
            )

        @Slot()
        def read_current_dtc(self):
            """Read DTCs from the current/last driving cycle"""
            if not self._connection or not self._connected:
                logger.warning("Cannot read current DTCs - not connected")
                return

            logger.info("Reading current DTCs...")
            threading.Thread(target=self._do_read_current_dtc, daemon=True).start()

        def _do_read_current_dtc(self):
            """Read current DTCs in background thread"""
            def process(response):
                if response.is_null():
                    logger.info("No current DTCs found")
                    self._emitDtcCodes.emit([])
                    return

                dtcs = response.value or []
                dtc_list = [{"code": code, "description": desc} for code, desc in dtcs]
                logger.info(f"Found {len(dtc_list)} current DTCs")
                self._emitDtcCodes.emit(dtc_list)

            self._run_diagnostic_query(
                obd.commands.GET_CURRENT_DTC,
                process,
                error_emissions=[(self._emitDtcCodes, [])]
            )

        @Slot()
        def read_freeze_frame(self):
            """Read freeze frame DTCs"""
            if not self._connection or not self._connected:
                logger.warning("Cannot read freeze frame - not connected")
                return

            logger.info("Reading freeze frame DTCs...")
            threading.Thread(target=self._do_read_freeze_frame, daemon=True).start()

        def _do_read_freeze_frame(self):
            """Read freeze frame in background thread"""
            def process(response):
                if response.is_null():
                    logger.info("No freeze frame data")
                    self._freeze_frame_dtcs = []
                    self._emitFreezeFrame.emit([])
                    return

                dtcs = response.value or []
                dtc_list = [{"code": code, "description": desc} for code, desc in dtcs]
                self._freeze_frame_dtcs = dtc_list
                logger.debug(f"Freeze frame DTCs: {dtc_list}")
                self._emitFreezeFrame.emit(dtc_list)

            self._run_diagnostic_query(
                obd.commands.FREEZE_DTC,
                process,
                error_emissions=[(self._emitFreezeFrame, [])]
            )

        @Slot()
        def clear_dtc(self):
            """Clear all DTCs and reset the MIL (Check Engine Light)."""
            if not self._connection or not self._connected:
                logger.warning("Cannot clear DTCs - not connected")
                self.dtcClearResult.emit(False, "Not connected to vehicle")
                return

            logger.info("Clearing DTCs...")
            threading.Thread(target=self._do_clear_dtc, daemon=True).start()

        def _do_clear_dtc(self):
            """Clear DTCs in background thread"""
            def process(response):
                if response.is_null():
                    logger.warning("Clear DTC command returned null")
                    self._emitDtcClearResult.emit(False, "Clear command failed")
                    return

                self._dtc_codes = []
                self._dtc_count = 0
                self._mil_status = False

                logger.info("DTCs cleared successfully")
                self._emitDtcClearResult.emit(True, "DTCs cleared successfully")
                self._emitDtcCodes.emit([])
                self._emitDtcCount.emit(0)
                self._emitMilStatus.emit(False)

            self._run_diagnostic_query(
                obd.commands.CLEAR_DTC,
                process,
                error_emissions=[(self._emitDtcClearResult, (False, "Connection failed"))]
            )

        @Slot()
        def read_status(self):
            """Read vehicle status including MIL and DTC count"""
            if not self._connection or not self._connected:
                logger.warning("Cannot read status - not connected")
                return

            logger.info("Reading vehicle status...")
            threading.Thread(target=self._do_read_status, daemon=True).start()

        def _do_read_status(self):
            """Read status in background thread"""
            def process(response):
                if response.is_null():
                    logger.warning("Status command returned null")
                    self._emitMilStatus.emit(False)
                    self._emitDtcCount.emit(0)
                    return

                status = response.value
                self._mil_status = status.MIL
                self._dtc_count = status.DTC_count

                logger.info(f"MIL: {self._mil_status}, DTC count: {self._dtc_count}")
                self._emitMilStatus.emit(self._mil_status)
                self._emitDtcCount.emit(self._dtc_count)

            self._run_diagnostic_query(
                obd.commands.STATUS,
                process,
                error_emissions=[(self._emitMilStatus, False), (self._emitDtcCount, 0)]
            )

        # ==================== Thread-safe signal forwarding ====================

        @Slot(list)
        def _forwardDtcCodes(self, codes):
            """Forward DTC codes signal to QML (runs on main thread)"""
            logger.debug(f"Forwarding dtcCodesChanged signal with {len(codes) if codes else 0} codes")
            self.dtcCodesChanged.emit(codes)

        @Slot(int)
        def _forwardDtcCount(self, count):
            """Forward DTC count signal to QML (runs on main thread)"""
            logger.debug(f"Forwarding dtcCountChanged signal with count: {count}")
            self.dtcCountChanged.emit(count)

        @Slot(bool)
        def _forwardMilStatus(self, status):
            """Forward MIL status signal to QML (runs on main thread)"""
            logger.debug(f"Forwarding milStatusChanged signal with status: {status}")
            self.milStatusChanged.emit(status)

        @Slot(bool, str)
        def _forwardDtcClearResult(self, success, message):
            """Forward DTC clear result signal to QML (runs on main thread)"""
            logger.debug(f"Forwarding dtcClearResult signal: {success}, {message}")
            self.dtcClearResult.emit(success, message)

        @Slot(list)
        def _forwardFreezeFrame(self, data):
            """Forward freeze frame signal to QML (runs on main thread)"""
            logger.debug(f"Forwarding freezeFrameChanged signal with {len(data) if data else 0} items")
            self.freezeFrameChanged.emit(data)

        # ==================== Diagnostic data getters ====================

        @Slot(result=list)
        def get_dtc_codes(self):
            """Get the last read DTCs"""
            return self._dtc_codes

        @Slot(result=int)
        def get_dtc_count(self):
            """Get the number of DTCs"""
            return self._dtc_count

        @Slot(result=bool)
        def get_mil_status(self):
            """Get MIL (Check Engine Light) status"""
            return self._mil_status

        @Slot(result=list)
        def get_freeze_frame(self):
            """Get freeze frame DTCs"""
            return self._freeze_frame_dtcs

    # Add all signals to the class
    for signal_name, signal_obj in signals.items():
        setattr(OBDManagerImpl, signal_name, signal_obj)

    return OBDManagerImpl


# Create the actual class
OBDManager = _create_obd_manager_class()
