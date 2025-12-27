from PySide6.QtCore import QObject, Signal, Slot, Property
import os
import json
import platform
import subprocess
import threading
import time

# Check system type
SYSTEM = platform.system()  # 'Windows', 'Linux', or 'Darwin' for macOS

class EqualizerManager(QObject):
    """Manager class for system-wide equalizer functionality"""
    
    # Signals
    equalizerBandsChanged = Signal(list)
    presetChanged = Signal(str)
    equalizerStatusChanged = Signal(bool)
    available_presetsChanged = Signal()
    builtin_presetsChanged = Signal()
    
    def __init__(self, media_manager=None):
        super().__init__()
        
        # Store reference to media manager
        self._media_manager = media_manager
        
        # Equalizer settings
        self._backend_dir = os.path.dirname(os.path.abspath(__file__))
        self._presets_file = os.path.join(self._backend_dir, 'equalizer_presets.json')
        
        # Default equalizer bands (Hz): 32, 64, 125, 250, 500, 1K, 2K, 4K, 8K, 16K
        self._equalizer_frequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        self._equalizer_values = [0.0] * len(self._equalizer_frequencies)  # Default all to 0 dB
        
        # Define built-in equalizer presets
        self._built_in_presets = {
            "Flat": [0.0] * len(self._equalizer_frequencies),
            "Bass Boost": [6.0, 5.0, 4.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            "Treble Boost": [0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 3.0, 4.0, 5.0, 6.0],
            "Rock": [4.0, 3.0, -2.5, -4.0, -1.5, 1.0, 3.0, 4.5, 4.5, 1.0],
            "Pop": [5.0, 4.0, 1.0, 1.5, 2.0, 2.0, 3.0, 4.0, -1.0, -2.0],
            "Jazz": [3.0, 2.0, 1.0, 2.0, -2.0, -2.0, 0.0, 1.5, 3.0, 4.0],
            "Classical": [5.0, 4.0, 3.0, 2.0, -1.0, -1.0, 0.0, 3.0, 4.0, 4.5],
            "Electronic": [4.0, 3.5, 0.0, -2.0, -3.0, -2.0, 0.0, 2.0, 4.0, 5.0],
            "Vocal": [-2.0, -1.0, 0.0, 2.0, 4.0, 3.0, 2.0, 1.0, 0.0, -1.0]
        }
        
        # Load user presets from file
        self._user_presets = {}
        self._load_user_presets()
        
        # Combine built-in and user presets
        self._equalizer_presets = {**self._built_in_presets, **self._user_presets}
        
        # Current preset and status
        self._current_preset = "Flat"
        self._equalizer_active = False
        self._system_equalizer_available = False
        
        # Platform-specific settings
        self._setup_platform_specific()
        
        # Apply default preset
        self.apply_preset("Flat")
    
    # -------- Properties and Slots --------
    
    # Property getters
    def _get_equalizer_frequencies(self): return self._equalizer_frequencies
    def _get_equalizer_values(self): return self._equalizer_values
    def _get_available_presets(self): return list(self._equalizer_presets.keys())
    def _get_builtin_presets(self): return list(self._built_in_presets.keys())
    def _get_current_preset(self): return self._current_preset
    def _is_system_equalizer_available(self): return self._system_equalizer_available
    def _is_equalizer_active(self): return self._equalizer_active
    
    def _set_equalizer_active(self, active):
        if self._equalizer_active != active:
            self._equalizer_active = active
            
            if active:
                self._apply_system_equalizer()
            
            self.equalizerStatusChanged.emit(active)
            
    # Define the properties with notify signals for QML
    equalizer_frequencies = Property(list, _get_equalizer_frequencies, notify=equalizerBandsChanged)
    equalizer_values = Property(list, _get_equalizer_values, notify=equalizerBandsChanged)
    available_presets = Property(list, _get_available_presets, notify=available_presetsChanged)
    builtin_presets = Property(list, _get_builtin_presets, notify=builtin_presetsChanged)
    current_preset = Property(str, _get_current_preset, notify=presetChanged)
    system_equalizer_available = Property(bool, _is_system_equalizer_available, notify=equalizerStatusChanged)
    equalizer_active = Property(bool, _is_equalizer_active, _set_equalizer_active, notify=equalizerStatusChanged)
    
    # Slots for access from QML
    @Slot(result=list)
    def get_equalizer_frequencies(self): return self._equalizer_frequencies

    @Slot(result=list)
    def get_equalizer_values(self): return self._equalizer_values

    @Slot(result=list)
    def get_available_presets(self): return list(self._equalizer_presets.keys())

    @Slot(result=list)
    def get_builtin_presets(self): return list(self._built_in_presets.keys())

    @Slot(result=str)
    def get_current_preset(self): return self._current_preset

    @Slot(result=bool)
    def is_system_equalizer_available(self): return self._system_equalizer_available

    @Slot(result=bool)
    def is_equalizer_active(self): return self._equalizer_active

    @Slot(bool)
    def set_equalizer_active(self, active):
        self._set_equalizer_active(active)
        print(f"Equalizer active state set to: {active}")

    @Slot(int, float)
    def set_equalizer_band(self, band_index, value):
        """Set the value for a specific equalizer band"""
        if 0 <= band_index < len(self._equalizer_values):
            # Round to one decimal place
            value = round(value, 1)
            
            # Update the value
            self._equalizer_values[band_index] = value
            
            # Update current preset to "Custom" if not matching any preset
            if not self._is_matching_preset():
                self._current_preset = "Custom"
                self.presetChanged.emit("Custom")
            
            # Apply to system equalizer if active
            if self._equalizer_active:
                self._apply_system_equalizer()
            
            # Emit signal
            self.equalizerBandsChanged.emit(self._equalizer_values)
            print(f"Set equalizer band {band_index} ({self._equalizer_frequencies[band_index]} Hz) to {value} dB")

    @Slot(str, result=bool)
    def is_builtin_preset(self, preset_name):
        """Check if a preset is a built-in preset"""
        return preset_name in self._built_in_presets
    
    @Slot(str, list)
    def save_preset(self, preset_name, values=None):
        """Save current equalizer settings as a new preset"""
        if not preset_name or preset_name == "Custom":
            print("Error: Invalid preset name")
            return
        
        try:
            # Use provided values or current values
            preset_values = values if values is not None else self._equalizer_values.copy()
            
            # Save the preset to user presets
            self._user_presets[preset_name] = preset_values
            
            # Update combined presets
            self._equalizer_presets = {**self._built_in_presets, **self._user_presets}
            
            # Update current preset
            self._current_preset = preset_name
            
            # Save to file
            self._save_user_presets()
            
            # Save to platform-specific format if needed
            if SYSTEM == "Linux" and self._eq_command_path:
                safe_name = preset_name.replace(" ", "_").lower()
                self._create_easyeffects_preset(safe_name)
                
                # Apply if active
                if self._equalizer_active:
                    self._apply_system_equalizer()
            
            # Emit signals
            self.available_presetsChanged.emit()
            self.presetChanged.emit(preset_name)
            
            print(f"Saved preset: {preset_name}")
        except Exception as e:
            print(f"Error saving preset: {e}")
    
    @Slot(str)
    def delete_preset(self, preset_name):
        """Delete a user-defined preset"""
        if preset_name not in self._equalizer_presets:
            print(f"Error: Preset '{preset_name}' does not exist")
            return
            
        if preset_name in self._built_in_presets:
            print(f"Error: Cannot delete built-in preset '{preset_name}'")
            return
        
        try:
            # Delete the preset from user presets
            if preset_name in self._user_presets:
                del self._user_presets[preset_name]
                
                # Update combined presets
                self._equalizer_presets = {**self._built_in_presets, **self._user_presets}
                
                # Save to file
                self._save_user_presets()
                
                # Delete the EasyEffects preset file if on Linux
                if SYSTEM == "Linux" and self._eq_command_path:
                    safe_name = preset_name.replace(" ", "_").lower()
                    preset_path = os.path.join(self._easyeffects_preset_dir, f"{safe_name}.json")
                    if os.path.exists(preset_path):
                        os.remove(preset_path)
                
                # If current preset was deleted, reset to Flat
                if self._current_preset == preset_name:
                    self.apply_preset("Flat")
                
                # Emit signal for updated presets
                self.available_presetsChanged.emit()
                
                print(f"Deleted preset: {preset_name}")
        except Exception as e:
            print(f"Error deleting preset: {e}")
    
    @Slot()
    def open_system_equalizer(self):
        """Open the system equalizer application directly"""
        try:
            if SYSTEM == "Windows" and self._eq_command_path:
                program_files = os.environ.get('ProgramFiles', 'C:\\Program Files')
                eapo_configurator = os.path.join(program_files, 'EqualizerAPO', 'Configurator.exe')
                
                if os.path.exists(eapo_configurator):
                    subprocess.Popen([eapo_configurator], shell=True)
                else:
                    program_files_x86 = os.environ.get('ProgramFiles(x86)', 'C:\\Program Files (x86)')
                    eapo_configurator_x86 = os.path.join(program_files_x86, 'EqualizerAPO', 'Configurator.exe')
                    if os.path.exists(eapo_configurator_x86):
                        subprocess.Popen([eapo_configurator_x86], shell=True)
            
            elif SYSTEM == "Linux" and self._eq_command_path:
                self._launch_easyeffects_ui()
            
            elif SYSTEM == "Darwin" and self._eq_command_path:  # macOS
                subprocess.Popen(self._eq_command_path, shell=True)
        except Exception as e:
            print(f"Error opening system equalizer: {e}")

    @Slot(str)
    def apply_preset(self, preset_name):
        """Apply a saved equalizer preset"""
        if preset_name not in self._equalizer_presets:
            print(f"Error: Preset '{preset_name}' does not exist")
            return
        
        try:
            # Get preset values
            preset_values = self._equalizer_presets[preset_name]
            
            # Apply values
            self._equalizer_values = preset_values.copy()
            
            # Update current preset
            self._current_preset = preset_name
            
            # Apply to system equalizer if active
            if self._equalizer_active:
                self._apply_system_equalizer()
            
            # Emit signals
            self.equalizerBandsChanged.emit(self._equalizer_values)
            self.presetChanged.emit(preset_name)
            
        except Exception as e:
            print(f"Error applying preset: {e}")
    
    # -------- Helper Methods --------
    
    def _setup_platform_specific(self):
        """Set up platform-specific settings and paths"""
        try:
            self._eq_command_path = None
            self._config_files = []
            
            if SYSTEM == "Windows":
                # Check for Equalizer APO
                for program_files in [os.environ.get('ProgramFiles', 'C:\\Program Files'), 
                                      os.environ.get('ProgramFiles(x86)', 'C:\\Program Files (x86)')]:
                    eapo_path = os.path.join(program_files, 'EqualizerAPO')
                    if os.path.exists(eapo_path):
                        self._eq_command_path = os.path.join(eapo_path, 'config\\config.txt')
                        self._config_files.append(self._eq_command_path)
                        self._system_equalizer_available = True
                        break
                
            elif SYSTEM == "Linux":
                # Check for EasyEffects
                self._is_flatpak = False
                try:
                    # Check Flatpak first
                    if subprocess.call(['flatpak', 'info', 'com.github.wwmm.easyeffects'], 
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
                        self._eq_command_path = "flatpak run com.github.wwmm.easyeffects"
                        self._is_flatpak = True
                        self._easyeffects_preset_dir = os.path.expanduser("~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output")
                        self._system_equalizer_available = True
                    # Check native installation
                    elif subprocess.call(['which', 'easyeffects'], 
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
                        self._eq_command_path = "easyeffects"
                        self._easyeffects_preset_dir = os.path.expanduser("~/.config/easyeffects/output")
                        self._system_equalizer_available = True
                        
                    # Create preset directory if needed
                    if self._eq_command_path and not os.path.exists(self._easyeffects_preset_dir):
                        os.makedirs(self._easyeffects_preset_dir, exist_ok=True)
                except:
                    pass
                    
                # Check for D-Bus support
                try:
                    import dbus
                    self._dbus_available = True
                except ImportError:
                    self._dbus_available = False
                
            elif SYSTEM == "Darwin":  # macOS
                # Check for eqMac
                if os.path.exists("/Applications/eqMac.app"):
                    self._eq_command_path = "open -a eqMac"
                    self._system_equalizer_available = True
                # Check for AU Lab
                elif os.path.exists("/Applications/AU Lab.app"):
                    self._eq_command_path = "open -a 'AU Lab'"
                    self._system_equalizer_available = True
                    
        except Exception as e:
            print(f"Error setting up platform-specific settings: {e}")
            self._system_equalizer_available = False
    
    def _apply_system_equalizer(self):
        """Apply equalizer settings to system-wide equalizer"""
        if not self._equalizer_active:
            return
            
        try:
            if SYSTEM == "Windows":
                self._apply_windows_equalizer()
            elif SYSTEM == "Linux":
                self._apply_linux_equalizer_file_only()
            elif SYSTEM == "Darwin":  # macOS
                if self._eq_command_path:
                    subprocess.Popen(self._eq_command_path, shell=True)
        except Exception as e:
            print(f"Error applying system equalizer: {e}")
    
    def _apply_linux_equalizer_file_only(self):
        """Apply equalizer settings to EasyEffects on Linux using file-based approach"""
        if not self._eq_command_path:
            return
            
        try:
            # Create EasyEffects preset file with current preset name
            preset_name = self._current_preset.replace(" ", "_").lower()
            self._create_easyeffects_preset(preset_name)
            
            # Launch the EasyEffects UI
            self._launch_easyeffects_ui()
        except Exception as e:
            print(f"Error applying EasyEffects settings: {e}")
    
    def _create_easyeffects_preset(self, preset_name="octave_preset"):
        """Create EasyEffects preset file with current settings"""
        try:
            preset_path = os.path.join(self._easyeffects_preset_dir, f"{preset_name}.json")
            
            # Prepare preset data for EasyEffects
            preset_data = {
                "output": {
                    "blocklist": [],
                    "equalizer": {
                        "input-gain": 0.0,
                        "output-gain": 0.0,
                        "mode": "IIR",
                        "num-bands": len(self._equalizer_frequencies),
                        "split-channels": False,
                        "left": {},
                        "right": {}
                    },
                    "plugins_order": [
                        "equalizer"
                    ]
                }
            }
            
            # Add bands data - using a consistent Q value as seen in the example
            q_value = 1.504760237537245
            
            for i, freq in enumerate(self._equalizer_frequencies):
                band_data = {
                    "frequency": float(freq),
                    "gain": self._equalizer_values[i], 
                    "mode": "RLC (BT)",
                    "mute": False,
                    "q": q_value,
                    "slope": "x1",
                    "solo": False,
                    "type": "Bell"
                }
                
                # Add for both channels
                preset_data["output"]["equalizer"]["left"][f"band{i}"] = band_data.copy()
                preset_data["output"]["equalizer"]["right"][f"band{i}"] = band_data.copy()
            
            # Write the file
            with open(preset_path, 'w') as f:
                json.dump(preset_data, f, indent=2)
            
            print(f"Created EasyEffects preset: {preset_path}")
            return preset_path
        except Exception as e:
            print(f"Error creating EasyEffects preset: {e}")
            return None
    
    def _launch_easyeffects_ui(self):
        """Launch EasyEffects UI"""
        try:
            # Check if EasyEffects is already running
            ps_output = subprocess.check_output(['ps', 'aux'], text=True)
            
            if 'easyeffects' not in ps_output:
                # Start it if not running
                if self._is_flatpak:
                    subprocess.Popen(["flatpak", "run", "com.github.wwmm.easyeffects"])
                else:
                    subprocess.Popen(["easyeffects"])
        except Exception as e:
            print(f"Error launching EasyEffects: {e}")
    
    def _load_user_presets(self):
        """Load user-defined presets from file"""
        try:
            if os.path.exists(self._presets_file):
                with open(self._presets_file, 'r') as f:
                    self._user_presets = json.load(f)
        except Exception as e:
            print(f"Error loading user presets: {e}")
            self._user_presets = {}
            
    def _save_user_presets(self):
        """Save user-defined presets to file"""
        try:
            os.makedirs(os.path.dirname(self._presets_file), exist_ok=True)
            with open(self._presets_file, 'w') as f:
                json.dump(self._user_presets, f, indent=2)
        except Exception as e:
            print(f"Error saving user presets: {e}")
    
    def _apply_windows_equalizer(self):
        """Apply equalizer settings to Equalizer APO on Windows"""
        if not self._eq_command_path:
            return
            
        try:
            # Create configuration file
            with open(self._eq_command_path, 'w') as f:
                # Write header
                f.write(f"# Equalizer configuration generated by Octave\n")
                f.write(f"# Preset: {self._current_preset}\n")
                f.write(f"# Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                
                # Create GraphicEQ command
                f.write("GraphicEQ: ")
                
                # Add frequency points
                eq_points = [f"20 {self._equalizer_values[0]}"]
                for i, freq in enumerate(self._equalizer_frequencies):
                    eq_points.append(f"{freq} {self._equalizer_values[i]}")
                eq_points.append(f"20000 {self._equalizer_values[-1]}")
                
                f.write("; ".join(eq_points))
        except Exception as e:
            print(f"Error applying Windows equalizer: {e}")
            
    def _is_matching_preset(self):
        """Check if current values match any preset"""
        for preset_name, preset_values in self._equalizer_presets.items():
            if all(abs(a - b) < 0.1 for a, b in zip(self._equalizer_values, preset_values)):
                if preset_name != self._current_preset:
                    self._current_preset = preset_name
                    self.presetChanged.emit(preset_name)
                return True
        return False