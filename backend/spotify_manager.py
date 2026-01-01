"""
Spotify Connect Manager for OCTAVE
Controls Spotify playback on connected devices (phone, desktop, etc.)
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, QMetaObject, Qt, Q_ARG
import os
import json
import webbrowser
import secrets
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
from concurrent.futures import ThreadPoolExecutor

try:
    import spotipy
    from spotipy.oauth2 import SpotifyOAuth
    from spotipy.cache_handler import CacheHandler
    SPOTIPY_AVAILABLE = True
except ImportError:
    SPOTIPY_AVAILABLE = False
    print("Warning: spotipy not installed. Run: pip install spotipy")

try:
    import keyring
    KEYRING_AVAILABLE = True
except ImportError:
    KEYRING_AVAILABLE = False
    print("Warning: keyring not installed. Token storage will be less secure.")


class KeyringCacheHandler(CacheHandler):
    """
    Secure token cache using OS keychain (Windows Credential Manager, macOS Keychain, etc.)
    Falls back to file-based cache if keyring is not available.
    """
    SERVICE_NAME = "OCTAVE_Spotify"
    USERNAME = "spotify_token"

    def __init__(self):
        super().__init__()
        # Fallback file cache location (in backend directory)
        self._cache_file = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            '.spotify_token_cache'
        )

    def get_cached_token(self):
        """Retrieve token from OS keychain or fallback file"""
        if KEYRING_AVAILABLE:
            try:
                token_string = keyring.get_password(self.SERVICE_NAME, self.USERNAME)
                if token_string:
                    return json.loads(token_string)
            except Exception as e:
                print(f"Keyring read error: {e}")

        # Fallback to file cache
        if os.path.exists(self._cache_file):
            try:
                with open(self._cache_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"File cache read error: {e}")
        return None

    def save_token_to_cache(self, token_info):
        """Save token to OS keychain or fallback file"""
        if KEYRING_AVAILABLE:
            try:
                token_string = json.dumps(token_info)
                keyring.set_password(self.SERVICE_NAME, self.USERNAME, token_string)
                return
            except Exception as e:
                print(f"Keyring write error: {e}")

        # Fallback to file cache
        try:
            with open(self._cache_file, 'w') as f:
                json.dump(token_info, f)
        except Exception as e:
            print(f"File cache write error: {e}")

    def delete_cached_token(self):
        """Remove token from OS keychain and fallback file"""
        if KEYRING_AVAILABLE:
            try:
                keyring.delete_password(self.SERVICE_NAME, self.USERNAME)
            except keyring.errors.PasswordDeleteError:
                pass  # Token didn't exist
            except Exception as e:
                print(f"Keyring delete error: {e}")

        # Also delete file cache
        if os.path.exists(self._cache_file):
            try:
                os.remove(self._cache_file)
            except Exception as e:
                print(f"File cache delete error: {e}")


class SpotifyManager(QObject):
    # Connection state signals
    connectionStateChanged = Signal(bool)  # True when authenticated
    errorOccurred = Signal(str)  # Error messages

    # Playback state signals (mirror MediaManager's signals)
    playStateChanged = Signal(bool)
    currentTrackChanged = Signal(str, str, str, str)  # title, artist, album, art_url
    durationChanged = Signal(int)
    positionChanged = Signal(int)
    shuffleStateChanged = Signal(bool)
    volumeChanged = Signal(int)  # Volume 0-100

    # Device signals
    devicesChanged = Signal(list)  # List of available Spotify Connect devices
    activeDeviceChanged = Signal(str)  # Currently active device name

    # Playlist/library signals
    playlistsChanged = Signal(list)  # List of user playlists
    spotifyTracksChanged = Signal(list)  # Tracks from selected playlist
    currentSpotifyPlaylistChanged = Signal(str)  # Current playlist name

    # Auth flow signal
    authUrlReady = Signal(str)  # URL for user to visit for OAuth

    # Status progress signal for terminal-style feedback
    statusProgress = Signal(str)  # Status messages with prefixes like [INFO], [ERROR], etc.

    # Internal signal for thread-safe initialization after auth
    _authCompleted = Signal()

    # Internal signals for async API results (thread-safe)
    _playbackStateReady = Signal(object)  # Playback data from API
    _devicesReady = Signal(list)  # Devices from API
    _playlistsReady = Signal(list)  # Playlists from API

    def __init__(self):
        super().__init__()

        self._is_connected = False
        self._sp = None  # Spotipy client

        # Thread pool for async API calls (max 2 concurrent to avoid rate limits)
        self._executor = ThreadPoolExecutor(max_workers=2)
        self._current_track = {}
        self._devices = []
        self._active_device_id = None
        self._playlists = []
        self._is_playing = False
        self._current_position_ms = 0
        self._is_shuffled = False
        self._current_volume = 100  # Volume 0-100

        # Spotify playlist tracks state
        self._spotify_tracks = []
        self._current_spotify_playlist_id = ""
        self._current_spotify_playlist_name = ""

        # Credentials (loaded from settings)
        self._client_id = ""
        self._client_secret = ""
        self._redirect_uri = "http://127.0.0.1:8888/callback"

        # Secure token cache using OS keychain
        self.backend_dir = os.path.dirname(os.path.abspath(__file__))
        self._cache_handler = KeyringCacheHandler()

        # OAuth state for CSRF protection
        self._oauth_state = None

        # Polling timer for playback state (API calls)
        self._poll_timer = QTimer()
        self._poll_timer.setInterval(3000)  # Poll every 3 seconds (avoid rate limits)
        self._poll_timer.timeout.connect(self._poll_playback_state)

        # Fast local timer for smooth position interpolation (no API calls)
        self._interpolation_timer = QTimer()
        self._interpolation_timer.setInterval(250)  # Update UI 4x per second
        self._interpolation_timer.timeout.connect(self._interpolate_position)

        # Track last known position and time for interpolation
        self._last_known_position_ms = 0
        self._last_poll_timestamp = 0

        # Store auth_manager for use after thread callback
        self._pending_auth_manager = None

        # Connect internal signals for thread-safe callbacks
        self._authCompleted.connect(self._on_auth_completed)
        self._playbackStateReady.connect(self._handle_playback_state)
        self._devicesReady.connect(self._handle_devices_result)
        self._playlistsReady.connect(self._handle_playlists_result)

        # Track pending async operations to avoid duplicates
        self._poll_in_progress = False

        self._settings_manager = None

    @Slot(QObject)
    def connect_settings_manager(self, settings_manager):
        """Connect to settings manager to load/save credentials"""
        self._settings_manager = settings_manager
        self._load_credentials()

    def _load_credentials(self):
        """Load Spotify credentials from settings"""
        if self._settings_manager:
            self._client_id = self._settings_manager.get_spotify_client_id()
            self._client_secret = self._settings_manager.get_spotify_client_secret()

    @Slot()
    def _on_auth_completed(self):
        """Called on main thread after successful OAuth callback"""
        if self._pending_auth_manager:
            self.statusProgress.emit("[SUCCESS] OAuth completed, setting up connection...")
            self._sp = spotipy.Spotify(auth_manager=self._pending_auth_manager)
            self._is_connected = True
            self.connectionStateChanged.emit(True)
            self._poll_timer.start()
            self._interpolation_timer.start()  # Start smooth position updates
            self._refresh_devices()
            self._refresh_playlists()
            self._pending_auth_manager = None
            self.statusProgress.emit("[DONE] Successfully connected to Spotify!")
            print("Spotify: Post-auth setup completed on main thread")

    @Slot(result=bool)
    def is_available(self):
        """Check if spotipy library is installed"""
        return SPOTIPY_AVAILABLE

    @Slot(result=bool)
    def is_connected(self):
        """Check if we're authenticated with Spotify"""
        return self._is_connected

    @Slot(result=bool)
    def has_credentials(self):
        """Check if client ID and secret are configured"""
        return bool(self._client_id and self._client_secret)

    @Slot(str, str)
    def set_credentials(self, client_id, client_secret):
        """Set Spotify API credentials"""
        self._client_id = client_id
        self._client_secret = client_secret

        # Save to settings
        if self._settings_manager:
            self._settings_manager.save_spotify_credentials(client_id, client_secret)

    @Slot()
    def authenticate(self):
        """Start OAuth authentication flow"""
        self.statusProgress.emit("[INFO] Starting Spotify authentication...")

        if not SPOTIPY_AVAILABLE:
            self.statusProgress.emit("[ERROR] Spotipy library not installed")
            self.errorOccurred.emit("Spotipy library not installed")
            return

        if not self.has_credentials():
            self.statusProgress.emit("[ERROR] Spotify credentials not configured")
            self.errorOccurred.emit("Spotify credentials not configured")
            return

        try:
            # Required scopes for playback control
            scope = (
                "user-read-playback-state "
                "user-modify-playback-state "
                "user-read-currently-playing "
                "playlist-read-private "
                "playlist-read-collaborative "
                "user-library-read"
            )

            # Generate secure state for CSRF protection
            self._oauth_state = secrets.token_urlsafe(32)

            auth_manager = SpotifyOAuth(
                client_id=self._client_id,
                client_secret=self._client_secret,
                redirect_uri=self._redirect_uri,
                scope=scope,
                cache_handler=self._cache_handler,
                open_browser=False,
                state=self._oauth_state
            )

            # Check if we have a cached token
            token_info = auth_manager.get_cached_token()

            if token_info:
                # We have a valid token, create client
                self.statusProgress.emit("[INFO] Found cached token, connecting...")
                self._sp = spotipy.Spotify(auth_manager=auth_manager)
                self._is_connected = True
                self.connectionStateChanged.emit(True)
                self._poll_timer.start()
                self._interpolation_timer.start()  # Start smooth position updates
                self._refresh_devices()
                self._refresh_playlists()
                self.statusProgress.emit("[SUCCESS] Connected with cached token")
                print("Spotify: Connected with cached token")
            else:
                # Need to authenticate - get auth URL
                self.statusProgress.emit("[INFO] No cached token, starting OAuth flow...")
                auth_url = auth_manager.get_authorize_url()
                self.authUrlReady.emit(auth_url)

                # Start local server to catch the callback
                self._start_auth_server(auth_manager)
                self.statusProgress.emit("[INFO] Waiting for browser authentication...")

        except Exception as e:
            self.statusProgress.emit(f"[ERROR] Authentication failed: {str(e)}")
            self.errorOccurred.emit(f"Authentication failed: {str(e)}")
            print(f"Spotify auth error: {e}")

    def _start_auth_server(self, auth_manager):
        """Start a local HTTP server to catch OAuth callback"""
        manager = self

        class CallbackHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                query = urlparse(self.path).query
                params = parse_qs(query)

                # Validate state parameter to prevent CSRF attacks
                received_state = params.get('state', [None])[0]
                if received_state != manager._oauth_state:
                    self.send_response(403)
                    self.send_header('Content-type', 'text/html')
                    self.end_headers()
                    self.wfile.write(b"""
                        <html><body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                        <h1>Authentication Failed</h1>
                        <p>Invalid state parameter. Please try again.</p>
                        </body></html>
                    """)
                    manager.errorOccurred.emit("OAuth state mismatch - possible CSRF attack")
                    return

                if 'code' in params:
                    code = params['code'][0]
                    try:
                        # Exchange code for token
                        auth_manager.get_access_token(code)

                        # Clear the state after successful use
                        manager._oauth_state = None

                        # Store auth_manager and emit signal to complete setup on main thread
                        manager._pending_auth_manager = auth_manager
                        manager._authCompleted.emit()

                        # Send success response
                        self.send_response(200)
                        self.send_header('Content-type', 'text/html')
                        self.end_headers()
                        self.wfile.write(b"""
                            <html><body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                            <h1>Success!</h1>
                            <p>Spotify connected. You can close this window.</p>
                            </body></html>
                        """)
                        print("Spotify: Successfully authenticated")
                    except Exception as e:
                        manager.errorOccurred.emit(f"Token exchange failed: {str(e)}")
                        self.send_response(500)
                        self.end_headers()
                else:
                    self.send_response(400)
                    self.end_headers()

            def log_message(self, format, *args):
                pass  # Suppress HTTP server logs

        def run_server():
            server = HTTPServer(('127.0.0.1', 8888), CallbackHandler)
            server.timeout = 120  # 2 minute timeout
            server.handle_request()  # Handle single request then stop

        # Run server in background thread
        thread = threading.Thread(target=run_server, daemon=True)
        thread.start()

        # Open browser for user to authenticate
        auth_url = auth_manager.get_authorize_url()
        print(f"Spotify auth URL: {auth_url}")

        # Open browser for authentication
        import platform

        opened = False
        if platform.system() == 'Windows':
            try:
                # Use os.startfile on Windows (safe, no shell injection risk)
                os.startfile(auth_url)
                opened = True
                print("Spotify: Opened browser via os.startfile")
            except Exception as e:
                print(f"os.startfile failed: {e}")

        if not opened:
            try:
                # Fallback: standard webbrowser module (cross-platform)
                webbrowser.open(auth_url)
                opened = True
                print("Spotify: Opened browser via webbrowser module")
            except Exception as e:
                print(f"webbrowser.open failed: {e}")

        if not opened:
            # Last resort: emit URL for user to copy manually
            self.authUrlReady.emit(auth_url)
            self.errorOccurred.emit(f"Could not open browser. Please visit: {auth_url}")

    @Slot()
    def disconnect(self):
        """Disconnect from Spotify"""
        self.statusProgress.emit("[INFO] Disconnecting from Spotify...")
        self._poll_timer.stop()
        self._interpolation_timer.stop()
        self._sp = None
        self._is_connected = False
        self._devices = []
        self._current_track = {}

        # Remove cached token from OS keychain
        self._cache_handler.delete_cached_token()
        self.statusProgress.emit("[INFO] Cleared cached token")

        self.connectionStateChanged.emit(False)
        self.statusProgress.emit("[DONE] Disconnected from Spotify")
        print("Spotify: Disconnected")

    @Slot()
    def cleanup(self):
        """Stop all timers and threads - call before app exit"""
        print("Spotify: Cleaning up...")

        # Stop timers first to prevent new tasks
        self._poll_timer.stop()
        self._interpolation_timer.stop()

        # Mark as not connected to prevent callbacks from doing work
        self._is_connected = False

        # Clear the client to make API calls fail fast
        self._sp = None

        # Shutdown executor - cancel pending tasks
        self._executor.shutdown(wait=False, cancel_futures=True)

        print("Spotify: Cleanup complete")

    # ==================== Playback Control ====================

    def _run_async(self, func, success_callback=None, error_msg="Operation failed"):
        """Run a Spotify API call asynchronously"""
        def on_done(future):
            # Skip if shutting down
            if not self._sp:
                return
            try:
                result = future.result()
                if success_callback:
                    # Use QMetaObject to call callback on main thread
                    QMetaObject.invokeMethod(self, success_callback, Qt.QueuedConnection)
            except Exception as e:
                if self._sp:  # Only emit error if not shutting down
                    self.errorOccurred.emit(f"{error_msg}: {str(e)}")

        self._executor.submit(func).add_done_callback(on_done)

    @Slot()
    def play(self):
        """Resume playback"""
        if not self._sp:
            return
        # Optimistic UI update
        self._is_playing = True
        self.playStateChanged.emit(True)

        def do_play():
            self._sp.start_playback(device_id=self._active_device_id)

        self._run_async(do_play, error_msg="Play failed")

    @Slot()
    def pause(self):
        """Pause playback"""
        if not self._sp:
            return
        # Optimistic UI update
        self._is_playing = False
        self.playStateChanged.emit(False)

        def do_pause():
            self._sp.pause_playback(device_id=self._active_device_id)

        self._run_async(do_pause, error_msg="Pause failed")

    @Slot()
    def toggle_play(self):
        """Toggle play/pause"""
        if not self._sp:
            return
        if self._is_playing:
            self.pause()
        else:
            self.play()

    @Slot()
    def next_track(self):
        """Skip to next track"""
        if not self._sp:
            return

        def do_next():
            self._sp.next_track(device_id=self._active_device_id)

        self._run_async(do_next, error_msg="Next track failed")

    @Slot()
    def previous_track(self):
        """Skip to previous track"""
        if not self._sp:
            return

        def do_prev():
            self._sp.previous_track(device_id=self._active_device_id)

        self._run_async(do_prev, error_msg="Previous track failed")

    @Slot(int)
    def set_position(self, position_ms):
        """Seek to position in current track"""
        if not self._sp:
            return
        # Optimistic UI update
        self._current_position_ms = position_ms
        self._last_known_position_ms = position_ms
        self._last_poll_timestamp = time.time()

        def do_seek():
            self._sp.seek_track(position_ms, device_id=self._active_device_id)

        self._run_async(do_seek, error_msg="Seek failed")

    @Slot(int)
    def set_volume(self, volume_percent):
        """Set playback volume (0-100)"""
        if not self._sp:
            return
        volume = max(0, min(100, int(volume_percent)))
        # Optimistic UI update
        self._current_volume = volume
        self.volumeChanged.emit(volume)

        def do_volume():
            self._sp.volume(volume, device_id=self._active_device_id)

        self._run_async(do_volume, error_msg="Volume failed")

    @Slot()
    def toggle_shuffle(self):
        """Toggle shuffle mode"""
        if not self._sp:
            return
        new_state = not self._is_shuffled
        # Optimistic UI update
        self._is_shuffled = new_state
        self.shuffleStateChanged.emit(new_state)

        def do_shuffle():
            self._sp.shuffle(new_state, device_id=self._active_device_id)

        self._run_async(do_shuffle, error_msg="Shuffle toggle failed")

    @Slot(result=bool)
    def is_shuffled(self):
        """Check if shuffle is enabled"""
        return self._is_shuffled

    @Slot(str)
    def play_uri(self, uri):
        """Play a specific Spotify URI (track, album, playlist)"""
        if not self._sp:
            return

        # Optimistic UI update
        self._is_playing = True
        self.playStateChanged.emit(True)

        # Prepare the API call parameters
        device_id = self._active_device_id
        playlist_id = self._current_spotify_playlist_id
        tracks = self._spotify_tracks

        def do_play():
            if uri.startswith('spotify:track:'):
                # If we have a current playlist context, play within that context
                if playlist_id:
                    playlist_uri = f"spotify:playlist:{playlist_id}"
                    # Find the offset of this track in the playlist
                    offset = None
                    for i, track in enumerate(tracks):
                        if track.get('uri') == uri:
                            offset = i
                            break

                    if offset is not None:
                        self._sp.start_playback(
                            device_id=device_id,
                            context_uri=playlist_uri,
                            offset={"position": offset}
                        )
                    else:
                        # Track not found in playlist, play standalone
                        self._sp.start_playback(device_id=device_id, uris=[uri])
                else:
                    self._sp.start_playback(device_id=device_id, uris=[uri])
            else:
                # Album or playlist
                self._sp.start_playback(device_id=device_id, context_uri=uri)

        self._run_async(do_play, error_msg="Play URI failed")

    # ==================== Device Management ====================

    @Slot()
    def refresh_devices(self):
        """Refresh list of available devices (public slot)"""
        self._refresh_devices()

    def _refresh_devices(self):
        """Schedule async refresh of available Spotify Connect devices"""
        if not self._sp:
            return

        self.statusProgress.emit("[INFO] Scanning for Spotify devices...")

        def fetch():
            try:
                result = self._sp.devices()
                return result.get('devices', [])
            except Exception as e:
                print(f"Spotify device refresh error: {e}")
                return []

        def on_done(future):
            if not self._sp:  # Skip if shutting down
                return
            try:
                devices = future.result()
                self._devicesReady.emit(devices)
            except Exception:
                pass

        self._executor.submit(fetch).add_done_callback(on_done)

    def _handle_devices_result(self, devices):
        """Handle devices result on main thread"""
        self._devices = [{
            'id': d['id'],
            'name': d['name'],
            'type': d['type'],
            'is_active': d['is_active'],
            'volume': d.get('volume_percent', 0)
        } for d in devices]

        # Find active device
        for d in self._devices:
            if d['is_active']:
                self._active_device_id = d['id']
                self.activeDeviceChanged.emit(d['name'])
                break

        self.devicesChanged.emit(self._devices)

        if len(self._devices) == 0:
            self.statusProgress.emit("[WARN] No devices found - open Spotify on a device")
        else:
            self.statusProgress.emit(f"[FOUND] {len(self._devices)} device(s) available")

    @Slot(str)
    def set_active_device(self, device_id):
        """Transfer playback to a specific device"""
        if not self._sp:
            return
        try:
            self._sp.transfer_playback(device_id, force_play=False)
            self._active_device_id = device_id

            # Find device name
            for d in self._devices:
                if d['id'] == device_id:
                    self.activeDeviceChanged.emit(d['name'])
                    break
        except Exception as e:
            self.errorOccurred.emit(f"Device transfer failed: {str(e)}")

    @Slot(result=list)
    def get_devices(self):
        """Get list of available devices"""
        return self._devices

    # ==================== Playlist Management ====================

    def _refresh_playlists(self):
        """Schedule async refresh of user playlists"""
        if not self._sp:
            return

        self.statusProgress.emit("[INFO] Loading Spotify playlists...")

        def fetch():
            try:
                results = self._sp.current_user_playlists(limit=50)
                return [{
                    'id': p['id'],
                    'name': p['name'],
                    'uri': p['uri'],
                    'track_count': p['tracks']['total'],
                    'image': p['images'][0]['url'] if p['images'] else ''
                } for p in results.get('items', [])]
            except Exception as e:
                print(f"Spotify playlist refresh error: {e}")
                return []

        def on_done(future):
            if not self._sp:  # Skip if shutting down
                return
            try:
                playlists = future.result()
                self._playlistsReady.emit(playlists)
            except Exception:
                pass

        self._executor.submit(fetch).add_done_callback(on_done)

    def _handle_playlists_result(self, playlists):
        """Handle playlists result on main thread"""
        self._playlists = playlists
        self.playlistsChanged.emit(self._playlists)
        self.statusProgress.emit(f"[FOUND] {len(self._playlists)} playlist(s) loaded")

    @Slot(result=list)
    def get_playlists(self):
        """Get list of user playlists"""
        return self._playlists

    @Slot(str, result=list)
    def get_playlist_tracks(self, playlist_id):
        """Get tracks from a playlist"""
        if not self._sp:
            return []
        try:
            results = self._sp.playlist_tracks(playlist_id, limit=100)

            tracks = []
            for item in results.get('items', []):
                track = item.get('track')
                if track:
                    tracks.append({
                        'id': track['id'],
                        'name': track['name'],
                        'uri': track['uri'],
                        'artist': ', '.join([a['name'] for a in track['artists']]),
                        'album': track['album']['name'],
                        'duration_ms': track['duration_ms'],
                        'image': track['album']['images'][0]['url'] if track['album']['images'] else ''
                    })
            return tracks

        except Exception as e:
            print(f"Spotify get playlist tracks error: {e}")
            return []

    @Slot(str)
    def select_spotify_playlist(self, playlist_id):
        """Select a Spotify playlist and load its tracks"""
        print(f"select_spotify_playlist called with ID: {playlist_id}")
        if not self._sp:
            print("Error: Spotify client not connected")
            return

        # Find playlist name from stored playlists
        playlist_name = ""
        for p in self._playlists:
            if p['id'] == playlist_id:
                playlist_name = p['name']
                break

        print(f"Found playlist name: {playlist_name}")

        # Load tracks
        self._spotify_tracks = self.get_playlist_tracks(playlist_id)
        self._current_spotify_playlist_id = playlist_id
        self._current_spotify_playlist_name = playlist_name

        print(f"Loaded {len(self._spotify_tracks)} tracks")
        if self._spotify_tracks:
            print(f"First track: {self._spotify_tracks[0]}")

        # Emit signals
        self.spotifyTracksChanged.emit(self._spotify_tracks)
        self.currentSpotifyPlaylistChanged.emit(playlist_name)

    @Slot(result=list)
    def get_spotify_playlist_names(self):
        """Return list of playlist names"""
        return [p['name'] for p in self._playlists]

    @Slot(result=list)
    def get_spotify_tracks(self):
        """Return currently loaded Spotify playlist tracks"""
        return self._spotify_tracks

    @Slot(result=str)
    def get_current_spotify_playlist_name(self):
        """Return current Spotify playlist name"""
        return self._current_spotify_playlist_name

    @Slot(str, result=str)
    def get_spotify_track_artist(self, track_name):
        """Get artist for a track by name"""
        for track in self._spotify_tracks:
            if track['name'] == track_name:
                return track.get('artist', 'Unknown Artist')
        return 'Unknown Artist'

    @Slot(str, result=str)
    def get_spotify_track_album(self, track_name):
        """Get album for a track by name"""
        for track in self._spotify_tracks:
            if track['name'] == track_name:
                return track.get('album', 'Unknown Album')
        return 'Unknown Album'

    @Slot(str, result=str)
    def get_spotify_track_image(self, track_name):
        """Get album art URL for a track by name"""
        for track in self._spotify_tracks:
            if track['name'] == track_name:
                return track.get('image', '')
        return ''

    @Slot(str, result=str)
    def get_spotify_track_duration_formatted(self, track_name):
        """Get formatted duration (MM:SS) for a track by name"""
        for track in self._spotify_tracks:
            if track['name'] == track_name:
                duration_ms = track.get('duration_ms', 0)
                minutes = duration_ms // 60000
                seconds = (duration_ms % 60000) // 1000
                return f"{minutes}:{seconds:02d}"
        return "0:00"

    @Slot(str, result=str)
    def get_spotify_track_uri(self, track_name):
        """Get Spotify URI for a track by name"""
        for track in self._spotify_tracks:
            if track['name'] == track_name:
                return track.get('uri', '')
        return ''

    @Slot(str, result=str)
    def get_spotify_playlist_id(self, playlist_name):
        """Get playlist ID from playlist name"""
        for p in self._playlists:
            if p['name'] == playlist_name:
                return p['id']
        return ''

    @Slot(result=str)
    def get_current_spotify_playlist_id(self):
        """Get the currently selected Spotify playlist ID"""
        return self._current_spotify_playlist_id

    @Slot(result=str)
    def get_current_spotify_playlist_name(self):
        """Get the currently selected Spotify playlist name"""
        return self._current_spotify_playlist_name

    @Slot(result=bool)
    def has_spotify_playlist_loaded(self):
        """Check if a Spotify playlist is currently loaded"""
        return bool(self._current_spotify_playlist_id and self._spotify_tracks)

    # ==================== Playback State Polling ====================

    def _poll_playback_state(self):
        """Schedule async poll of playback state from Spotify"""
        if not self._sp or self._poll_in_progress:
            return

        self._poll_in_progress = True

        def fetch():
            try:
                return self._sp.current_playback()
            except Exception as e:
                return None

        def on_done(future):
            # Skip if shutting down
            if not self._sp:
                self._poll_in_progress = False
                return
            try:
                playback = future.result()
                # Emit signal to handle result on main thread
                self._playbackStateReady.emit(playback)
            except Exception:
                pass
            finally:
                self._poll_in_progress = False

        future = self._executor.submit(fetch)
        future.add_done_callback(on_done)

    def _handle_playback_state(self, playback):
        """Handle playback state on main thread (called via signal)"""
        if not playback:
            # No active playback - slow down polling
            if self._poll_timer.interval() != 10000:
                self._poll_timer.setInterval(10000)  # 10 seconds when idle
            return

        # Get play state
        is_playing = playback.get('is_playing', False)

        # Adjust poll rate based on playback state
        if is_playing:
            if self._poll_timer.interval() != 3000:
                self._poll_timer.setInterval(3000)  # 3 seconds when playing
        else:
            if self._poll_timer.interval() != 5000:
                self._poll_timer.setInterval(5000)  # 5 seconds when paused

        # Only emit play state if changed
        if is_playing != self._is_playing:
            self._is_playing = is_playing
            self.playStateChanged.emit(is_playing)

        # Check shuffle state - only emit if changed
        shuffle_state = playback.get('shuffle_state', False)
        if shuffle_state != self._is_shuffled:
            self._is_shuffled = shuffle_state
            self.shuffleStateChanged.emit(shuffle_state)

        # Check volume from device - only emit if changed
        device = playback.get('device')
        if device:
            volume = device.get('volume_percent', 100)
            if volume != self._current_volume:
                self._current_volume = volume
                self.volumeChanged.emit(volume)

        # Update position and timestamp for interpolation
        progress_ms = playback.get('progress_ms', 0)
        self._last_known_position_ms = progress_ms
        self._last_poll_timestamp = time.time()
        self._current_position_ms = progress_ms
        self.positionChanged.emit(progress_ms)

        # Check if track changed
        track = playback.get('item')
        if track:
            track_id = track.get('id')
            if track_id != self._current_track.get('id'):
                # Track changed
                self._current_track = {
                    'id': track_id,
                    'name': track.get('name', ''),
                    'artist': ', '.join([a['name'] for a in track.get('artists', [])]),
                    'album': track.get('album', {}).get('name', ''),
                    'duration_ms': track.get('duration_ms', 0),
                    'image': ''
                }

                # Get album art
                album = track.get('album', {})
                images = album.get('images', [])
                if images:
                    self._current_track['image'] = images[0]['url']

                # Emit signals
                self.currentTrackChanged.emit(
                    self._current_track['name'],
                    self._current_track['artist'],
                    self._current_track['album'],
                    self._current_track['image']
                )
                self.durationChanged.emit(self._current_track['duration_ms'])

    def _interpolate_position(self):
        """Interpolate position between API polls for smooth UI updates"""
        if not self._is_playing or self._last_poll_timestamp == 0:
            return

        # Calculate elapsed time since last poll
        elapsed_ms = int((time.time() - self._last_poll_timestamp) * 1000)

        # Estimate current position
        estimated_position = self._last_known_position_ms + elapsed_ms

        # Don't exceed track duration
        duration = self._current_track.get('duration_ms', 0)
        if duration > 0 and estimated_position > duration:
            estimated_position = duration

        # Only emit if position changed significantly (avoid spam)
        if abs(estimated_position - self._current_position_ms) >= 200:
            self._current_position_ms = estimated_position
            self.positionChanged.emit(estimated_position)

    @Slot(result=str)
    def get_current_track_name(self):
        """Get current track name"""
        return self._current_track.get('name', '')

    @Slot(result=str)
    def get_current_artist(self):
        """Get current artist"""
        return self._current_track.get('artist', '')

    @Slot(result=str)
    def get_current_album(self):
        """Get current album"""
        return self._current_track.get('album', '')

    @Slot(result=str)
    def get_current_album_art(self):
        """Get current album art URL"""
        return self._current_track.get('image', '')

    # ==================== Compatibility Methods (match MediaManager API) ====================

    @Slot(result=bool)
    def is_playing(self):
        """Check if currently playing"""
        return self._is_playing

    @Slot(result=int)
    def get_duration(self):
        """Get current track duration in milliseconds"""
        return self._current_track.get('duration_ms', 0)

    @Slot(result=int)
    def get_position(self):
        """Get current playback position in milliseconds"""
        return self._current_position_ms

    @Slot(result=int)
    def get_volume(self):
        """Get current volume (0-100)"""
        return self._current_volume

    @Slot(result=str)
    def get_current_file(self):
        """Get current track name (for compatibility with MediaManager)"""
        return self._current_track.get('name', '')
