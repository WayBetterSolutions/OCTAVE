cmake_minimum_required(VERSION 3.21)
project(OCTAVE VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ---- Qt 6 ----
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Multimedia Network)
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
)

# ---- QML import path: reuse existing frontend/ directory ----
# The QML files live in frontend/ and are loaded at runtime (not compiled into resources).
# This keeps them shared with the Python backend during migration.
set_target_properties(octave PROPERTIES
    QT_QML_IMPORT_PATH "${CMAKE_SOURCE_DIR}/frontend"
)
