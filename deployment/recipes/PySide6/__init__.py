# Copyright (C) 2023 The Qt Company Ltd.
# SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only
from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

from pythonforandroid.logger import info
from pythonforandroid.recipe import PythonRecipe


class PySideRecipe(PythonRecipe):
    version = '6.11.0'
    wheel_path = '/home/rhea/Dropbox/Oasis/_OCTAVE_ANDROID_WHEELS/pyside6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl'
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


recipe = PySideRecipe()