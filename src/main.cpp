#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QScreen>
#include <QObject>
#include <QDir>

// Phase 1 managers (real C++ implementations)
#include "managers/settingsmanager.h"
#include "managers/clock.h"
#include "managers/networkmanager.h"
#include "managers/volumecontroller.h"

// Minimal stub for managers not yet ported.
class Stub : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
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

    // Apply saved startup volume
    volumeController.applyVolume(settingsManager.currentVolume());

    // ==================================================================
    // Stubs for managers not yet ported (Phases 2-5)
    // ==================================================================

    Stub mediaManager;
    ctx->setContextProperty("mediaManager", &mediaManager);

    Stub audioAnalyzer;
    ctx->setContextProperty("audioAnalyzer", &audioAnalyzer);

    Stub obdManager;
    ctx->setContextProperty("obdManager", &obdManager);

    Stub spotifyManager;
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

    Stub downloadManager;
    ctx->setContextProperty("downloadManager", &downloadManager);

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

    // Cleanup on quit
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&]() {
        networkManager.cleanup();
    });

    return app.exec();
}

#include "main.moc"
