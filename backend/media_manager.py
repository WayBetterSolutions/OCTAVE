"""
Media Manager for OCTAVE
Handles audio playback, playlist management, and album art processing.
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
from PySide6.QtCore import QUrl
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB
import os
import random
import re
import hashlib
import colorsys
import json
from PIL import Image
import numpy as np

from backend.logging_config import get_logger
logger = get_logger(__name__)


# =============================================================================
# Utility Functions
# =============================================================================

def is_safe_path(base_path, target_path):
    """Validate that target_path is within base_path (prevents path traversal attacks)."""
    base = os.path.normpath(os.path.realpath(base_path))
    target = os.path.normpath(os.path.realpath(target_path))
    return target.startswith(base + os.sep) or target == base


def sanitize_metadata(text, max_length=200):
    """Sanitize metadata strings from ID3 tags to prevent display issues."""
    if not isinstance(text, str):
        text = str(text) if text else ""
    sanitized = ''.join(char if (char.isprintable() or char in ' ') else ' ' for char in text)
    sanitized = ' '.join(sanitized.split())
    if len(sanitized) > max_length:
        sanitized = sanitized[:max_length - 3] + "..."
    return sanitized


def sort_key(filename):
    """Create a consistent sort key for filenames (removes punctuation, lowercases)."""
    return re.sub(r'[^\w\s]|_', '', filename.lower())


def format_duration_ms(ms):
    """Format milliseconds to hours:minutes:seconds string."""
    try:
        seconds = int(ms / 1000)
        minutes, seconds = divmod(seconds, 60)
        hours, minutes = divmod(minutes, 60)
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    except Exception:
        return "0:00:00"


def format_duration_seconds(seconds):
    """Format seconds to minutes:seconds string."""
    minutes, secs = divmod(int(seconds), 60)
    return f"{minutes}:{secs:02d}"


# =============================================================================
# Album Art Color Extractor
# =============================================================================

class AlbumColorExtractor:
    """Extracts dominant colors from album art and generates theme palettes."""

    @staticmethod
    def extract_colors(image_path):
        """Extract dominant colors from album art image using k-means clustering."""
        try:
            img = Image.open(image_path).convert('RGB')
            try:
                resample = Image.Resampling.LANCZOS
            except AttributeError:
                resample = Image.LANCZOS
            img = img.resize((100, 100), resample)

            pixels = np.array(img).reshape(-1, 3)
            colors = AlbumColorExtractor._kmeans_colors(pixels, k=5)

            # Sort by vibrancy (saturation * brightness)
            colors = sorted(colors, key=AlbumColorExtractor._color_vibrancy, reverse=True)

            # Calculate average luminance
            avg_luminance = np.mean([AlbumColorExtractor._luminance(p) for p in pixels[:1000]])
            is_dark_image = avg_luminance < 0.5

            return AlbumColorExtractor._generate_theme(colors, is_dark_image)

        except Exception as e:
            logger.debug(f"Error extracting colors: {e}")
            return None

    @staticmethod
    def _kmeans_colors(pixels, k=5, max_iterations=10):
        """Simple k-means clustering to find dominant colors."""
        np.random.seed(42)
        indices = np.random.choice(len(pixels), k, replace=False)
        centroids = pixels[indices].astype(float)

        for _ in range(max_iterations):
            distances = np.sqrt(((pixels[:, np.newaxis] - centroids) ** 2).sum(axis=2))
            labels = np.argmin(distances, axis=1)
            new_centroids = np.array([
                pixels[labels == i].mean(axis=0) if np.sum(labels == i) > 0 else centroids[i]
                for i in range(k)
            ])
            if np.allclose(centroids, new_centroids):
                break
            centroids = new_centroids

        return centroids.astype(int).tolist()

    @staticmethod
    def _color_vibrancy(rgb):
        """Calculate color vibrancy (saturation * brightness)."""
        r, g, b = rgb[0] / 255, rgb[1] / 255, rgb[2] / 255
        _, s, v = colorsys.rgb_to_hsv(r, g, b)
        return s * v

    @staticmethod
    def _luminance(rgb):
        """Calculate relative luminance."""
        r, g, b = rgb[0] / 255, rgb[1] / 255, rgb[2] / 255
        return 0.299 * r + 0.587 * g + 0.114 * b

    @staticmethod
    def _get_wcag_luminance(rgb):
        """Calculate WCAG relative luminance for contrast calculations."""
        def channel_lum(c):
            c = c / 255.0
            return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
        return 0.2126 * channel_lum(rgb[0]) + 0.7152 * channel_lum(rgb[1]) + 0.0722 * channel_lum(rgb[2])

    @staticmethod
    def _contrast_ratio(rgb1, rgb2):
        """Calculate WCAG contrast ratio between two colors."""
        l1, l2 = AlbumColorExtractor._get_wcag_luminance(rgb1), AlbumColorExtractor._get_wcag_luminance(rgb2)
        lighter, darker = max(l1, l2), min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)

    @staticmethod
    def _adjust_brightness(rgb, factor):
        """Adjust brightness of RGB color."""
        r, g, b = rgb[0] / 255, rgb[1] / 255, rgb[2] / 255
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        v = max(0, min(1, v * factor))
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        return [int(r * 255), int(g * 255), int(b * 255)]

    @staticmethod
    def _adjust_saturation(rgb, factor):
        """Adjust saturation of RGB color."""
        r, g, b = rgb[0] / 255, rgb[1] / 255, rgb[2] / 255
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        s = max(0, min(1, s * factor))
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        return [int(r * 255), int(g * 255), int(b * 255)]

    @staticmethod
    def _cap_brightness(rgb, max_brightness=0.85):
        """Cap brightness to prevent overly bright colors."""
        r, g, b = rgb[0] / 255, rgb[1] / 255, rgb[2] / 255
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if v > max_brightness:
            v = max_brightness
            s = min(1.0, s * 1.1)
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        return [int(r * 255), int(g * 255), int(b * 255)]

    @staticmethod
    def _rgb_to_hex(rgb):
        """Convert RGB list to hex string."""
        return "#{:02x}{:02x}{:02x}".format(int(rgb[0]), int(rgb[1]), int(rgb[2]))

    @staticmethod
    def _get_readable_text_color(background_rgb):
        """Return white or black text based on background luminance."""
        lum = AlbumColorExtractor._get_wcag_luminance(background_rgb)
        return [245, 245, 245] if lum < 0.3 else [25, 25, 25]

    @staticmethod
    def _get_secondary_text_color(background_rgb):
        """Return secondary text color with good contrast but less prominent."""
        lum = AlbumColorExtractor._get_wcag_luminance(background_rgb)
        return [210, 210, 210] if lum < 0.3 else [60, 60, 60]

    @staticmethod
    def _ensure_icon_contrast(icon_rgb, background_rgb, min_contrast=3.0):
        """Ensure icon color has sufficient contrast against background."""
        contrast = AlbumColorExtractor._contrast_ratio(icon_rgb, background_rgb)
        if contrast >= min_contrast:
            return AlbumColorExtractor._cap_brightness(icon_rgb)

        bg_lum = AlbumColorExtractor._get_wcag_luminance(background_rgb)
        adjusted = icon_rgb[:]

        if bg_lum < 0.5:
            # Dark background - brighten the icon
            for factor in [1.3, 1.5, 1.8, 2.0, 2.5, 3.0]:
                adjusted = AlbumColorExtractor._adjust_brightness(icon_rgb, factor)
                if AlbumColorExtractor._contrast_ratio(adjusted, background_rgb) >= min_contrast:
                    return AlbumColorExtractor._cap_brightness(adjusted)
            return [200, 180, 130]  # Fallback muted gold
        else:
            # Light background - darken the icon
            for factor in [0.7, 0.5, 0.4, 0.3, 0.2]:
                adjusted = AlbumColorExtractor._adjust_brightness(icon_rgb, factor)
                if AlbumColorExtractor._contrast_ratio(adjusted, background_rgb) >= min_contrast:
                    return adjusted
            return [50, 40, 30]  # Fallback dark

    @staticmethod
    def _generate_theme(colors, is_dark):
        """Generate a complete theme palette from extracted colors."""
        adj_bright = AlbumColorExtractor._adjust_brightness
        adj_sat = AlbumColorExtractor._adjust_saturation
        to_hex = AlbumColorExtractor._rgb_to_hex
        ensure_contrast = AlbumColorExtractor._ensure_icon_contrast
        get_text = AlbumColorExtractor._get_readable_text_color
        get_secondary = AlbumColorExtractor._get_secondary_text_color

        # Get primary colors from palette
        primary = colors[0]
        secondary = colors[1] if len(colors) > 1 else primary
        tertiary = colors[2] if len(colors) > 2 else secondary
        quaternary = colors[3] if len(colors) > 3 else tertiary

        # Create accent colors with contrast
        accent = adj_bright(adj_sat(primary, 1.4), 1.2)
        accent2 = adj_bright(adj_sat(secondary, 1.3), 1.15)
        accent3 = adj_bright(adj_sat(tertiary, 1.25), 1.1)
        accent4 = adj_bright(adj_sat(quaternary, 1.2), 1.05)

        # Navigation colors (dimmer)
        nav_color = adj_bright(accent, 0.7)
        nav_color2 = adj_bright(accent2, 0.75)

        # Base colors based on theme
        if is_dark:
            base = adj_bright(primary, 0.15)
            base_alt = adj_bright(primary, 0.22)
            hover = adj_bright(primary, 0.30)
            paused = adj_bright(primary, 0.25)
            playing = adj_bright(primary, 0.35)
        else:
            base = adj_sat(adj_bright(primary, 2.5), 0.3)
            base_alt = adj_bright(base, 0.92)
            hover = adj_bright(base, 0.88)
            paused = adj_bright(base, 0.85)
            playing = adj_bright(base, 0.80)

        # Text colors
        text_primary = get_text(base)
        text_secondary = get_secondary(base)

        # Ensure icon visibility
        accent_vis = ensure_contrast(accent, base)
        accent2_vis = ensure_contrast(accent2, base)
        accent3_vis = ensure_contrast(accent3, base)
        accent4_vis = ensure_contrast(accent4, base)
        nav_vis = ensure_contrast(nav_color, base)
        nav2_vis = ensure_contrast(nav_color2, base)

        theme = {
            "base": to_hex(base),
            "baseAlt": to_hex(base_alt),
            "accent": to_hex(accent_vis),
            "text": {
                "primary": to_hex(text_primary),
                "secondary": to_hex(text_secondary)
            },
            "states": {
                "hover": to_hex(hover),
                "paused": to_hex(paused),
                "playing": to_hex(playing)
            },
            "sliders": {
                "volume": to_hex(accent_vis),
                "media": to_hex(accent2_vis),
                "settings": to_hex(accent3_vis)
            },
            "bottombar": {
                "previous": to_hex(nav_vis),
                "play": to_hex(accent_vis),
                "pause": to_hex(accent_vis),
                "next": to_hex(nav_vis),
                "volume": to_hex(accent2_vis),
                "shuffle": to_hex(accent3_vis),
                "toggleShade": to_hex(hover),
                "homeButton": to_hex(accent_vis),
                "obdButton": to_hex(accent4_vis),
                "mediaButton": to_hex(accent2_vis),
                "settingsButton": to_hex(accent3_vis),
                "androidAutoButton": to_hex(nav2_vis),
                "phoneMirrorButton": to_hex(accent4_vis)
            },
            "mediaroom": {
                "previous": to_hex(nav_vis),
                "play": to_hex(ensure_contrast(adj_bright(accent, 1.1), base)),
                "pause": to_hex(ensure_contrast(adj_bright(accent, 1.1), base)),
                "next": to_hex(nav_vis),
                "left": to_hex(accent4_vis),
                "right": to_hex(accent4_vis),
                "shuffle": to_hex(accent3_vis),
                "toggleShade": to_hex(paused)
            },
            "mainmenu": {
                "mediaContainer": to_hex(adj_bright(accent2_vis, 0.6))
            },
            "obd": {
                "boxBackground": to_hex(base_alt),
                "barColor": to_hex(ensure_contrast(accent4, base_alt)),
                "labelColor": to_hex(get_secondary(base_alt)),
                "valueColor": to_hex(get_text(base_alt))
            }
        }

        return json.dumps(theme)


# =============================================================================
# Media Manager
# =============================================================================

class MediaManager(QObject):
    # Playback signals
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

    # Statistics signals
    totalDurationChanged = Signal(str)
    albumCountChanged = Signal(int)
    artistCountChanged = Signal(int)

    # Playlist signals
    playlistsChanged = Signal()
    currentPlaylistChanged = Signal(str)
    scanProgress = Signal(str)

    # Theme signals
    albumColorsExtracted = Signal(str)

    def __init__(self):
        super().__init__()

        # Qt Media components
        self._player = QMediaPlayer()
        self._audio_output = QAudioOutput()
        self._player.setAudioOutput(self._audio_output)
        self._audio_output.setVolume(0.5)
        self._player.setProperty("probe-size", 10000000)
        self._player.setProperty("analyzeduration", 5000000)

        # Directories
        self.backend_dir = os.path.dirname(os.path.abspath(__file__))
        self.default_media_dir = os.path.join(self.backend_dir, 'media')
        self.media_dir = self.default_media_dir
        self.temp_dir = os.path.join(self.backend_dir, 'temp')

        # Playback state
        self._current_index = 0
        self._is_muted = False
        self._previous_volume = 0.5
        self._is_playing = False
        self._is_paused = True
        self._shuffle = False
        self._auto_play = False

        # Playlists
        self._original_files = []
        self._current_playlist = []
        self._library_root = ""
        self._playlists = {}
        self._playlist_names = []
        self._current_playlist_name = ""
        self._all_music_file_paths = {}
        self._is_all_music_active = False

        # Caching
        self._album_art_cache = {}
        self._metadata_cache = {}
        self._max_cache_files = 500
        self._metadata_cache_max = 1000
        self._access_count = {}

        # Album art theme state
        self._album_art_capture_active = False

        # Statistics cache
        self._stats_cache = {
            "total_duration_ms": 0,
            "total_duration_formatted": "0:00:00",
            "album_count": 0,
            "artist_count": 0,
            "is_valid": False
        }

        # Settings manager reference
        self._settings_manager = None

        # Connect signals
        self._player.durationChanged.connect(self.durationChanged.emit)
        self._player.positionChanged.connect(self.positionChanged.emit)
        self._player.mediaStatusChanged.connect(self._handle_media_status)
        self.currentMediaChanged.connect(self._on_media_changed_for_theme)

        # Position update timer
        self._position_timer = QTimer()
        self._position_timer.setInterval(100)
        self._position_timer.timeout.connect(self._update_position)
        self._position_timer.start()

        # Initialize directories
        self._ensure_directories()
        self._clear_temp_files()

    def __del__(self):
        """Clean up resources on destruction."""
        try:
            self._save_playback_state()
            self._clear_temp_files()
            if self._player:
                self._player.stop()
            if self._position_timer:
                self._position_timer.stop()
        except Exception:
            pass

    # ==================== Directory Management ====================

    def _ensure_directories(self):
        """Ensure required directories exist."""
        for directory in [self.media_dir, self.temp_dir]:
            try:
                if not os.path.exists(directory):
                    os.makedirs(directory)
                    logger.info(f"Created directory: {directory}")
            except Exception as e:
                logger.error(f"Error creating directory {directory}: {e}")

    @Slot()
    def _clear_temp_files(self):
        """Clear temporary files."""
        if os.path.exists(self.temp_dir):
            for file in os.listdir(self.temp_dir):
                try:
                    file_path = os.path.join(self.temp_dir, file)
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                except Exception as e:
                    logger.warning(f"Error removing temp file {file}: {e}")

        try:
            if not os.path.exists(self.temp_dir):
                os.makedirs(self.temp_dir)
        except Exception as e:
            logger.error(f"Error creating temp directory: {e}")

    # ==================== File Path Handling ====================

    def _get_file_path(self, filename):
        """Get the full file path for a filename, handling All Music multi-folder playlist."""
        if '..' in filename or filename.startswith('/') or filename.startswith('\\'):
            logger.warning(f"Rejected potentially unsafe filename: {filename}")
            return None

        if filename in self._all_music_file_paths:
            directory = self._all_music_file_paths[filename]
            if " - " in filename and not os.path.exists(os.path.join(directory, filename)):
                original_filename = filename.split(" - ", 1)[1]
                file_path = os.path.join(directory, original_filename)
            else:
                file_path = os.path.join(directory, filename)
        else:
            file_path = os.path.join(self.media_dir, filename)

        if self._library_root and not is_safe_path(self._library_root, file_path):
            logger.warning(f"Path validation failed - file outside library: {file_path}")
            return None

        return file_path

    def _get_original_filename(self, filename):
        """Get the original filename (without folder prefix for All Music duplicates)."""
        if " - " in filename and filename in self._all_music_file_paths:
            parts = filename.split(" - ", 1)
            if len(parts) == 2:
                potential_original = parts[1]
                if potential_original in self._all_music_file_paths:
                    return potential_original
        return filename

    # ==================== Metadata Handling ====================

    def _cache_metadata(self, filename):
        """Cache metadata for a file to reduce disk operations."""
        if filename in self._metadata_cache:
            return

        try:
            file_path = self._get_file_path(filename)
            display_name = self._get_original_filename(filename)

            if len(self._metadata_cache) >= self._metadata_cache_max:
                self._metadata_cache.pop(next(iter(self._metadata_cache)))

            audio = ID3(file_path)
            mp3 = MP3(file_path)

            self._metadata_cache[filename] = {
                "artist": self._extract_id3_text(audio.get('TPE1'), "Unknown Artist"),
                "album": self._extract_id3_text(audio.get('TALB'), "Unknown Album"),
                "title": self._extract_id3_text(audio.get('TIT2'), display_name.replace('.mp3', '')),
                "duration": int(mp3.info.length)
            }
        except Exception as e:
            logger.debug(f"Metadata caching error for {filename}: {e}")
            display_name = self._get_original_filename(filename)
            self._metadata_cache[filename] = {
                "artist": "Unknown Artist",
                "album": "Unknown Album",
                "title": display_name.replace('.mp3', ''),
                "duration": 0
            }

    def _extract_id3_text(self, tag, default=""):
        """Safely extract and sanitize text from ID3 tags."""
        if tag is None:
            return sanitize_metadata(default)
        if isinstance(tag, str):
            return sanitize_metadata(tag)
        if hasattr(tag, 'text') and tag.text:
            return sanitize_metadata(tag.text[0])
        return sanitize_metadata(str(tag)) if tag else sanitize_metadata(default)

    def _emit_metadata(self, filename):
        """Emit metadata change signals."""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)

        meta = self._metadata_cache[filename]
        self.metadataChanged.emit(
            meta.get("title", filename.replace('.mp3', '')),
            meta.get("artist", "Unknown Artist"),
            meta.get("album", "Unknown Album")
        )

    @Slot(str, result=str)
    def get_formatted_duration(self, filename):
        """Get formatted duration string (MM:SS)."""
        try:
            if filename not in self._metadata_cache:
                self._cache_metadata(filename)

            duration_seconds = self._metadata_cache[filename]["duration"]
            formatted = format_duration_seconds(duration_seconds)
            self.durationFormatChanged.emit(formatted)
            return formatted
        except Exception as e:
            logger.debug(f"Error getting duration: {e}")
            return "0:00"

    @Slot(str, result=str)
    def get_band(self, filename):
        """Get artist name from metadata."""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)
        return self._metadata_cache[filename]["artist"]

    @Slot(str, result=str)
    def get_album(self, filename):
        """Get album name from metadata."""
        if filename not in self._metadata_cache:
            self._cache_metadata(filename)
        return self._metadata_cache[filename]["album"]

    # ==================== Album Art ====================

    def _get_album_id(self, filename):
        """Create a unique ID for album art caching."""
        try:
            if filename not in self._metadata_cache:
                self._cache_metadata(filename)
            meta = self._metadata_cache[filename]
            return f"{meta['album']}_{meta['artist']}"
        except Exception:
            return hashlib.sha256(filename.encode('utf-8')).hexdigest()[:16]

    def _manage_cache(self, new_album_id):
        """LRU cache management for album art."""
        try:
            if len(self._album_art_cache) >= self._max_cache_files:
                items = [(k, v) for k, v in self._access_count.items() if k != new_album_id]
                if not items:
                    return

                least_used = min(items, key=lambda x: x[1])[0]

                if least_used in self._album_art_cache:
                    file_path = self._album_art_cache[least_used].replace('file:///', '')
                    try:
                        if os.path.exists(file_path):
                            os.remove(file_path)
                    except Exception as e:
                        logger.warning(f"Could not remove file {file_path}: {e}")
                    finally:
                        del self._album_art_cache[least_used]
                        del self._access_count[least_used]

                logger.debug(f"Cache managed. New size: {len(self._album_art_cache)}")
        except Exception as e:
            logger.error(f"Cache management error: {e}")

    @Slot(str, result=str)
    def get_album_art(self, filename):
        """Extract and cache album art."""
        try:
            album_id = self._get_album_id(filename)
            self._access_count[album_id] = self._access_count.get(album_id, 0) + 1

            if album_id in self._album_art_cache:
                return self._album_art_cache[album_id]

            self._manage_cache(album_id)

            file_path = self._get_file_path(filename)
            audio = ID3(file_path)

            for tag in audio.values():
                if tag.FrameID == 'APIC':
                    mime = tag.mime.lower()
                    ext = {'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png', 'image/gif': 'gif'}.get(mime, 'img')

                    cache_hash = hashlib.sha256(album_id.encode('utf-8')).hexdigest()[:16]
                    temp_path = os.path.join(self.temp_dir, f'cover_{cache_hash}.{ext}')

                    with open(temp_path, 'wb') as img_file:
                        img_file.write(tag.data)

                    url = QUrl.fromLocalFile(temp_path).toString()
                    self._album_art_cache[album_id] = url
                    return url

            return ""
        except Exception as e:
            logger.debug(f"Error getting album art: {e}")
            return ""

    @Slot(str)
    def extract_colors_from_album_art(self, filename):
        """Extract colors from album art and emit signal with theme colors."""
        logger.debug(f"extract_colors_from_album_art called with: {filename}")
        try:
            art_url = self.get_album_art(filename)
            if not art_url:
                logger.debug(f"No album art found for: {filename}")
                return

            qurl = QUrl(art_url)
            image_path = qurl.toLocalFile()

            if not image_path or not os.path.exists(image_path):
                logger.debug(f"Album art file not found: {image_path}")
                return

            theme_json = AlbumColorExtractor.extract_colors(image_path)
            if theme_json:
                if self._settings_manager:
                    self._settings_manager.set_album_art_colors(theme_json)
                    logger.debug(f"Called set_album_art_colors for: {filename}")
                else:
                    self.albumColorsExtracted.emit(theme_json)
                    logger.debug(f"Emitted via mediaManager for: {filename}")
        except Exception as e:
            logger.error(f"Error extracting colors from album art: {e}", exc_info=True)

    # ==================== Media File Access ====================

    @Slot(result=list)
    def get_media_files(self, emit_signal=True):
        """Get list of available MP3 files."""
        mp3_files = []
        try:
            if os.path.exists(self.media_dir):
                for file in os.listdir(self.media_dir):
                    if file.lower().endswith('.mp3'):
                        mp3_files.append(file)
                if emit_signal:
                    self.mediaListChanged.emit(mp3_files)
        except Exception as e:
            logger.error(f"Error getting media files: {e}")
        return mp3_files

    def _get_current_playlist_files(self):
        """Get the files for the currently selected playlist."""
        if self._current_playlist_name and self._current_playlist_name in self._playlists:
            return self._playlists[self._current_playlist_name]["files"].copy()
        return self._current_playlist.copy() if self._current_playlist else []

    @Slot(result=str)
    def get_current_file(self):
        """Get currently playing file without auto-playing."""
        if not self._current_playlist:
            files = self._get_current_playlist_files()
            if files:
                self._current_playlist = sorted(files, key=sort_key)
                self._current_index = 0
                return self._current_playlist[0]

        if 0 <= self._current_index < len(self._current_playlist):
            return self._current_playlist[self._current_index]

        files = self._get_current_playlist_files()
        if files:
            self._current_playlist = sorted(files, key=sort_key)
            self._current_index = 0
            return self._current_playlist[0]

        return ""

    # ==================== Playback Control ====================

    def _update_position(self):
        """Update position for UI slider."""
        if self._player.playbackState() == QMediaPlayer.PlayingState:
            self.positionChanged.emit(self._player.position())

    def _handle_media_status(self, status):
        """Handle media status changes."""
        try:
            if status == QMediaPlayer.MediaStatus.EndOfMedia:
                logger.debug("Song ended, playing next track")
                self.next_track()
        except Exception as e:
            logger.error(f"Media status handling error: {e}")

    @Slot(str)
    def play_file(self, filename):
        """Play specified file."""
        if not self._current_playlist:
            try:
                files = self._get_current_playlist_files()
                self._current_playlist = self._shuffle_playlist() if self._shuffle else sorted(files, key=sort_key)
            except Exception as e:
                logger.error(f"Error initializing playlist: {e}")
                self._current_playlist = []

        if not self._current_playlist:
            logger.warning("No media files available to play")
            return

        try:
            if filename in self._current_playlist:
                self._current_index = self._current_playlist.index(filename)
            elif not self._shuffle:
                files = self._get_current_playlist_files()
                self._current_playlist = sorted(files, key=sort_key)
                if filename in self._current_playlist:
                    self._current_index = self._current_playlist.index(filename)
                else:
                    filename = self._current_playlist[0] if self._current_playlist else ""
                    self._current_index = 0
        except Exception as e:
            logger.error(f"Error finding file in playlist: {e}")
            self._current_index = 0
            if self._current_playlist:
                filename = self._current_playlist[0]
            else:
                return

        file_path = self._get_file_path(filename)
        if os.path.exists(file_path):
            try:
                url = QUrl.fromLocalFile(file_path)
                self._player.setSource(url)
                self._player.play()
                self._is_playing = True
                self._is_paused = False

                if self._is_muted:
                    self._audio_output.setVolume(0.0)

                self.playStateChanged.emit(True)
                self.currentMediaChanged.emit(filename)
                self._emit_metadata(filename)
                self.get_formatted_duration(filename)
                logger.info(f"Now playing: {filename} at position {self._current_index}")

            except Exception as e:
                logger.error(f"Playback error: {e}")
        else:
            logger.warning(f"File not found: {file_path}")

    @Slot()
    def next_track(self):
        """Play next track in playlist."""
        try:
            if not self._current_playlist:
                files = self._get_current_playlist_files()
                self._current_playlist = sorted(files, key=sort_key)

            if not self._current_playlist:
                logger.warning("No media files available")
                return

            self._current_index = (self._current_index + 1) % len(self._current_playlist)
            self.play_file(self._current_playlist[self._current_index])
            self._save_playback_state()
        except Exception as e:
            logger.error(f"Error in next_track: {e}")

    @Slot()
    def previous_track(self):
        """Play previous track in playlist."""
        try:
            if not self._current_playlist:
                files = self._get_current_playlist_files()
                self._current_playlist = sorted(files, key=sort_key)

            if not self._current_playlist:
                logger.warning("No media files available")
                return

            self._current_index = (self._current_index - 1) % len(self._current_playlist)
            self.play_file(self._current_playlist[self._current_index])
            self._save_playback_state()
        except Exception as e:
            logger.error(f"Error in previous_track: {e}")

    @Slot()
    def pause(self):
        """Pause playback."""
        self._player.pause()
        self._is_paused = True
        self._is_playing = False
        self.playStateChanged.emit(False)
        self._save_playback_state()

    @Slot()
    def toggle_play(self):
        """Toggle play/pause state."""
        if not self._player.source().isValid():
            current_file = self.get_current_file()
            if current_file:
                self.play_file(current_file)
                return

        if self._is_playing:
            self._player.pause()
            self._is_paused = True
            self._is_playing = False
            self._save_playback_state()
        else:
            self._player.play()
            self._is_paused = False
            self._is_playing = True
            if self._is_muted:
                self._audio_output.setVolume(0.0)

        self.playStateChanged.emit(self._is_playing)

    @Slot(result=bool)
    def is_playing(self):
        """Return current playing state."""
        return self._is_playing

    @Slot(result=bool)
    def is_paused(self):
        """Return current paused state."""
        return self._is_paused

    @Slot(result=float)
    def get_duration(self):
        """Get current media duration in ms."""
        return self._player.duration()

    @Slot(result=float)
    def get_position(self):
        """Get current playback position in ms."""
        return self._player.position()

    @Slot(int)
    def set_position(self, position):
        """Set playback position in ms."""
        self._player.setPosition(position)

    # ==================== Volume Control ====================

    @Slot()
    def toggle_mute(self):
        """Toggle mute state."""
        if self._is_muted:
            self._audio_output.setVolume(self._previous_volume)
        else:
            self._previous_volume = self._audio_output.volume()
            self._audio_output.setVolume(0.0)

        self._is_muted = not self._is_muted
        self.muteChanged.emit(self._is_muted)
        logger.debug(f"Mute toggled: {self._is_muted}")

    @Slot(result=bool)
    def is_muted(self):
        """Return current mute state."""
        return self._is_muted

    @Slot(float)
    def setVolume(self, volume):
        """Set output volume (0.0-1.0)."""
        try:
            volume = max(0.0, min(1.0, float(volume)))

            if self._is_muted:
                self._previous_volume = volume
                self._audio_output.setVolume(0.0)
            else:
                self._audio_output.setVolume(volume)

            self.volumeChanged.emit(volume)
        except Exception as e:
            logger.error(f"Error setting volume: {e}")

    @Slot(result=float)
    def getVolume(self):
        """Get current volume level (0.0-1.0)."""
        return self._audio_output.volume()

    # ==================== Shuffle ====================

    def _shuffle_playlist(self):
        """Create shuffled playlist from current playlist files."""
        files = self._get_current_playlist_files()
        if not files:
            files = self.get_media_files()
        if not files:
            return []
        shuffled = files.copy()
        random.shuffle(shuffled)
        return shuffled

    @Slot()
    def toggle_shuffle(self):
        """Toggle shuffle mode."""
        self._shuffle = not self._shuffle
        self.shuffleStateChanged.emit(self._shuffle)

        current_song = self.get_current_file()
        files = self._get_current_playlist_files()

        if self._shuffle:
            if not self._original_files:
                self._original_files = files.copy()

            shuffled = files.copy()
            random.shuffle(shuffled)

            if current_song in shuffled:
                idx = shuffled.index(current_song)
                if idx > 0:
                    shuffled[0], shuffled[idx] = shuffled[idx], shuffled[0]

            self._current_playlist = shuffled
            self._current_index = 0
            logger.info(f"Shuffle enabled, starting from: {current_song}")
        else:
            alphabetical = sorted(files, key=sort_key)

            if current_song and current_song in alphabetical:
                self._current_index = alphabetical.index(current_song)
                self._current_playlist = alphabetical
                logger.info(f"Shuffle disabled, continuing from: {current_song}")
            else:
                self._current_playlist = alphabetical
                self._current_index = 0

        if not self._shuffle:
            self._original_files = []

        self.mediaListChanged.emit(self._current_playlist)

    @Slot(result=bool)
    def is_shuffled(self):
        """Return current shuffle state."""
        return self._shuffle

    # ==================== Playlist Management ====================

    @Slot()
    def scan_library(self):
        """Scan the library root for subfolders (playlists) and their MP3s."""
        if not self._library_root or not os.path.exists(self._library_root):
            self.scanProgress.emit("[ERROR] Library path not set or doesn't exist")
            logger.warning(f"Library root not set or doesn't exist: {self._library_root}")
            return

        self.scanProgress.emit("[SCAN] Starting library scan...")
        self.scanProgress.emit(f"[PATH] {self._library_root}")
        logger.info(f"Scanning library at: {self._library_root}")

        # Clear caches
        self._playlists = {}
        self._playlist_names = []
        self._metadata_cache = {}
        self._album_art_cache = {}
        self._access_count = {}
        self._all_music_file_paths = {}
        self._is_all_music_active = False
        self.invalidate_stats_cache()
        self.scanProgress.emit("[CLEAR] Caches cleared")

        all_music_files = []

        # Check root-level MP3s
        self.scanProgress.emit("[SCAN] Checking root folder for MP3s...")
        root_mp3s = []
        try:
            for item in os.listdir(self._library_root):
                item_path = os.path.join(self._library_root, item)
                if os.path.isfile(item_path) and item.lower().endswith('.mp3'):
                    root_mp3s.append(item)
                    self._all_music_file_paths[item] = self._library_root
                    all_music_files.append(item)
        except Exception as e:
            self.scanProgress.emit(f"[ERROR] Failed to scan root: {e}")
            logger.error(f"Error scanning root for MP3s: {e}")

        if root_mp3s:
            self._playlists["Unsorted"] = {
                "name": "Unsorted",
                "path": self._library_root,
                "files": root_mp3s,
                "song_count": len(root_mp3s)
            }
            self._playlist_names.append("Unsorted")
            self.scanProgress.emit(f"[FOUND] 'Unsorted' - {len(root_mp3s)} songs")

        # Scan subfolders
        self.scanProgress.emit("[SCAN] Scanning subfolders...")
        try:
            subfolders = [item for item in os.listdir(self._library_root)
                         if os.path.isdir(os.path.join(self._library_root, item))]
            self.scanProgress.emit(f"[INFO] Found {len(subfolders)} subfolders to scan")

            for item in subfolders:
                subfolder_path = os.path.join(self._library_root, item)
                mp3_files = []
                try:
                    for f in os.listdir(subfolder_path):
                        if f.lower().endswith('.mp3'):
                            mp3_files.append(f)
                            unique_name = f
                            if f in self._all_music_file_paths:
                                unique_name = f"{item} - {f}"
                            self._all_music_file_paths[unique_name] = subfolder_path
                            all_music_files.append(unique_name)
                except Exception as e:
                    self.scanProgress.emit(f"[ERROR] Failed to scan '{item}': {e}")
                    continue

                if mp3_files:
                    self._playlists[item] = {
                        "name": item,
                        "path": subfolder_path,
                        "files": mp3_files,
                        "song_count": len(mp3_files)
                    }
                    self._playlist_names.append(item)
                    self.scanProgress.emit(f"[FOUND] '{item}' - {len(mp3_files)} songs")
        except Exception as e:
            self.scanProgress.emit(f"[ERROR] Failed to scan subfolders: {e}")
            logger.error(f"Error scanning library subfolders: {e}")

        # Create "All Music" playlist
        if all_music_files:
            self._playlists["All Music"] = {
                "name": "All Music",
                "path": self._library_root,
                "files": all_music_files,
                "song_count": len(all_music_files),
                "is_combined": True
            }
            self.scanProgress.emit(f"[FOUND] 'All Music' - {len(all_music_files)} songs (combined)")

        # Sort playlist names
        if "Unsorted" in self._playlist_names:
            self._playlist_names.remove("Unsorted")
        self._playlist_names.sort(key=str.lower)

        if "Unsorted" in self._playlists:
            self._playlist_names.insert(0, "Unsorted")
        if "All Music" in self._playlists:
            self._playlist_names.insert(0, "All Music")

        self.scanProgress.emit(f"[DONE] Scan complete: {len(self._playlist_names)} playlists, {len(all_music_files)} total songs")
        logger.info(f"Library scan complete. Found {len(self._playlist_names)} playlists")

        self.playlistsChanged.emit()

    @Slot(str)
    def set_library_root(self, path):
        """Set the main library folder and scan for playlists."""
        if not path:
            logger.warning("Invalid library path: empty path")
            return

        normalized_path = os.path.normpath(os.path.realpath(path))

        if os.path.exists(normalized_path) and os.path.isdir(normalized_path):
            self._library_root = normalized_path
            logger.info(f"Library root set to: {normalized_path}")
            self.scan_library()

            if self._playlist_names:
                self.select_playlist(self._playlist_names[0])
        else:
            logger.warning(f"Invalid library path: {path}")

    @Slot(result=list)
    def get_playlist_names(self):
        """Return list of all playlist names."""
        return self._playlist_names

    @Slot(str)
    def select_playlist(self, name):
        """Select a playlist and load its songs."""
        if name not in self._playlists:
            logger.warning(f"Playlist not found: {name}")
            return

        logger.info(f"Selecting playlist: {name}")

        self._current_playlist_name = name
        playlist = self._playlists[name]

        self._is_all_music_active = playlist.get("is_combined", False)

        if self._is_all_music_active:
            self.media_dir = self._library_root
        else:
            self.media_dir = playlist["path"]

        self._current_playlist = sorted(playlist["files"], key=sort_key)
        self._current_index = 0

        self.invalidate_stats_cache()
        self._metadata_cache = {}

        self.currentPlaylistChanged.emit(name)
        self.mediaListChanged.emit(self._current_playlist)

    @Slot(result=str)
    def get_current_playlist_name(self):
        """Return current playlist name."""
        return self._current_playlist_name

    # ==================== Statistics ====================

    @Slot()
    def invalidate_stats_cache(self):
        """Mark the statistics cache as invalid to force recalculation."""
        self._stats_cache["is_valid"] = False

    def _calculate_all_stats(self):
        """Calculate all statistics at once and cache the results."""
        if self._stats_cache["is_valid"]:
            return

        try:
            files = self._get_current_playlist_files()

            total_ms = 0
            albums = set()
            artists = set()

            for filename in files:
                if filename not in self._metadata_cache:
                    self._cache_metadata(filename)

                duration_seconds = self._metadata_cache[filename]["duration"]
                total_ms += duration_seconds * 1000

                album = self._metadata_cache[filename]["album"]
                if album and album != "Unknown Album":
                    albums.add(album)

                artist = self._metadata_cache[filename]["artist"]
                if artist and artist != "Unknown Artist":
                    artists.add(artist)

            self._stats_cache["total_duration_ms"] = total_ms
            self._stats_cache["total_duration_formatted"] = format_duration_ms(total_ms)
            self._stats_cache["album_count"] = len(albums)
            self._stats_cache["artist_count"] = len(artists)
            self._stats_cache["is_valid"] = True

            self.totalDurationChanged.emit(self._stats_cache["total_duration_formatted"])
            self.albumCountChanged.emit(self._stats_cache["album_count"])
            self.artistCountChanged.emit(self._stats_cache["artist_count"])

        except Exception as e:
            logger.error(f"Error calculating statistics: {e}")
            self._stats_cache["total_duration_ms"] = 0
            self._stats_cache["total_duration_formatted"] = "0:00:00"
            self._stats_cache["album_count"] = 0
            self._stats_cache["artist_count"] = 0

    @Slot(result=str)
    def get_total_duration(self):
        """Get the total duration of all media files as formatted string."""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["total_duration_formatted"]

    @Slot(result=int)
    def get_album_count(self):
        """Get the count of unique albums."""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["album_count"]

    @Slot(result=int)
    def get_artist_count(self):
        """Get the count of unique artists."""
        if not self._stats_cache["is_valid"]:
            self._calculate_all_stats()
        return self._stats_cache["artist_count"]

    @Slot(str, bool, result=list)
    def sort_media_files(self, sort_column, ascending=True):
        """Sort media files based on criteria."""
        try:
            files = self._current_playlist if self._current_playlist else self.get_media_files(emit_signal=False)

            if sort_column == "title":
                sorted_files = sorted(files, key=lambda x: sort_key(x.replace('.mp3', '')), reverse=not ascending)
            elif sort_column == "album":
                sorted_files = sorted(files, key=lambda x: sort_key(self.get_album(x)), reverse=not ascending)
            elif sort_column == "artist":
                sorted_files = sorted(files, key=lambda x: sort_key(self.get_band(x)), reverse=not ascending)
            else:
                sorted_files = files

            return sorted_files
        except Exception as e:
            logger.error(f"Error sorting media files: {e}")
            return []

    # ==================== Settings Integration ====================

    @Slot(QObject)
    def connect_settings_manager(self, settings_manager):
        """Connect to settings manager for persistence and configuration."""
        if self._settings_manager is not None:
            return

        self._settings_manager = settings_manager

        if self._settings_manager:
            self.set_library_root(self._settings_manager.mediaFolder)
            self._settings_manager.mediaFolderChanged.connect(self.set_library_root)

            QTimer.singleShot(500, self._restore_playback_state)

            self._settings_manager.themeSettingChanged.connect(self._on_theme_changed)

            current_theme = self._settings_manager.themeSetting
            self._album_art_capture_active = (current_theme == "Album Art Capture")

            if self._album_art_capture_active:
                QTimer.singleShot(1000, self._extract_colors_on_startup)

    def _on_theme_changed(self, theme):
        """Handle theme change - extract colors if Album Art Capture is selected."""
        logger.debug(f"Theme changed to: {theme}")
        self._album_art_capture_active = (theme == "Album Art Capture")

        if self._album_art_capture_active:
            current_file = self.get_current_file()
            if current_file:
                self.extract_colors_from_album_art(current_file)

    def _on_media_changed_for_theme(self, filename):
        """Handle media change - extract colors if Album Art Capture is active."""
        if self._album_art_capture_active and filename:
            logger.debug(f"Media changed, extracting colors for: {filename}")
            self.extract_colors_from_album_art(filename)

    def _extract_colors_on_startup(self):
        """Extract colors on startup if Album Art Capture theme is already active."""
        if self._album_art_capture_active:
            current_file = self.get_current_file()
            if current_file:
                self.extract_colors_from_album_art(current_file)

    def _restore_playback_state(self):
        """Restore last played song and position from settings."""
        if not self._settings_manager:
            return

        last_song = self._settings_manager.get_last_played_song()
        last_position = self._settings_manager.get_last_played_position()
        last_playlist = self._settings_manager.get_last_played_playlist()
        auto_play = self._settings_manager.get_auto_play_on_startup()

        logger.info(f"Restoring playback state: song={last_song}, position={last_position}, playlist={last_playlist}")

        if not last_song:
            return

        if last_playlist and last_playlist in self._playlists:
            self.select_playlist(last_playlist)

        if last_song not in self._current_playlist:
            logger.warning(f"Last played song '{last_song}' not found in current playlist")
            return

        file_path = self._get_file_path(last_song)
        if not os.path.exists(file_path):
            logger.warning(f"Last played file not found: {file_path}")
            return

        self._current_index = self._current_playlist.index(last_song)

        url = QUrl.fromLocalFile(file_path)
        self._player.setSource(url)

        self.currentMediaChanged.emit(last_song)
        self._emit_metadata(last_song)
        self.get_formatted_duration(last_song)

        if last_position > 0:
            QTimer.singleShot(100, lambda: self._player.setPosition(last_position))

        if auto_play:
            QTimer.singleShot(500, self._player.play)
            QTimer.singleShot(500, lambda: self._set_playing_state(True))

        logger.info(f"Playback state restored: {last_song} at position {last_position}ms")

    def _set_playing_state(self, is_playing):
        """Helper to set playing state and emit signal."""
        self._is_playing = is_playing
        self._is_paused = not is_playing
        self.playStateChanged.emit(is_playing)

    @Slot()
    def _save_playback_state(self):
        """Save current playback state to settings."""
        if not self._settings_manager:
            return

        current_song = self.get_current_file()
        current_position = self._player.position()
        current_playlist = self._current_playlist_name

        if current_song:
            self._settings_manager.save_playback_state(current_song, current_position, current_playlist)

    def update_media_directory(self, directory):
        """Update the media directory and refresh file list."""
        if os.path.exists(directory) and os.path.isdir(directory):
            self.media_dir = directory

            self._metadata_cache = {}
            self._album_art_cache = {}
            self._access_count = {}
            self.invalidate_stats_cache()

            self.get_media_files()

            current_file = self.get_current_file()
            if self._is_playing and current_file and os.path.exists(self._get_file_path(current_file)):
                self.play_file(current_file)
            elif self._is_playing:
                files = self.get_media_files()
                if files:
                    self.play_file(files[0])
                else:
                    self._player.stop()
                    self._is_playing = False
                    self._is_paused = True
                    self.playStateChanged.emit(False)
        else:
            logger.warning(f"Directory {directory} does not exist or is not a directory")

    @Slot(result=str)
    def get_default_media_dir(self):
        """Return the default media directory path."""
        return self.default_media_dir

    @Slot(result=str)
    def get_media_folder_name(self):
        """Return just the folder name of the current media directory."""
        return os.path.basename(self.media_dir)
