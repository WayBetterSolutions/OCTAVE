@echo off
REM OCTAVE Windows Build Script
REM Creates standalone executable and Inno Setup installer

setlocal enabledelayedexpansion

echo ========================================
echo OCTAVE Windows Build Script
echo ========================================
echo.

REM Get the project root directory (parent of build_scripts)
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

REM Check for Python
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Python not found in PATH
    exit /b 1
)

echo [1/5] Setting up virtual environment...
if not exist "venv" (
    python -m venv venv
)
call venv\Scripts\activate.bat

echo [2/5] Installing dependencies...
pip install -r requirements.txt --quiet
pip install pyinstaller --quiet

echo [3/5] Cleaning previous builds...
if exist "build" rmdir /s /q "build"
if exist "dist" rmdir /s /q "dist"

echo [4/5] Building executable with PyInstaller...
pyinstaller octave.spec --noconfirm

if %ERRORLEVEL% neq 0 (
    echo ERROR: PyInstaller build failed
    exit /b 1
)

echo [5/5] Build complete!
echo.
echo Executable location: dist\OCTAVE\OCTAVE.exe
echo.

REM Check if Inno Setup is installed
set "ISCC_PATH="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if defined ISCC_PATH (
    echo Creating installer with Inno Setup...
    "%ISCC_PATH%" "%PROJECT_ROOT%\build_scripts\installer_windows.iss"
    if %ERRORLEVEL% equ 0 (
        echo.
        echo Installer created: dist\OCTAVE_Setup.exe
    ) else (
        echo WARNING: Installer creation failed
    )
) else (
    echo.
    echo NOTE: Inno Setup not found. To create an installer:
    echo 1. Download Inno Setup from https://jrsoftware.org/isdl.php
    echo 2. Install it to the default location
    echo 3. Run this script again
    echo.
    echo You can still distribute the dist\OCTAVE folder as a portable app.
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
pause
