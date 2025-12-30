# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for OCTAVE
Cross-platform build configuration for Windows, macOS, and Linux
"""

import sys
import os
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# Determine platform
is_windows = sys.platform == 'win32'
is_macos = sys.platform == 'darwin'
is_linux = sys.platform.startswith('linux')

# Project paths
PROJECT_ROOT = os.path.abspath(SPECPATH)
FRONTEND_DIR = os.path.join(PROJECT_ROOT, 'frontend')
BACKEND_DIR = os.path.join(PROJECT_ROOT, 'backend')

# Collect all frontend files (QML, assets, fonts)
frontend_datas = []
for root, dirs, files in os.walk(FRONTEND_DIR):
    # Skip source design files
    if '-src' in root:
        continue
    for file in files:
        src = os.path.join(root, file)
        # Destination preserves directory structure
        dst = os.path.relpath(root, PROJECT_ROOT)
        frontend_datas.append((src, dst))

# Backend data files (exclude .pyc, include necessary resources)
backend_datas = []
for root, dirs, files in os.walk(BACKEND_DIR):
    # Skip __pycache__ and temp directories
    dirs[:] = [d for d in dirs if d not in ('__pycache__', 'temp', 'media')]
    for file in files:
        if file.endswith(('.json', '.txt')) and not file.startswith('.'):
            src = os.path.join(root, file)
            dst = os.path.relpath(root, PROJECT_ROOT)
            backend_datas.append((src, dst))

# Collect PySide6 QML modules
pyside6_datas = collect_data_files('PySide6', includes=['**/*.qml', '**/*.js'])

# Hidden imports for PySide6 and dependencies
hidden_imports = [
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtQml',
    'PySide6.QtQuick',
    'PySide6.QtQuickControls2',
    'PySide6.QtWidgets',
    'PySide6.QtMultimedia',
    'PySide6.QtNetwork',
    'PySide6.QtSvg',
    'PySide6.QtSvgWidgets',
    # Backend dependencies
    'mutagen',
    'mutagen.mp3',
    'mutagen.id3',
    'spotipy',
    'spotipy.oauth2',
    'obd',
    'obd.commands',
    'sounddevice',
    'numpy',
    'scipy',
    'keyring',
    'keyring.backends',
]

# Platform-specific keyring backends
if is_windows:
    hidden_imports.extend([
        'keyring.backends.Windows',
        'win32timezone',
    ])
elif is_macos:
    hidden_imports.extend([
        'keyring.backends.macOS',
    ])
else:
    hidden_imports.extend([
        'keyring.backends.SecretService',
        'keyring.backends.kwallet',
    ])

# Collect submodules
hidden_imports.extend(collect_submodules('PySide6'))

a = Analysis(
    ['main.py'],
    pathex=[PROJECT_ROOT],
    binaries=[],
    datas=frontend_datas + backend_datas + pyside6_datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'PIL',
        'cv2',
        'pandas',
        'pytest',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Platform-specific executable settings
if is_windows:
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name='OCTAVE',
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        console=False,  # GUI application, no console
        disable_windowed_traceback=False,
        argv_emulation=False,
        target_arch=None,
        codesign_identity=None,
        entitlements_file=None,
        icon=os.path.join(PROJECT_ROOT, 'build_resources', 'icon.ico') if os.path.exists(os.path.join(PROJECT_ROOT, 'build_resources', 'icon.ico')) else None,
    )
elif is_macos:
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name='OCTAVE',
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        console=False,
        disable_windowed_traceback=False,
        argv_emulation=True,  # macOS needs this for proper app behavior
        target_arch=None,
        codesign_identity=None,
        entitlements_file=None,
        icon=os.path.join(PROJECT_ROOT, 'build_resources', 'icon.icns') if os.path.exists(os.path.join(PROJECT_ROOT, 'build_resources', 'icon.icns')) else None,
    )
else:  # Linux
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name='octave',  # lowercase for Linux convention
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        console=False,
        disable_windowed_traceback=False,
        argv_emulation=False,
        target_arch=None,
        codesign_identity=None,
        entitlements_file=None,
    )

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='OCTAVE',
)

# macOS app bundle
if is_macos:
    app = BUNDLE(
        coll,
        name='OCTAVE.app',
        icon=os.path.join(PROJECT_ROOT, 'build_resources', 'icon.icns') if os.path.exists(os.path.join(PROJECT_ROOT, 'build_resources', 'icon.icns')) else None,
        bundle_identifier='com.waybettersolutions.octave',
        info_plist={
            'CFBundleName': 'OCTAVE',
            'CFBundleDisplayName': 'OCTAVE',
            'CFBundleVersion': '1.0.0',
            'CFBundleShortVersionString': '1.0.0',
            'NSHighResolutionCapable': True,
            'NSRequiresAquaSystemAppearance': False,  # Support dark mode
            'LSMinimumSystemVersion': '10.14.0',
            'NSBluetoothAlwaysUsageDescription': 'OCTAVE needs Bluetooth access to connect to OBD-II adapters.',
            'NSMicrophoneUsageDescription': 'OCTAVE needs microphone access for audio features.',
        },
    )
