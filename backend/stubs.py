"""
Stub managers for Android deployment.

These provide the same Signal/Property/Slot interface as the real managers
but perform no hardware I/O. QML can bind to them without crashing.
"""

from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQuick import QQuickItem, QQuickImageProvider
from PySide6.QtGui import QImage
from PySide6.QtQml import QQmlImageProviderBase


# ---------------------------------------------------------------------------
# Stub image provider — returns a 1x1 transparent image for any request
# ---------------------------------------------------------------------------

class StubImageProvider(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQmlImageProviderBase.ImageType.Image)

    def requestImage(self, id, size, requestedSize):
        img = QImage(1, 1, QImage.Format.Format_ARGB32)
        img.fill(0)
        return img


# ---------------------------------------------------------------------------
# StubOBDManager
# ---------------------------------------------------------------------------

class StubOBDManager(QObject):
    # All 87 sensor signals
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

    # Status signals
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

    def __init__(self, settings_manager=None):
        super().__init__()

    # Sensor value slots — all return 0.0
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

    # Connection slots
    @Slot()
    def reconnect(self): pass
    @Slot()
    def force_connect(self): pass
    @Slot(result=bool)
    def is_connected(self): return False
    @Slot(result=str)
    def get_connection_status(self): return "Disconnected"
    @Slot()
    def close(self): pass
    @Slot()
    def reset_connection(self): pass
    @Slot(result=bool)
    def check_device_presence(self): return False
    @Slot(result=list)
    def get_available_ports(self): return []
    @Slot(bool)
    def set_auto_reconnect(self, enabled): pass
    @Slot(int)
    def set_connection_timeout(self, timeout_seconds): pass

    # Scan/diagnostic slots
    @Slot(result=list)
    def get_all_parameter_names(self): return []
    @Slot(result=list)
    def get_supported_commands(self): return []
    @Slot(result=bool)
    def is_scanning(self): return False
    @Slot()
    def scan_vehicle(self): pass
    @Slot(list)
    def enable_scanned_parameters(self, param_names): pass
    @Slot()
    def enable_all_supported(self): pass
    @Slot()
    def enter_diagnostic_mode(self): pass
    @Slot()
    def exit_diagnostic_mode(self): pass
    @Slot(result=list)
    def getDtcCodes(self): return []
    @Slot(result=int)
    def getDtcCount(self): return 0
    @Slot(result=bool)
    def getMilStatus(self): return False
    @Slot(result=list)
    def getFreezeFrames(self): return []

    @Slot()
    def refresh_values(self): pass
    @Slot()
    def cleanup(self): pass


# ---------------------------------------------------------------------------
# StubBerryIMUManager
# ---------------------------------------------------------------------------

class StubBerryIMUManager(QObject):
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

    @Property(bool, notify=connectionStatusChanged)
    def connected(self):
        return False

    @Slot(result=str)
    def getConnectionStatus(self): return "Unavailable"
    @Slot(bool)
    def setEnabled(self, enabled): pass
    @Slot(result=bool)
    def isEnabled(self): return False
    @Slot(int)
    def setEmitRate(self, hz): pass
    @Slot()
    def calibrateTare(self): pass
    @Slot()
    def resetTare(self): pass
    @Slot()
    def cleanup(self): pass

    def connect_settings_manager(self, settings_manager):
        pass


# ---------------------------------------------------------------------------
# StubGestureManager
# ---------------------------------------------------------------------------

class StubGestureManager(QObject):
    gestureDetected = Signal(str)
    actionTriggered = Signal(str)
    connectionStatusChanged = Signal(str)

    def __init__(self):
        super().__init__()

    @Slot(result=str)
    def getConnectionStatus(self): return "Unavailable"
    @Slot(str, str)
    def setGestureAction(self, gesture, action): pass
    @Slot(str, result=str)
    def getGestureAction(self, gesture): return ""
    @Slot()
    def resetMappingToDefaults(self): pass
    @Slot(bool)
    def setEnabled(self, enabled): pass
    @Slot(int)
    def setCooldown(self, ms): pass
    @Slot(result=bool)
    def isEnabled(self): return False
    @Slot()
    def cleanup(self): pass

    def connect_settings_manager(self, settings_manager):
        pass


