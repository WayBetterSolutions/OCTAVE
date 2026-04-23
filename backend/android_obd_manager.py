"""
Android OBD Manager — connects to ELM327 adapters via Classic Bluetooth RFCOMM.

Primary transport is Classic BT (SPP/RFCOMM) since most OBD adapters (NEXAS, ELM327
clones, etc.) are Classic Bluetooth devices.  BLE (FFE0/FFE1) is kept as a fallback
for adapters that genuinely use BLE.

Implements the same signal interface as the desktop OBDManager so QML works unchanged.
"""

import subprocess
import re

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QByteArray, QUuid
from PySide6.QtBluetooth import (
    QBluetoothUuid,
    QBluetoothAddress,
    QBluetoothSocket,
    QBluetoothServiceInfo,
    QLowEnergyController,
    QLowEnergyService,
    QLowEnergyCharacteristic,
    QLowEnergyDescriptor,
)

from backend.elm327_protocol import (
    INIT_COMMANDS, DEFAULT_PIDS, PID_TABLE,
    format_pid_request, parse_response, decode_pid,
    parse_supported_pids, parse_dtc_response, ResponseBuffer,
)
from backend.logging_config import get_logger

logger = get_logger(__name__)

# BLE ELM327 service/characteristic UUIDs (FFE0/FFE1 standard)
ELM_SERVICE_UUID = QBluetoothUuid(QUuid("{0000FFE0-0000-1000-8000-00805F9B34FB}"))
ELM_CHAR_UUID = QBluetoothUuid(QUuid("{0000FFE1-0000-1000-8000-00805F9B34FB}"))
CCCD_UUID = QBluetoothUuid(QUuid("{00002902-0000-1000-8000-00805F9B34FB}"))

# Standard SPP UUID for RFCOMM
SPP_UUID = QBluetoothUuid(QUuid("{00001101-0000-1000-8000-00805F9B34FB}"))

# Device name keywords to filter during scanning
ADAPTER_KEYWORDS = ("elm327", "obd", "obdii", "v-link", "vlink", "veepeak",
                    "bafx", "nexas", "nexlink", "ios-vlink", "carista")


