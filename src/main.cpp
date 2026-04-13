#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QScreen>
#include <QObject>
#include <QDir>

// Minimal stub QObject — provides an empty QObject so QML context property
// references like "settingsManager ? settingsManager.foo : default" resolve
// to a non-null object without crashing.  Real manager classes will replace
// these one-by-one as each phase is ported.
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

    // ---- Stub manager objects ----
    // Each stub is a plain QObject.  QML null-checks these with the
    // "settingsManager ? settingsManager.foo : fallback" pattern, so a
    // non-null QObject is enough to avoid binding errors.  Property/slot
    // access on the stub will produce warnings in the console — that's
    // expected and shows exactly which APIs each QML file uses.
    //
    // Replace each stub with the real C++ manager class as it's ported.

    Stub settingsManager;
    ctx->setContextProperty("settingsManager", &settingsManager);

    Stub clock;
    ctx->setContextProperty("clock", &clock);

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

    Stub volumeController;
    ctx->setContextProperty("volumeController", &volumeController);

    Stub berryIMU;
    ctx->setContextProperty("berryIMU", &berryIMU);

    Stub gestureSensor;
    ctx->setContextProperty("gestureSensor", &gestureSensor);

    Stub networkManager;
    ctx->setContextProperty("networkManager", &networkManager);

    Stub downloadManager;
    ctx->setContextProperty("downloadManager", &downloadManager);

    // ---- QML import path: share frontend/ with Python version ----
    QString appDir = QGuiApplication::applicationDirPath();
    // In development, the binary is in build/ — frontend/ is one level up.
    // Walk up from the binary location to find frontend/.
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

    return app.exec();
}

#include "main.moc"
