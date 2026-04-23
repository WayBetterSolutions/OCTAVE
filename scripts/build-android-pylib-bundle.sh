#!/usr/bin/env bash
# Rebuild android/assets/python-packages/ytmusic-bundle.zip
#
# The Android APK bundles ytmusicapi + its pure-Python dep chain as a zip
# asset because the AAR-shipped Python 3.12 has no pip / ensurepip. The
# OctaveMediaBridge extracts this bundle into filesDir/pylibs/ on first
# launch and points PYTHONPATH at it when running ytmusic_search.py.
#
# Run this script from the repo root. Requires: python3 + pip in a venv
# (uses the one at ./venv if present).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/android/assets/python-packages/ytmusic-bundle.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

PIP="pip"
if [ -x "$REPO/venv/bin/pip" ]; then
    PIP="$REPO/venv/bin/pip"
fi

mkdir -p "$(dirname "$OUT")"

# Install ytmusicapi and its full transitive dep tree into the stage dir.
"$PIP" install --target "$STAGE" --upgrade ytmusicapi requests >/dev/null

# Strip platform-specific artifacts — the AAR Python is arm64 Android while
# pip builds wheels for the dev host. charset_normalizer ships a mypyc-
# compiled .so alongside pure-Python fallbacks (md.py / cd.py) which Python
# uses transparently when the .so is absent.
find "$STAGE" -name '*.so'   -delete
find "$STAGE" -name '*.pyd'  -delete
find "$STAGE" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
rm -rf "$STAGE"/bin "$STAGE"/*.dist-info

# Keep only the packages we actually need at runtime.
( cd "$STAGE" && zip -r -q "$OUT" \
    ytmusicapi requests charset_normalizer idna urllib3 certifi )

ls -la "$OUT"
