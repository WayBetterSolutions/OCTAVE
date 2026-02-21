"""
Callback-based progress handler for OCTAVE music_dl.
Replaces the Rich TUI-based progress handler from spotdl.
"""

import logging
from typing import Any, Callable, Dict, List, Optional

from backend.music_dl.types.song import Song
from backend.music_dl.utils.static import BAD_CHARS

__all__ = [
    "ProgressHandler",
    "SongTracker",
    "ProgressHandlerError",
]

logger = logging.getLogger(__name__)


class ProgressHandlerError(Exception):
    """
    Base class for all exceptions raised by ProgressHandler subclasses.
    """


class ProgressHandler:
    """
    Callback-based progress handler. Instead of Rich TUI, it invokes
    a callback function with progress updates that DownloadManager
    can forward as Qt signals.
    """

    def __init__(
        self,
        simple_tui: bool = False,
        update_callback: Optional[Callable[[Any, str], None]] = None,
        web_ui: bool = False,
    ):
        self.songs: List[Song] = []
        self.song_count: int = 0
        self.overall_progress = 0
        self.overall_total = 100
        self.overall_completed_tasks = 0
        self.update_callback = update_callback
        self.previous_overall = self.overall_completed_tasks
        self.simple_tui = True  # Always use simple mode (no Rich)

    def add_song(self, song: Song) -> None:
        self.songs.append(song)
        self.set_song_count(len(self.songs))

    def set_songs(self, songs: List[Song]) -> None:
        self.songs = songs
        self.set_song_count(len(songs))

    def set_song_count(self, count: int) -> None:
        self.song_count = count
        self.overall_total = 100 * count

    def update_overall(self) -> None:
        if self.previous_overall != self.overall_completed_tasks:
            logger.info(
                "%s/%s complete", self.overall_completed_tasks, self.song_count
            )
            self.previous_overall = self.overall_completed_tasks

    def get_new_tracker(self, song: Song) -> "SongTracker":
        return SongTracker(self, song)

    def close(self) -> None:
        pass


class SongTracker:
    """
    Tracks the progress of a single song download.
    """

    def __init__(self, parent: ProgressHandler, song: Song) -> None:
        self.parent = parent
        self.song = song

        # Clean up the song name from weird unicode characters
        self.song_name = "".join(
            char
            for char in self.song.display_name
            if char not in [chr(i) for i in BAD_CHARS]
        )

        self.progress: int = 0
        self.old_progress: int = 0
        self.status = ""

    def update(self, message=""):
        old_message = self.status
        self.status = message

        delta = self.progress - self.old_progress

        # If task is complete
        if self.progress == 100 or message == "Error":
            self.parent.overall_completed_tasks += 1

        if old_message != self.status:
            logger.info("%s: %s", self.song_name, message)

        # Update the overall progress bar
        if self.parent.song_count == self.parent.overall_completed_tasks:
            self.parent.overall_progress = self.parent.song_count * 100
        else:
            self.parent.overall_progress += delta

        self.parent.update_overall()
        self.old_progress = self.progress

        if self.parent.update_callback:
            self.parent.update_callback(self, message)

    def notify_error(
        self, message: str, traceback: Exception, finish: bool = False
    ) -> None:
        self.update("Error")
        if finish:
            self.progress = 100

        if logger.getEffectiveLevel() == logging.DEBUG:
            logger.exception(message)
        else:
            logger.error("%s: %s", traceback.__class__.__name__, traceback)

    def notify_download_complete(self, status="Converting") -> None:
        self.progress = 50
        self.update(status)

    def notify_conversion_complete(self, status="Embedding metadata") -> None:
        self.progress = 95
        self.update(status)

    def notify_complete(self, status="Done") -> None:
        self.progress = 100
        self.update(status)

    def notify_download_skip(self, status="Skipped") -> None:
        self.progress = 100
        self.update(status)

    def ffmpeg_progress_hook(self, progress: int) -> None:
        self.progress = 50
        self.update("Converting")

    def yt_dlp_progress_hook(self, data: Dict[str, Any]) -> None:
        if data["status"] == "downloading":
            file_bytes = data.get("total_bytes")
            if file_bytes is None:
                file_bytes = data.get("total_bytes_estimate")

            downloaded_bytes = data.get("downloaded_bytes")
            if file_bytes and downloaded_bytes:
                self.progress = int(downloaded_bytes / file_bytes * 50)

            self.update("Downloading")
