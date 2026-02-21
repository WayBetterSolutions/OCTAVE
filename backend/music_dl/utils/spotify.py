"""
Spotify client module for OCTAVE music_dl (forked from spotdl).
Simplified: removed Singleton metaclass, uses module-level client instance.
"""

import json
import logging
from typing import Dict, Optional

import requests
from spotipy import Spotify
from spotipy.cache_handler import CacheFileHandler, MemoryCacheHandler
from spotipy.oauth2 import SpotifyClientCredentials, SpotifyOAuth

from backend.music_dl.utils.config import get_cache_path, get_spotify_cache_path

__all__ = [
    "SpotifyError",
    "SpotifyClient",
    "save_spotify_cache",
]

logger = logging.getLogger(__name__)

# Module-level client instance (replaces Singleton metaclass)
_spotify_instance: Optional["SpotifyClient"] = None


class SpotifyError(Exception):
    """
    Base class for all exceptions related to SpotifyClient.
    """


class SpotifyClient(Spotify):
    """
    Spotify client for music_dl. Must be initialized via SpotifyClient.init()
    before use. Subsequent SpotifyClient() calls return the existing instance.
    """

    _initialized = False
    cache: Dict[str, Optional[Dict]] = {}

    def __new__(cls, *args, **kwargs):
        global _spotify_instance
        if _spotify_instance is None:
            raise SpotifyError(
                "Spotify client not created. Call SpotifyClient.init("
                "client_id, client_secret) first."
            )
        return _spotify_instance

    def __init__(self, *args, **kwargs):
        # Skip re-init if already initialized
        if self._initialized:
            return
        super().__init__(*args, **kwargs)
        self._initialized = True

        use_cache_file: bool = getattr(self, 'use_cache_file', False)
        cache_file_loc = get_spotify_cache_path()

        if use_cache_file and cache_file_loc.exists():
            with open(cache_file_loc, "r", encoding="utf-8") as cache_file:
                self.cache = json.load(cache_file)
        elif use_cache_file:
            with open(cache_file_loc, "w", encoding="utf-8") as cache_file:
                json.dump(self.cache, cache_file)

    @classmethod
    def init(
        cls,
        client_id: str,
        client_secret: str,
        user_auth: bool = False,
        no_cache: bool = False,
        headless: bool = False,
        max_retries: int = 3,
        use_cache_file: bool = False,
        auth_token: Optional[str] = None,
        cache_path: Optional[str] = None,
    ) -> "SpotifyClient":
        global _spotify_instance

        if _spotify_instance is not None:
            raise SpotifyError("A spotify client has already been initialized")

        credential_manager = None
        cache_handler = (
            CacheFileHandler(cache_path or get_cache_path())
            if not no_cache
            else MemoryCacheHandler()
        )

        if user_auth:
            credential_manager = SpotifyOAuth(
                client_id=client_id,
                client_secret=client_secret,
                redirect_uri="http://127.0.0.1:9900/",
                scope="user-library-read,user-follow-read,playlist-read-private",
                cache_handler=cache_handler,
                open_browser=not headless,
            )
        else:
            credential_manager = SpotifyClientCredentials(
                client_id=client_id,
                client_secret=client_secret,
                cache_handler=cache_handler,
            )

        if auth_token is not None:
            credential_manager = None

        # Create the instance directly (bypass __new__ check)
        instance = Spotify.__new__(cls)
        instance.user_auth = user_auth
        instance.no_cache = no_cache
        instance.max_retries = max_retries
        instance.use_cache_file = use_cache_file
        instance._initialized = False

        # Initialize the Spotify base class
        Spotify.__init__(
            instance,
            auth=auth_token,
            auth_manager=credential_manager,
            status_forcelist=(429, 500, 502, 503, 504, 404),
        )
        instance._initialized = True

        # Handle cache file
        cache_file_loc = get_spotify_cache_path()
        if use_cache_file and cache_file_loc.exists():
            with open(cache_file_loc, "r", encoding="utf-8") as cache_file:
                instance.cache = json.load(cache_file)
        elif use_cache_file:
            with open(cache_file_loc, "w", encoding="utf-8") as cache_file:
                json.dump(instance.cache, cache_file)

        _spotify_instance = instance
        return instance

    @classmethod
    def reset(cls):
        """Reset the client instance (useful for re-initialization with new credentials)."""
        global _spotify_instance
        _spotify_instance = None
        cls._initialized = False
        cls.cache = {}

    def _get(self, url, args=None, payload=None, **kwargs):
        """Override get method for caching support."""
        use_cache = not self.no_cache

        if args:
            kwargs.update(args)

        cache_key = None
        if use_cache:
            key_obj = dict(kwargs)
            key_obj["url"] = url
            key_obj["data"] = json.dumps(payload)
            cache_key = json.dumps(key_obj)
            if self.cache.get(cache_key) is not None:
                return self.cache[cache_key]

        response = None
        retries = self.max_retries
        while response is None:
            try:
                response = self._internal_call("GET", url, payload, kwargs)
            except (requests.exceptions.Timeout, requests.ConnectionError) as exc:
                retries -= 1
                if retries <= 0:
                    raise exc

        if use_cache and cache_key is not None:
            self.cache[cache_key] = response

        return response


def save_spotify_cache(cache: Dict[str, Optional[Dict]]):
    """Save the Spotify cache to a file."""
    cache_file_loc = get_spotify_cache_path()
    logger.debug("Saving Spotify cache to %s", cache_file_loc)

    cache = {
        key: value
        for key, value in cache.items()
        if value is not None and "tracks/" in key
    }

    with open(cache_file_loc, "w", encoding="utf-8") as cache_file:
        json.dump(cache, cache_file)
