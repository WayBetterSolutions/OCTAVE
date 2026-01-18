#!/bin/bash
# Octave Start Script
# Launches Octave with proper environment

OCTAVE_DIR="/home/rob/Roxy/octave"

cd "$OCTAVE_DIR" || exit 1
source ./venv/bin/activate

export DISPLAY=:0
export MESA_GL_VERSION_OVERRIDE=3.3

exec python3 main.py >> /home/rob/Roxy/octave.log 2>&1
