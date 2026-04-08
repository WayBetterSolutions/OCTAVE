# Copyright (C) 2023 The Qt Company Ltd.
# SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only
from __future__ import annotations

import os
import shutil
import zipfile
from pathlib import Path

from pythonforandroid.logger import info
from pythonforandroid.recipe import PythonRecipe

# Wheel files should be placed in deployment/wheels/
# Download PySide6 Android wheels from: https://download.qt.io/official_releases/QtForPython/
# Required: PySide6 6.11.0 wheels built for android_aarch64, CPython 3.11 (cp311)
# Override location with OCTAVE_WHEELS_DIR env var if needed
_deployment_dir = Path(__file__).resolve().parent.parent.parent
_wheels_dir = Path(os.environ.get('OCTAVE_WHEELS_DIR', str(_deployment_dir / 'wheels')))


class PySideRecipe(PythonRecipe):
    version = '6.11.0'
    wheel_path = str(_wheels_dir / 'pyside6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl')
    depends = ["shiboken6"]
    call_hostpython_via_targetpython = False
    install_in_hostpython = False

    def build_arch(self, arch):
        """Unzip the wheel and copy into site-packages of target"""

        info("Copying libc++_shared.so from SDK to be loaded on startup")
        libcpp_path = f"{self.ctx.ndk.sysroot_lib_dir}/{arch.command_prefix}/libc++_shared.so"
        shutil.copyfile(libcpp_path, Path(self.ctx.get_libs_dir(arch.arch)) / "libc++_shared.so")

        info(f"Installing {self.name} into site-packages")
        with zipfile.ZipFile(self.wheel_path, "r") as zip_ref:
            info("Unzip wheels and copy into {}".format(self.ctx.get_python_install_dir(arch.arch)))
            zip_ref.extractall(self.ctx.get_python_install_dir(arch.arch))

        lib_dir = Path(f"{self.ctx.get_python_install_dir(arch.arch)}/PySide6/Qt/lib")

        info("Copying Qt libraries to be loaded on startup")
        shutil.copytree(lib_dir, self.ctx.get_libs_dir(arch.arch), dirs_exist_ok=True)
        shutil.copyfile(lib_dir.parent.parent / "libpyside6.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "libpyside6.abi3.so")

          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtOpenGL.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtOpenGL.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtQml.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtQml.abi3.so")
        # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / "libpyside6qml.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "libpyside6qml.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtConcurrent.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtConcurrent.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtCore.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtCore.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtWidgets.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtWidgets.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtQuickControls2.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtQuickControls2.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtQuick.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtQuick.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtMultimedia.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtMultimedia.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtGui.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtGui.abi3.so")
          # noqa: E999
          # noqa: E999
        shutil.copyfile(lib_dir.parent.parent / f"QtNetwork.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "QtNetwork.abi3.so")
          # noqa: E999
          # noqa: E999

          # noqa: E999

          # noqa: E999
        plugin_path = (lib_dir.parent / "plugins" / "multimedia" /
                      f"libplugins_multimedia_ffmpegmediaplugin_{arch.arch}.so")
        if plugin_path.exists():
            shutil.copyfile(plugin_path,
                            (Path(self.ctx.get_libs_dir(arch.arch)) /
                             f"libplugins_multimedia_ffmpegmediaplugin_{arch.arch}.so"))
          # noqa: E999
        plugin_path = (lib_dir.parent / "plugins" / "platforms" /
                      f"libplugins_platforms_qtforandroid_{arch.arch}.so")
        if plugin_path.exists():
            shutil.copyfile(plugin_path,
                            (Path(self.ctx.get_libs_dir(arch.arch)) /
                             f"libplugins_platforms_qtforandroid_{arch.arch}.so"))
          # noqa: E999
        plugin_path = (lib_dir.parent / "plugins" / "multimedia" /
                      f"libplugins_multimedia_androidmediaplugin_{arch.arch}.so")
        if plugin_path.exists():
            shutil.copyfile(plugin_path,
                            (Path(self.ctx.get_libs_dir(arch.arch)) /
                             f"libplugins_multimedia_androidmediaplugin_{arch.arch}.so"))
          # noqa: E999
        # Copy image format plugins (needed for album art, SVGs, etc.)
        for fmt in ["qjpeg", "qsvg", "qgif", "qico", "qwebp"]:
            plugin = (lib_dir.parent / "plugins" / "imageformats" /
                      f"libplugins_imageformats_{fmt}_{arch.arch}.so")
            if plugin.exists():
                shutil.copyfile(plugin,
                                Path(self.ctx.get_libs_dir(arch.arch)) / plugin.name)
                info(f"Copied {fmt} image format plugin")

        # Copy SVG icon engine
        iconengine = (lib_dir.parent / "plugins" / "iconengines" /
                      f"libplugins_iconengines_qsvgicon_{arch.arch}.so")
        if iconengine.exists():
            shutil.copyfile(iconengine,
                            Path(self.ctx.get_libs_dir(arch.arch)) / iconengine.name)
            info("Copied SVG icon engine plugin")

        # Copy SVG and Bluetooth shared libraries
        for extra_lib in ["libQt6Svg", "libQt6SvgWidgets", "libQt6Bluetooth"]:
            extra_so = lib_dir / f"{extra_lib}_{arch.arch}.so"
            if extra_so.exists():
                shutil.copyfile(extra_so,
                                Path(self.ctx.get_libs_dir(arch.arch)) / extra_so.name)


recipe = PySideRecipe()