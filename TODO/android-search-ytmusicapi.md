# Android C++ APK — wire ytmusicapi for YouTube Music search

**Status:** active, blocking. Sideload APK is otherwise daily-drivable — search is the last real quality gap.
**Last updated:** 2026-04-20
**Complexity:** medium. ~2 hours of focused work. One JNI addition, one asset bundle, one script wiring.
**Read first:** `TODO/android-cpp-port.md` (context for the overall Android port), `ANDROID_BUILD_SETUP.md` (toolchain).

---

## Why this exists

The C++ Android APK's `DownloadManager::search()` uses `yt-dlp`'s `ytsearch15:` prefix OR `https://music.youtube.com/search?q=...` in `--flat-playlist` mode. Both are bad:

- `ytsearch15:` — hits YouTube's general video search. Returns reaction videos, full-album-rip compilations, podcasts. Low relevance.
- `music.youtube.com/search` — returns a mix where ~50% of entries are `ie_key: YoutubeTab` (album/artist/playlist pages with empty title). Filtering those out leaves few, inconsistent results.

Neither path is fixable with more yt-dlp flags. **The Python APK already solves this cleanly** via the `ytmusicapi` Python library, which queries YouTube Music's internal API directly with proper filtering (`filter="songs"`) and returns curated song metadata (artist array, album object, square thumbnails, year, duration).

