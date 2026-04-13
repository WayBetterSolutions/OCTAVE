# Spotify Web API February 2026 Migration (Time-sensitive)

**Status:** Deferred but **time-sensitive**. Must be completed before **March 9, 2026** or OCTAVE's Spotify playlist browsing will break.

**Last updated:** 2026-04-11

---

## Background

In February 2026 Spotify tightened Development Mode restrictions and removed a large number of Web API endpoints. Announcement: https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security

**Relevant timelines:**
- **February 11, 2026** — new Development Mode Client IDs face the new restrictions immediately
- **March 9, 2026** — existing Development Mode integrations migrate to the new restrictions

Endpoint reference: https://developer.spotify.com/documentation/web-api/references/changes/february-2026
Migration guide: https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide

## Audit summary (performed 2026-04-11)

OCTAVE makes 13 distinct Spotify API calls in `backend/spotify_manager.py`. 12 of them hit endpoints that are kept. Exactly **one** call hits a removed endpoint.

### What breaks: `get_playlist_tracks()`

**Location:** `backend/spotify_manager.py:805-830`

**Current code:**
```python
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
        logger.error(f"Get playlist tracks error: {e}")
        return []
```

`sp.playlist_tracks()` in spotipy calls `GET /playlists/{id}/tracks`, which is **removed**. The replacement is `GET /playlists/{id}/items`, with two differences:
1. The path is `items`, not `tracks`
2. The response structure returns `item['item']` instead of `item['track']`

### Required change

```python
@Slot(str, result=list)
def get_playlist_tracks(self, playlist_id):
    """Get tracks from a playlist (uses the post-Feb-2026 /items endpoint)."""
    if not self._sp:
        return []
    try:
        # Spotipy may not expose a wrapper for /items yet; call the raw API.
        results = self._sp._get(f'playlists/{playlist_id}/items', limit=100)

        tracks = []
        for item in results.get('items', []):
            track = item.get('item')  # was 'track' pre-February 2026
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
        logger.error(f"Get playlist tracks error: {e}")
        self.errorOccurred.emit(f"Could not load playlist tracks: {e}")
        return []
```

**Verification needed before shipping:**
1. Confirm spotipy doesn't have a higher-level wrapper yet (`sp.playlist_items()`?). If it does, use it. Check whichever spotipy version is in `requirements.txt` at the time this migration happens.
2. Test against a real playlist and verify every field (id, name, uri, artists, album, album image) still exists on the response. None of these fields are in the "removed fields" list from the migration guide, but confirm empirically.
3. Verify the new endpoint accepts the same pagination pattern. If not, paginate explicitly.
4. Add an errorOccurred emission on failure (see the diff above) — the current version only logs, which is a Phase 2 gap.

## What is NOT affected

Every other API call in `spotify_manager.py` hits a kept endpoint:

| Call | Endpoint | Status |
|---|---|---|
| `start_playback / pause_playback / next_track / previous_track / seek_track / volume / shuffle` | `/me/player/*` | Kept |
| `devices / transfer_playback / current_playback / queue` | `/me/player/*` | Kept |
| `current_user_playlists(limit=50)` | `GET /me/playlists` | Kept |

No changes needed to any of these. No OAuth scope changes needed — the scopes OCTAVE requests (`user-read-playback-state`, `user-modify-playback-state`, `user-read-currently-playing`, `playlist-read-private`, `playlist-read-collaborative`, `user-library-read`) all still apply.

## music_dl subsystem (separate concern — lower priority)

`backend/music_dl/` is a forked spotdl module used only for music downloads (metadata lookup for yt-dlp). It uses the Client Credentials flow, not user-auth Dev Mode. The migration guide is ambiguous about whether Client Credentials apps are affected the same way.

**API calls in music_dl:**
- `spotify_client.track(url)` — hits `GET /tracks/{id}` (singular) — kept
- `spotify_client.album(url)` — hits `GET /albums/{id}` (singular) — kept
- `spotify_client.artist(url)` — hits `GET /artists/{id}` (singular) — kept
- `spotify_client.playlist(url)` — hits `GET /playlists/{id}` — kept
- `spotify_client.search(search_term)` — hits `GET /search` — kept, but **new max limit is 10** (default 5)

**Action items:**
1. **Low risk:** all singular endpoints are on the keep list. They should continue working.
2. **Watch:** `search()` used to allow `limit=50`. If music_dl anywhere passes `limit > 10`, those requests will silently cap or fail. Grep `backend/music_dl/` for `search(` and verify. Pin `limit=10` explicitly anywhere that's ambiguous.
3. **Test before March 9:** run an actual download end-to-end with the post-migration API and confirm. If Client Credentials apps are restricted the same way Dev Mode apps are, music downloads stop working — but infotainment (`spotify_manager.py`) remains unaffected.

## Platform restrictions (non-issues for OCTAVE's distribution model)

| Restriction | Applies to OCTAVE? |
|---|---|
| Premium required for app owner | Each user registers their own dev app, so the Premium requirement applies per-user. Playback control API has always required user Premium anyway. |
| 1 Client ID per developer | Non-issue — each user only needs one |
| 5 authorized users per Client ID | **Non-issue** — OCTAVE's settings let each user enter their own Client ID/Secret. Each user's Client ID has its own 5-user budget, of which they use exactly 1 (themselves). This is the ideal architecture for the change. |

## Recommended order of operations (when this gets picked up)

1. Read this file plus the two Spotify reference URLs at the top.
2. Apply the `get_playlist_tracks()` fix in `spotify_manager.py`.
3. Test against a Premium account with at least one playlist containing multiple tracks.
4. Grep `backend/music_dl/` for `search(` calls; pin `limit=10` where needed.
5. Run a full music_dl download cycle end-to-end to verify Client Credentials flow still works.
6. Update `wiki/spotify-manager.html` to note:
   - Feb 2026 restrictions (users need Premium, each user creates their own Client ID)
   - Which endpoints changed, for future-developer context
7. Commit both fixes together with a clear message referencing the migration.
8. Delete this TODO file.

## Why this is "time-sensitive" rather than "do it now"

The breaking change doesn't take effect until March 9, 2026. Doing the migration now means:
- Testing against pre-migration API behavior, which may not match post-migration behavior
- Risk that spotipy itself ships an update that handles this better (new wrapper method) before we need to ship
- Risk that Spotify revises the plan again (they already postponed endpoint access changes once in early March 2026)

Doing the migration one to two weeks before the deadline is the right window — late enough that the plan is stable, early enough to catch surprises.

**Recommendation:** set a calendar reminder for late February 2026 to start this migration, with March 9 as the hard deadline.
