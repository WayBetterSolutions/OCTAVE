# Settings icons: Unicode glyphs → consistent icon system

**Status:** deferred
**Last updated:** 2026-05-24

## Why it's parked

During a visual-cohesion cleanup pass we flagged that the settings UI uses
monochrome **Unicode glyphs** for icons while the rest of the app (bottom bar,
media controls) uses **theme-tinted SVGs** in `frontend/assets/*.svg`. Converting
is the right cohesion move, but it turned out to be an asset/design project, not
a quick cleanup — so it was intentionally deferred to give icon design proper
attention rather than hand-author ~25 mismatched SVGs under time pressure.

Note: the glyphs **already tint to the theme** (e.g. `SettingsTile` renders the
icon in `App.Style.accent`), so this is *stylistic* polish, not a functional
theme gap. Nothing is broken today.

## What's involved

Two separate glyph sets are rendered as `Text { text: <glyph> }`:

1. **Top-level category icons** (6) — defined in `frontend/SettingsMenu.qml:22-40`
   (`pageModel`): Display `☼`, Media `♫`, OBD `⚡`, Accessories `⎈`, Device `⚙`,
   About `ℹ`. Rendered in:
   - `frontend/SettingsCarouselLayout.qml:62` (tab label: `icon + "  " + name`)
   - `SettingsHubCard` / `SettingsHubGridCard` / `SettingsDashboardCard` (via a
     `categoryIcon` property — see `SettingsCarouselLayout.qml:137`,
     `SettingsDashboardLayout.qml:165`)
2. **Subsection tile icons** (~20) — e.g. `frontend/settings/DisplaySettingsPage.qml:22-25`
   (`tileModel`: Layout `▦`, Window `▣`, Appearance `❖`, Clock `◐`), plus the
   `subSections` lists in `SettingsMenu.qml` (Library, Playback, Album Art,
   Background, Effects, Spotify, Connection, Parameters, Volume Knob, IMU Sensor,
   Gesture Sensor, Phone Dock, …). Rendered in `frontend/settings/SettingsTile.qml:81,89`.

**Existing SVGs that already fit** (`frontend/assets/`): `media_button.svg` (Media),
`obd_button.svg` (OBD), `settings_button.svg` (gear → Device), `sensor_button.svg`
(≈ Accessories), `clock_symbol.svg` (Clock).
**Missing:** Display, About, and most subsection icons — no source set exists
(`frontend/assets/-src/` holds only `.ai` logo + play/pause sources).

## Recommended approach (decided direction TBD)

Leading candidate from the cohesion review: **bundle an icon font** (Material
Symbols or Phosphor — both have permissive licenses). One theme-tintable system
covering every category *and* subsection, a single render path, and no
hand-authoring. The app already loads custom fonts from the fonts folder, so the
plumbing exists. Alternative is a full hand-authored SVG set (~25 icons), which
carries aesthetic-match risk against the existing professional button SVGs.

Order of operations once picked up:
1. Choose the system (icon font vs. SVG set); if a font, verify license + bundle.
2. Add an `icon` mapping (glyph/codepoint or `assets/*.svg`) to `pageModel` and
   `tileModel`, replacing the literal Unicode chars.
3. Swap the `Text { text: icon }` render sites for the new system, keeping the
   existing theme-color tint (`App.Style.accent` / `secondaryTextColor`).
4. Verify across all four settings layouts (Carousel/Sidebar/Hub/Dashboard).

## Cross-references

- Related cohesion work already landed (same review): dead-EnvironmentTheme cut,
  experimental-layout gating, gauge `statusDanger` routing.
- If a drag-drop dashboard editor lands (`TODO/dashboards-roadmap.md`), a shared
  icon system would benefit its palette/picker too.

Delete this file when the conversion is done.
