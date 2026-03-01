"""
MusicDL — OCTAVE's music download engine (forked from spotdl).
Provides search and download capabilities using Spotify metadata + YouTube audio.
"""

import asyncio
import concurrent.futures
import logging
from pathlib import Path
from typing import List, Optional, Tuple, Union

from backend.music_dl._version import __version__
from backend.music_dl.download.downloader import Downloader
from backend.music_dl.types.options import DownloaderOptionalOptions, DownloaderOptions
from backend.music_dl.types.song import Song
from backend.music_dl.utils.search import parse_query
from backend.music_dl.utils.spotify import SpotifyClient

__all__ = ["MusicDL", "__version__"]

logger = logging.getLogger(__name__)


class MusicDL:
    """
    Main entry point for OCTAVE's music download engine.

    Usage:
        from backend.music_dl import MusicDL

        dl = MusicDL(client_id='...', client_secret='...')
        songs = dl.search(['joji - test drive'])
        results = dl.download_songs(songs)
        song, path = dl.download(songs[0])
    """

    def __init__(
        self,
        client_id: str,
        client_secret: str,
        user_auth: bool = False,
        cache_path: Optional[str] = None,
        no_cache: bool = False,
        headless: bool = False,
        downloader_settings: Optional[
            Union[DownloaderOptionalOptions, DownloaderOptions]
        ] = None,
    ):
        if downloader_settings is None:
            downloader_settings = {}

        # Initialize spotify client only if credentials are provided
        self.has_spotify = bool(client_id and client_secret)
        if self.has_spotify:
            SpotifyClient.init(
                client_id=client_id,
                client_secret=client_secret,
                user_auth=user_auth,
                cache_path=cache_path,
                no_cache=no_cache,
                headless=headless,
            )

        # Initialize downloader
        self.downloader = Downloader(
            settings=downloader_settings,
        )

    def search(self, query: List[str]) -> List[Song]:
        """
        Search for songs.

        ### Arguments
        - query: List of search queries (song titles, Spotify URLs, etc.)

        ### Returns
        - A list of Song objects
        """

        return parse_query(
            query=query,
            threads=self.downloader.settings["threads"],
            use_ytm_data=self.downloader.settings["ytm_data"],
            playlist_numbering=self.downloader.settings["playlist_numbering"],
            album_type=self.downloader.settings["album_type"],
            playlist_retain_track_cover=self.downloader.settings[
                "playlist_retain_track_cover"
            ],
        )

    def get_download_urls(self, songs: List[Song]) -> List[Optional[str]]:
        """
        Get the download urls for a list of songs (multi-threaded).
        """

        urls: List[Optional[str]] = []
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=self.downloader.settings["threads"]
        ) as executor:
            future_to_song = {
                executor.submit(self.downloader.search, song): song for song in songs
            }
            for future in concurrent.futures.as_completed(future_to_song):
                song = future_to_song[future]
                try:
                    data = future.result()
                    urls.append(data)
                except Exception as exc:
                    logger.error("%s generated an exception: %s", song, exc)

        return urls

    def download(self, song: Song) -> Tuple[Song, Optional[Path]]:
        """Download and convert a single song."""
        return self.downloader.download_song(song)

    def download_songs(self, songs: List[Song]) -> List[Tuple[Song, Optional[Path]]]:
        """Download and convert multiple songs."""
        return self.downloader.download_multiple_songs(songs)

    def cleanup(self):
        """Clean up resources."""
        if self.has_spotify:
            try:
                SpotifyClient.reset()
            except Exception:
                pass
