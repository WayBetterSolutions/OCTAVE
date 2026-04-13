cmake_minimum_required(VERSION 3.21)
project(OCTAVE VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ---- Qt 6 ----
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Multimedia Network Concurrent NetworkAuth SerialPort Bluetooth)
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
# Optional modules needed in later phases:
#   SerialPort Bluetooth NetworkAuth

# ---- Download feature flag (OFF for app store builds) ----
option(OCTAVE_ENABLE_DOWNLOADS "Enable music download feature (disable for app store builds)" ON)

# ---- Executable ----
qt_add_executable(octave
    src/main.cpp
    src/managers/settingsmanager.h
    src/managers/settingsmanager.cpp
    src/managers/clock.h
    src/managers/clock.cpp
    src/managers/networkmanager.h
    src/managers/networkmanager.cpp
    src/managers/volumecontroller.h
    src/managers/volumecontroller.cpp
    src/managers/mediamanager.h
    src/managers/mediamanager.cpp
    src/managers/audioanalyzer.h
    src/managers/audioanalyzer.cpp
    src/managers/spotifymanager.h
    src/managers/spotifymanager.cpp
    src/managers/downloadmanager.h
    src/managers/downloadmanager.cpp
    src/managers/elm327protocol.h
    src/managers/elm327protocol.cpp
    src/managers/obdmanager.h
    src/managers/obdmanager.cpp
    src/managers/esp32volumemanager.h
    src/managers/esp32volumemanager.cpp
    src/managers/berryimumanager.h
    src/managers/berryimumanager.cpp
    src/managers/gesturemanager.h
    src/managers/gesturemanager.cpp
    src/managers/phonemirrormanager.h
    src/managers/phonemirrormanager.cpp
    src/managers/androidautomanager.h
    src/managers/androidautomanager.cpp
    src/items/scrcpycapture.h
    src/items/scrcpycapture.cpp
    src/items/embeddedscrcpyitem.h
    src/items/embeddedscrcpyitem.cpp
    src/items/embeddeddhuitem.h
    src/items/embeddeddhuitem.cpp
)

target_compile_definitions(octave PRIVATE
    $<$<BOOL:${OCTAVE_ENABLE_DOWNLOADS}>:OCTAVE_ENABLE_DOWNLOADS>
)

target_link_libraries(octave PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::Network
    Qt6::Concurrent
    Qt6::NetworkAuth
    Qt6::SerialPort
    Qt6::Bluetooth
    PkgConfig::TAGLIB
)

# ---- QML import path: reuse existing frontend/ directory ----
# The QML files live in frontend/ and are loaded at runtime (not compiled into resources).
# This keeps them shared with the Python backend during migration.
set_target_properties(octave PROPERTIES
    QT_QML_IMPORT_PATH "${CMAKE_SOURCE_DIR}/frontend"
)
