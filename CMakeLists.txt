cmake_minimum_required(VERSION 3.21)
project(OCTAVE VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ---- Qt 6 ----
set(OCTAVE_QT_COMPONENTS Core Gui Qml Quick QuickControls2 Multimedia Network Concurrent NetworkAuth SerialPort Bluetooth)
if(ANDROID)
    list(APPEND OCTAVE_QT_COMPONENTS Sensors)
endif()
find_package(Qt6 REQUIRED COMPONENTS ${OCTAVE_QT_COMPONENTS})
# Qt6::CorePrivate is an imported target provided by Qt6::Core — not a
# separately-findable component. Linking it grants access to private headers
# (QtAndroidPrivate::requestPermission on Android).

# TagLib only available on desktop (no pkg-config on Android host; mobile uses Qt metadata fallback)
if(NOT ANDROID)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
endif()

# ---- Download feature flag ----
# Desktop: default ON. Disable with `-DOCTAVE_ENABLE_DOWNLOADS=OFF` for app-store builds
#          (yt-dlp is forbidden on Apple/Microsoft/Play stores).
# Android: default ON for sideload APKs — downloads run through the
#          youtubedl-android AAR (Python + yt-dlp + ffmpeg bundled). For Play
#          Store builds, pass `-DOCTAVE_ENABLE_DOWNLOADS=OFF` explicitly.
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
    src/managers/dashboardmanager.h
    src/managers/dashboardmanager.cpp
    src/items/scrcpycapture.h
    src/items/scrcpycapture.cpp
    src/items/embeddedscrcpyitem.h
    src/items/embeddedscrcpyitem.cpp
    src/items/embeddeddhuitem.h
    src/items/embeddeddhuitem.cpp
    # Android-only platform headers: fully guarded by #ifdef Q_OS_ANDROID
    # so AUTOMOC on desktop produces empty moc files (no Q_OBJECT visible).
    src/platform/androidmediabridge.h
    src/platform/androidprocessadapter.h
)

target_compile_definitions(octave PRIVATE
    $<$<BOOL:${OCTAVE_ENABLE_DOWNLOADS}>:OCTAVE_ENABLE_DOWNLOADS>
    # Activate existing #ifndef Q_OS_MOBILE guards on Android (and iOS later).
    # Without this define the guards are no-ops and desktop-only code compiles on mobile.
    $<$<BOOL:${ANDROID}>:Q_OS_MOBILE>
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
)
if(ANDROID)
    target_link_libraries(octave PRIVATE Qt6::Sensors Qt6::CorePrivate)
else()
    target_link_libraries(octave PRIVATE PkgConfig::TAGLIB)
endif()

# ---- QML import path: reuse existing frontend/ directory ----
# The QML files live in frontend/ and are loaded at runtime (not compiled into resources).
# This keeps them shared with the Python backend during migration.
set_target_properties(octave PROPERTIES
    QT_QML_IMPORT_PATH "${CMAKE_SOURCE_DIR}/frontend"
)

# ---- Android packaging ----
if(ANDROID)
    # androiddeployqt packages the app, bundles Qt .so's, generates the APK.
    # Properties must be set before the auto-finalize step that qt_add_executable
    # schedules (via CMake's DEFERRED mechanism).
    set_target_properties(octave PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android"
        # Capped at 33 by AGP 7.4.1 (Qt 6.7.3's target AGP).
        # Bump to 34+ once upgrading to Qt 6.8+ + AGP 8.5+ (Play Store target).
        QT_ANDROID_TARGET_SDK_VERSION 33
        QT_ANDROID_MIN_SDK_VERSION 30
        QT_ANDROID_ABIS "arm64-v8a"
        # Bundle the QML frontend/ dir into the APK so runtime-loaded QML is findable.
        QT_QML_ROOT_PATH "${CMAKE_SOURCE_DIR}/frontend"
    )
    # No manual qt_finalize_executable call — qt_add_executable schedules it automatically.
endif()
