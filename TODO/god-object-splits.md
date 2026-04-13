# God Object Splits (Parked)

**Status:** Deferred. This is item #4 from the original cleanup punch list — a refactor, not a bug fix. Not urgent. Should ideally come AFTER `future-tests.md` lands enough safety nets to make the refactor safe.

**Last updated:** 2026-04-11

---

## The three targets

Three backend manager files are over 2000 lines and handle multiple distinct responsibilities. They violate single-responsibility hard enough that making changes to them is risky — every edit could touch unrelated subsystems.

| File | Lines | Current responsibilities |
|---|---|---|
| `backend/settings_manager.py` | 2412 | JSON I/O + in-memory cache + validation + defaults + theming helpers + platform-specific path resolution + per-section visibility + every getter/setter for every setting |
| `backend/media_manager.py` | 2474 | QMediaPlayer wrapping + playlist management + library scan + metadata caching + album art LRU cache + stats computation + "All Music" virtual playlist + mute toggle guard + position timer + save-state debounce |
| `backend/obd_manager.py` | 2305 | OBD connection state machine + threaded connection worker + DTC reading + freeze frame + diagnostic mode + watcher refresh + reconnect logic + protocol caching + scan logic + data watchdog + diagnostic sync connection |

---

## Why this is parked

1. **It's a refactor, not a bug fix.** Users don't feel this directly. The app works. This is purely developer experience.
2. **It's high risk.** 2400 lines of tightly-coupled code have load-bearing assumptions we don't fully understand. Breaking any of them is a regression users WILL feel.
3. **We don't have the safety net yet.** Without integration tests, splitting these files is "move code around and hope nothing broke." The Phase 1 smoke tests catch import errors, not behavior regressions.
4. **You chose to skip it.** You explicitly said #4 wasn't a priority in the session where we planned Phases 1–3.

---

## Recommended order (safest first)

### 1. settings_manager.py (do first)

Clearest seams, lowest risk of breaking runtime behavior. `SettingsManager` is the only class QML references, so the public API stays identical — behind the facade, code just moves to helper modules.

**Proposed split:**
- `backend/settings/io.py` — JSON load/save, atomic writes, migration on schema drift, backup on write failure. Pure I/O, no Qt dependency.
- `backend/settings/defaults.py` — the big `_default_settings` dict + OBD parameter defaults. Just data.
- `backend/settings/paths.py` — OS-specific path resolution (Windows / macOS / Linux / Android). Just functions.
- `backend/settings_manager.py` (shrunk) — the `SettingsManager` QObject facade. Holds the in-memory cache, exposes `@Slot` / `@Property` to QML, delegates actual I/O to `io.py`.

**Target shrink:** 2412 → ~800 lines in the facade, ~1600 lines distributed across the helpers.

### 2. media_manager.py (do second)

Medium risk. More state than `settings_manager`. The mute toggle guard, save-state debounce, and playlist transition logic have subtle interactions that need care.

**Proposed split:**
- `backend/media/playback.py` — QMediaPlayer wrapper, play/pause/seek/volume, position timer. Just playback control.
- `backend/media/library.py` — folder scanning, "All Music" virtual playlist, playlist name resolution, file discovery. Filesystem only.
- `backend/media/metadata.py` — ID3 tag reading, sanitization of control characters, album art extraction. Pure functions + file reads.
- `backend/media/cache.py` — album art LRU cache, metadata cache, access count tracking. Pure data structures.
- `backend/media/stats.py` — total duration, album count, artist count computation. Pure functions over the scanned library.
- `backend/media_manager.py` (shrunk) — facade that composes the above into the `MediaManager` QObject exposed to QML.

**Prerequisite:** the `VolumeController` dispatch test and a `metadata.py` sanitization test (both in `future-tests.md`) should go in BEFORE this split. They validate the two most fragile parts of this subsystem.

### 3. obd_manager.py (do last)

Highest risk. Concurrent code with threads, timers, locks, and the diagnostic-mode cancellation handshake we documented in Phase 2. The race-condition comment we added at `exit_diagnostic_mode` (the "entry cancelled during blocking I/O window" flow) is exactly the kind of subtle thing that breaks when code moves.

**Proposed split:**
- `backend/obd/connection.py` — connection state machine, reconnect logic, port discovery, protocol caching. Sync calls only.
- `backend/obd/worker.py` — the `QThread` worker that runs `connection.py` off the UI thread, emits progress signals.
- `backend/obd/diagnostic.py` — DTC reading, freeze frame, clear DTCs, MIL status, diagnostic-mode enter/exit. Uses the sync connection.
- `backend/obd/watcher.py` — async watcher setup, refresh logic, supported-PID caching.
- `backend/obd_manager.py` (shrunk) — facade that owns the worker thread, routes QML slots to the right subsystem, manages the data watchdog timer.

**Prerequisite:** DO NOT touch `obd_manager.py` until the OBD protocol replay suite from `future-tests.md` exists. You need to be able to smoke-test the entire OBD path without a car, or the refactor is "move things around and pray."

---

## Approach: incremental, one PR per extraction

Not "one big refactor." Instead:

1. Pick one target (settings_manager first).
2. Extract ONE helper module at a time — start with the lowest-risk one (`paths.py`, because it's pure functions with no Qt).
3. Run the smoke tests after each extraction.
4. Manually test the app for 5 minutes, hitting the subsystem you just touched.
5. Commit. Move to the next helper.
6. Only after all helpers are extracted does the "shrunk facade" version get committed.

This keeps every commit small and revertable. If something breaks, `git bisect` finds the bad extraction in minutes, not hours.

---

## What would make this safer (dependencies on `future-tests.md`)

Before starting any split, these tests should exist:

| Target | Required tests before split |
|---|---|
| `settings_manager.py` | Settings round-trip test (Tier 1) |
| `media_manager.py` | `VolumeController` dispatch test + metadata sanitization tests (Tier 1 + Tier 2) |
| `obd_manager.py` | ELM327 protocol tests + OBD protocol replay suite (Tier 1 + Tier 3) |

**Rule of thumb:** if a subsystem has no test coverage, don't refactor it. Add tests first, then refactor. The tests tell you when the refactor is done.

---

## What NOT to do

- **Don't do all three at once.** That's a 3000+ line PR nobody can review and nobody can bisect.
- **Don't split just to hit a line count.** If a section of code genuinely belongs together, leave it. The goal is clearer responsibilities, not smaller files.
- **Don't change behavior during the split.** The refactor PR should be 100% code motion — no bug fixes, no feature changes, no "while I'm in here" cleanups. Those come before or after, never during.
- **Don't skip the manual test pass between extractions.** Import smoke tests don't catch signal/slot wiring regressions. If you move a method from `media_manager.py` to `media/playback.py`, the only way to know all the callers still work is to actually use the app.
- **Don't break the QML context property contract.** QML references these managers by name (`mediaManager`, `settingsManager`, `obdManager`) and expects specific `@Slot` and `@Property` decorators on specific classes. The public API of the facade classes must stay byte-for-byte identical during the refactor.
