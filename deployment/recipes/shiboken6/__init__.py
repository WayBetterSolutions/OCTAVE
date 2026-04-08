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
# Download shiboken6 Android wheels from: https://download.qt.io/official_releases/QtForPython/
# Required: shiboken6 6.11.0 wheels built for android_aarch64, CPython 3.11 (cp311)
# Override location with OCTAVE_WHEELS_DIR env var if needed
_deployment_dir = Path(__file__).resolve().parent.parent.parent
_wheels_dir = Path(os.environ.get('OCTAVE_WHEELS_DIR', str(_deployment_dir / 'wheels')))


class ShibokenRecipe(PythonRecipe):
    version = '6.11.0'
    wheel_path = str(_wheels_dir / 'shiboken6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl')

    call_hostpython_via_targetpython = False
    install_in_hostpython = False

    def build_arch(self, arch):
        ''' Unzip the wheel and copy into site-packages of target'''
        info('Installing {} into site-packages'.format(self.name))
        with zipfile.ZipFile(self.wheel_path, 'r') as zip_ref:
            info('Unzip wheels and copy into {}'.format(self.ctx.get_python_install_dir(arch.arch)))
            zip_ref.extractall(self.ctx.get_python_install_dir(arch.arch))

        lib_dir = Path(f"{self.ctx.get_python_install_dir(arch.arch)}/shiboken6")
        shutil.copyfile(lib_dir / "libshiboken6.abi3.so",
                        Path(self.ctx.get_libs_dir(arch.arch)) / "libshiboken6.abi3.so")


recipe = ShibokenRecipe()