# ---------------------------------------------------------------------------
# StubESP32VolumeManager
# ---------------------------------------------------------------------------

class StubESP32VolumeManager(QObject):
    connectionStatusChanged = Signal(str)
    connectionDetailChanged = Signal(str)
    availablePortsChanged = Signal(list)
    volumeChangeRequested = Signal(float)
    muteToggleRequested = Signal()

    def __init__(self, settings_manager=None):
        super().__init__()

    @Property(bool, notify=connectionStatusChanged)
    def connected(self):
        return False

    @Property(str, notify=connectionStatusChanged)
    def connectionStatus(self):
        return "Unavailable"

    @Property(str, notify=connectionDetailChanged)
    def connectionDetail(self):
        return ""

    @Property(list, notify=availablePortsChanged)
    def availablePorts(self):
        return []

    @Slot()
    def connect_device(self): pass
    @Slot()
    def disconnect_device(self): pass
    @Slot(result=list)
    def get_available_ports(self): return []
    @Slot(result=str)
    def get_ports_with_descriptions(self): return ""
    @Slot(result=bool)
    def is_connected(self): return False
    @Slot(result=str)
    def get_connection_status(self): return "Unavailable"
    @Slot(result=str)
    def get_connection_detail(self): return ""
    @Slot()
    def refresh_ports(self): pass
    @Slot()
    def reset_reconnect_attempts(self): pass
    @Slot()
    def cleanup(self): pass

    def connect_settings_manager(self, settings_manager):
        pass

    def send_volume_update(self, volume):
        pass

    def send_mute_state(self, muted):
        pass

    def send_theme_color(self, r, g, b):
        pass


# ---------------------------------------------------------------------------
# StubPhoneMirrorManager
# ---------------------------------------------------------------------------

class StubPhoneMirrorManager(QObject):
    scrcpyPathChanged = Signal()
    error = Signal(str)
    scrcpyStarted = Signal(int)
    scrcpyStopped = Signal()
    scrcpyError = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

    @Property(bool, notify=scrcpyPathChanged)
    def isScrcpyInstalled(self):
        return False

    @Property(str, notify=scrcpyPathChanged)
    def scrcpyPath(self):
        return ""

    @Property(str)
    def adbPath(self):
        return ""

    @Property(bool, notify=scrcpyStarted)
    def isRunning(self):
        return False

    @Property(int, notify=scrcpyStarted)
    def scrcpyWindowHandle(self):
        return 0

    @Slot(str)
    def setScrcpyPath(self, path): pass
    @Slot(bool)
    def setAudioEnabled(self, enabled): pass
    @Slot(float)
    def setVolume(self, volume): pass
    @Slot(result=bool)
    def hasConnectedDevice(self): return False
    @Slot(result=str)
    def getDeviceSerial(self): return ""
    @Slot(result=str)
    def getDeviceName(self): return ""
    @Slot(result=str)
    def getDeviceResolution(self): return ""
    @Slot(result=str)
    def getInstallInstructions(self): return ""
    @Slot()
    def startScrcpy(self): pass
    @Slot()
    def stopScrcpy(self): pass
    @Slot()
    def cleanup(self): pass


# ---------------------------------------------------------------------------
# StubDhuCapture (used internally by StubAndroidAutoManager)
# ---------------------------------------------------------------------------

