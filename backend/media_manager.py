from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
from PySide6.QtCore import QUrl
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB
import os
import random
import re

class MediaManager(QObject):
    playbackStateChanged = Signal(int)
    playStateChanged = Signal(bool)
    currentMediaChanged = Signal(str)
    mediaListChanged = Signal(list)
    muteChanged = Signal(bool)
    durationChanged = Signal(int)
    positionChanged = Signal(int)
    metadataChanged = Signal(str, str, str)
    durationFormatChanged = Signal(str)
    volumeChanged = Signal(float)
    shuffleStateChanged = Signal(bool)
    totalDurationChanged = Signal(str)  # Formatted duration string
    albumCountChanged = Signal(int)     # Number of unique albums
    artistCountChanged = Signal(int)    # Number of unique artists
    playlistsChanged = Signal()         # When playlist list updates
    currentPlaylistChanged = Signal(str)  # When active playlist changes
    
    
    def __init__(self):
        super().__init__()
        self._player = QMediaPlayer()
        self._audio_output = QAudioOutput()
        self._player.setAudioOutput(self._audio_output)
        
        # Set default volume
        self._audio_output.setVolume(0.5)
        
        # Set up media directory
        self.backend_dir = os.path.dirname(os.path.abspath(__file__))
        self.default_media_dir = os.path.join(self.backend_dir, 'media')
        self.media_dir = self.default_media_dir
        self.temp_dir = os.path.join(self.backend_dir, 'temp')
        
        # Media player configuration
        self._player.setProperty("probe-size", 10000000)  # 10MB
        self._player.setProperty("analyzeduration", 5000000)  # 5 seconds
        
        # Playback state
        self._current_index = 0
        self._is_muted = False
        self._previous_volume = 0.5
        self._is_playing = False
        self._is_paused = True
        self._shuffle = False
        self._auto_play = False  # Set to False to prevent auto-play
        
        # Playlist management
        self._original_files = []
        self._current_playlist = []
        
        # Caching
        self._album_art_cache = {}  # Album ID to filename mapping
        self._metadata_cache = {}  # Filename to metadata mapping
        self._max_cache_files = 500  # Maximum number of cached files
        self._metadata_cache_max = 1000  # Maximum metadata cache entries
        self._access_count = {}  # Track album art access for LRU caching
        
        # Statistics cache
        self._stats_cache = {
            "total_duration_ms": 0,
            "total_duration_formatted": "0:00:00",
            "album_count": 0,
            "artist_count": 0,
            "is_valid": False
        }

        # Playlist management
        self._library_root = ""                   # Main source folder
        self._playlists = {}                      # Dict: name -> {path, files, song_count}
        self._playlist_names = []                 # List of playlist names
        self._current_playlist_name = ""          # Active playlist
        
        # Connect signals
        self._player.durationChanged.connect(self.durationChanged.emit)
        self._player.positionChanged.connect(self.positionChanged.emit)
        self._player.mediaStatusChanged.connect(self._handle_media_status)
        
        # Initialize position timer
        self._position_timer = QTimer()
        self._position_timer.setInterval(100)  # Update every 100ms
        self._position_timer.timeout.connect(self._update_position)
        self._position_timer.start()
        
        # Create media and temp directories if they don't exist
        self._ensure_directories()
        
        # Clear temp files on startup
        self._clear_temp_files()
        
        self._settings_manager = None

    def __del__(self):
        """Clean up resources on destruction"""
        try:
            # Save playback state before shutdown
            self._save_playback_state()
            self._clear_temp_files()
            if self._player:
                self._player.stop()
            if self._position_timer:
                self._position_timer.stop()
        except:
            pass  # Avoid errors during shutdown
    
    def _ensure_directories(self):
        """Ensure required directories exist"""
        try:
            if not os.path.exists(self.media_dir):
                os.makedirs(self.media_dir)
                print(f"Created media directory at: {self.media_dir}")
            
            if not os.path.exists(self.temp_dir):
                os.makedirs(self.temp_dir)
                print(f"Created temp directory at: {self.temp_dir}")
        except Exception as e:
            print(f"Error creating directories: {e}")
            
    def _update_position(self):
        """Update position for UI slider"""
        if self._player.playbackState() == QMediaPlayer.PlayingState:
            self.positionChanged.emit(self._player.position())
            
    def _handle_media_status(self, status):
        """Handle media status changes"""
        try:
            if status == QMediaPlayer.MediaStatus.EndOfMedia:
                print("Song ended, playing next track")
                self.next_track()
        except Exception as e:
            print(f"Media status handling error: {e}")

    def _cache_metadata(self, filename):
        """Cache metadata for a file to reduce disk operations"""
        if filename in self._metadata_cache:
            return
            
        try:
            file_path = os.path.join(self.media_dir, filename)
            
            # Manage cache size
            if len(self._metadata_cache) >= self._metadata_cache_max:
                # Remove oldest entry
                self._metadata_cache.pop(next(iter(self._metadata_cache)))
                
            # Read metadata once
            audio = ID3(file_path)
            mp3 = MP3(file_path)
            
            # Store all required metadata at once
            self._metadata_cache[filename] = {
                "artist": self._extract_id3_text(audio.get('TPE1'), "Unknown Artist"),
                "album": self._extract_id3_text(audio.get('TALB'), "Unknown Album"),
                "title": self._extract_id3_text(audio.get('TIT2'), filename.replace('.mp3', '')),
                "duration": int(mp3.info.length)
            }
        except Exception as e:
            print(f"Metadata caching error for {filename}: {e}")
            # Set fallback values
            self._metadata_cache[filename] = {
                "artist": "Unknown Artist",
                "album": "Unknown Album",
                "title": filename.replace('.mp3', ''),
                "duration": 0
            }
    
    def _extract_id3_text(self, tag, default=""):
        """Helper to safely extract text from ID3 tags"""
        if tag is None:
            return default
        if isinstance(tag, str):
            return tag
        if hasattr(tag, 'text') and tag.text:
            return tag.text[0]
        return str(tag) if tag else default

    def _emit_metadata(self, filename):
        """Emit metadata change signals"""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)
            
        meta = self._metadata_cache[filename]
        self.metadataChanged.emit(
            meta.get("title", filename.replace('.mp3', '')),
            meta.get("artist", "Unknown Artist"),
            meta.get("album", "Unknown Album")
        )
        
    def _get_album_id(self, filename):
        """Create a unique ID for album art caching"""
        try:
            if filename not in self._metadata_cache:
                self._cache_metadata(filename)
                
            meta = self._metadata_cache[filename]
            # Create unique ID from album and artist
            return f"{meta['album']}_{meta['artist']}"
        except Exception as e:
            print(f"Error getting album ID: {e}")
            return str(hash(filename))
        
    def _manage_cache(self, new_album_id):
        """More efficient cache management using LRU approach"""
        try:
            if len(self._album_art_cache) >= self._max_cache_files:
                # Find least recently accessed item, excluding the new one
                items = [(k, v) for k, v in self._access_count.items() if k != new_album_id]
                if not items:
                    return
                    
                # Find least used album art
                least_used = min(items, key=lambda x: x[1])[0]
                
                # Remove it from cache
                if least_used in self._album_art_cache:
                    file_path = self._album_art_cache[least_used].replace('file:///', '')
                    try:
                        if os.path.exists(file_path):
                            os.remove(file_path)
                    except Exception as e:
                        print(f"Warning: Could not remove file {file_path}: {e}")
                    finally:
                        del self._album_art_cache[least_used]
                        del self._access_count[least_used]
                        
                print(f"Cache managed. New size: {len(self._album_art_cache)}")
        except Exception as e:
            print(f"Cache management error: {e}")

    @Slot()
    def invalidate_stats_cache(self):
        """Mark the statistics cache as invalid to force recalculation"""
        self._stats_cache["is_valid"] = False  
                
    @Slot()
    def _clear_temp_files(self):
        """Improved temp file management with error handling"""
        if os.path.exists(self.temp_dir):
            for file in os.listdir(self.temp_dir):
                try:
                    file_path = os.path.join(self.temp_dir, file)
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                except Exception as e:
                    print(f"Error removing temp file {file}: {e}")
                    
        # Make sure directory exists
        try:
            if not os.path.exists(self.temp_dir):
                os.makedirs(self.temp_dir)
        except Exception as e:
            print(f"Error creating temp directory: {e}")
                
    def _shuffle_playlist(self):
        """Helper method to create shuffled playlist"""
        files = self.get_media_files()
        if not files:
            return []
            
        shuffled = files.copy()
        random.shuffle(shuffled)
        return shuffled
                
    @Slot(result=list)
    def get_media_files(self, emit_signal=True):
        """Get list of available MP3 files"""
        mp3_files = []
        try:
            if os.path.exists(self.media_dir):
                for file in os.listdir(self.media_dir):
                    if file.lower().endswith('.mp3'):
                        mp3_files.append(file)
                        
                # Only emit signal if requested
                if emit_signal:
                    self.mediaListChanged.emit(mp3_files)
                
        except Exception as e:
            print(f"Error getting media files: {e}")
                
        return mp3_files
    
    @Slot(str, result=str)
    def get_formatted_duration(self, filename):
        """Get formatted duration string (MM:SS)"""
        try:
            if filename not in self._metadata_cache:
                self._cache_metadata(filename)
                
            duration_seconds = self._metadata_cache[filename]["duration"]
            minutes = duration_seconds // 60
            seconds = duration_seconds % 60
            formatted = f"{minutes}:{seconds:02d}"
            self.durationFormatChanged.emit(formatted)
            return formatted
        except Exception as e:
            print(f"Error getting duration: {e}")
            return "0:00"
    
    @Slot(str, result=str)
    def get_band(self, filename):
        """Get artist name from metadata"""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)
        return self._metadata_cache[filename]["artist"]

    @Slot(str, result=str)
    def get_album(self, filename):
        """Get album name from metadata"""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)
        return self._metadata_cache[filename]["album"]

    @Slot(str, result=str)
    def get_album_art(self, filename):
        """Extract and cache album art"""
        try:
            album_id = self._get_album_id(filename)
            
            # Update access count for LRU cache
            self._access_count[album_id] = self._access_count.get(album_id, 0) + 1

            # Return if already cached
            if album_id in self._album_art_cache:
                return self._album_art_cache[album_id]
            
            # Manage cache BEFORE adding new entry
            self._manage_cache(album_id)

            # Extract and cache new album art
            file_path = os.path.join(self.media_dir, filename)
            audio = ID3(file_path)
            
            found_apic = False
            apic_index = 0
            for tag in audio.values():
                if tag.FrameID == 'APIC':
                    found_apic = True
                    # Determine file extension from MIME type
                    mime = tag.mime.lower()
                    if mime == 'image/jpeg' or mime == 'image/jpg':
                        ext = 'jpg'
                    elif mime == 'image/png':
                        ext = 'png'
                    elif mime == 'image/gif':
                        ext = 'gif'
                    else:
                        ext = 'img'  # fallback

                    # Create a unique name for this album art (support multiple APIC frames)
                    temp_path = os.path.join(self.temp_dir, f'cover_{hash((album_id, apic_index))}.{ext}')
                    
                    # Write the image data
                    with open(temp_path, 'wb') as img_file:
                        img_file.write(tag.data)
                    
                    # Convert to URL and cache (cache only the first one for this album_id)
                    if album_id not in self._album_art_cache:
                        url = QUrl.fromLocalFile(temp_path).toString()
                        self._album_art_cache[album_id] = url
                        # Optionally, you could return here if you only want the first image
                        return url
                    apic_index += 1

            if not found_apic:
                return ""
            # If multiple APICs, only the first is returned/cached for now
            return self._album_art_cache.get(album_id, "")
        except Exception as e:
            print(f"Error getting album art: {e}")
            return ""
            
    @Slot(result=str)
    def get_current_file(self):
        
        """Get currently playing file without auto-playing"""
        # Initialize playlist if empty
        if not self._current_playlist:
            files = self.get_media_files()
            if files:

                self._current_playlist = sorted(files, key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
                self._current_index = 0
                # Return the first file from the sorted playlist but don't play it
                return self._current_playlist[0]
                
        # Return current file if index is valid
        if 0 <= self._current_index < len(self._current_playlist):
            return self._current_playlist[self._current_index]
        
        # Fallback to first file if index is invalid
        files = self.get_media_files()
        if files:
            self._current_playlist = sorted(files, key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
            self._current_index = 0
            return self._current_playlist[0]
            
        return ""
    
    @Slot(str)
    def play_file(self, filename):
        """Play specified file"""
        # Initialize current_playlist if needed
        if not self._current_playlist:
            try:
                self._current_playlist = self._shuffle_playlist() if self._shuffle else sorted(self.get_media_files(), key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
            except Exception as e:
                print(f"Error initializing playlist: {e}")
                self._current_playlist = []
                
        # Only proceed if we have files
        if not self._current_playlist:
            print("No media files available to play")
            return

        # Try to find the file in the playlist
        try:
            if filename in self._current_playlist:
                self._current_index = self._current_playlist.index(filename)
            elif not self._shuffle:
                # If not found and not shuffled, rebuild alphabetical playlist
                self._current_playlist = sorted(self.get_media_files(), key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
                if filename in self._current_playlist:
                    self._current_index = self._current_playlist.index(filename)
                else:
                    # File not found in any playlist, use the first file
                    filename = self._current_playlist[0] if self._current_playlist else ""
                    self._current_index = 0
        except Exception as e:
            print(f"Error finding file in playlist: {e}")
            # Fallback to first file
            self._current_index = 0
            if self._current_playlist:
                filename = self._current_playlist[0]
            else:
                return
        
        # Play the file
        file_path = os.path.join(self.media_dir, filename)
        if os.path.exists(file_path):
            try:
                url = QUrl.fromLocalFile(file_path)
                self._player.setSource(url)
                self._player.play()
                self._is_playing = True
                self._is_paused = False
                self.playStateChanged.emit(True)
                self.currentMediaChanged.emit(filename)  
                self._emit_metadata(filename)
                self.get_formatted_duration(filename)
                print(f"Now playing: {filename} from {'shuffled' if self._shuffle else 'alphabetical'} playlist at position {self._current_index}")

            except Exception as e:
                print(f"Playback error: {e}")
        else:
            print(f"File not found: {file_path}")
     
    @Slot()
    def next_track(self):
        """Play next track in playlist"""
        try:
            if not self._current_playlist:
                self._current_playlist = sorted(self.get_media_files(), key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
                
            if not self._current_playlist:
                print("No media files available")
                return
                
            self._current_index = (self._current_index + 1) % len(self._current_playlist)
            next_song = self._current_playlist[self._current_index]
            self.play_file(next_song)
        except Exception as e:
            print(f"Error in next_track: {e}")

    @Slot()
    def previous_track(self):
        """Play previous track in playlist"""
        try:
            if not self._current_playlist:
                self._current_playlist = sorted(self.get_media_files(), key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
                
            if not self._current_playlist:
                print("No media files available")
                return
                
            self._current_index = (self._current_index - 1) % len(self._current_playlist)
            prev_song = self._current_playlist[self._current_index]
            self.play_file(prev_song)
        except Exception as e:
            print(f"Error in previous_track: {e}")
        
    @Slot()
    def pause(self):
        """Pause playback"""
        self._player.pause()
        self._is_paused = True
        self._is_playing = False
        self.playStateChanged.emit(False)
        # Save playback state when paused
        self._save_playback_state()
        
    @Slot()
    def toggle_play(self):
        # Handle case when no source is set
        if not self._player.source().isValid():
            current_file = self.get_current_file()
            if current_file:
                self.play_file(current_file)
                return

        # Rest of method remains the same
        if self._is_playing:
            self._player.pause()
            self._is_paused = True
            self._is_playing = False
            # Save playback state when pausing
            self._save_playback_state()
        else:
            self._player.play()
            self._is_paused = False
            self._is_playing = True

        self.playStateChanged.emit(self._is_playing)
            
    @Slot(result=bool)
    def is_playing(self):
        """Return current playing state"""
        return self._is_playing
    
    @Slot(result=bool)
    def is_paused(self):
        """Return current paused state"""
        return self._is_paused
    
    @Slot(result=float)
    def get_duration(self):
        """Get current media duration in ms"""
        return self._player.duration()

    @Slot(result=float)
    def get_position(self):
        """Get current playback position in ms"""
        return self._player.position()

    @Slot(int)
    def set_position(self, position):
        """Set playback position in ms"""
        self._player.setPosition(position)

    @Slot()
    def toggle_mute(self):
        """Toggle mute state"""
        if self._is_muted:
            self._audio_output.setVolume(self._previous_volume)
        else:
            self._previous_volume = self._audio_output.volume()
            self._audio_output.setVolume(0.0)
            
        self._is_muted = not self._is_muted
        self.muteChanged.emit(self._is_muted)
        print(f"Mute toggled: {self._is_muted}")
    
    @Slot(result=bool)
    def is_muted(self):
        """Return current mute state"""
        return self._is_muted
            
    @Slot(float)
    def setVolume(self, volume):
        """Set output volume (0.0-1.0)"""
        try:
            volume = float(volume)
            # Clamp volume to valid range
            volume = max(0.0, min(1.0, volume))
            
            #print(f"Volume set to: {volume}")
            self._audio_output.setVolume(volume)
            self.volumeChanged.emit(volume)
            
            # If volume is being set and we were muted, unmute
            if self._is_muted and volume > 0:
                self._is_muted = False
                self.muteChanged.emit(False)
        except Exception as e:
            print(f"Error setting volume: {e}")
            
    @Slot(result=float)
    def getVolume(self):
        """Get current volume level (0.0-1.0)"""
        return self._audio_output.volume()
    
    @Slot()
    def toggle_shuffle(self):
        """Toggle shuffle mode"""
        self._shuffle = not self._shuffle
        self.shuffleStateChanged.emit(self._shuffle)
        
        # Get current song before changing playlists
        current_song = self.get_current_file()
        files = self.get_media_files()
        
        if self._shuffle:
            # Store original order if needed
            if not self._original_files:
                self._original_files = files.copy()
            
            # Create shuffled playlist
            shuffled = files.copy()
            random.shuffle(shuffled)
            
            # Move current song to start of shuffled list if it exists
            if current_song in shuffled:
                idx = shuffled.index(current_song)
                if idx > 0:  # Only swap if not already at position 0
                    shuffled[0], shuffled[idx] = shuffled[idx], shuffled[0]
                
            self._current_playlist = shuffled
            self._current_index = 0
            print(f"Shuffle enabled, starting from: {current_song}")
        else:
            # Get alphabetical list
            alphabetical = sorted(files, key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower()))
            
            # Find current song in alphabetical order
            if current_song and current_song in alphabetical:
                self._current_index = alphabetical.index(current_song)
                self._current_playlist = alphabetical
                print(f"Shuffle disabled. Continuing alphabetically from: {current_song}")
            else:
                self._current_playlist = alphabetical
                self._current_index = 0
        
        # Update UI
        self.mediaListChanged.emit(self._current_playlist)
        
    @Slot(result=bool)
    def is_shuffled(self):
        """Return current shuffle state"""
        return self._shuffle

    # ==================== Playlist Management ====================

    @Slot()
    def scan_library(self):
        """Scan the library root for subfolders (playlists) and their MP3s"""
        if not self._library_root or not os.path.exists(self._library_root):
            print(f"Library root not set or doesn't exist: {self._library_root}")
            return

        print(f"Scanning library at: {self._library_root}")

        # Clear existing caches
        self._playlists = {}
        self._playlist_names = []
        self._metadata_cache = {}
        self._album_art_cache = {}
        self._access_count = {}
        self.invalidate_stats_cache()

        # First, check for root-level MP3s (goes to "Unsorted" playlist)
        root_mp3s = []
        try:
            for item in os.listdir(self._library_root):
                item_path = os.path.join(self._library_root, item)
                if os.path.isfile(item_path) and item.lower().endswith('.mp3'):
                    root_mp3s.append(item)
        except Exception as e:
            print(f"Error scanning root for MP3s: {e}")

        if root_mp3s:
            self._playlists["Unsorted"] = {
                "name": "Unsorted",
                "path": self._library_root,
                "files": root_mp3s,
                "song_count": len(root_mp3s)
            }
            self._playlist_names.append("Unsorted")
            print(f"Found {len(root_mp3s)} unsorted MP3s in root")

        # Now scan each immediate subfolder as a playlist
        try:
            for item in os.listdir(self._library_root):
                subfolder_path = os.path.join(self._library_root, item)
                if os.path.isdir(subfolder_path):
                    mp3_files = []
                    try:
                        for f in os.listdir(subfolder_path):
                            if f.lower().endswith('.mp3'):
                                mp3_files.append(f)
                    except Exception as e:
                        print(f"Error scanning subfolder {item}: {e}")
                        continue

                    if mp3_files:  # Only create playlist if it has MP3s
                        self._playlists[item] = {
                            "name": item,
                            "path": subfolder_path,
                            "files": mp3_files,
                            "song_count": len(mp3_files)
                        }
                        self._playlist_names.append(item)
                        print(f"Found playlist '{item}' with {len(mp3_files)} songs")
        except Exception as e:
            print(f"Error scanning library subfolders: {e}")

        # Sort playlist names alphabetically (but keep Unsorted first if present)
        if "Unsorted" in self._playlist_names:
            self._playlist_names.remove("Unsorted")
            self._playlist_names.sort(key=str.lower)
            self._playlist_names.insert(0, "Unsorted")
        else:
            self._playlist_names.sort(key=str.lower)

        print(f"Library scan complete. Found {len(self._playlist_names)} playlists")

        # Emit signal
        self.playlistsChanged.emit()

    @Slot(str)
    def set_library_root(self, path):
        """Set the main library folder and scan for playlists"""
        if path and os.path.exists(path) and os.path.isdir(path):
            self._library_root = path
            print(f"Library root set to: {path}")
            self.scan_library()

            # Auto-select first playlist if available
            if self._playlist_names:
                self.select_playlist(self._playlist_names[0])
        else:
            print(f"Invalid library path: {path}")

    @Slot(result=list)
    def get_playlist_names(self):
        """Return list of all playlist names"""
        return self._playlist_names

    @Slot(str)
    def select_playlist(self, name):
        """Select a playlist and load its songs"""
        if name not in self._playlists:
            print(f"Playlist not found: {name}")
            return

        print(f"Selecting playlist: {name}")

        self._current_playlist_name = name
        playlist = self._playlists[name]

        # Update media_dir to playlist path for existing methods
        self.media_dir = playlist["path"]

        # Reset current playlist to sorted files
        self._current_playlist = sorted(
            playlist["files"],
            key=lambda x: re.sub(r'[^\w\s]|_', '', x.lower())
        )
        self._current_index = 0

        # Clear stats cache for new playlist
        self.invalidate_stats_cache()

        # Clear metadata cache if switching playlists (different folder)
        self._metadata_cache = {}

        # Emit signals
        self.currentPlaylistChanged.emit(name)
        self.mediaListChanged.emit(self._current_playlist)

    @Slot(result=str)
    def get_current_playlist_name(self):
        """Return current playlist name"""
        return self._current_playlist_name

    @Slot(QObject)
    def connect_settings_manager(self, settings_manager):
        self._settings_manager = settings_manager
        # Set library root from settings and scan for playlists
        if self._settings_manager:
            self.set_library_root(self._settings_manager.mediaFolder)
            # Connect to future changes
            self._settings_manager.mediaFolderChanged.connect(self.set_library_root)

            # Restore last playback state after library is scanned
            QTimer.singleShot(500, self._restore_playback_state)

    def _restore_playback_state(self):
        """Restore last played song and position from settings"""
        if not self._settings_manager:
            return

        last_song = self._settings_manager.get_last_played_song()
        last_position = self._settings_manager.get_last_played_position()
        last_playlist = self._settings_manager.get_last_played_playlist()
        auto_play = self._settings_manager.get_auto_play_on_startup()

        print(f"Restoring playback state: song={last_song}, position={last_position}, playlist={last_playlist}, auto_play={auto_play}")

        if not last_song:
            return

        # Select the playlist if it exists
        if last_playlist and last_playlist in self._playlists:
            self.select_playlist(last_playlist)

        # Check if the song exists in the current playlist
        if last_song not in self._current_playlist:
            print(f"Last played song '{last_song}' not found in current playlist")
            return

        # Set up the player with the last song
        file_path = os.path.join(self.media_dir, last_song)
        if not os.path.exists(file_path):
            print(f"Last played file not found: {file_path}")
            return

        # Find the song's index in the playlist
        self._current_index = self._current_playlist.index(last_song)

        # Load the song
        url = QUrl.fromLocalFile(file_path)
        self._player.setSource(url)

        # Emit signals to update UI
        self.currentMediaChanged.emit(last_song)
        self._emit_metadata(last_song)
        self.get_formatted_duration(last_song)

        # Set position after a small delay to ensure media is loaded
        if last_position > 0:
            QTimer.singleShot(100, lambda: self._player.setPosition(last_position))

        # Auto-play if enabled
        if auto_play:
            QTimer.singleShot(200, self._player.play)
            QTimer.singleShot(200, lambda: self._set_playing_state(True))

        print(f"Playback state restored: {last_song} at position {last_position}ms")

    def _set_playing_state(self, is_playing):
        """Helper to set playing state and emit signal"""
        self._is_playing = is_playing
        self._is_paused = not is_playing
        self.playStateChanged.emit(is_playing)

    def _save_playback_state(self):
        """Save current playback state to settings"""
        if not self._settings_manager:
            return

        current_song = self.get_current_file()
        current_position = self._player.position()
        current_playlist = self._current_playlist_name

        if current_song:
            self._settings_manager.save_playback_state(
                current_song,
                current_position,
                current_playlist
            )

    def update_media_directory(self, directory):
        if os.path.exists(directory) and os.path.isdir(directory):
            old_dir = self.media_dir
            self.media_dir = directory
            
            # Clear caches that depend on the previous directory
            self._metadata_cache = {}
            self._album_art_cache = {}
            self._access_count = {}
            self.invalidate_stats_cache()
            
            # Refresh media files
            self.get_media_files()
            
            # If currently playing, try to continue with same file or reset
            current_file = self.get_current_file()
            if self._is_playing and current_file and os.path.exists(os.path.join(self.media_dir, current_file)):
                self.play_file(current_file)
            elif self._is_playing:
                # Was playing but file not in new directory - play first available file
                files = self.get_media_files()
                if files:
                    self.play_file(files[0])
                else:
                    self._player.stop()
                    self._is_playing = False
                    self._is_paused = True
                    self.playStateChanged.emit(False)
        else:
            print(f"Warning: Directory {directory} does not exist or is not a directory")
            
    @Slot(result=str)
    def get_default_media_dir(self):
        """Return the default media directory path"""
        return self.default_media_dir

    @Slot(result=str)
    def get_media_folder_name(self):
        """Return just the folder name of the current media directory"""
        return os.path.basename(self.media_dir)

    def _calculate_all_stats(self):
        """Calculate all statistics at once and cache the results"""
        if self._stats_cache["is_valid"]:
            return
            
        try:
            files = self.get_media_files()
            
            # Initialize calculation variables
            total_ms = 0
            albums = set()
            artists = set()
            
            # Process all files in a single pass
            for filename in files:
                if filename not in self._metadata_cache:
                    self._cache_metadata(filename)
                    
                # Duration
                duration_seconds = self._metadata_cache[filename]["duration"]
                total_ms += duration_seconds * 1000
                
                # Album
                album = self._metadata_cache[filename]["album"]
                if album and album != "Unknown Album":
                    albums.add(album)
                    
                # Artist
                artist = self._metadata_cache[filename]["artist"]
                if artist and artist != "Unknown Artist":
                    artists.add(artist)
            
            # Update cache
            self._stats_cache["total_duration_ms"] = total_ms
            self._stats_cache["total_duration_formatted"] = self._format_duration(total_ms)
            self._stats_cache["album_count"] = len(albums)
            self._stats_cache["artist_count"] = len(artists)
            self._stats_cache["is_valid"] = True
            
            # Emit signals with new values
            self.totalDurationChanged.emit(self._stats_cache["total_duration_formatted"])
            self.albumCountChanged.emit(self._stats_cache["album_count"])
            self.artistCountChanged.emit(self._stats_cache["artist_count"])
        
        except Exception as e:
            print(f"Error calculating statistics: {e}")
            # Set default values on error
            self._stats_cache["total_duration_ms"] = 0
            self._stats_cache["total_duration_formatted"] = "0:00:00"
            self._stats_cache["album_count"] = 0
            self._stats_cache["artist_count"] = 0

    def _format_duration(self, ms):
        """Format milliseconds to hours:minutes:seconds"""
        try:
            seconds = int(ms / 1000)
            minutes = int(seconds / 60)
            hours = int(minutes / 60)
            minutes = minutes % 60
            seconds = seconds % 60
            return f"{hours}:{minutes:02d}:{seconds:02d}"
        except Exception as e:
            print(f"Error formatting duration: {e}")
            return "0:00:00"

    @Slot(result=str)
    def get_total_duration(self):
        """Get the total duration of all media files as formatted string"""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["total_duration_formatted"]

    @Slot(result=int)
    def get_album_count(self):
        """Get the count of unique albums"""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["album_count"]

    @Slot(result=int)
    def get_artist_count(self):
        """Get the count of unique artists"""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["artist_count"]
    
    def _clean_for_sort(self, filename):
        """Helper function to create consistent sort keys"""
        return re.sub(r'[^\w\s]|_', '', filename.lower())

    @Slot(str, bool, result=list)
    def sort_media_files(self, sort_column, ascending=True):
        """Sort media files based on criteria"""
        try:
            # Use cached files instead of calling get_media_files() again
            # This is the key change to prevent the infinite recursion
            files = self._current_playlist if self._current_playlist else self.get_media_files(emit_signal=False)
            
            if sort_column == "title":
                sorted_files = sorted(files, 
                                key=lambda x: re.sub(r'[^\w\s]|_', '', 
                                                    x.replace('.mp3', '').lower().strip()), 
                                reverse=not ascending)
            elif sort_column == "album":
                sorted_files = sorted(files, 
                                key=lambda x: re.sub(r'[^\w\s]|_', '', 
                                                    self.get_album(x).lower().strip()), 
                                reverse=not ascending)
            elif sort_column == "artist":
                sorted_files = sorted(files, 
                                key=lambda x: re.sub(r'[^\w\s]|_', '', 
                                                    self.get_band(x).lower().strip()), 
                                reverse=not ascending)
            else:
                sorted_files = files
                
            return sorted_files
        except Exception as e:
            print(f"Error sorting media files: {e}")
            return []  # Return empty list on error instead of calling get_media_files again