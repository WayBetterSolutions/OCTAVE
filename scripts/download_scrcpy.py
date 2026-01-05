#!/usr/bin/env python3
"""
Download scrcpy for bundling with OCTAVE.

This script downloads the appropriate scrcpy release for the current platform
and extracts it to the tools/scrcpy directory.

Usage:
    python scripts/download_scrcpy.py
"""

import os
import sys
import platform
import zipfile
import tarfile
import shutil
import urllib.request
from pathlib import Path

# scrcpy version to download
SCRCPY_VERSION = "3.1"

# Download URLs for each platform
DOWNLOAD_URLS = {
    "Windows": f"https://github.com/Genymobile/scrcpy/releases/download/v{SCRCPY_VERSION}/scrcpy-win64-v{SCRCPY_VERSION}.zip",
    "Linux": f"https://github.com/Genymobile/scrcpy/releases/download/v{SCRCPY_VERSION}/scrcpy-linux-x86_64-v{SCRCPY_VERSION}.tar.gz",
    # macOS: scrcpy is typically installed via Homebrew, but we can bundle it
    "Darwin": None,  # macOS users should use: brew install scrcpy
}

LICENSE_URL = "https://raw.githubusercontent.com/Genymobile/scrcpy/master/LICENSE"


def get_project_root() -> Path:
    """Get the project root directory."""
    return Path(__file__).parent.parent


def download_file(url: str, dest: Path) -> None:
    """Download a file from URL to destination."""
    print(f"Downloading: {url}")
    print(f"Destination: {dest}")

    # Create a request with a user agent
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) OCTAVE/1.0"}
    )

    with urllib.request.urlopen(request) as response:
        total_size = int(response.headers.get("Content-Length", 0))
        downloaded = 0
        block_size = 8192

        with open(dest, "wb") as f:
            while True:
                chunk = response.read(block_size)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total_size:
                    percent = (downloaded / total_size) * 100
                    print(f"\rProgress: {percent:.1f}%", end="", flush=True)
        print()  # New line after progress


def extract_archive(archive_path: Path, dest_dir: Path) -> None:
    """Extract archive (zip or tar.gz) to destination directory."""
    print(f"Extracting to: {dest_dir}")

    if archive_path.suffix == ".zip":
        with zipfile.ZipFile(archive_path, "r") as zf:
            # Get the root folder name in the archive (if any)
            root_folder = None
            for name in zf.namelist():
                parts = name.split("/")
                if len(parts) > 1 and parts[0]:
                    root_folder = parts[0]
                    break

            # Extract files directly to dest_dir, stripping the root folder
            for member in zf.namelist():
                # Skip directories
                if member.endswith("/"):
                    continue

                # Strip the root folder from the path
                if root_folder and member.startswith(root_folder + "/"):
                    target_name = member[len(root_folder) + 1:]
                else:
                    target_name = member

                if not target_name:
                    continue

                target_path = dest_dir / target_name
                target_path.parent.mkdir(parents=True, exist_ok=True)

                with zf.open(member) as src, open(target_path, "wb") as dst:
                    dst.write(src.read())

    elif archive_path.name.endswith(".tar.gz"):
        with tarfile.open(archive_path, "r:gz") as tf:
            # Get the root folder name
            root_folder = None
            for member in tf.getmembers():
                parts = member.name.split("/")
                if len(parts) > 1 and parts[0]:
                    root_folder = parts[0]
                    break

            # Extract files directly to dest_dir, stripping the root folder
            for member in tf.getmembers():
                if not member.isfile():
                    continue

                # Strip the root folder from the path
                if root_folder and member.name.startswith(root_folder + "/"):
                    target_name = member.name[len(root_folder) + 1:]
                else:
                    target_name = member.name

                if not target_name:
                    continue

                target_path = dest_dir / target_name
                target_path.parent.mkdir(parents=True, exist_ok=True)

                with tf.extractfile(member) as src, open(target_path, "wb") as dst:
                    dst.write(src.read())


def main():
    """Main entry point."""
    system = platform.system()
    print(f"Platform: {system}")

    if system == "Darwin":
        print("\nmacOS detected.")
        print("Please install scrcpy using Homebrew:")
        print("    brew install scrcpy")
        print("\nOr download manually from:")
        print(f"    https://github.com/Genymobile/scrcpy/releases/tag/v{SCRCPY_VERSION}")
        sys.exit(0)

    url = DOWNLOAD_URLS.get(system)
    if not url:
        print(f"Unsupported platform: {system}")
        sys.exit(1)

    project_root = get_project_root()
    tools_dir = project_root / "tools" / "scrcpy"

    # Create tools directory
    tools_dir.mkdir(parents=True, exist_ok=True)

    # Check if already downloaded
    if system == "Windows":
        scrcpy_exe = tools_dir / "scrcpy.exe"
    else:
        scrcpy_exe = tools_dir / "scrcpy"

    if scrcpy_exe.exists():
        print(f"scrcpy already exists at: {scrcpy_exe}")
        response = input("Re-download? [y/N]: ").strip().lower()
        if response != "y":
            print("Skipping download.")
            return

        # Kill adb if running (it locks the exe file on Windows)
        if system == "Windows":
            import subprocess
            subprocess.run(["taskkill", "/F", "/IM", "adb.exe"],
                          capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)

        # Clean existing files
        for item in tools_dir.iterdir():
            if item.name != "LICENSE":
                try:
                    if item.is_file():
                        item.unlink()
                    else:
                        shutil.rmtree(item)
                except PermissionError:
                    print(f"Warning: Could not delete {item.name} (file in use)")
                    print("Please close any applications using scrcpy/adb and try again.")
                    sys.exit(1)

    # Download archive
    archive_name = url.split("/")[-1]
    archive_path = tools_dir / archive_name

    try:
        download_file(url, archive_path)
        extract_archive(archive_path, tools_dir)

        # Clean up archive
        archive_path.unlink()

        # Download LICENSE if not present
        license_path = tools_dir / "LICENSE"
        if not license_path.exists():
            print("\nDownloading LICENSE...")
            download_file(LICENSE_URL, license_path)

        print(f"\nscrcpy v{SCRCPY_VERSION} installed successfully!")
        print(f"Location: {tools_dir}")

        # List installed files
        print("\nInstalled files:")
        for item in sorted(tools_dir.iterdir()):
            size = item.stat().st_size if item.is_file() else 0
            size_str = f"{size / 1024:.1f} KB" if size > 0 else "dir"
            print(f"  {item.name}: {size_str}")

    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
