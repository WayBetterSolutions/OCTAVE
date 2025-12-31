from PySide6.QtCore import QObject, Signal, Slot, QTimer, QThread
import obd
from obd import OBDStatus
import time
import os
import sys
import threading
import glob


class OBDConnectionWorker(QObject):
    """Worker that runs OBD connection in a separate thread to avoid blocking UI"""

    # Signals to communicate back to main thread
    connectionComplete = Signal(object, object)  # (connection, status)
    connectionProgress = Signal(int, str)  # (progress, message)
    connectionError = Signal(str)

    def __init__(self):
        super().__init__()
        self._port = None
        self._fast_mode = True
        self._timeout = 10

    def set_params(self, port, fast_mode, timeout):
        self._port = port
        self._fast_mode = fast_mode
        self._timeout = timeout

    def do_connect(self):
        """Perform the actual OBD connection - runs in worker thread"""
        try:
            self.connectionProgress.emit(20, "Initializing OBD adapter...")

            # Create the connection (this is the blocking call)
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


class OBDManager(QObject):
    # Signals for OBD parameters
    coolantTempChanged = Signal(float)
    voltageChanged = Signal(float)
    engineLoadChanged = Signal(float)
    throttlePositionChanged = Signal(float)
    intakeAirTempChanged = Signal(float)
    timingAdvanceChanged = Signal(float)
    massAirFlowChanged = Signal(float)
    speedMPHChanged = Signal(float)
    rpmChanged = Signal(float)
    airFuelRatioChanged = Signal(float)
    fuelLevelChanged = Signal(float)
    intakeManifoldPressureChanged = Signal(float)
    shortTermFuelTrimChanged = Signal(float)
    longTermFuelTrimChanged = Signal(float)
    oxygenSensorVoltageChanged = Signal(float)
    fuelPressureChanged = Signal(float)
    engineOilTempChanged = Signal(float)
    ignitionTimingChanged = Signal(float)

    # Connection status signals
    connectionStatusChanged = Signal(str)
    connectionStatusDetailChanged = Signal(str)
    connectionProgressChanged = Signal(int)
    devicePresenceChanged = Signal(bool)
    availablePortsChanged = Signal(list)  # New signal for discovered ports

    def __init__(self, settings_manager=None):
        super().__init__()
        self._connection = None
        self._connected = False
        self._settings_manager = settings_manager

        # Thread safety lock
        self._lock = threading.Lock()

        # OBD parameter values
        self._coolant_temp = 0.0
        self._voltage = 0.0
        self._engine_load = 0.0
        self._throttle_pos = 0.0
        self._intake_temp = 0.0
        self._timing_advance = 0.0
        self._mass_airflow = 0.0
        self._speed_mph = 0.0
        self._rpm = 0.0
        self._air_fuel_ratio = 0.0
        self._fuel_level = 0.0
        self._intake_pressure = 0.0
        self._short_term_fuel_trim = 0.0
        self._long_term_fuel_trim = 0.0
        self._o2_sensor_voltage = 0.0
        self._fuel_pressure = 0.0
        self._oil_temp = 0.0
        self._ignition_timing = 0.0

        # Connection management
        self._connection_attempts = 0
        self._connection_status = "Not Connected"
        self._connection_detail = "Waiting for startup..."
        self._is_connecting = False
        self._last_reconnect_time = 0

        # Auto-reconnect settings (loaded from settings_manager)
        self._auto_reconnect_delay = 5.0  # seconds
        self._force_stop_reconnect = False  # Used to stop reconnects on close()

        # Connection timeout (configurable)
        self._connection_timeout = 10  # seconds

        # Connection monitor thread
        self._monitor_thread = None
        self._stop_monitor = False

        # Worker thread for non-blocking connections
        self._worker_thread = None
        self._worker = None

        # Device discovery
        self._available_ports = []
        self._last_device_scan = 0
        self._device_scan_interval = 10.0  # Scan for devices every 10 seconds when not connected

        # Background device scanner timer
        self._device_scanner_timer = QTimer()
        self._device_scanner_timer.setInterval(10000)  # 10 seconds
        self._device_scanner_timer.timeout.connect(self._scan_for_devices)

        # Debounce timer for settings changes - only reconnect if port changes
        self._port_change_timer = QTimer()
        self._port_change_timer.setSingleShot(True)
        self._port_change_timer.setInterval(1000)  # 1 second debounce for port changes
        self._port_change_timer.timeout.connect(self._on_port_changed)

        # Pending port change
        self._pending_port = None

        # Startup timer - defer connection to not block init
        self._startup_timer = QTimer()
        self._startup_timer.setSingleShot(True)
        self._startup_timer.setInterval(1500)  # 1.5 second delay after startup
        self._startup_timer.timeout.connect(self._initial_connect)
        self._startup_timer.start()

        # Connect to settings changes
        if self._settings_manager:
            # Port changes trigger reconnect (debounced)
            self._settings_manager.obdBluetoothPortChanged.connect(self._schedule_port_change)
            # Fast mode changes are applied on next connection, no immediate reconnect needed
            # Parameter changes just refresh watchers, don't need full reconnect
            self._settings_manager.obdParametersChanged.connect(self._refresh_watchers)

    def _get_platform(self):
        """Detect the current platform"""
        if sys.platform.startswith('win'):
            return 'windows'
        elif sys.platform.startswith('darwin'):
            return 'macos'
        else:
            return 'linux'

    def _get_max_reconnect_attempts(self):
        """Get max reconnect attempts from settings (0 = disabled)"""
        if self._settings_manager:
            return self._settings_manager.obdAutoReconnectAttempts
        return 0  # Default to disabled

    def _is_auto_reconnect_enabled(self):
        """Check if auto-reconnect is enabled based on settings"""
        return self._get_max_reconnect_attempts() > 0

    def _scan_for_devices(self):
        """Scan for available OBD/serial ports based on platform"""
        platform = self._get_platform()
        ports = []

        try:
            if platform == 'windows':
                # Windows: Check COM ports
                import serial.tools.list_ports
                for port in serial.tools.list_ports.comports():
                    # Look for Bluetooth or OBD-related devices
                    desc_lower = port.description.lower()
                    if any(keyword in desc_lower for keyword in ['bluetooth', 'obd', 'elm', 'serial', 'usb']):
                        ports.append(port.device)
                    elif port.device.startswith('COM'):
                        # Include all COM ports as potential candidates
                        ports.append(port.device)

            elif platform == 'macos':
                # macOS: Check /dev/tty.* and /dev/cu.* devices
                ports.extend(glob.glob('/dev/tty.OBD*'))
                ports.extend(glob.glob('/dev/tty.Bluetooth*'))
                ports.extend(glob.glob('/dev/cu.OBD*'))
                ports.extend(glob.glob('/dev/cu.Bluetooth*'))
                ports.extend(glob.glob('/dev/tty.usbserial*'))
                ports.extend(glob.glob('/dev/cu.usbserial*'))
                # Also check for ELM327 devices
                ports.extend(glob.glob('/dev/tty.*ELM*'))
                ports.extend(glob.glob('/dev/cu.*ELM*'))

            else:
                # Linux: Check rfcomm devices and USB serial
                ports.extend(glob.glob('/dev/rfcomm*'))
                ports.extend(glob.glob('/dev/ttyUSB*'))
                ports.extend(glob.glob('/dev/ttyACM*'))
                # Also check for any Bluetooth serial ports
                ports.extend(glob.glob('/dev/ttyS*'))

            # Remove duplicates and sort
            ports = sorted(list(set(ports)))

            # Update available ports if changed
            if ports != self._available_ports:
                self._available_ports = ports
                self.availablePortsChanged.emit(ports)
                print(f"[OBD] Discovered ports: {ports}")

                # If we found a new port and we're not connected, try to connect
                if ports and not self._connected and not self._is_connecting:
                    configured_port = self._get_configured_port()
                    if configured_port in ports:
                        print(f"[OBD] Configured port {configured_port} is now available, attempting connection...")
                        self._connection_attempts = 0  # Reset attempts when device appears
                        self._start_connection()
                    elif ports:
                        # If configured port not found but we have other ports, notify user
                        self.connectionStatusDetailChanged.emit(f"Device at {configured_port} not found. Available: {', '.join(ports)}")

        except Exception as e:
            print(f"[OBD] Error scanning for devices: {e}")

        self._last_device_scan = time.time()

    def _get_configured_port(self):
        """Get the configured port from settings, with platform-appropriate default"""
        if self._settings_manager:
            port = self._settings_manager.obdBluetoothPort
            if port:
                return port

        # Platform-specific defaults
        platform = self._get_platform()
        if platform == 'windows':
            return 'COM3'  # Common default for Bluetooth serial on Windows
        elif platform == 'macos':
            return '/dev/tty.OBD'
        else:
            return '/dev/rfcomm0'

    def _check_port_exists(self, port):
        """Check if a port exists, cross-platform"""
        platform = self._get_platform()

        if platform == 'windows':
            # On Windows, COM ports don't show up as files
            # We need to try to open them or check via serial.tools
            try:
                import serial.tools.list_ports
                available = [p.device for p in serial.tools.list_ports.comports()]
                return port in available
            except (ImportError, OSError) as e:
                # Fallback: assume port might be available
                print(f"[OBD] Port check fallback: {e}")
                return True
        else:
            # On Unix-like systems, check if device file exists
            return os.path.exists(port)

    def _schedule_port_change(self):
        """Schedule a port change with debouncing"""
        new_port = self._settings_manager.obdBluetoothPort if self._settings_manager else None
        if new_port and new_port != self._pending_port:
            self._pending_port = new_port
            self._port_change_timer.start()
            print(f"[OBD] Port change scheduled: {new_port}")

    def _on_port_changed(self):
        """Handle port change after debounce"""
        if self._pending_port:
            print(f"[OBD] Port changed to: {self._pending_port}")
            self._connection_attempts = 0  # Reset on port change
            self.reconnect()
            self._pending_port = None

    def _initial_connect(self):
        """Initial connection attempt on startup"""
        print("[OBD] Starting initial connection...")

        # First scan for devices
        self._scan_for_devices()

        # Start the background device scanner
        self._device_scanner_timer.start()

        # Attempt connection
        self._start_connection()

    def _start_connection(self):
        """Start a non-blocking connection attempt"""
        with self._lock:
            if self._is_connecting:
                print("[OBD] Already connecting - skipping")
                return
            self._is_connecting = True

        self._connection_attempts += 1
        print(f"[OBD] Starting connection attempt #{self._connection_attempts}")

        self.connectionStatusChanged.emit("Connecting")
        self.connectionStatusDetailChanged.emit(f"Attempt {self._connection_attempts}...")
        self.connectionProgressChanged.emit(10)

        # Get settings
        port = self._get_configured_port()
        fast_mode = True
        if self._settings_manager:
            fast_mode = self._settings_manager.obdFastMode

        # Check if device exists
        if not self._check_port_exists(port):
            self._connected = False
            self.connectionStatusChanged.emit("Device Not Found")
            self.connectionStatusDetailChanged.emit(f"Port {port} not available")
            self.connectionProgressChanged.emit(0)
            self.devicePresenceChanged.emit(False)
            print(f"[OBD] Port {port} not found")
            with self._lock:
                self._is_connecting = False
            self._schedule_auto_reconnect()
            return

        self.devicePresenceChanged.emit(True)
        self.connectionProgressChanged.emit(15)
        self.connectionStatusDetailChanged.emit(f"Found {port}, connecting...")

        # Clean up previous thread if it exists
        if self._worker_thread is not None and self._worker_thread.isRunning():
            self._worker_thread.quit()
            self._worker_thread.wait(1000)

        # Create worker and thread for non-blocking connection using Qt threading
        self._worker = OBDConnectionWorker()
        self._worker.set_params(port, fast_mode, self._connection_timeout)

        self._worker_thread = QThread()
        self._worker.moveToThread(self._worker_thread)

        # Connect signals
        self._worker.connectionProgress.connect(self._on_connection_progress)
        self._worker.connectionComplete.connect(self._on_connection_complete)
        self._worker.connectionError.connect(self._on_connection_error)

        # Start the thread and trigger the connection
        self._worker_thread.started.connect(self._worker.do_connect)
        self._worker_thread.start()

    def _on_connection_progress(self, progress, message):
        """Handle connection progress updates from worker"""
        self.connectionProgressChanged.emit(progress)
        self.connectionStatusDetailChanged.emit(message)

    def _on_connection_complete(self, connection, status):
        """Handle connection result on main thread"""
        print(f"[OBD] Connection complete, status: {status}")

        if status == OBDStatus.CAR_CONNECTED:
            self._connection = connection
            self._connected = True
            self._connection_attempts = 0

            self.connectionStatusChanged.emit("Connected")
            self.connectionStatusDetailChanged.emit("OBD interface connected successfully")
            self.connectionProgressChanged.emit(100)

            self._setup_watchers()
            self._connection.start()
            self._start_connection_monitor()

            # Stop background scanning while connected
            self._device_scanner_timer.stop()

        elif status == OBDStatus.ELM_CONNECTED:
            self._connection = connection
            self._connected = False

            self.connectionStatusChanged.emit("No Vehicle")
            self.connectionStatusDetailChanged.emit("Connected to adapter, waiting for vehicle...")
            self.connectionProgressChanged.emit(50)

            # Keep trying - vehicle might not be on yet
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

        # Clean up worker thread
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
        print(f"[OBD] Connection error: {error_msg}")
        self._connected = False

        self.connectionStatusChanged.emit("Error")
        self.connectionStatusDetailChanged.emit(f"Error: {error_msg}")
        self.connectionProgressChanged.emit(0)

        with self._lock:
            self._is_connecting = False

        # Clean up worker thread
        self._cleanup_worker_thread()

        self._schedule_auto_reconnect()

    def _schedule_auto_reconnect(self):
        """Schedule an automatic reconnection attempt"""
        # Check if we've been told to stop completely (e.g., during close())
        if self._force_stop_reconnect:
            print("[OBD] Reconnect stopped by force flag")
            return

        max_attempts = self._get_max_reconnect_attempts()

        # If auto-reconnect is disabled (0), just start device scanner for passive monitoring
        if not self._is_auto_reconnect_enabled():
            print("[OBD] Auto-reconnect disabled, switching to passive scanning")
            self.connectionStatusDetailChanged.emit("Auto-reconnect disabled")
            self._device_scanner_timer.start()
            return

        if self._connection_attempts >= max_attempts:
            print(f"[OBD] Max attempts ({max_attempts}) reached, switching to passive scanning")
            self.connectionStatusDetailChanged.emit("Max retries reached. Scanning...")
            # Don't stop trying completely - just rely on device scanner
            self._device_scanner_timer.start()
            return

        # Calculate backoff delay (5s, 10s, 15s, 20s, 25s, 30s max)
        delay = min(30, 5 + (self._connection_attempts * 5))
        self.connectionStatusDetailChanged.emit(f"Retry in {delay}s... ({self._connection_attempts}/{max_attempts})")
        print(f"[OBD] Auto-reconnect in {delay}s (attempt {self._connection_attempts + 1}/{max_attempts})")

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
                        # Use QTimer.singleShot to emit from main thread
                        QTimer.singleShot(0, lambda: self.connectionStatusChanged.emit("Disconnected"))
                        QTimer.singleShot(0, lambda: self.connectionStatusDetailChanged.emit("Connection to vehicle lost"))
                        QTimer.singleShot(0, lambda: self.connectionProgressChanged.emit(0))
                        QTimer.singleShot(0, self._schedule_auto_reconnect)
                        QTimer.singleShot(0, self._device_scanner_timer.start)

                    last_status = current_status

                # Check if device is still available
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
                print(f"[OBD] Monitor error: {e}")

            time.sleep(check_interval)

    def _refresh_watchers(self):
        """Refresh OBD watchers when parameters change (no full reconnect needed)"""
        if not self._connection or not self._connected:
            print("[OBD] Cannot refresh watchers - not connected")
            return

        print("[OBD] Refreshing watchers for parameter changes...")

        try:
            # Stop current watching
            self._connection.stop()

            # Unwatch all current commands
            self._connection.unwatch_all()

            # Set up new watchers based on current settings
            self._setup_watchers()

            # Restart watching
            self._connection.start()

            print("[OBD] Watchers refreshed successfully")
        except Exception as e:
            print(f"[OBD] Error refreshing watchers: {e}")

    def _setup_watchers(self):
        """Set up watchers based on settings"""
        if not self._connection:
            return

        commands_to_watch = {
            "COOLANT_TEMP": (obd.commands.COOLANT_TEMP, self._update_coolant),
            "CONTROL_MODULE_VOLTAGE": (obd.commands.CONTROL_MODULE_VOLTAGE, self._update_voltage),
            "ENGINE_LOAD": (obd.commands.ENGINE_LOAD, self._update_load),
            "THROTTLE_POS": (obd.commands.THROTTLE_POS, self._update_throttle),
            "INTAKE_TEMP": (obd.commands.INTAKE_TEMP, self._update_intake),
            "TIMING_ADVANCE": (obd.commands.TIMING_ADVANCE, self._update_timing_combined),
            "MAF": (obd.commands.MAF, self._update_maf),
            "SPEED": (obd.commands.SPEED, self._update_speed),
            "RPM": (obd.commands.RPM, self._update_rpm),
            "COMMANDED_EQUIV_RATIO": (obd.commands.COMMANDED_EQUIV_RATIO, self._update_afr),
            "FUEL_LEVEL": (obd.commands.FUEL_LEVEL, self._update_fuel_level),
            "INTAKE_PRESSURE": (obd.commands.INTAKE_PRESSURE, self._update_intake_pressure),
            "SHORT_FUEL_TRIM_1": (obd.commands.SHORT_FUEL_TRIM_1, self._update_short_term_fuel_trim),
            "LONG_FUEL_TRIM_1": (obd.commands.LONG_FUEL_TRIM_1, self._update_long_term_fuel_trim),
            "O2_B1S1": (obd.commands.O2_B1S1, self._update_o2_sensor),
            "FUEL_PRESSURE": (obd.commands.FUEL_PRESSURE, self._update_fuel_pressure),
            "OIL_TEMP": (obd.commands.OIL_TEMP, self._update_oil_temp),
        }

        for param, (command, callback) in commands_to_watch.items():
            should_watch = True
            if self._settings_manager:
                should_watch = self._settings_manager.get_obd_parameter_enabled(param, True)

            if should_watch:
                print(f"[OBD] Watching: {param}")
                self._connection.watch(command, callback=callback)

    # Callback functions
    def _update_coolant(self, r):
        if not r.is_null():
            self._coolant_temp = float(r.value.magnitude)
            self.coolantTempChanged.emit(self._coolant_temp)

    def _update_voltage(self, r):
        if not r.is_null():
            self._voltage = float(r.value.magnitude)
            self.voltageChanged.emit(self._voltage)

    def _update_load(self, r):
        if not r.is_null():
            self._engine_load = float(r.value.magnitude)
            self.engineLoadChanged.emit(self._engine_load)

    def _update_throttle(self, r):
        if not r.is_null():
            self._throttle_pos = float(r.value.magnitude)
            self.throttlePositionChanged.emit(self._throttle_pos)

    def _update_intake(self, r):
        if not r.is_null():
            self._intake_temp = float(r.value.magnitude)
            self.intakeAirTempChanged.emit(self._intake_temp)

    def _update_timing_combined(self, r):
        """Combined handler for timing advance and ignition timing (same OBD command)"""
        if not r.is_null():
            value = float(r.value.magnitude)
            self._timing_advance = value
            self._ignition_timing = value
            self.timingAdvanceChanged.emit(self._timing_advance)
            self.ignitionTimingChanged.emit(self._ignition_timing)

    def _update_maf(self, r):
        if not r.is_null():
            self._mass_airflow = float(r.value.magnitude)
            self.massAirFlowChanged.emit(self._mass_airflow)

    def _update_speed(self, r):
        if not r.is_null():
            self._speed_mph = float(r.value.to("mph").magnitude)
            self.speedMPHChanged.emit(self._speed_mph)

    def _update_rpm(self, r):
        if not r.is_null():
            self._rpm = float(r.value.magnitude)
            self.rpmChanged.emit(self._rpm)

    def _update_afr(self, r):
        if not r.is_null():
            self._air_fuel_ratio = float(r.value.magnitude) * 14.7
            self.airFuelRatioChanged.emit(self._air_fuel_ratio)

    def _update_fuel_level(self, r):
        if not r.is_null():
            self._fuel_level = float(r.value.magnitude)
            self.fuelLevelChanged.emit(self._fuel_level)

    def _update_intake_pressure(self, r):
        if not r.is_null():
            self._intake_pressure = float(r.value.magnitude)
            self.intakeManifoldPressureChanged.emit(self._intake_pressure)

    def _update_short_term_fuel_trim(self, r):
        if not r.is_null():
            self._short_term_fuel_trim = float(r.value.magnitude)
            self.shortTermFuelTrimChanged.emit(self._short_term_fuel_trim)

    def _update_long_term_fuel_trim(self, r):
        if not r.is_null():
            self._long_term_fuel_trim = float(r.value.magnitude)
            self.longTermFuelTrimChanged.emit(self._long_term_fuel_trim)

    def _update_o2_sensor(self, r):
        if not r.is_null():
            self._o2_sensor_voltage = float(r.value.magnitude)
            self.oxygenSensorVoltageChanged.emit(self._o2_sensor_voltage)

    def _update_fuel_pressure(self, r):
        if not r.is_null():
            self._fuel_pressure = float(r.value.magnitude)
            self.fuelPressureChanged.emit(self._fuel_pressure)

    def _update_oil_temp(self, r):
        if not r.is_null():
            self._oil_temp = float(r.value.magnitude)
            self.engineOilTempChanged.emit(self._oil_temp)

    # Getter methods
    @Slot(result=float)
    def coolantTemp(self):
        return self._coolant_temp

    @Slot(result=float)
    def voltage(self):
        return self._voltage

    @Slot(result=float)
    def engineLoad(self):
        return self._engine_load

    @Slot(result=float)
    def throttlePosition(self):
        return self._throttle_pos

    @Slot(result=float)
    def intakeTemp(self):
        return self._intake_temp

    @Slot(result=float)
    def timingAdvance(self):
        return self._timing_advance

    @Slot(result=float)
    def massAirFlow(self):
        return self._mass_airflow

    @Slot(result=float)
    def speedMPH(self):
        return self._speed_mph

    @Slot(result=float)
    def rpm(self):
        return self._rpm

    @Slot(result=float)
    def airFuelRatio(self):
        return self._air_fuel_ratio

    @Slot(result=float)
    def fuelLevel(self):
        return self._fuel_level

    @Slot(result=float)
    def intakeManifoldPressure(self):
        return self._intake_pressure

    @Slot(result=float)
    def shortTermFuelTrim(self):
        return self._short_term_fuel_trim

    @Slot(result=float)
    def longTermFuelTrim(self):
        return self._long_term_fuel_trim

    @Slot(result=float)
    def oxygenSensorVoltage(self):
        return self._o2_sensor_voltage

    @Slot(result=float)
    def fuelPressure(self):
        return self._fuel_pressure

    @Slot(result=float)
    def engineOilTemp(self):
        return self._oil_temp

    @Slot(result=float)
    def ignitionTiming(self):
        return self._ignition_timing

    @Slot()
    def reconnect(self):
        """Attempt to reconnect to the OBD device"""
        print("[OBD] Manual reconnect requested")
        self._cleanup_connection()
        self._connection_attempts = 0
        self._start_connection()

    @Slot()
    def force_connect(self):
        """Force a connection attempt, bypassing backoff and resetting attempt counter"""
        print("[OBD] Force connect requested")
        self._connection_attempts = 0
        self._cleanup_connection()
        self._start_connection()

    def _cleanup_connection(self):
        """Clean up existing connection before reconnecting"""
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
        """Deprecated: Auto-reconnect is now controlled via settings (obdAutoReconnectAttempts)"""
        print("[OBD] Warning: set_auto_reconnect() is deprecated. Use Settings > OBD > Auto-Reconnect Attempts instead.")

    @Slot(int)
    def set_connection_timeout(self, timeout_seconds):
        """Set the connection timeout"""
        self._connection_timeout = max(5, min(60, timeout_seconds))