The ytmusicapi-based search helper is already written and sitting at `scripts/ytmusic_search.py`. It outputs JSON-per-line that `DownloadManager::_parseSearchOutput()` already parses correctly (the Python APK's desktop backend uses the exact same script).

We just need to make the Android C++ APK invoke it, same as desktop does.

## The opportunity

`youtubedl-android` (the AAR we already bundle, at `io.github.junkfood02.youtubedl-android:library:0.18.1`) ships a full **Python 3.9 runtime** in addition to yt-dlp. That Python interpreter can `pip install` arbitrary packages and run arbitrary scripts. We just haven't exposed that from our Java bridge yet.

On disk at runtime (verified), the Python binary lives at:
```
/data/user/0/org.octave.app/no_backup/youtubedl-android/packages/python/usr/bin/python
```

And it already has a working site-packages dir we can extend.

## Implementation plan

### Step 1 — Locate Python + add `pip install ytmusicapi` to bridge init

**File:** `android/src/org/octave/app/OctaveMediaBridge.java`

Add a method that:
1. Finds the bundled Python binary path via reflection on `YoutubeDL.INSTANCE.binDir` / or hardcode `new File(ctx.getNoBackupFilesDir(), "youtubedl-android/packages/python/usr/bin/python")`.
2. If ytmusicapi isn't already installed (check a flag file in app cache), runs `python -m pip install --no-cache-dir ytmusicapi` via `Runtime.exec()`.
3. Writes the flag file on success.

Call this from the existing `init(Context)` method **after** `YoutubeDL.getInstance().init(ctx)` succeeds — the youtubedl-android init is what extracts Python in the first place.

Wrap in a try/catch + 60s timeout. First-launch install adds ~10–15s to the existing Python extract step. That's acceptable; we're already running bridge init async off the GUI thread in `main.cpp`.

Pseudo-code:

```java
private static volatile boolean ytmusicapiReady = false;

private static void ensureYtmusicapi(Context ctx) {
    File flag = new File(ctx.getCacheDir(), ".ytmusicapi-installed");
    if (flag.exists()) { ytmusicapiReady = true; return; }

    String python = getPythonBinaryPath();  // see below
    if (python == null) return;

    try {
        Process p = new ProcessBuilder(python, "-m", "pip", "install",
                                        "--no-cache-dir", "ytmusicapi")
            .redirectErrorStream(true)
            .start();
        if (p.waitFor(120, TimeUnit.SECONDS) && p.exitValue() == 0) {
            flag.createNewFile();
            ytmusicapiReady = true;
            Log.i(TAG, "ytmusicapi installed");
        } else {
            Log.w(TAG, "pip install ytmusicapi failed: exit=" + p.exitValue());
        }
    } catch (Throwable t) {
        Log.w(TAG, "ytmusicapi install threw", t);
    }
}

public static String getPythonBinaryPath() {
    // Try reflection first (YoutubeDL keeps a private pythonPath field).
    // Fall back to the well-known layout:
    //   noBackupFilesDir/youtubedl-android/packages/python/usr/bin/python
    // Same approach as getFfmpegBinaryPath() below in this file.
}
```

### Step 2 — Bundle `scripts/ytmusic_search.py` into the APK

The script already exists at `/home/rhea/Dropbox/Oasis/_OCTAVE/scripts/ytmusic_search.py`. It's the same helper the Python desktop build uses. Its output format is already what `DownloadManager::_parseSearchOutput()` expects.

**Where to put it in the APK:**

Option A (recommended): drop into the existing android assets symlink tree.

```bash
mkdir -p android/assets/scripts
ln -sf ../../../scripts android/assets/scripts
# or direct copy if symlinks don't bundle reliably — test
```

This mirrors how we already bundle `frontend/` as `assets/frontend/`. The symlink+rebuild pattern was proven to work for QML.

**Extraction at runtime:** Qt's `assets:/` URL scheme doesn't give a filesystem path Python can execute from. The Java bridge has to copy the script from the asset stream to a writable file path at first use.

In `OctaveMediaBridge.java`:

```java
public static String extractSearchScript(Context ctx) {
    File out = new File(ctx.getFilesDir(), "ytmusic_search.py");
    if (out.exists() && out.length() > 0) return out.getAbsolutePath();

    try (InputStream in = ctx.getAssets().open("scripts/ytmusic_search.py");
         FileOutputStream fos = new FileOutputStream(out)) {
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
    } catch (Throwable t) {
        Log.w(TAG, "extractSearchScript failed", t);
        return null;
    }
    return out.getAbsolutePath();
}
```

### Step 3 — New JNI method: `runYtMusicSearch(query, limit)`

In `OctaveMediaBridge.java`:

```java
public static String runYtMusicSearch(Context ctx, String query, int limit) {
    if (!ytmusicapiReady) ensureYtmusicapi(ctx);
    if (!ytmusicapiReady) {
        lastExitCode = -1;
        return "";  // caller will fall back to yt-dlp
    }

    String script = extractSearchScript(ctx);
    String python = getPythonBinaryPath();
    if (script == null || python == null) {
        lastExitCode = -1;
        return "";
    }

    try {
        Process p = new ProcessBuilder(python, script, query, String.valueOf(limit))
            .redirectErrorStream(false)
            .start();

        // Capture stdout fully; stderr goes to logcat
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try (InputStream stdout = p.getInputStream()) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = stdout.read(buf)) > 0) bos.write(buf, 0, n);
        }
        if (!p.waitFor(30, TimeUnit.SECONDS)) {
            p.destroy();
            lastExitCode = -2;
            return "";
        }
        lastExitCode = p.exitValue();
        return bos.toString("UTF-8");
    } catch (Throwable t) {
        Log.e(TAG, "runYtMusicSearch failed", t);
        lastExitCode = -2;
        return "";
    }
}
```

### Step 4 — Expose via C++ bridge header

In `src/platform/androidmediabridge.h`, add inline wrapper:

```cpp
inline QString runYtMusicSearch(const QString &query, int limit)
{
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");
    if (!activity.isValid()) return {};
    QJniObject jq = QJniObject::fromString(query);
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/octave/app/OctaveMediaBridge",
        "runYtMusicSearch",
        "(Landroid/content/Context;Ljava/lang/String;I)Ljava/lang/String;",
        activity.object<jobject>(),
        jq.object<jstring>(),
        static_cast<jint>(limit));
    return result.toString();
}
```

### Step 5 — Route downloadmanager's search through ytmusicapi on Android

**File:** `src/managers/downloadmanager.cpp`, in `DownloadManager::search(const QString &query)`.

The current Android branch (around lines 282–310) uses yt-dlp. Replace its body with a direct JNI call that bypasses the yt-dlp process machinery entirely — the ytmusicapi script is fast (~1–2s) and returns pre-formatted JSON-per-line that `_parseSearchOutput()` already handles.

```cpp
#ifdef Q_OS_ANDROID
    m_searchBuffer.clear();
    // Run in a worker so the UI doesn't block on Python startup.
    auto watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher]() {
        const QString output = watcher->result();
        watcher->deleteLater();
        m_isSearching = false;
        emit isSearchingChanged(false);
        emit searchInProgress(false);

        if (output.isEmpty()) {
            emit searchError(QStringLiteral("YouTube Music search failed"));
            return;
        }
        m_searchBuffer = output.toUtf8();
        QJsonArray results = _parseSearchOutput(m_searchBuffer);
        m_searchBuffer.clear();
        _markDownloaded(results);
        m_allResults = results;
        m_searchOffset = results.size();
        QJsonDocument doc(m_allResults);
        emit searchResults(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
        emit statusMessage(QStringLiteral("Showing %1 result(s)").arg(m_allResults.size()));
    });
    watcher->setFuture(QtConcurrent::run([query=trimmed]() {
        return OctaveAndroid::runYtMusicSearch(query, 25);
    }));
    return;
#endif
```

Note this path completely replaces the `m_searchProcess` plumbing on Android — no AndroidProcessAdapter involved. Cleaner and faster.

### Step 6 — `_parseSearchOutput` already works, no changes needed

The existing parser handles one JSON object per line, which is exactly what `ytmusic_search.py` outputs. The artist/title/album/cover_url/duration/year fields all map through unchanged. Remove the Android-specific title-splitting + YoutubeTab-filtering + thumbnail-synthesis hacks I added — they're obsolete once ytmusicapi is in.

Explicitly, remove from `_parseSearchOutput()`:

```cpp
// Remove: #ifdef Q_OS_ANDROID YoutubeTab filter
// Remove: #ifdef Q_OS_ANDROID title-split (Artist - Song)
// Remove: #ifdef Q_OS_ANDROID cacheHttpImage thumbnail rewrite
```

Actually **keep** the `cacheHttpImage` thumbnail rewrite — ytmusicapi returns `https://lh3.googleusercontent.com/` URLs for thumbnails which still have to be HTTPS-fetched through Java (Qt's OpenSSL is broken on our APK). That helper stays.

### Step 7 — Build, install, verify

```bash
bash -ic 'cd /home/rhea/Dropbox/Oasis/_OCTAVE && cmake --build build-android -j$(nproc)'
adb install -t -r build-android/android-build/octave.apk
adb shell am force-stop org.octave.app
adb shell am start -n org.octave.app/org.qtproject.qt.android.bindings.QtActivity
# First launch adds ~10-15s to bridge init for pip install ytmusicapi.
# Watch logcat:
adb logcat -d | grep -E 'OctaveMediaBridge|octave.download' | tail -30
```

Verify:
1. `adb logcat` shows `OctaveMediaBridge: ytmusicapi installed` on first launch (after the 10-15s pip step)
2. Search "pink floyd" → returns clean song entries with proper artist names ("Pink Floyd"), proper song titles ("Wish You Were Here"), proper thumbnails (square album art)
3. Clicking a result downloads it to `App Downloads` playlist
4. Downloaded song plays back with embedded metadata

## Fallback strategy

If `pip install ytmusicapi` fails (network, sandbox policy, Python env issue) the code path falls through to yt-dlp search. That's the current behavior already. So the absolute worst case is "ytmusicapi didn't install, search quality is the same as it is today" — no regression.

## Tests to add

After landing, add to `tests/test_smoke.py` (Python smoke tests already run headless in CI):
- Verify `scripts/ytmusic_search.py` still parses with a mocked ytmusicapi
- Verify `backend/download_manager.py` desktop still shells to the same script

The Android JNI path has no CI coverage today; that's acknowledged debt (no Android instrumentation tests). Manual APK test on S22 Ultra is the verification.

## Files to touch (complete list)

| File | Change |
|---|---|
| `android/src/org/octave/app/OctaveMediaBridge.java` | +3 methods: `ensureYtmusicapi`, `extractSearchScript`, `runYtMusicSearch`, `getPythonBinaryPath`; call `ensureYtmusicapi` from `init()` |
| `android/assets/scripts/ytmusic_search.py` | new (symlink to `../../../scripts/ytmusic_search.py` preferred; copy if symlink doesn't bundle) |
| `src/platform/androidmediabridge.h` | +1 inline wrapper: `runYtMusicSearch(QString, int)` |
| `src/managers/downloadmanager.cpp` | Replace Android branch in `search()` with `QFutureWatcher` + JNI call; delete Android-specific hacks in `_parseSearchOutput` (YoutubeTab filter, title-split, thumbnail-synthesis) |

## Why the previous attempts failed (avoid repeating them)

Session log summary — don't re-try these:

- `ytsearch15:query` + `--flat-playlist` → works fast but returns reaction videos / compilations mixed with songs. No viable match-filter because flat-playlist omits duration/channel.
- `music.youtube.com/search?q=...` + `--flat-playlist` → returns a mix of `ie_key: YoutubeTab` (album/artist pages, empty titles) and `ie_key: Youtube` (actual songs). Even with YoutubeTab-filter, the Youtube entries don't include `artist` field in flat-playlist mode, requiring title-split heuristics that don't always work.
- `music.youtube.com/search` without `--flat-playlist` → Samsung Freecess freezes the background thread before per-video detail fetches complete (~20-30s work, Freecess freezes every ~6s). Unusable.
- `--extractor-args youtube:player_client=ios,tv_embedded,android` → fixes HTTP 403 on downloads but doesn't change search quality.

The root reason all of these fall short: yt-dlp's public YouTube Music support is less curated than ytmusicapi's direct internal-API queries. ytmusicapi returns `result.filter="songs"` → genuinely just songs, with complete metadata, in the right relevance order. Nothing in yt-dlp matches that on Android.

## Pre-existing file locations (helpful shortcuts)

- `scripts/ytmusic_search.py` — the Python helper. Reused verbatim. Already outputs the right JSON-per-line format.
- `backend/music_dl/utils/search.py` — Python desktop backend's usage (reference, don't modify).
- `src/managers/downloadmanager.cpp:_parseSearchOutput()` — parser. No changes needed aside from removing the Android-specific hacks.
- `android/src/org/octave/app/OctaveMediaBridge.java` — Java JNI bridge. Already has `runYtDlp`, `getFfmpegBinaryPath`, `cacheHttpImage`, `readMetadata`, `extractAlbumArt`. Add new methods here.
- `src/platform/androidmediabridge.h` — C++ inline JNI wrappers. Add one more.

## Delete this file when done

When ytmusicapi search is working on the S22 APK and clean "pink floyd" / "vundabar" searches return proper song lists with artist names and square album art, delete this TODO. If anything in this plan needs revision mid-execution, update it inline so the next reader has the current picture.
