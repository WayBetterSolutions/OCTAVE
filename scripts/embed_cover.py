#!/usr/bin/env python3
"""Replace the cover art atom of an m4a/mp4 file.

Usage: python embed_cover.py <audio.m4a> <cover.jpg|png>

Runs against the Python 3.12 runtime bundled inside the Android APK —
mutagen ships pre-installed in youtubedl-android's site-packages so no
extra deps are needed. Mutates the file in place; no re-encode.
"""

import sys


def main():
    if len(sys.argv) < 3:
        sys.exit(1)

    audio_path = sys.argv[1]
    cover_path = sys.argv[2]

    from mutagen.mp4 import MP4, MP4Cover

    with open(cover_path, "rb") as f:
        cover_bytes = f.read()

    fmt = (
        MP4Cover.FORMAT_PNG
        if cover_path.lower().endswith(".png")
        else MP4Cover.FORMAT_JPEG
    )

    audio = MP4(audio_path)
    audio["covr"] = [MP4Cover(cover_bytes, imageformat=fmt)]
    audio.save()


if __name__ == "__main__":
    main()