class AndroidOBDManager(QObject):
    """OBD-II manager for Android — Classic Bluetooth RFCOMM primary, BLE fallback."""

    # ── Sensor signals (same interface as desktop OBDManager) ──────────
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
    runTimeChanged = Signal(float)
    distanceWithMILChanged = Signal(float)
    fuelRailPressureChanged = Signal(float)
    fuelRailPressureDirectChanged = Signal(float)
    barometricPressureChanged = Signal(float)
    ambientAirTempChanged = Signal(float)
    relativeThrottlePosChanged = Signal(float)
    absoluteThrottlePosBChanged = Signal(float)
    acceleratorPosChanged = Signal(float)
    catalystTempB1S1Changed = Signal(float)
    catalystTempB1S2Changed = Signal(float)
    evapVaporPressureChanged = Signal(float)
    shortFuelTrim2Changed = Signal(float)
    longFuelTrim2Changed = Signal(float)
    o2SensorB1S2Changed = Signal(float)
    o2SensorB2S1Changed = Signal(float)
    o2SensorB2S2Changed = Signal(float)
    distanceSinceCodesCleared = Signal(float)
    warmupsSinceCodesCleared = Signal(float)
    absoluteLoadChanged = Signal(float)
    commandedEGRChanged = Signal(float)
    egrErrorChanged = Signal(float)
    ethanoPercentChanged = Signal(float)
    o2SensorB1S3Changed = Signal(float)
    o2SensorB1S4Changed = Signal(float)
    o2SensorB2S3Changed = Signal(float)
    o2SensorB2S4Changed = Signal(float)
    o2S1WRVoltageChanged = Signal(float)
    o2S2WRVoltageChanged = Signal(float)
    o2S3WRVoltageChanged = Signal(float)
    o2S4WRVoltageChanged = Signal(float)
    o2S5WRVoltageChanged = Signal(float)
    o2S6WRVoltageChanged = Signal(float)
    o2S7WRVoltageChanged = Signal(float)
    o2S8WRVoltageChanged = Signal(float)
    o2S1WRCurrentChanged = Signal(float)
    o2S2WRCurrentChanged = Signal(float)
    o2S3WRCurrentChanged = Signal(float)
    o2S4WRCurrentChanged = Signal(float)
    o2S5WRCurrentChanged = Signal(float)
    o2S6WRCurrentChanged = Signal(float)
    o2S7WRCurrentChanged = Signal(float)
    o2S8WRCurrentChanged = Signal(float)
    catalystTempB2S1Changed = Signal(float)
    catalystTempB2S2Changed = Signal(float)
    throttlePosCChanged = Signal(float)
    acceleratorPosEChanged = Signal(float)
    acceleratorPosFChanged = Signal(float)
    throttleActuatorChanged = Signal(float)
    evaporativePurgeChanged = Signal(float)
    fuelRailPressureAbsChanged = Signal(float)
    fuelInjectTimingChanged = Signal(float)
    fuelRateChanged = Signal(float)
    runTimeMILChanged = Signal(float)
    timeSinceDTCClearedChanged = Signal(float)
    maxMAFChanged = Signal(float)
    fuelTypeChanged = Signal(float)
    evapVaporPressureAbsChanged = Signal(float)
    evapVaporPressureAltChanged = Signal(float)
    shortO2TrimB1Changed = Signal(float)
    longO2TrimB1Changed = Signal(float)
    shortO2TrimB2Changed = Signal(float)
    longO2TrimB2Changed = Signal(float)
    relativeAccelPosChanged = Signal(float)
    hybridBatteryRemainingChanged = Signal(float)
    elmVoltageChanged = Signal(float)

    # ── Status signals ─────────────────────────────────────────────────
    connectionStatusChanged = Signal(str)
    connectionStatusDetailChanged = Signal(str)
    connectionProgressChanged = Signal(int)
    devicePresenceChanged = Signal(bool)
    availablePortsChanged = Signal(list)
    supportedCommandsChanged = Signal(list)
    scanProgressChanged = Signal(int, str)
    scanCompleteChanged = Signal(list)
    scanOutputChanged = Signal(str)
    dtcCodesChanged = Signal(list)
    dtcCountChanged = Signal(int)
    milStatusChanged = Signal(bool)
    dtcClearResult = Signal(bool, str)
    freezeFrameChanged = Signal(list)

    # ── Connection log — live debug text for the UI ────────────────────
    connectionLogChanged = Signal(str)

    def __init__(self, settings_manager=None):
        super().__init__()
        self._settings_manager = settings_manager
        self._connected = False
        self._connecting = False
        self._elm_initialized = False
        self._target_address = ""
        self._target_device = None
        self._supported_pids = set()
        self._enabled_pids = list(DEFAULT_PIDS)
        self._poll_index = 0
        self._response_buffer = ResponseBuffer()
        self._init_step = 0
        self._discovered_devices = []
        self._reconnect_attempts = 0
        self._max_reconnect = 3
        self._log_lines = []
        self._diag_mode = False       # True during DTC read/clear
        self._diag_responses = []     # Holds responses during diagnostic mode

        # BLE objects (fallback only)
        self._controller = None
        self._service = None
        self._char = None
        self._use_ble = False

        # Classic BT socket (primary transport)
        self._socket = QBluetoothSocket(QBluetoothServiceInfo.Protocol.RfcommProtocol, self)
        self._socket.connected.connect(self._on_classic_connected)
        self._socket.disconnected.connect(self._on_disconnected)
        self._socket.readyRead.connect(self._on_classic_data_ready)
        self._socket.errorOccurred.connect(self._on_classic_error)

        # Build signal lookup from PID table
        self._signal_map = {}
        for key, (name, signal_name, decoder, nbytes) in PID_TABLE.items():
            sig = getattr(self, signal_name, None)
            if sig:
                self._signal_map[signal_name] = sig

        # Qt device discovery is NOT used on Android — crashes with
        # NullPointerException in QtBluetoothBroadcastReceiver.onReceive.
        # Discovery is done via dumpsys subprocess instead.
        self._discovery_active = False

        # Poll timer — safety net that re-kicks polling if a response is lost
        self._poll_timer = QTimer(self)
        self._poll_timer.setSingleShot(True)
        self._poll_timer.timeout.connect(self._on_poll_timeout)
        self._polling_active = False
        self._stale_count = 0

        # Init timer (steps through ELM327 AT commands)
        self._init_timer = QTimer(self)
        self._init_timer.setSingleShot(True)
        self._init_timer.timeout.connect(self._send_next_init)

        # Reconnect timer
        self._reconnect_timer = QTimer(self)
        self._reconnect_timer.setSingleShot(True)
        self._reconnect_timer.timeout.connect(self._attempt_reconnect)

        # Load saved address from settings — user enters their adapter's MAC in OBDSettingsPage
        self._target_address = ""
        if settings_manager:
            saved = settings_manager.obdBluetoothPort
            mac_re = re.compile(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$')
            if saved and mac_re.match(saved):
                self._target_address = saved

        self._log("AndroidOBDManager initialized (Classic RFCOMM primary)")
        logger.info("AndroidOBDManager initialized (Classic RFCOMM primary)")

    # ───────────────────────────────────────────────────────────────────
    # Connection log — emits to UI and logger
    # ───────────────────────────────────────────────────────────────────

    def _log(self, msg):
        """Append to the connection log and emit to QML."""
        self._log_lines.append(msg)
        # Keep last 100 lines
        if len(self._log_lines) > 100:
            self._log_lines = self._log_lines[-100:]
        self.connectionLogChanged.emit(msg)
        logger.info(f"[OBD] {msg}")

    @Slot(result=list)
    def get_connection_log(self):
        return list(self._log_lines)

    # ───────────────────────────────────────────────────────────────────
    # Android helpers
    # ───────────────────────────────────────────────────────────────────

    @Slot()
    def open_bluetooth_settings(self):
        """Launch Android's Bluetooth settings for pairing."""
        self._log("Opening Android Bluetooth settings...")
        try:
            subprocess.Popen([
                'am', 'start', '-a', 'android.settings.BLUETOOTH_SETTINGS'
            ])
        except Exception as e:
            self._log(f"Failed to open BT settings: {e}")

    # ───────────────────────────────────────────────────────────────────
    # Device discovery
    # ───────────────────────────────────────────────────────────────────

    @Slot()
    def refresh_ports(self):
        """List bonded BT devices via dumpsys + start Qt scan as supplement."""
        self._log("Starting Bluetooth scan...")
        self._discovered_devices.clear()
        self.connectionStatusChanged.emit("Scanning...")

        # Get bonded (paired) devices from Android system via dumpsys
        # NOTE: Do NOT call self._discovery.start() — Qt's BLE scanner crashes
        # on Android with NullPointerException in QtBluetoothBroadcastReceiver
        self._list_bonded_devices()

    def _list_bonded_devices(self):
        """Parse bonded devices from Android's dumpsys bluetooth_manager."""
        try:
            result = subprocess.run(
                ['dumpsys', 'bluetooth_manager'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode != 0:
                self._log("dumpsys failed")
                return

            output = result.stdout
            lines = output.split('\n')

            # ── Parse "Bonded devices:" section ──
            in_bonded = False
            bonded_count = 0
            for line in lines:
                stripped = line.strip()
                if 'Bonded devices:' in stripped:
                    in_bonded = True
                    continue
                if in_bonded:
                    if not stripped or stripped.startswith('='):
                        break
                    mac_match = re.search(
                        r'([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})', stripped
                    )
                    if mac_match:
                        address = mac_match.group(1).upper()
                        # Name is everything before the MAC
                        name = stripped[:mac_match.start()].strip(' :()')
                        if not name:
                            name = address
                        self._add_device(name, address, is_ble=False)
                        bonded_count += 1

            # ── Also look for device names in RE_NAM fields ──
            name_pattern = re.compile(r'RE_NAM["\s:=]+([^"]+)"')
            mac_pattern = re.compile(
                r'([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})'
            )
            for match in name_pattern.finditer(output):
                dev_name = match.group(1).strip()
                if not dev_name or dev_name == "unknown":
                    continue
                name_lower = dev_name.lower()
                if any(kw in name_lower for kw in ADAPTER_KEYWORDS):
                    # Search nearby text for a full MAC
                    region = output[max(0, match.start() - 1000):match.end() + 1000]
                    mac_hit = mac_pattern.search(region)
                    if mac_hit:
                        addr = mac_hit.group(1).upper()
                        self._add_device(dev_name, addr, is_ble=False)
                        self._log(f"Found OBD device in logs: {dev_name} [{addr}]")

            self._log(f"dumpsys: {bonded_count} bonded, {len(self._discovered_devices)} total devices")

        except Exception as e:
            self._log(f"Error listing devices: {e}")

        if self._discovered_devices:
            self.availablePortsChanged.emit(self.get_available_ports())
            self.connectionStatusChanged.emit(
                f"Found {len(self._discovered_devices)} device(s)"
            )
        else:
            self.connectionStatusChanged.emit("No devices found — pair in BT Settings first")

    def _add_device(self, name, address, is_ble):
        """Add a device to the discovered list (no duplicates)."""
        if not any(d["address"] == address for d in self._discovered_devices):
            self._discovered_devices.append({
                "name": name,
                "address": address,
                "device": None,
                "is_ble": is_ble,
            })
            self._log(f"Device: {name} [{address}] {'BLE' if is_ble else 'Classic'}")

    @Slot(result=list)
    def get_available_ports(self):
        return [f"{d['name']} ({d['address']})" for d in self._discovered_devices]

    # ───────────────────────────────────────────────────────────────────
    # Connection entry points
    # ───────────────────────────────────────────────────────────────────

    @Slot(str)
    def set_target_address(self, address):
        """Set the MAC address to connect to (from QML manual entry)."""
        address = address.strip().upper()
        if address:
            self._target_address = address
            if self._settings_manager:
                self._settings_manager.save_obd_bluetooth_port(address)
            self._log(f"Target address set: {address}")

    @Slot()
    def reconnect(self):
        self.force_connect()

    @Slot()
    def force_connect(self):
        """Connect to the target OBD adapter. Prefers Classic RFCOMM."""
        if self._connected or self._connecting:
            self._log("Already connected/connecting, ignoring")
            return

        # Find the device entry to connect to
        device_entry = None

        # 1) If we have a target address, find it in discovered devices
        if self._target_address:
            for d in self._discovered_devices:
                if d["address"] == self._target_address:
                    device_entry = d
                    break

        # 2) If not found in list but we have a MAC, create a synthetic entry
        #    (user typed it manually or it was saved from a previous session)
        if not device_entry and self._target_address:
            mac_re = re.compile(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$')
            if mac_re.match(self._target_address):
                device_entry = {
                    "name": "Manual",
                    "address": self._target_address,
                    "device": None,
                    "is_ble": False,
                }
                self._log(f"Using manual MAC: {self._target_address}")
            else:
                self._log(f"Invalid MAC format: {self._target_address}")
                self.connectionStatusChanged.emit("Invalid MAC address")
                return

        # 3) Fall back to first discovered device
        if not device_entry and self._discovered_devices:
            device_entry = self._discovered_devices[0]
            self._target_address = device_entry["address"]
            self._log(f"No target set, using first device: {device_entry['name']}")

        if not device_entry:
            self._log("No device to connect to — scan or enter MAC first")
            self.connectionStatusChanged.emit("No adapter — scan or enter MAC")
            return

        self._connecting = True
        self._reconnect_attempts = 0

        # Route to Classic RFCOMM unless explicitly marked BLE
        if device_entry.get("is_ble"):
            self._log(f"Connecting BLE → {device_entry['name']} [{device_entry['address']}]")
            self._connect_ble(device_entry["device"])
        else:
            self._log(f"Connecting RFCOMM → {device_entry['name']} [{device_entry['address']}]")
            self._connect_classic(device_entry["address"])

    # ───────────────────────────────────────────────────────────────────
    # Classic Bluetooth (RFCOMM) — primary transport
    # ───────────────────────────────────────────────────────────────────

    def _connect_classic(self, address):
        """Connect via Classic Bluetooth RFCOMM (SPP)."""
        self.connectionStatusChanged.emit("Connecting RFCOMM...")
        self.connectionProgressChanged.emit(20)
        self._use_ble = False
        self._target_address = address
        self._response_buffer.clear()

        # Disconnect any existing socket first
        if self._socket.state() != QBluetoothSocket.SocketState.UnconnectedState:
            self._log("Closing existing socket...")
            self._socket.disconnectFromService()
            # Give it a moment to clean up
            QTimer.singleShot(500, lambda: self._do_classic_connect(address))
        else:
            self._do_classic_connect(address)

    def _do_classic_connect(self, address):
        """Actually initiate the RFCOMM connection."""
        bt_address = QBluetoothAddress(address)
        self._log(f"RFCOMM connecting to {address} with SPP UUID...")
        self.connectionProgressChanged.emit(30)

        try:
            self._socket.connectToService(bt_address, SPP_UUID)
        except Exception as e:
            self._log(f"RFCOMM connect exception: {e}")
            self._connecting = False
            self.connectionStatusChanged.emit("Connection failed")
            self.connectionProgressChanged.emit(0)

    def _on_classic_connected(self):
        """Socket connected — start ELM327 init sequence."""
        self._log("RFCOMM socket connected!")
        self._connecting = False
        self.connectionProgressChanged.emit(50)
        self.connectionStatusChanged.emit("Initializing ELM327...")

        if self._settings_manager and self._target_address:
            self._settings_manager.save_obd_bluetooth_port(self._target_address)

        self._elm_initialized = False
        self._response_buffer.clear()
        self._init_step = 0
        QTimer.singleShot(500, self._send_next_init)

    def _on_classic_data_ready(self):
        """Data arrived on RFCOMM socket."""
        data = self._socket.readAll().data()
        self._response_buffer.feed(data)
        while True:
            response = self._response_buffer.get_response()
            if response is None:
                break
            self._process_response(response)

    def _on_classic_error(self, error):
        self._connecting = False
        error_names = {
            QBluetoothSocket.SocketError.NoSocketError: "No error",
            QBluetoothSocket.SocketError.UnknownSocketError: "Unknown error",
            QBluetoothSocket.SocketError.HostNotFoundError: "Device not found",
            QBluetoothSocket.SocketError.ServiceNotFoundError: "SPP service not found",
            QBluetoothSocket.SocketError.NetworkError: "Network error",
            QBluetoothSocket.SocketError.UnsupportedProtocolError: "Protocol not supported",
            QBluetoothSocket.SocketError.OperationError: "Operation error",
            QBluetoothSocket.SocketError.RemoteHostClosedError: "Device closed connection",
        }
        err_text = error_names.get(error, f"Error code {error}")
        self._log(f"RFCOMM error: {err_text}")

        socket_state = self._socket.state()
        self._log(f"Socket state: {socket_state}")

        self.connectionStatusChanged.emit(f"RFCOMM: {err_text}")
        self.connectionProgressChanged.emit(0)

        if error == QBluetoothSocket.SocketError.ServiceNotFoundError:
            self._log("Hint: Device may not be paired. Open BT Settings to pair first.")
        elif error == QBluetoothSocket.SocketError.HostNotFoundError:
            self._log("Hint: Device not reachable. Is the adapter powered on?")

        if self._reconnect_attempts < self._max_reconnect:
            self._reconnect_attempts += 1
            delay = min(2000 * self._reconnect_attempts, 10000)
            self._log(f"Will retry in {delay}ms ({self._reconnect_attempts}/{self._max_reconnect})")
            self._reconnect_timer.start(delay)

    # ───────────────────────────────────────────────────────────────────
    # BLE Connection — fallback for BLE-only adapters
    # ───────────────────────────────────────────────────────────────────

    def _connect_ble(self, device_info):
        """Create BLE controller and connect."""
        self._use_ble = True
        self.connectionStatusChanged.emit("Connecting BLE...")
        self.connectionProgressChanged.emit(20)

        if self._controller:
            self._controller.disconnectFromDevice()
            self._controller.deleteLater()

        self._target_device = device_info
        self._controller = QLowEnergyController.createCentral(device_info, self)
        self._controller.connected.connect(self._on_ble_connected)
        self._controller.disconnected.connect(self._on_disconnected)
        self._controller.errorOccurred.connect(self._on_ble_error)
        self._controller.serviceDiscovered.connect(self._on_service_discovered)
        self._controller.discoveryFinished.connect(self._on_service_discovery_finished)

        self._controller.connectToDevice()

    def _on_ble_connected(self):
        self._log("BLE connected, discovering services...")
        self.connectionStatusChanged.emit("Discovering services...")
        self.connectionProgressChanged.emit(40)
        self._controller.discoverServices()

    def _on_service_discovered(self, service_uuid):
        self._log(f"BLE service: {service_uuid.toString()}")

    def _on_service_discovery_finished(self):
        self._log("BLE service discovery complete")

        self._service = self._controller.createServiceObject(ELM_SERVICE_UUID, self)
        if not self._service:
            for uuid in self._controller.services():
                self._log(f"  Available: {uuid.toString()}")
            self._log("ELM327 FFE0 service not found")
            self.connectionStatusChanged.emit("ELM327 service not found")
            self._connecting = False
            return

        self._service.stateChanged.connect(self._on_service_state_changed)
        self._service.characteristicChanged.connect(self._on_characteristic_changed)
        self._service.errorOccurred.connect(self._on_service_error)
        self.connectionProgressChanged.emit(60)
        self._service.discoverDetails()

    def _on_service_state_changed(self, state):
        if state == QLowEnergyService.ServiceState.RemoteServiceDiscovered:
            self._log("BLE FFE0 service details discovered")

            self._char = self._service.characteristic(ELM_CHAR_UUID)
            if not self._char.isValid():
                self._log("FFE1 characteristic not found")
                self.connectionStatusChanged.emit("FFE1 not found")
                self._connecting = False
                return

            cccd = self._char.descriptor(CCCD_UUID)
            if cccd.isValid():
                self._service.writeDescriptor(cccd, QByteArray.fromHex(b"0100"))
                self._log("BLE notifications enabled on FFE1")

            self._connecting = False
            self.connectionProgressChanged.emit(70)
            self.connectionStatusChanged.emit("Initializing ELM327...")

            if self._settings_manager and self._target_address:
                self._settings_manager.save_obd_bluetooth_port(self._target_address)

            self._elm_initialized = False
            self._response_buffer.clear()
            self._init_step = 0
            QTimer.singleShot(500, self._send_next_init)

    def _on_characteristic_changed(self, char, data):
        self._response_buffer.feed(bytes(data))
        while True:
            response = self._response_buffer.get_response()
            if response is None:
                break
            self._process_response(response)

    def _on_ble_error(self, error):
        self._connecting = False
        self._log(f"BLE error: {error}")
        self.connectionStatusChanged.emit("BLE error")
        self.connectionProgressChanged.emit(0)
        if self._reconnect_attempts < self._max_reconnect:
            self._reconnect_attempts += 1
            self._reconnect_timer.start(3000)

    def _on_service_error(self, error):
        self._log(f"BLE service error: {error}")

    # ───────────────────────────────────────────────────────────────────
    # Shared disconnect / reconnect
    # ───────────────────────────────────────────────────────────────────

    def _on_disconnected(self):
        was_connected = self._connected
        self._connected = False
        self._elm_initialized = False
        self._stop_polling()
        transport = "BLE" if self._use_ble else "RFCOMM"
        self._log(f"{transport} disconnected")
        self.connectionStatusChanged.emit("Disconnected")
        self.connectionProgressChanged.emit(0)

        if was_connected and self._reconnect_attempts < self._max_reconnect:
            delay = min(2000 * (self._reconnect_attempts + 1), 10000)
            self._log(f"Auto-reconnect in {delay}ms")
            self._reconnect_timer.start(delay)

    def _attempt_reconnect(self):
        if not self._connected and (self._discovered_devices or self._target_address):
            self._reconnect_attempts += 1
            self._log(f"Reconnect attempt {self._reconnect_attempts}/{self._max_reconnect}")
            self.force_connect()

    # ───────────────────────────────────────────────────────────────────
    # Write — auto-selects BLE or Classic
    # ───────────────────────────────────────────────────────────────────

    def _write(self, data):
        """Write bytes to ELM327 via the active transport."""
        if self._use_ble and self._service and self._char and self._char.isValid():
            chunk_size = 20
            for i in range(0, len(data), chunk_size):
                chunk = data[i:i + chunk_size]
                self._service.writeCharacteristic(
                    self._char, QByteArray(chunk),
                    QLowEnergyService.WriteMode.WriteWithoutResponse
                )
        elif not self._use_ble and self._socket.state() == QBluetoothSocket.SocketState.ConnectedState:
            self._socket.write(QByteArray(data))
        else:
            self._log("Write failed — no active transport")

    # ───────────────────────────────────────────────────────────────────
    # ELM327 initialization + PID polling
    # ───────────────────────────────────────────────────────────────────

    def _send_next_init(self):
        if self._init_step >= len(INIT_COMMANDS):
            self._elm_initialized = True
            self._log("ELM327 init complete, querying supported PIDs...")
            self.connectionProgressChanged.emit(80)
            self.connectionStatusChanged.emit("Querying PIDs...")
            self._query_supported_pids()
            return

        cmd, timeout = INIT_COMMANDS[self._init_step]
        cmd_str = cmd.decode('ascii', errors='ignore').strip()
        self._log(f"Init [{self._init_step + 1}/{len(INIT_COMMANDS)}]: {cmd_str}")
        self._write(cmd)
        self._init_step += 1
        self._init_timer.start(int(timeout * 1000))

    def _query_supported_pids(self):
        self._write(b"0100\r")
        QTimer.singleShot(2000, self._finalize_connection)

    def _finalize_connection(self):
        self._connected = True
        self._log(f"Connected! {len(self._supported_pids)} supported PIDs detected")
        self.connectionStatusChanged.emit("Connected")
        self.connectionProgressChanged.emit(100)
        self.devicePresenceChanged.emit(True)

        if self._supported_pids:
            self._enabled_pids = [
                p for p in DEFAULT_PIDS if p[1] in self._supported_pids
            ]
            if not self._enabled_pids:
                self._enabled_pids = list(DEFAULT_PIDS)
        else:
            self._enabled_pids = list(DEFAULT_PIDS)

        self._poll_index = 0
        self._polling_active = True
        self._stale_count = 0
        # Start response-driven polling — send first request immediately
        self._poll_next_pid()

    def _poll_next_pid(self):
        if not self._connected or not self._enabled_pids or not self._polling_active:
            return
        mode, pid = self._enabled_pids[self._poll_index]
        self._write(format_pid_request(mode, pid))
        self._poll_index = (self._poll_index + 1) % len(self._enabled_pids)
        # Safety net: if no response in 500ms, watchdog kicks in
        self._poll_timer.start(500)

    def _on_poll_timeout(self):
        """No response received in 500ms — re-kick polling."""
        if not self._polling_active or not self._connected:
            return
        self._stale_count += 1
        if self._stale_count >= 10:
            # 5 seconds with no data — flush buffer and restart
            self._log("Data stale for 5s, flushing buffer and restarting polling")
            self._response_buffer.clear()
            self._stale_count = 0
        self._poll_next_pid()

    def _process_response(self, response):
        if not response:
            return
        if not self._elm_initialized:
            self._log(f"Init response: {response}")
            return

        # During diagnostic mode, stash responses for the diag handler
        if self._diag_mode:
            self._diag_responses.append(response)
            return

        # Got a valid response — reset stale counter and fire next request
        self._stale_count = 0

        parsed = parse_response(response)
        if parsed is None:
            # Unparseable but still a response — keep polling
            if self._polling_active:
                self._poll_next_pid()
            return

        mode, pid, data = parsed

        if mode == 1 and pid in (0x00, 0x20, 0x40, 0x60):
            new_pids = parse_supported_pids(data)
            self._supported_pids.update(p + pid for p in new_pids)
            if self._polling_active:
                self._poll_next_pid()
            return

        result = decode_pid(mode, pid, data)
        if result:
            signal_name, value = result
            sig = self._signal_map.get(signal_name)
            if sig:
                sig.emit(value)

        # Response-driven: immediately request the next PID
        if self._polling_active:
            self._poll_next_pid()

    # ───────────────────────────────────────────────────────────────────
    # QML slots
    # ───────────────────────────────────────────────────────────────────

    @Slot(result=float)
    def coolantTemp(self): return 0.0
    @Slot(result=float)
    def voltage(self): return 0.0
    @Slot(result=float)
    def engineLoad(self): return 0.0
    @Slot(result=float)
    def throttlePosition(self): return 0.0
    @Slot(result=float)
    def intakeTemp(self): return 0.0
    @Slot(result=float)
    def timingAdvance(self): return 0.0
    @Slot(result=float)
    def massAirFlow(self): return 0.0
    @Slot(result=float)
    def speedMPH(self): return 0.0
    @Slot(result=float)
    def rpm(self): return 0.0
    @Slot(result=float)
    def airFuelRatio(self): return 0.0
    @Slot(result=float)
    def fuelLevel(self): return 0.0
    @Slot(result=float)
    def intakeManifoldPressure(self): return 0.0
    @Slot(result=float)
    def shortTermFuelTrim(self): return 0.0
    @Slot(result=float)
    def longTermFuelTrim(self): return 0.0
    @Slot(result=float)
    def oxygenSensorVoltage(self): return 0.0
    @Slot(result=float)
    def fuelPressure(self): return 0.0
    @Slot(result=float)
    def engineOilTemp(self): return 0.0
    @Slot(result=float)
    def ignitionTiming(self): return 0.0

    @Slot(result=bool)
    def is_connected(self): return self._connected
    @Slot(result=str)
    def get_connection_status(self):
        return "Connected" if self._connected else "Disconnected"

    @Slot()
    def close(self):
        self._stop_polling()
        if self._use_ble and self._controller:
            self._controller.disconnectFromDevice()
        elif not self._use_ble and self._socket.state() != QBluetoothSocket.SocketState.UnconnectedState:
            self._socket.disconnectFromService()
        self._connected = False
        self._log("Connection closed")

    @Slot()
    def reset_connection(self):
        self.close()
        QTimer.singleShot(1000, self.force_connect)

    @Slot(result=bool)
    def check_device_presence(self): return self._connected
    @Slot(bool)
    def set_auto_reconnect(self, enabled):
        self._max_reconnect = 3 if enabled else 0
    @Slot(int)
    def set_connection_timeout(self, timeout_seconds): pass
    @Slot(result=list)
    def get_all_parameter_names(self):
        return [info[0] for info in PID_TABLE.values()]
    @Slot(result=list)
    def get_supported_commands(self):
        return [PID_TABLE[k][0] for k in PID_TABLE if k[1] in self._supported_pids]
    @Slot(result=bool)
    def is_scanning(self): return self._discovery_active

    def _start_polling(self):
        """Start response-driven PID polling."""
        self._polling_active = True
        self._poll_next_pid()
        self._poll_timer.start(500)  # Safety net

    def _stop_polling(self):
        """Stop PID polling."""
        self._polling_active = False
        self._poll_timer.stop()

    @Slot()
    def scan_vehicle(self):
        if not self._connected:
            return
        self._stop_polling()
        self._supported_pids.clear()
        self.scanProgressChanged.emit(0, "Scanning PIDs...")
        for base_pid in [0x00, 0x20, 0x40, 0x60]:
            self._write(format_pid_request(1, base_pid))
        QTimer.singleShot(3000, self._scan_complete)

    def _scan_complete(self):
        supported_names = self.get_supported_commands()
        self.scanCompleteChanged.emit(supported_names)
        self.supportedCommandsChanged.emit(supported_names)
        self.scanProgressChanged.emit(
            100, f"Found {len(supported_names)} parameters"
        )
        self._start_polling()

    @Slot(list)
    def enable_scanned_parameters(self, param_names):
        self._enabled_pids = []
        for key, (name, sig, dec, nb) in PID_TABLE.items():
            if name in param_names:
                self._enabled_pids.append(key)
        if not self._enabled_pids:
            self._enabled_pids = list(DEFAULT_PIDS)

    @Slot()
    def enable_all_supported(self):
        self._enabled_pids = [
            k for k in PID_TABLE if k[1] in self._supported_pids
        ]
        if not self._enabled_pids:
            self._enabled_pids = list(DEFAULT_PIDS)

    # Diagnostics
    @Slot()
    def enter_diagnostic_mode(self): self._stop_polling()
    @Slot()
    def exit_diagnostic_mode(self):
        if self._connected:
            self._start_polling()
    @Slot(result=list)
    def getDtcCodes(self): return []
    @Slot(result=int)
    def getDtcCount(self): return 0
    @Slot(result=bool)
    def getMilStatus(self): return False
    @Slot(result=list)
    def getFreezeFrames(self): return []

    @Slot()
    def read_dtc(self):
        if not self._connected: return
        self._stop_polling()
        self._diag_mode = True
        self._diag_responses.clear()
        self._log("Reading DTCs...")
        self._write(b"03\r")
        QTimer.singleShot(2000, self._process_dtc_response)

    def _process_dtc_response(self):
        self._diag_mode = False
        # Use stashed diag responses (not the buffer, which _process_response skipped)
        raw = " ".join(self._diag_responses) if self._diag_responses else ""
        self._log(f"DTC raw: {raw}")
        codes = parse_dtc_response(raw) if raw else []
        self._log(f"DTCs found: {codes}")
        self.dtcCodesChanged.emit(codes)
        self.dtcCountChanged.emit(len(codes))
        self.milStatusChanged.emit(len(codes) > 0)
        self._diag_responses.clear()
        self._start_polling()

    @Slot()
    def clear_dtc(self):
        if not self._connected: return
        self._stop_polling()
        self._diag_mode = True
        self._diag_responses.clear()
        self._log("Clearing DTCs...")
        self._write(b"04\r")
        QTimer.singleShot(2000, self._process_clear_result)

    def _process_clear_result(self):
        self._diag_mode = False
        raw = " ".join(self._diag_responses) if self._diag_responses else ""
        self._log(f"Clear DTC raw: {raw}")
        success = "44" in raw
        self.dtcClearResult.emit(
            success, "Codes cleared" if success else "Clear failed"
        )
        self.dtcCodesChanged.emit([])
        self.dtcCountChanged.emit(0)
        self.milStatusChanged.emit(False)
        self._diag_responses.clear()
        self._start_polling()

    @Slot()
    def refresh_values(self): pass
    @Slot()
    def cleanup(self):
        self._stop_polling()
        self._init_timer.stop()
        self._reconnect_timer.stop()
        self.close()
        self._log("AndroidOBDManager cleaned up")