class StubDhuCapture(QObject):
    frameReady = Signal()
    captureStarted = Signal()
    captureStopped = Signal()
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._frame_provider = StubImageProvider()

    @property
    def frame_provider(self):
        return self._frame_provider

    @Property(bool, notify=captureStarted)
    def isCapturing(self):
        return False

    @Property(int)
    def windowHandle(self):
        return 0

    @Slot(int)
    def setWindowHandle(self, hwnd): pass
    @Slot()
    def startCapture(self): pass
    @Slot()
    def stopCapture(self): pass
    @Slot(int, int)
    def sendMouseClick(self, x, y): pass
    @Slot(int, int, bool)
    def sendMouseEvent(self, x, y, pressed): pass


# ---------------------------------------------------------------------------
# StubAndroidAutoManager
# ---------------------------------------------------------------------------

class StubAndroidAutoManager(QObject):
    connectionProgress = Signal(str)
    error = Signal(str)
    dhuWindowReady = Signal(int)
    dhuEmbeddedChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._dhu_capture = StubDhuCapture()

    @Property(bool, constant=True)
    def isDhuInstalled(self):
        return False

    @Property(str, constant=True)
    def dhuPath(self):
        return ""

    @Property(bool, notify=dhuEmbeddedChanged)
    def isDhuEmbedded(self):
        return False

    @Property(int, notify=dhuWindowReady)
    def dhuWindowHandle(self):
        return 0

    @Property(QObject, constant=True)
    def dhuCapture(self):
        return self._dhu_capture

    @Slot(result=str)
    def getDhuInstallInstructions(self): return ""
    @Slot(result=bool)
    def launchDhuSeamless(self): return False
    @Slot(int, int)
    def sendDhuClick(self, x, y): pass
    @Slot()
    def closeDhu(self): pass
    @Slot()
    def cleanup(self): pass


# ---------------------------------------------------------------------------
# StubScrcpyCapture
# ---------------------------------------------------------------------------

class StubScrcpyCapture(QObject):
    frameReady = Signal()
    captureStarted = Signal()
    captureStopped = Signal()
    error = Signal(str)
    frameSizeChanged = Signal(int, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._frame_provider = StubImageProvider()

    @property
    def frame_provider(self):
        return self._frame_provider

    @Property(bool, notify=captureStarted)
    def isCapturing(self):
        return False

    @Property(int)
    def windowHandle(self):
        return 0

    @Property(int)
    def frameWidth(self):
        return 0

    @Property(int)
    def frameHeight(self):
        return 0

    @Slot(int)
    def setWindowHandle(self, hwnd): pass
    @Slot()
    def startCapture(self): pass
    @Slot()
    def stopCapture(self): pass
    @Slot(float, float)
    def sendTap(self, rel_x, rel_y): pass
    @Slot(float, float, float, float, int)
    def sendSwipe(self, rel_x1, rel_y1, rel_x2, rel_y2, duration_ms=300): pass
    @Slot(float, float, bool)
    def sendTouchEvent(self, rel_x, rel_y, pressed): pass
    @Slot(float, float)
    def sendTouchMove(self, rel_x, rel_y): pass

    def setPhoneMirrorManager(self, manager):
        pass


# ---------------------------------------------------------------------------
# Stub QQuickItem subclasses (registered via qmlRegisterType)
# ---------------------------------------------------------------------------

class StubEmbeddedDhuItem(QQuickItem):
    def __init__(self, parent=None):
        super().__init__(parent)


class StubEmbeddedScrcpyItem(QQuickItem):
    def __init__(self, parent=None):
        super().__init__(parent)


class StubScrcpyCaptureItem(QQuickItem):
    streamStarted = Signal()
    streamStopped = Signal()
    errorOccurred = Signal(str)
    frameRefresh = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

    @Property(int, notify=frameRefresh)
    def frameCounter(self):
        return 0

    @Property(int, notify=streamStarted)
    def frameWidth(self):
        return 0

    @Property(int, notify=streamStarted)
    def frameHeight(self):
        return 0

    @Property(bool, notify=streamStarted)
    def isStreaming(self):
        return False

    @Slot(QObject)
    def connectToManager(self, manager): pass
    @Slot()
    def detach(self): pass
    @Slot()
    def reattach(self): pass
