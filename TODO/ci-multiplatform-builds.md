**Status:** deferred — blocked on Android C++ port stabilizing first
**Last updated:** 2026-05-02

# Multiplatform CI builds + first real release (v0.9)

Wire GitHub Actions to compile OCTAVE for every supported target on every release (and a rolling nightly), so anyone can download a fresh build without cloning and compiling. Then cut **v0.9.0** as the first real public release.

## Why it's parked

The Android C++ port is still in flight (see `TODO/android-cpp-port.md` — OBD-on-Android path is incomplete). It doesn't make sense to wire CI for Android until the local `cmake build-android + adb install` flow is rock-solid; otherwise CI just amplifies a broken target. Desktop CI alone *could* land sooner, but bundling all targets into one push lets us cut v0.9.0 as a single coherent moment instead of dribbling out half-releases.

**Pick this back up when:** the Android C++ build runs reliably from the command line and the basic feature set (music + at minimum one OBD path) works on a real device.

## Current state of CI

`.github/workflows/build.yml` already does:

- ✅ Lint (ruff) + smoke tests (pytest, headless) on every push/PR to `main`
- ✅ Python/PyInstaller builds for Windows / macOS / Linux **on `v*` tag push only**
- ✅ Auto-creates a GitHub Release on tag with artifacts:
  - `OCTAVE-Windows.zip` (PyInstaller folder)
  - `OCTAVE-macOS-App.zip` + `OCTAVE.dmg`
  - `OCTAVE-Linux.zip` + `OCTAVE-x86_64.AppImage`

What's missing:

- ❌ **No C++/Qt builds anywhere** — primary backend for desktop, only path for mobile, currently un-CI'd
- ❌ **No Android APK** in CI
- ❌ **No nightly / per-push downloadable artifacts** — only on tag
- ❌ iOS, Flatpak, app-store variants from the BUILD.md "9 targets"

## Plan (in two parts)

### Part A — Rolling nightly

Every push to `main` (or daily cron — see open question below) runs the full build matrix and uploads to a fixed `nightly` GitHub Release tag using `softprops/action-gh-release` with `prerelease: true`. The tag overwrites itself, so the URL `…/releases/tag/nightly` is always the latest. README links to it as "bleeding edge."

### Part B — Versioned release (v0.9.0)

Pushing a `v0.9.0` tag fires the same matrix → produces a permanent, immutable release with auto-generated changelog. README links to `…/releases/latest` as "stable."

### Workflow file split

Refactor the single `build.yml` into:

- `ci.yml` — lint + smoke tests on every push/PR (fast feedback, current behavior preserved)
- `nightly.yml` — full matrix → rolling `nightly` prerelease (cron + `workflow_dispatch`)
- `release.yml` — full matrix → permanent release on `v*` tag

Each platform/backend combination should live in its own reusable workflow (`workflows/_build-*.yml`) so a single target can be re-run without re-running everything.

## Build matrix proposed for v0.9

| Target | Backend | Output | Status / Risk |
|---|---|---|---|
| Windows x64 | Python | `.exe` + Inno Setup installer | ✅ already working in `build.yml` |
| macOS Intel/ARM | Python | `.app` + `.dmg` | ✅ already working |
| Linux x64 | Python | AppImage | ✅ already working |
| Windows x64 | C++ / Qt 6 | `.exe` + installer | 🟡 first-time CI — install Qt via `jurplel/install-qt-action`, MSVC, `windeployqt`, Inno Setup |
| macOS | C++ / Qt 6 | `.app` + `.dmg` (unsigned) | 🟡 first-time CI — `macdeployqt`, hdiutil DMG |
| Linux x64 | C++ / Qt 6 | AppImage | 🟡 first-time CI — libudev / BlueZ deps for OBD serial |
| Android arm64 | C++ / Qt 6 | APK (debug-signed) | 🟠 depends on `TODO/android-cpp-port.md` finishing — OBD path on Android still TODO |
| iOS | C++ / Qt 6 | `.ipa` | ❌ defer — needs Apple Developer account ($99/yr) + signing certs |
| Flatpak | C++ / Qt 6 | `.flatpak` | 🟡 nice-to-have, defer to v0.10 |
| App-store variants (downloads stripped via `OCTAVE_ENABLE_DOWNLOADS=OFF`) | C++ / Qt 6 | per-store | ❌ defer — no store accounts yet |

## Open questions to settle before writing YAML

1. **Trigger cadence** — every push to main, or daily cron + on-demand `workflow_dispatch`?
   - Recommendation: **daily cron + manual dispatch + every `v*` tag.** Lint+test still runs on every push for fast feedback. Cron is meaningful as "nightly"; every-push wastes 30 min of CI churn on typo fixes. Easy to flip to every-push later if cron feels slow.

2. **Android in v0.9 or v0.10?** Memory note: Android C++ OBD path is incomplete.
   - (a) Ship APK in v0.9 with "OBD coming in v1.0" note
   - (b) Ship Android-minus-OBD as v0.9, call OBD a v1.0 feature
   - (c) Defer Android entirely; v0.9 is desktop-only
   - **Default plan: revisit this question once the Android port is stable. The current intent is to delay v0.9 until Android is in.**

3. **Both Python AND C++ desktop binaries in v0.9, or just one?**
   - (a) Ship both — transparent about the dual-backend story (matches the README pitch)
   - (b) Ship only C++ as default, Python is dev-only (cleaner UX, less confusion)
   - **Recommendation: (a) for v0.9, narrow to (b) at v1.0.**

4. **Code signing?**
   - macOS unsigned → "app is damaged", users `xattr -cr` past it
   - Windows unsigned → SmartScreen warning
   - Both fixable later with certs + money. **Ship unsigned for v0.9, document workaround in README.**

5. **Repo visibility** — assumed public (unlimited Actions minutes). Confirm before committing to a cron schedule.

## Prerequisites / dependencies

- `TODO/android-cpp-port.md` must be substantially done — at minimum: clean cmake-android build, debug APK installs and launches, music playback works on a real device. OBD on Android can be deferred (see question 2).
- Local C++ desktop builds need to be reproducible from a clean checkout (currently they are, per `BUILD.md`, but verify on a fresh container before trusting CI).
- Decide on Qt 6 version pin for CI (currently 6.7.3 per developer environment) — pick one and use it across all matrix legs to avoid version skew.
- For Android: keystore handling. Debug-signed is fine for v0.9 nightly; release-signed APKs need a keystore stored as a GitHub Secret. Document the keystore generation + secret upload as a one-time setup step.

## Recommended order of operations when picking this back up

1. Verify Android C++ build is solid locally (precondition).
2. Answer the five open questions above; lock the matrix.
3. Add C++ desktop CI first (Linux → macOS → Windows) on a feature branch, iterate until green.
4. Add Android CI.
5. Refactor the single workflow into `ci.yml` / `nightly.yml` / `release.yml` + reusable per-target workflows.
6. Wire up the `nightly` rolling release tag.
7. Update README with download badges + links to `/releases/latest` and `/releases/tag/nightly`.
8. Push `v0.9.0` tag → confirm release page populates → announce.

## Cross-references

- `TODO/android-cpp-port.md` — blocker
- `BUILD.md` — current local build instructions for all targets, source of truth for the "9 targets" claim that needs to be reconciled with what CI actually produces

Delete this file when v0.9.0 is shipped and CI is producing nightly builds for all desktop + Android targets.
