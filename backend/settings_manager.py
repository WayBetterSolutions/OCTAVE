import json
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer
import os
import sys
import tempfile
from typing import List

# Platform-specific imports for file locking
if sys.platform == 'win32':
    import msvcrt
else:
    import fcntl


class SettingsManager(QObject):
    # Existing signals
    deviceNameChanged = Signal(str)
    themeSettingChanged = Signal(str)
    fontSettingChanged = Signal(str)
    startUpVolumeChanged = Signal(str)
    showClockChanged = Signal(bool)
    clockFormatChanged = Signal(bool)
    clockSizeChanged = Signal(int)
    backgroundGridChanged = Signal(str)
    screenWidthChanged = Signal(int)
    screenHeightChanged = Signal(int)
    backgroundBlurRadiusChanged = Signal(int)
    uiScaleChanged = Signal(float)
    obdBluetoothPortChanged = Signal(str)
    obdFastModeChanged = Signal(bool)
    obdParametersChanged = Signal()
    obdAutoReconnectAttemptsChanged = Signal(int)
    mediaFolderChanged = Signal(str)
    showBackgroundOverlayChanged = Signal(bool)
    directoryHistoryChanged = Signal()
    homeOBDParametersChanged = Signal()
    customThemesChanged = Signal()
    bottomBarOrientationChanged = Signal(str)
    showBottomBarMediaControlsChanged = Signal(bool)
    spotifyCredentialsChanged = Signal()
    mediaSourceChanged = Signal(str)  # "local" or "spotify"
    lastSettingsSectionChanged = Signal(str)
    currentVolumeChanged = Signal(int)  # Unified volume (0-100) for both local and Spotify
    autoPlayOnStartupChanged = Signal(bool)
    lastPlayedSongChanged = Signal(str)
    lastPlayedPositionChanged = Signal(int)
    lastPlayedPlaylistChanged = Signal(str)
    windowStateChanged = Signal(str)
    musicButtonDefaultPageChanged = Signal(str)
    returnToLibraryAfterSelectionChanged = Signal(bool)

    def __init__(self):
        super().__init__()
        self.backend_dir = os.path.dirname(os.path.abspath(__file__))
        self.settings_file = os.path.join(self.backend_dir, 'settingsConfigure.json')
        
        self._default_settings = {
            "deviceName": "Default Device",
            "themeSetting": "CosmicVoyager",
            "fontSetting": "Google Sans",
            "startUpVolume": 0.1,
            "showClock": True,
            "clockFormat24Hour": True,
            "clockSize": 18,
            "backgroundGrid": "4x4",
            "screenWidth": 1280,
            "screenHeight": 720,
            "backgroundBlurRadius": 40,
            "uiScale": 0.6,
            "obdBluetoothPort": "/dev/rfcomm0",
            "obdFastMode": True,
            "obdAutoReconnectAttempts": 0,  # 0 = disabled, 1-10 = number of attempts
            "showBackgroundOverlay": True,
            "bottomBarOrientation": "bottom",
            "showBottomBarMediaControls": True,
            "fuelTankCapacity": 15.0,  # Add fuel tank capacity setting in gallons
            "obdParameters": {
                "COOLANT_TEMP": True,
                "CONTROL_MODULE_VOLTAGE": True,
                "ENGINE_LOAD": True,
                "THROTTLE_POS": True,
                "INTAKE_TEMP": True,
                "TIMING_ADVANCE": True,
                "MAF": True,
                "SPEED": True,
                "RPM": True,
                "COMMANDED_EQUIV_RATIO": True,
                "FUEL_LEVEL": True,
                "INTAKE_PRESSURE": True,
                "SHORT_FUEL_TRIM_1": True,
                "LONG_FUEL_TRIM_1": True,
                "O2_B1S1": True,
                "FUEL_PRESSURE": True,
                "OIL_TEMP": True,
                "FUEL_ECONOMY": True,
                "DISTANCE_TO_EMPTY": True,
                "IGNITION_TIMING": True,
            },
            "homeOBDParameters": ["SPEED", "RPM", "COOLANT_TEMP", "CONTROL_MODULE_VOLTAGE"],
            "lastSettingsSection": "deviceSettings",
            "spotifyClientId": "",
            "spotifyClientSecret": "",
            "mediaSource": "local",
            "mediaFolder": "",
            "customThemes": {},
            "autoPlayOnStartup": False,
            "lastPlayedSong": "",
            "lastPlayedPosition": 0,
            "lastPlayedPlaylist": "",
            "windowState": "windowed",
            "musicButtonDefaultPage": "mediaRoom",  # "mediaRoom" or "mediaPlayer"
            "returnToLibraryAfterSelection": False,  # If True, return to MediaPlayer after song selection
        }
            
    
        
        self._default_settings["directoryHistory"] = []
            
        # Load settings at startup
        self._settings = self.load_settings()
        
        # Initialize directory history
        self._directory_history = self._settings.get("directoryHistory", [])
            
        # Load settings at startup
        self._settings = self.load_settings()
        
        # Initialize existing settings
        self._device_name = self._settings.get("deviceName", self._default_settings["deviceName"])
        self._theme_setting = self._settings.get("themeSetting", self._default_settings["themeSetting"])
        self._font_setting = self._settings.get("fontSetting", self._default_settings["fontSetting"])
        self._start_volume = self._settings.get("startUpVolume", self._default_settings["startUpVolume"])
        self._show_clock = self._settings.get("showClock", self._default_settings["showClock"])
        self._clock_format_24hour = self._settings.get("clockFormat24Hour", self._default_settings["clockFormat24Hour"])
        self._clock_size = self._settings.get("clockSize", self._default_settings["clockSize"])
        self._background_grid = self._settings.get("backgroundGrid", self._default_settings["backgroundGrid"])
        self._screen_width = self._settings.get("screenWidth", self._default_settings["screenWidth"])
        self._screen_height = self._settings.get("screenHeight", self._default_settings["screenHeight"])
        self._background_blur_radius = self._settings.get("backgroundBlurRadius", self._default_settings["backgroundBlurRadius"])
        self._ui_scale = self._settings.get("uiScale", self._default_settings["uiScale"])
        self._obd_bluetooth_port = self._settings.get("obdBluetoothPort", self._default_settings["obdBluetoothPort"])
        self._obd_fast_mode = self._settings.get("obdFastMode", self._default_settings["obdFastMode"])
        self._obd_auto_reconnect_attempts = self._settings.get("obdAutoReconnectAttempts", self._default_settings["obdAutoReconnectAttempts"])
        self._media_folder = self._settings.get("mediaFolder", os.path.join(self.backend_dir, 'media'))
        self._show_background_overlay = self._settings.get("showBackgroundOverlay", self._default_settings["showBackgroundOverlay"])
        self._fuel_tank_capacity = self._settings.get("fuelTankCapacity", self._default_settings["fuelTankCapacity"])
        self._home_obd_parameters = self._settings.get("homeOBDParameters", self._default_settings["homeOBDParameters"])
        self._bottom_bar_orientation = self._settings.get("bottomBarOrientation", self._default_settings["bottomBarOrientation"])
        self._show_bottom_bar_media_controls = self._settings.get("showBottomBarMediaControls", self._default_settings["showBottomBarMediaControls"])

        # Spotify credentials (stored separately for security)
        self._spotify_client_id = self._settings.get("spotifyClientId", "")
        self._spotify_client_secret = self._settings.get("spotifyClientSecret", "")

        # Media source preference: "local" or "spotify"
        self._media_source = self._settings.get("mediaSource", "local")

        # Auto-play and resume settings
        self._auto_play_on_startup = self._settings.get("autoPlayOnStartup", False)
        self._last_played_song = self._settings.get("lastPlayedSong", "")
        self._last_played_position = self._settings.get("lastPlayedPosition", 0)
        self._last_played_playlist = self._settings.get("lastPlayedPlaylist", "")

        # Window state: "windowed", "fullscreen", or "maximized"
        self._window_state = self._settings.get("windowState", "windowed")

        # Music button navigation settings
        self._music_button_default_page = self._settings.get("musicButtonDefaultPage", "mediaRoom")
        self._return_to_library_after_selection = self._settings.get("returnToLibraryAfterSelection", False)

        # Current volume (0-100) - unified volume for both local and Spotify
        # Initialize from startUpVolume, converted to 0-100 scale
        self._current_volume = int(round((self._start_volume ** 0.5) * 100))

        # Last settings section visited
        self._last_settings_section = self._settings.get("lastSettingsSection", self._default_settings["lastSettingsSection"])

        # Handle OBD parameters with a default if not present
        if "obdParameters" in self._settings:
            self._obd_parameters = self._settings["obdParameters"]

            # Add any missing parameters from defaults
            for param, value in self._default_settings["obdParameters"].items():
                if param not in self._obd_parameters:
                    self._obd_parameters[param] = value
        else:
            self._obd_parameters = self._default_settings["obdParameters"]

        settings = self.load_settings()
        settings["obdParameters"] = self._obd_parameters
        self.save_settings(settings)

        # Debounce timer for OBD parameter changes - batches rapid toggles
        self._obd_params_dirty = False
        self._obd_params_save_timer = QTimer()
        self._obd_params_save_timer.setSingleShot(True)
        self._obd_params_save_timer.setInterval(800)  # 800ms debounce
        self._obd_params_save_timer.timeout.connect(self._flush_obd_parameters)
            
    def _lock_file(self, f, exclusive=True):
        """Acquire a lock on the file (cross-platform)"""
        if sys.platform == 'win32':
            # Windows file locking
            if exclusive:
                msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                msvcrt.locking(f.fileno(), msvcrt.LK_NBRLCK, 1)
        else:
            # Unix file locking
            if exclusive:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            else:
                fcntl.flock(f.fileno(), fcntl.LOCK_SH | fcntl.LOCK_NB)

    def _unlock_file(self, f):
        """Release the lock on the file (cross-platform)"""
        if sys.platform == 'win32':
            try:
                msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
            except Exception:
                pass
        else:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    def _set_file_permissions(self, filepath):
        """Set restrictive file permissions (owner read/write only)"""
        if sys.platform != 'win32':
            # Unix: chmod 600
            os.chmod(filepath, 0o600)
        # Windows: permissions are handled differently via ACLs
        # The file is already protected by user account on Windows

    def _validate_settings(self, settings):
        """Validate settings structure and types, return sanitized settings"""
        if not isinstance(settings, dict):
            return self._default_settings.copy()

        validated = self._default_settings.copy()

        # Type validation for each setting
        type_checks = {
            "deviceName": str,
            "themeSetting": str,
            "fontSetting": str,
            "startUpVolume": (int, float),
            "showClock": bool,
            "clockFormat24Hour": bool,
            "clockSize": int,
            "backgroundGrid": str,
            "screenWidth": int,
            "screenHeight": int,
            "backgroundBlurRadius": int,
            "uiScale": (int, float),
            "obdBluetoothPort": str,
            "obdFastMode": bool,
            "obdAutoReconnectAttempts": int,
            "showBackgroundOverlay": bool,
            "bottomBarOrientation": str,
            "showBottomBarMediaControls": bool,
            "fuelTankCapacity": (int, float),
            "obdParameters": dict,
            "homeOBDParameters": list,
            "lastSettingsSection": str,
            "spotifyClientId": str,
            "spotifyClientSecret": str,
            "mediaSource": str,
            "mediaFolder": str,
            "customThemes": dict,
            "directoryHistory": list,
            "autoPlayOnStartup": bool,
            "lastPlayedSong": str,
            "lastPlayedPosition": int,
            "lastPlayedPlaylist": str,
            "windowState": str,
            "musicButtonDefaultPage": str,
            "returnToLibraryAfterSelection": bool,
        }

        for key, expected_type in type_checks.items():
            if key in settings:
                if isinstance(settings[key], expected_type):
                    validated[key] = settings[key]
                # else: keep default value

        # Copy any extra keys not in type_checks (for forward compatibility)
        for key in settings:
            if key not in type_checks and key not in validated:
                validated[key] = settings[key]

        return validated

    def load_settings(self):
        try:
            with open(self.settings_file, 'r') as f:
                try:
                    self._lock_file(f, exclusive=False)
                    settings = json.load(f)
                    return self._validate_settings(settings)
                except (BlockingIOError, OSError):
                    # Could not acquire lock, read anyway but log warning
                    print("Warning: Could not acquire file lock for reading settings")
                    f.seek(0)
                    settings = json.load(f)
                    return self._validate_settings(settings)
                finally:
                    try:
                        self._unlock_file(f)
                    except Exception:
                        pass
        except FileNotFoundError:
            self.save_settings(self._default_settings)
            return self._default_settings.copy()
        except json.JSONDecodeError as e:
            print(f"Error: Settings file corrupted ({e}), using defaults")
            return self._default_settings.copy()

    def save_settings(self, settings):
        """Save settings atomically with file locking"""
        # Validate before saving
        validated_settings = self._validate_settings(settings)

        # Write to temp file first, then rename (atomic on most systems)
        dir_name = os.path.dirname(self.settings_file)
        try:
            # Create temp file in same directory for atomic rename
            fd, temp_path = tempfile.mkstemp(dir=dir_name, suffix='.json')
            try:
                with os.fdopen(fd, 'w') as f:
                    try:
                        self._lock_file(f, exclusive=True)
                    except (BlockingIOError, OSError):
                        print("Warning: Could not acquire file lock for writing settings")
                    json.dump(validated_settings, f, indent=4)

                # Set permissions before rename
                self._set_file_permissions(temp_path)

                # Atomic rename (on Unix) or replace (on Windows)
                if sys.platform == 'win32':
                    # Windows doesn't support atomic rename over existing file
                    if os.path.exists(self.settings_file):
                        os.remove(self.settings_file)
                os.rename(temp_path, self.settings_file)

            except Exception as e:
                # Clean up temp file on error
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                raise e

        except Exception as e:
            print(f"Error saving settings: {e}")
            # Fallback to direct write if atomic fails
            with open(self.settings_file, 'w') as f:
                json.dump(validated_settings, f, indent=4)
            self._set_file_permissions(self.settings_file)

    def update_setting(self, key, value, signal=None):
        settings = self.load_settings()
        settings[key] = value
        self.save_settings(settings)
        if signal:
            signal.emit(value)

    @Property(float, notify=uiScaleChanged)
    def uiScale(self):
        return self._ui_scale
    
    @Property(str, notify=bottomBarOrientationChanged)
    def bottomBarOrientation(self):
        return self._bottom_bar_orientation

    @Property(bool, notify=showBottomBarMediaControlsChanged)
    def showBottomBarMediaControls(self):
        return self._show_bottom_bar_media_controls

    @Property(int, notify=backgroundBlurRadiusChanged)
    def backgroundBlurRadius(self):
        return self._background_blur_radius
    
    @Property(str, notify=deviceNameChanged)
    def deviceName(self):
        return self._device_name
    
    @Property(str, notify=themeSettingChanged)
    def themeSetting(self):
        return self._theme_setting

    @Property(str, notify=fontSettingChanged)
    def fontSetting(self):
        return self._font_setting

    @Property(float, notify=startUpVolumeChanged)
    def startUpVolume(self):
        return self._start_volume

    @Property(int, notify=currentVolumeChanged)
    def currentVolume(self):
        return self._current_volume

    @Slot(int)
    def setCurrentVolume(self, volume):
        """Set the unified volume (0-100) for both local and Spotify"""
        if self._current_volume != volume:
            self._current_volume = volume
            self.currentVolumeChanged.emit(volume)

    @Property(bool, notify=showClockChanged)
    def showClock(self):
        return self._show_clock
    
    @Property(bool, notify=clockFormatChanged)
    def clockFormat24Hour(self):
        return self._clock_format_24hour
    
    @Property(int, notify=clockSizeChanged)
    def clockSize(self):
        return self._clock_size
    
    @Property(str, notify=backgroundGridChanged)
    def backgroundGrid(self):
        return self._background_grid
    
    @Property(int, notify=screenWidthChanged)
    def screenWidth(self):
        return self._screen_width

    @Property(int, notify=screenHeightChanged)
    def screenHeight(self):
        return self._screen_height
    
    @Property(str, notify=obdBluetoothPortChanged)
    def obdBluetoothPort(self):
        return self._obd_bluetooth_port
    
    @Property(bool, notify=obdFastModeChanged)
    def obdFastMode(self):
        return self._obd_fast_mode

    @Property(int, notify=obdAutoReconnectAttemptsChanged)
    def obdAutoReconnectAttempts(self):
        return self._obd_auto_reconnect_attempts

    @Property(str, notify=mediaFolderChanged)
    def mediaFolder(self):
        return self._media_folder
    
    @Property(bool, notify=showBackgroundOverlayChanged)
    def showBackgroundOverlay(self):
        return self._show_background_overlay
    
    @Property('QVariantList', notify=directoryHistoryChanged)
    def directoryHistory(self):
        return self._directory_history
    
    @Property('QVariantList', notify=homeOBDParametersChanged)
    def homeOBDParameters(self):
        return self._home_obd_parameters
    
    @Property('QVariantList', notify=customThemesChanged)
    def customThemes(self):
        """Return list of custom theme names"""
        settings = self.load_settings()
        if "customThemes" in settings:
            return list(settings["customThemes"].keys())
        return []

    # Existing save methods
    @Slot(float)
    def save_ui_scale(self, scale):
        print(f"Saving UI scale: {scale}")
        self._ui_scale = scale
        self.update_setting("uiScale", scale, self.uiScaleChanged)
    
    @Slot(int)
    def save_background_blur_radius(self, radius):
        print(f"Saving background blur radius: {radius}")
        self._background_blur_radius = radius
        self.update_setting("backgroundBlurRadius", radius, self.backgroundBlurRadiusChanged)
    
    @Slot(str)
    def save_device_name(self, name):
        print(f"Saving device name: {name}")
        self._device_name = name
        self.update_setting("deviceName", name, self.deviceNameChanged)
        
    @Slot(str)
    def save_theme_setting(self, theme):
        print(f"Saving theme setting: {theme}")
        self._theme_setting = theme
        self.update_setting("themeSetting", theme, self.themeSettingChanged)

    @Slot(str)
    def save_font_setting(self, font):
        print(f"Saving font setting: {font}")
        self._font_setting = font
        self.update_setting("fontSetting", font, self.fontSettingChanged)
        
    @Slot(float)
    def save_start_volume(self, volume):
        print(f"Saving volume setting: {volume}")
        self._start_volume = volume
        self.update_setting("startUpVolume", volume, self.startUpVolumeChanged)
        
    @Slot(bool)
    def save_show_clock(self, show):
        print(f"Saving show clock setting: {show}")
        self._show_clock = show
        self.update_setting("showClock", show, self.showClockChanged)

    @Slot(bool)
    def save_clock_format(self, is_24hour):
        print(f"Saving clock format setting: {is_24hour}")
        self._clock_format_24hour = is_24hour
        self.update_setting("clockFormat24Hour", is_24hour, self.clockFormatChanged)

    @Slot(int)
    def save_clock_size(self, size):
        print(f"Saving clock size setting: {size}")
        self._clock_size = size
        self.update_setting("clockSize", size, self.clockSizeChanged)
        
    @Slot(str)
    def save_background_grid(self, grid_setting):
        print(f"Saving background grid setting: {grid_setting}")
        self._background_grid = grid_setting
        self.update_setting("backgroundGrid", grid_setting, self.backgroundGridChanged)
        
        
    @Slot(int)
    def save_screen_width(self, width):
        self._screen_width = width
        self.update_setting("screenWidth", width, self.screenWidthChanged)
        
    @Slot(int)
    def save_screen_height(self, height):
        self._screen_height = height
        self.update_setting("screenHeight", height, self.screenHeightChanged)
    
    # New OBD save methods
    @Slot(str)
    def save_obd_bluetooth_port(self, port):
        print(f"Saving OBD Bluetooth port: {port}")
        self._obd_bluetooth_port = port
        self.update_setting("obdBluetoothPort", port, self.obdBluetoothPortChanged)
    
    @Slot(bool)
    def save_obd_fast_mode(self, enabled):
        print(f"Saving OBD fast mode: {enabled}")
        self._obd_fast_mode = enabled
        self.update_setting("obdFastMode", enabled, self.obdFastModeChanged)

    @Slot(int)
    def save_obd_auto_reconnect_attempts(self, attempts):
        """Save OBD auto-reconnect attempts (0 = disabled, 1-10 = number of attempts)"""
        print(f"Saving OBD auto-reconnect attempts: {attempts}")
        self._obd_auto_reconnect_attempts = max(0, min(10, attempts))  # Clamp to 0-10
        self.update_setting("obdAutoReconnectAttempts", self._obd_auto_reconnect_attempts, self.obdAutoReconnectAttemptsChanged)

    @Slot(str, bool)
    def save_obd_parameter_enabled(self, parameter, enabled):
        """Save OBD parameter with debouncing to prevent lag from rapid toggles"""
        # Update internal state immediately (for responsive UI)
        self._obd_parameters[parameter] = enabled

        # Mark as dirty and restart debounce timer
        self._obd_params_dirty = True
        self._obd_params_save_timer.start()

    def _flush_obd_parameters(self):
        """Actually save OBD parameters to disk and emit signal (called after debounce)"""
        if not self._obd_params_dirty:
            return

        print("Flushing OBD parameter changes to disk")

        # Load current settings
        settings = self.load_settings()

        # Make sure obdParameters exists
        if "obdParameters" not in settings:
            settings["obdParameters"] = {}

        # Update all parameters
        settings["obdParameters"] = self._obd_parameters.copy()

        # Save to disk
        self.save_settings(settings)

        # Clear dirty flag
        self._obd_params_dirty = False

        # Emit signal once for all batched changes
        self.obdParametersChanged.emit()
        
    @Slot(str, bool, result=bool)
    def get_obd_parameter_enabled(self, parameter, default=True):
        """Get OBD parameter enabled state from memory (no disk I/O)"""
        if parameter in self._obd_parameters:
            return self._obd_parameters[parameter]

        # Parameter not in memory, use default and cache it
        self._obd_parameters[parameter] = default
        return default

    @Slot(str)
    def save_media_folder(self, folder_path):
        print(f"Saving media folder path: {folder_path}")
        self._media_folder = folder_path
        self.update_setting("mediaFolder", folder_path, self.mediaFolderChanged)
        
    @Slot(bool)
    def save_show_background_overlay(self, show):
        print(f"Saving show background overlay setting: {show}")
        self._show_background_overlay = show
        self.update_setting("showBackgroundOverlay", show, self.showBackgroundOverlayChanged)
        
    # Add new signal for fuel tank capacity
    fuelTankCapacityChanged = Signal(float)

    # Add property for fuel tank capacity
    @Property(float, notify=fuelTankCapacityChanged)
    def fuelTankCapacity(self):
        return self._fuel_tank_capacity

    # Add a method to save fuel tank capacity
    @Slot(float)
    def save_fuel_tank_capacity(self, capacity):
        print(f"Saving fuel tank capacity: {capacity}")
        self._fuel_tank_capacity = capacity
        self.update_setting("fuelTankCapacity", capacity, self.fuelTankCapacityChanged)
        
    @Slot(str)
    def save_to_directory_history(self, folder_path):
        print(f"Adding directory to history: {folder_path}")
        # Don't add duplicates
        if folder_path not in self._directory_history:
            # Add to the beginning of the list
            self._directory_history.insert(0, folder_path)
            
            # Limit the number of saved directories to 10
            if len(self._directory_history) > 10:
                self._directory_history = self._directory_history[:10]
                
            # Save to settings
            settings = self.load_settings()
            settings["directoryHistory"] = self._directory_history
            self.save_settings(settings)
            
            # Emit signal
            self.directoryHistoryChanged.emit()

    @Slot(str)
    def remove_from_directory_history(self, folder_path):
        print(f"Removing directory from history: {folder_path}")
        if folder_path in self._directory_history:
            self._directory_history.remove(folder_path)
            
            # Save to settings
            settings = self.load_settings()
            settings["directoryHistory"] = self._directory_history
            self.save_settings(settings)
            
            # Emit signal
            self.directoryHistoryChanged.emit()

    @Slot(result='QVariantList')
    def get_directory_history(self):
        return self._directory_history
    
    @Slot('QVariantList')
    def save_home_obd_parameters(self, parameters):
        """Save the list of OBD parameters to display on home screen"""
        print(f"Saving home OBD parameters: {parameters}")
        self._home_obd_parameters = list(parameters)  # Make a copy

        # Update the settings file
        settings = self.load_settings()
        settings["homeOBDParameters"] = list(parameters)
        self.save_settings(settings)

        # Emit signal to notify UI
        self.homeOBDParametersChanged.emit()
        
    @Slot(str)
    def save_bottom_bar_orientation(self, orientation):
        print(f"Saving bottom bar orientation: {orientation}")
        self._bottom_bar_orientation = orientation
        self.update_setting("bottomBarOrientation", orientation, self.bottomBarOrientationChanged)

    @Slot(bool)
    def save_show_bottom_bar_media_controls(self, show):
        print(f"Saving show bottom bar media controls: {show}")
        self._show_bottom_bar_media_controls = show
        self.update_setting("showBottomBarMediaControls", show, self.showBottomBarMediaControlsChanged)

    @Slot(result='QVariantList')
    def get_home_obd_parameters(self):
        """Return the list of OBD parameters to display on home screen"""
        return self._home_obd_parameters
    
    @Slot(str, result=str)
    def get_custom_theme(self, name):
        """Get a custom theme by name as JSON string"""
        settings = self.load_settings()
        if "customThemes" in settings and name in settings["customThemes"]:
            return json.dumps(settings["customThemes"][name])
        return "{}"

    # ==================== Spotify Credentials ====================

    @Slot(result=str)
    def get_spotify_client_id(self):
        """Get Spotify client ID"""
        return self._spotify_client_id

    @Slot(result=str)
    def get_spotify_client_secret(self):
        """Get Spotify client secret"""
        return self._spotify_client_secret

    @Slot(result=bool)
    def has_spotify_credentials(self):
        """Check if Spotify credentials are configured"""
        return bool(self._spotify_client_id and self._spotify_client_secret)

    @Slot(str, str)
    def save_spotify_credentials(self, client_id, client_secret):
        """Save Spotify API credentials"""
        print(f"Saving Spotify credentials")
        self._spotify_client_id = client_id
        self._spotify_client_secret = client_secret

        settings = self.load_settings()
        settings["spotifyClientId"] = client_id
        settings["spotifyClientSecret"] = client_secret
        self.save_settings(settings)

        self.spotifyCredentialsChanged.emit()

    @Slot()
    def clear_spotify_credentials(self):
        """Clear saved Spotify credentials"""
        self._spotify_client_id = ""
        self._spotify_client_secret = ""

        settings = self.load_settings()
        settings["spotifyClientId"] = ""
        settings["spotifyClientSecret"] = ""
        self.save_settings(settings)

        self.spotifyCredentialsChanged.emit()

    # ==================== Media Source ====================

    @Property(str, notify=mediaSourceChanged)
    def mediaSource(self):
        """Get current media source preference: 'local' or 'spotify'"""
        return self._media_source

    @Slot(result=str)
    def get_media_source(self):
        """Get current media source preference"""
        return self._media_source

    @Slot(str)
    def set_media_source(self, source):
        """Set media source preference: 'local' or 'spotify'"""
        if source not in ("local", "spotify"):
            return

        if source != self._media_source:
            self._media_source = source
            settings = self.load_settings()
            settings["mediaSource"] = source
            self.save_settings(settings)
            self.mediaSourceChanged.emit(source)

    @Slot()
    def toggle_media_source(self):
        """Toggle between local and spotify"""
        new_source = "spotify" if self._media_source == "local" else "local"
        self.set_media_source(new_source)

    # ==================== Auto Play & Resume Settings ====================

    @Property(bool, notify=autoPlayOnStartupChanged)
    def autoPlayOnStartup(self):
        """Get auto-play on startup setting"""
        return self._auto_play_on_startup

    @Slot(result=bool)
    def get_auto_play_on_startup(self):
        """Get auto-play on startup setting"""
        return self._auto_play_on_startup

    @Slot(bool)
    def save_auto_play_on_startup(self, enabled):
        """Save auto-play on startup setting"""
        print(f"Saving auto-play on startup: {enabled}")
        self._auto_play_on_startup = enabled
        self.update_setting("autoPlayOnStartup", enabled, self.autoPlayOnStartupChanged)

    @Property(str, notify=lastPlayedSongChanged)
    def lastPlayedSong(self):
        """Get last played song filename"""
        return self._last_played_song

    @Slot(result=str)
    def get_last_played_song(self):
        """Get last played song filename"""
        return self._last_played_song

    @Slot(str)
    def save_last_played_song(self, filename):
        """Save last played song filename"""
        self._last_played_song = filename
        self.update_setting("lastPlayedSong", filename, self.lastPlayedSongChanged)

    @Property(int, notify=lastPlayedPositionChanged)
    def lastPlayedPosition(self):
        """Get last played position in milliseconds"""
        return self._last_played_position

    @Slot(result=int)
    def get_last_played_position(self):
        """Get last played position in milliseconds"""
        return self._last_played_position

    @Slot(int)
    def save_last_played_position(self, position_ms):
        """Save last played position in milliseconds"""
        self._last_played_position = position_ms
        self.update_setting("lastPlayedPosition", position_ms, self.lastPlayedPositionChanged)

    @Property(str, notify=lastPlayedPlaylistChanged)
    def lastPlayedPlaylist(self):
        """Get last played playlist name"""
        return self._last_played_playlist

    @Slot(result=str)
    def get_last_played_playlist(self):
        """Get last played playlist name"""
        return self._last_played_playlist

    @Slot(str)
    def save_last_played_playlist(self, playlist_name):
        """Save last played playlist name"""
        self._last_played_playlist = playlist_name
        self.update_setting("lastPlayedPlaylist", playlist_name, self.lastPlayedPlaylistChanged)

    @Slot(str, int, str)
    def save_playback_state(self, song, position_ms, playlist):
        """Save all playback state at once (used when pausing/stopping)"""
        self._last_played_song = song
        self._last_played_position = position_ms
        self._last_played_playlist = playlist

        settings = self.load_settings()
        settings["lastPlayedSong"] = song
        settings["lastPlayedPosition"] = position_ms
        settings["lastPlayedPlaylist"] = playlist
        self.save_settings(settings)

    # ==================== Last Settings Section ====================

    @Property(str, notify=lastSettingsSectionChanged)
    def lastSettingsSection(self):
        """Get last visited settings section"""
        return self._last_settings_section

    @Slot(result=str)
    def get_last_settings_section(self):
        """Get last visited settings section"""
        return self._last_settings_section

    @Slot(str)
    def set_last_settings_section(self, section):
        """Set last visited settings section"""
        valid_sections = ["deviceSettings", "mediaSettings", "displaySettings", "obdSettings", "clockSettings", "about"]
        if section not in valid_sections:
            return

        if section != self._last_settings_section:
            self._last_settings_section = section
            settings = self.load_settings()
            settings["lastSettingsSection"] = section
            self.save_settings(settings)
            self.lastSettingsSectionChanged.emit(section)

    # ==================== Window State ====================

    @Property(str, notify=windowStateChanged)
    def windowState(self):
        """Get window state: 'windowed', 'fullscreen', or 'maximized'"""
        return self._window_state

    @Slot(result=str)
    def get_window_state(self):
        """Get window state"""
        return self._window_state

    @Slot(str)
    def save_window_state(self, state):
        """Save window state: 'windowed', 'fullscreen', or 'maximized'"""
        valid_states = ["windowed", "fullscreen", "maximized"]
        if state not in valid_states:
            return

        self._window_state = state
        self.update_setting("windowState", state, self.windowStateChanged)

    # ==================== Music Button Navigation Settings ====================

    @Property(str, notify=musicButtonDefaultPageChanged)
    def musicButtonDefaultPage(self):
        """Get music button default page: 'mediaRoom' or 'mediaPlayer'"""
        return self._music_button_default_page

    @Slot(result=str)
    def get_music_button_default_page(self):
        """Get music button default page"""
        return self._music_button_default_page

    @Slot(str)
    def save_music_button_default_page(self, page):
        """Save music button default page: 'mediaRoom' or 'mediaPlayer'"""
        valid_pages = ["mediaRoom", "mediaPlayer"]
        if page not in valid_pages:
            return

        print(f"Saving music button default page: {page}")
        self._music_button_default_page = page
        self.update_setting("musicButtonDefaultPage", page, self.musicButtonDefaultPageChanged)

    @Property(bool, notify=returnToLibraryAfterSelectionChanged)
    def returnToLibraryAfterSelection(self):
        """Get whether to return to library after song selection"""
        return self._return_to_library_after_selection

    @Slot(result=bool)
    def get_return_to_library_after_selection(self):
        """Get whether to return to library after song selection"""
        return self._return_to_library_after_selection

    @Slot(bool)
    def save_return_to_library_after_selection(self, return_to_library):
        """Save whether to return to library after song selection"""
        print(f"Saving return to library after selection: {return_to_library}")
        self._return_to_library_after_selection = return_to_library
        self.update_setting("returnToLibraryAfterSelection", return_to_library, self.returnToLibraryAfterSelectionChanged)

    @Slot()
    def reset_to_defaults(self):
        # Save default settings
        self.save_settings(self._default_settings)
        
        # Reset existing settings
        self._device_name = self._default_settings["deviceName"]
        self.deviceNameChanged.emit(self._device_name)
        
        self._theme_setting = self._default_settings["themeSetting"]
        self.themeSettingChanged.emit(self._theme_setting)

        self._font_setting = self._default_settings["fontSetting"]
        self.fontSettingChanged.emit(self._font_setting)

        self._start_volume = self._default_settings["startUpVolume"]
        self.startUpVolumeChanged.emit(self._start_volume)
        
        self._show_clock = self._default_settings["showClock"]
        self.showClockChanged.emit(self._show_clock)
        
        self._clock_format_24hour = self._default_settings["clockFormat24Hour"]
        self.clockFormatChanged.emit(self._clock_format_24hour)
        
        self._clock_size = self._default_settings["clockSize"]
        self.clockSizeChanged.emit(self._clock_size)
        
        self._background_grid = self._default_settings["backgroundGrid"]
        self.backgroundGridChanged.emit(self._background_grid)
                
        self._screen_width = self._default_settings["screenWidth"]
        self.screenWidthChanged.emit(self._screen_width)
        
        self._screen_height = self._default_settings["screenHeight"]
        self.screenHeightChanged.emit(self._screen_height)
        
        self._background_blur_radius = self._default_settings["backgroundBlurRadius"]
        self.backgroundBlurRadiusChanged.emit(self._background_blur_radius)
        
        self._ui_scale = self._default_settings["uiScale"]
        self.uiScaleChanged.emit(self._ui_scale)
        
        self._obd_bluetooth_port = self._default_settings["obdBluetoothPort"]
        self.obdBluetoothPortChanged.emit(self._obd_bluetooth_port)
        
        self._obd_fast_mode = self._default_settings["obdFastMode"]
        self.obdFastModeChanged.emit(self._obd_fast_mode)

        self._obd_auto_reconnect_attempts = self._default_settings["obdAutoReconnectAttempts"]
        self.obdAutoReconnectAttemptsChanged.emit(self._obd_auto_reconnect_attempts)

        self._obd_parameters = self._default_settings["obdParameters"]
        self.obdParametersChanged.emit()
        
        self._media_folder = self._default_settings["mediaFolder"]
        self.mediaFolderChanged.emit(self._media_folder)

        self._show_background_overlay = self._default_settings["showBackgroundOverlay"]
        self.showBackgroundOverlayChanged.emit(self._show_background_overlay)
        
        self._fuel_tank_capacity = self._default_settings["fuelTankCapacity"]
        self.fuelTankCapacityChanged.emit(self._fuel_tank_capacity)
            
        self._bottom_bar_orientation = self._default_settings["bottomBarOrientation"]
        self.bottomBarOrientationChanged.emit(self._bottom_bar_orientation)

        self._show_bottom_bar_media_controls = self._default_settings["showBottomBarMediaControls"]
        self.showBottomBarMediaControlsChanged.emit(self._show_bottom_bar_media_controls)

        self._auto_play_on_startup = self._default_settings["autoPlayOnStartup"]
        self.autoPlayOnStartupChanged.emit(self._auto_play_on_startup)

        self._last_played_song = self._default_settings["lastPlayedSong"]
        self.lastPlayedSongChanged.emit(self._last_played_song)

        self._last_played_position = self._default_settings["lastPlayedPosition"]
        self.lastPlayedPositionChanged.emit(self._last_played_position)

        self._last_played_playlist = self._default_settings["lastPlayedPlaylist"]
        self.lastPlayedPlaylistChanged.emit(self._last_played_playlist)

        self._music_button_default_page = self._default_settings["musicButtonDefaultPage"]
        self.musicButtonDefaultPageChanged.emit(self._music_button_default_page)

        self._return_to_library_after_selection = self._default_settings["returnToLibraryAfterSelection"]
        self.returnToLibraryAfterSelectionChanged.emit(self._return_to_library_after_selection)