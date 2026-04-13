#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QScreen>
#include <QObject>
#include <QDir>
#include <QWindow>
#include <QTimer>

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

// Minimal stub for managers not yet ported.
// Provides no-op implementations of commonly called methods so QML click
// handlers don't abort with TypeError before reaching real manager calls.
class Stub : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;

    // Methods QML calls on spotifyManager, obdManager, etc.
    Q_INVOKABLE bool is_connected() const { return false; }
    Q_INVOKABLE bool is_playing() const { return false; }
    Q_INVOKABLE bool has_credentials() const { return false; }
    Q_INVOKABLE bool is_scanning() const { return false; }
    Q_INVOKABLE bool is_connected_bool() const { return false; }
    Q_INVOKABLE QString get_connection_status() const { return QStringLiteral("Disconnected"); }
    Q_INVOKABLE QString get_current_track_name() const { return QString(); }
    Q_INVOKABLE void cleanup() {}
    Q_INVOKABLE void pause() {}
};

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
    // Stubs for managers not yet ported (Phases 3-5)
    // ==================================================================

    Stub obdManager;
    ctx->setContextProperty("obdManager", &obdManager);

    // Spotify Manager — Spotify Web API integration
    SpotifyManager spotifyManager;
    spotifyManager.setSettingsManager(&settingsManager);
    ctx->setContextProperty("spotifyManager", &spotifyManager);

    Stub androidAutoManager;
    ctx->setContextProperty("androidAutoManager", &androidAutoManager);

    Stub phoneMirrorManager;
    ctx->setContextProperty("phoneMirrorManager", &phoneMirrorManager);

    Stub scrcpyCapture;
    ctx->setContextProperty("scrcpyCapture", &scrcpyCapture);

    Stub esp32VolumeManager;
    ctx->setContextProperty("esp32VolumeManager", &esp32VolumeManager);

    Stub berryIMU;
    ctx->setContextProperty("berryIMU", &berryIMU);

    Stub gestureSensor;
    ctx->setContextProperty("gestureSensor", &gestureSensor);

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

    // Cleanup on quit
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        spotifyManager.cleanup();
        downloadManager.cleanup();
        networkManager.cleanup();
    });

    return app.exec();
}

#include "main.moc"
