#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QScreen>
#include <QObject>
#include <QDir>
#include <QWindow>
#include <QTimer>
#include <QtQml/qqml.h>

// Phase 1 managers
#include "managers/settingsmanager.h"
#include "managers/clock.h"
#include "managers/networkmanager.h"
#include "managers/volumecontroller.h"

// Phase 2 managers
#include "managers/mediamanager.h"
#include "managers/audioanalyzer.h"

// Phase 3 managers
#include "managers/spotifymanager.h"
#include "managers/downloadmanager.h"

// Phase 4 managers
#include "managers/obdmanager.h"
#include "managers/esp32volumemanager.h"
#include "managers/berryimumanager.h"
#include "managers/gesturemanager.h"

// Phase 5 managers (desktop only)
#include "managers/phonemirrormanager.h"
#include "managers/androidautomanager.h"
#include "items/scrcpycapture.h"
#include "items/embeddedscrcpyitem.h"
#include "items/embeddeddhuitem.h"

// Phase 6 — dashboards feature (see TODO/dashboards-roadmap.md)
#include "managers/dashboardmanager.h"

// All managers are now real C++ implementations -- no stubs needed.

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("OCTAVE");
    app.setApplicationName("OCTAVE");

    // Force Qt Quick Controls to Basic style (matches Python version —
    // required for full Slider customization)
    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;

    // ---- Auto-detect screen scale (mirrors main.py logic) ----
    qreal autoScale = 1.0;
    if (QScreen *screen = app.primaryScreen()) {
        QSize available = screen->availableSize();
        autoScale = available.height() / 720.0;
        autoScale = qBound(0.4, autoScale, 3.0);
    }

    QQmlContext *ctx = engine.rootContext();

    // ---- Scalar context properties ----
    ctx->setContextProperty("screenAutoScale", autoScale);
    ctx->setContextProperty("isAndroid", false);

    // ==================================================================
    // Phase 1: Real manager objects
    // ==================================================================

    // Settings Manager — central settings store, everything depends on this
    SettingsManager settingsManager;
    ctx->setContextProperty("settingsManager", &settingsManager);

    // Clock — time display, depends on settings for format
    Clock clock(&settingsManager);
    ctx->setContextProperty("clock", &clock);

    // Network Manager — WiFi status, update checking
    NetworkManager networkManager;
    ctx->setContextProperty("networkManager", &networkManager);

    // Volume Controller — quadratic curve + dispatch to all audio outputs.
    // Other manager pointers (media, spotify, etc.) will be wired in when
    // those managers are ported in Phase 2/3.
    VolumeController volumeController(&settingsManager);
    ctx->setContextProperty("volumeController", &volumeController);

    // Apply saved startup volume (media wiring below, after MediaManager creation)

    // ==================================================================
    // Phase 2: Media Playback
    // ==================================================================

    // Media Manager — local music playback, library scanning, playlists
    MediaManager mediaManager;
    mediaManager.setSettingsManager(&settingsManager);
    ctx->setContextProperty("mediaManager", &mediaManager);

    // Audio Analyzer — waveform visualization via FFT
    AudioAnalyzer audioAnalyzer;
    audioAnalyzer.set_quality(settingsManager.visualizerQuality());
    QObject::connect(&settingsManager, &SettingsManager::visualizerQualityChanged,
                     &audioAnalyzer, &AudioAnalyzer::set_quality);
    ctx->setContextProperty("audioAnalyzer", &audioAnalyzer);

    // Volume wiring moved below after all managers are created

    // Auto-rescan library when download completes (wired when downloadManager is ported)

    // ==================================================================
    // Phase 3: Online Features
    // ==================================================================

    // Spotify Manager — Spotify Web API integration
    SpotifyManager spotifyManager;
    spotifyManager.setSettingsManager(&settingsManager);
    ctx->setContextProperty("spotifyManager", &spotifyManager);

    // ==================================================================
    // Phase 4: Vehicle & Hardware
    // ==================================================================

    // OBD Manager — vehicle diagnostics via ELM327
    OBDManager obdManager(&settingsManager);
    ctx->setContextProperty("obdManager", &obdManager);

    // ESP32 Volume Manager — wireless rotary encoder volume control
    ESP32VolumeManager esp32VolumeManager;
    esp32VolumeManager.connect_settings_manager(&settingsManager);
    ctx->setContextProperty("esp32VolumeManager", &esp32VolumeManager);

    // BerryIMU v3 — accelerometer/gyro/mag/barometer sensor
    BerryIMUManager berryIMU;
    berryIMU.connect_settings_manager(&settingsManager);
    ctx->setContextProperty("berryIMU", &berryIMU);

    // Gesture Sensor — PAJ7620U2 gesture recognition
    GestureManager gestureSensor;
    gestureSensor.connect_settings_manager(&settingsManager);
    ctx->setContextProperty("gestureSensor", &gestureSensor);

    // ==================================================================
    // Phase 5: Desktop Integration (phone mirror, Android Auto)
    // ==================================================================

    // Android Auto Manager
    AndroidAutoManager androidAutoManager;
    ctx->setContextProperty("androidAutoManager", &androidAutoManager);

    // Register DHU frame provider for seamless Android Auto display
    engine.addImageProvider(QStringLiteral("dhuframe"),
                            androidAutoManager.frameProvider());

    // Phone Mirror Manager
    PhoneMirrorManager phoneMirrorManager;
    ctx->setContextProperty("phoneMirrorManager", &phoneMirrorManager);

    // Scrcpy Capture for frame-based phone mirroring
    ScrcpyCapture scrcpyCapture;
    scrcpyCapture.setPhoneMirrorManager(&phoneMirrorManager);
    ctx->setContextProperty("scrcpyCapture", &scrcpyCapture);
    engine.addImageProvider(QStringLiteral("scrcpyframe"),
                            scrcpyCapture.frameProvider());

    // Phone mirror settings from saved config
    QString savedScrcpyPath = settingsManager.get_scrcpy_path();
    if (!savedScrcpyPath.isEmpty())
        phoneMirrorManager.setScrcpyPath(savedScrcpyPath);
    phoneMirrorManager.setAudioEnabled(settingsManager.get_scrcpy_audio_enabled());

    // Register custom QML types for video embedding
    qmlRegisterType<EmbeddedDhuItem>("OCTAVE.AndroidAuto", 1, 0, "EmbeddedDhuItem");
    qmlRegisterType<EmbeddedScrcpyItem>("OCTAVE.PhoneMirror", 1, 0, "EmbeddedScrcpyItem");
    qmlRegisterType<ScrcpyCaptureItem>("OCTAVE.PhoneMirror", 1, 0, "ScrcpyCaptureItem");

    // Download Manager — music search & download via yt-dlp
    DownloadManager downloadManager;
    downloadManager.connect_settings_manager(&settingsManager);
    ctx->setContextProperty("downloadManager", &downloadManager);

    // Auto-rescan library when a download completes
    QObject::connect(&downloadManager, &DownloadManager::downloadComplete,
                     [&mediaManager](const QString &, const QString &) {
        mediaManager.scan_library(false);
    });

    // Wire volume controller -> all audio outputs
    // Spotify volume is debounced (300ms) to avoid 429 rate limiting
    static QTimer spotifyVolumeDebounce;
    spotifyVolumeDebounce.setSingleShot(true);
    spotifyVolumeDebounce.setInterval(300);
    static int pendingSpotifyVolume = 0;

    QObject::connect(&spotifyVolumeDebounce, &QTimer::timeout,
                     [&spotifyManager]() {
        if (spotifyManager.is_connected())
            spotifyManager.set_volume(pendingSpotifyVolume);
    });

    QObject::connect(&volumeController, &VolumeController::volumeApplied,
                     [&mediaManager](int percent, float linear) {
        mediaManager.setVolume(linear);
        pendingSpotifyVolume = percent;
        spotifyVolumeDebounce.start();
    });
    volumeController.applyVolume(settingsManager.currentVolume());

    // ---- QML import path: share frontend/ with Python version ----
    QString appDir = QGuiApplication::applicationDirPath();
    // In development, the binary is in build/ — frontend/ is one level up.
    QDir frontendDir(appDir);
    if (!frontendDir.cd("frontend")) {
        frontendDir = QDir(appDir);
        frontendDir.cdUp();  // build/ -> project root
        if (!frontendDir.cd("frontend")) {
            qWarning("Could not locate frontend/ directory");
        }
    }

    engine.addImportPath(frontendDir.absolutePath());

    // ==================================================================
    // Phase 6: Dashboards (data-driven dashboards + user-authored presets)
    // See TODO/dashboards-roadmap.md. Must be registered before engine.load
    // so QML sees the context property at first binding evaluation.
    // ==================================================================
    DashboardManager dashboardManager;
    dashboardManager.setPresetsDir(frontendDir.absoluteFilePath("dashboards/presets"));
    dashboardManager.setUserDir(SettingsManager::getAppDataDir()
                                + QStringLiteral("/dashboards"));
    ctx->setContextProperty("dashboardManager", &dashboardManager);

    // ---- Load Main.qml ----
    QString qmlFile = frontendDir.absoluteFilePath("Main.qml");
    engine.load(QUrl::fromLocalFile(qmlFile));

    if (engine.rootObjects().isEmpty()) {
        qCritical("Failed to load Main.qml from %s", qPrintable(qmlFile));
        return -1;
    }

    // Quit the app when the last window is closed (Mod+Q, X button, etc.)
    app.setQuitOnLastWindowClosed(true);
    QObject::connect(&app, &QGuiApplication::lastWindowClosed,
                     &app, &QGuiApplication::quit);

    // Wire gesture sensor actions -> media control (matching Python main.py)
    QObject::connect(&gestureSensor, &GestureManager::actionTriggered,
                     [&mediaManager, &volumeController, &settingsManager](const QString &action) {
        if (action == "next_track") mediaManager.next_track();
        else if (action == "previous_track") mediaManager.previous_track();
        else if (action == "play_pause") mediaManager.toggle_play();
        else if (action == "mute_toggle") mediaManager.toggle_mute();
        else if (action == "volume_up") {
            int step = settingsManager.gestureVolumeStep();
            volumeController.applyVolume(settingsManager.currentVolume() + step);
        } else if (action == "volume_down") {
            int step = settingsManager.gestureVolumeStep();
            volumeController.applyVolume(settingsManager.currentVolume() - step);
        }
    });

    // Wire ESP32 volume knob -> volume controller
    QObject::connect(&esp32VolumeManager, &ESP32VolumeManager::volumeChangeRequested,
                     [&volumeController, &settingsManager](float delta) {
        static float accumulator = 0.0f;
        accumulator += delta;
        if (std::abs(accumulator) >= 1.0f) {
            int change = static_cast<int>(accumulator);
            accumulator -= change;
            volumeController.applyVolume(settingsManager.currentVolume() + change);
        }
    });
    QObject::connect(&esp32VolumeManager, &ESP32VolumeManager::muteToggleRequested,
                     [&mediaManager, &esp32VolumeManager]() {
        mediaManager.toggle_mute();
        esp32VolumeManager.send_mute_state(mediaManager.is_muted());
    });

    // Cleanup on quit
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        androidAutoManager.cleanup();
        phoneMirrorManager.cleanup();
        obdManager.close();
        esp32VolumeManager.cleanup();
        berryIMU.cleanup();
        gestureSensor.cleanup();
        spotifyManager.cleanup();
        downloadManager.cleanup();
        networkManager.cleanup();
    });

    return app.exec();
}

#include "main.moc"
