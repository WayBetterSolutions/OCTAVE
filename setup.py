#!/usr/bin/env python3
"""
OCTAVE Setup Script
Cross-platform installer that handles dependencies and environment setup.

Usage:
    python setup.py          # Setup only
    python setup.py --run    # Setup and run the app
"""

import subprocess
import sys
import os
import platform
import shutil

def print_header(text):
    print("\n" + "=" * 50)
    print(f"  {text}")
    print("=" * 50)

def print_step(text):
    print(f"\n→ {text}")

def run_command(cmd, check=True, shell=False):
    """Run a command and return success status."""
    try:
        if isinstance(cmd, str) and not shell:
            cmd = cmd.split()
        subprocess.run(cmd, check=check, shell=shell)
        return True
    except subprocess.CalledProcessError:
        return False
    except FileNotFoundError:
        return False

def detect_platform():
    """Detect the current platform."""
    system = platform.system().lower()
    if system == "darwin":
        return "macos"
    elif system == "windows":
        return "windows"
    elif system == "linux":
        # Check if Raspberry Pi
        try:
            with open("/sys/firmware/devicetree/base/model", "r") as f:
                if "raspberry" in f.read().lower():
                    return "raspberry"
        except:
            pass
        return "linux"
    return "unknown"

def install_linux_deps():
    """Install Linux system dependencies."""
    print_step("Installing system dependencies (requires sudo)...")

    packages = [
        "python3", "python3-venv", "python3-pip",
        "libpulse0", "libegl1", "libxkbcommon0", "libxcb-cursor0",
        "libxcb-icccm4", "libxcb-keysyms1", "libxcb-shape0",
        "libgl1-mesa-dri", "libgl1-mesa-glx"
    ]

    # Update package list
    run_command("sudo apt update", shell=True)

    # Install packages
    cmd = f"sudo apt install -y {' '.join(packages)}"
    if run_command(cmd, shell=True, check=False):
        print("✓ System dependencies installed")
    else:
        print("⚠ Some packages may not have installed. Continuing anyway...")

def check_python_version():
    """Check if Python version is adequate."""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print(f"✗ Python 3.8+ required, found {version.major}.{version.minor}")
        sys.exit(1)
    print(f"✓ Python {version.major}.{version.minor}.{version.micro}")

def setup_venv():
    """Create virtual environment if it doesn't exist."""
    print_step("Setting up virtual environment...")

    venv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "venv")

    if os.path.exists(venv_path):
        print("✓ Virtual environment already exists")
        return venv_path

    try:
        import venv
        venv.create(venv_path, with_pip=True)
        print("✓ Virtual environment created")
        return venv_path
    except Exception as e:
        print(f"✗ Failed to create venv: {e}")
        print("\nTry installing python3-venv:")
        print("  sudo apt install python3-venv")
        sys.exit(1)

def get_pip_path(venv_path):
    """Get the pip executable path for the venv."""
    if platform.system() == "Windows":
        return os.path.join(venv_path, "Scripts", "pip.exe")
    return os.path.join(venv_path, "bin", "pip")

def get_python_path(venv_path):
    """Get the python executable path for the venv."""
    if platform.system() == "Windows":
        return os.path.join(venv_path, "Scripts", "python.exe")
    return os.path.join(venv_path, "bin", "python")

def install_python_deps(venv_path):
    """Install Python dependencies."""
    print_step("Installing Python dependencies...")

    pip_path = get_pip_path(venv_path)
    requirements = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements.txt")

    # Upgrade pip first
    run_command([pip_path, "install", "--upgrade", "pip"], check=False)

    # Install requirements
    if run_command([pip_path, "install", "-r", requirements]):
        print("✓ Python dependencies installed")
    else:
        print("✗ Failed to install some dependencies")
        sys.exit(1)

def run_app(venv_path):
    """Run the OCTAVE application."""
    print_header("Starting OCTAVE")

    python_path = get_python_path(venv_path)
    main_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.py")

    os.execv(python_path, [python_path, main_py])

def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    print_header("OCTAVE Setup")

    # Detect platform
    plat = detect_platform()
    print(f"Platform: {plat}")

    # Check Python version
    check_python_version()

    # Install system dependencies on Linux
    if plat in ("linux", "raspberry"):
        install_linux_deps()
    elif plat == "macos":
        print_step("macOS detected - system dependencies should be available")
    elif plat == "windows":
        print_step("Windows detected - no system dependencies needed")

    # Setup virtual environment
    venv_path = setup_venv()

    # Install Python dependencies
    install_python_deps(venv_path)

    print_header("Setup Complete!")

    # Show run instructions
    if plat == "windows":
        activate_cmd = r"venv\Scripts\activate"
        python_cmd = "python"
    else:
        activate_cmd = "source venv/bin/activate"
        python_cmd = "python3"

    print(f"""
To run OCTAVE:
    {activate_cmd}
    {python_cmd} main.py

Or run directly:
    {python_cmd} setup.py --run
""")

    # Run the app if --run flag is passed
    if "--run" in sys.argv:
        run_app(venv_path)

if __name__ == "__main__":
    main()
