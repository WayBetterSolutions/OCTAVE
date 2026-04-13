#ifndef Q_OS_MOBILE

#include "scrcpycapture.h"
#include "../managers/phonemirrormanager.h"

#include <QGuiApplication>
#include <QScreen>
#include <QThread>

#include <cmath>

Q_LOGGING_CATEGORY(lcScrcpyCapture, "octave.scrcpy.capture")

// =====================================================================
// ScrcpyFrameProvider
// =====================================================================

ScrcpyFrameProvider::ScrcpyFrameProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage ScrcpyFrameProvider::requestImage(const QString &id, QSize *size,
                                         const QSize &requestedSize)
{
    Q_UNUSED(id)
    Q_UNUSED(requestedSize)

    QMutexLocker lock(&m_mutex);
    if (!m_currentFrame.isNull()) {
        if (size)
            *size = m_currentFrame.size();
        return m_currentFrame;
    }
    // Placeholder when no frame is available yet
    QImage placeholder(720, 1280, QImage::Format_RGB32);
    placeholder.fill(Qt::black);
    if (size)
        *size = placeholder.size();
    return placeholder;
}

void ScrcpyFrameProvider::updateFrame(const QImage &frame)
{
    QMutexLocker lock(&m_mutex);
    m_currentFrame = frame;
}

bool ScrcpyFrameProvider::hasFrame() const
{
    QMutexLocker lock(&m_mutex);
    return !m_currentFrame.isNull();
}

// =====================================================================
// ScrcpyCapture
// =====================================================================

ScrcpyCapture::ScrcpyCapture(QObject *parent)
    : QObject(parent)
    , m_frameProvider(new ScrcpyFrameProvider)
{
}

ScrcpyCapture::~ScrcpyCapture()
{
    stopCapture();
    // Note: m_frameProvider ownership transfers to the QML engine when
    // registered via addImageProvider — do NOT delete it here.
}

// ─── Window handle ────────────────────────────────────────────────────

void ScrcpyCapture::setWindowHandle(int hwnd)
{
    m_hwnd = hwnd;
    qCDebug(lcScrcpyCapture) << "Window handle set to:" << hwnd;
}

// ─── Start / Stop ─────────────────────────────────────────────────────

void ScrcpyCapture::startCapture()
{
    if (m_capturing)
        return;

    if (!m_hwnd) {
        emit error(QStringLiteral("No window handle set"));
        return;
    }

    qCDebug(lcScrcpyCapture) << "Starting capture of window" << m_hwnd
                              << "at" << m_targetFps << "FPS";

    m_capturing = true;
    m_frameCount = 0;

    // Fetch device info for ADB-based touch input
    fetchDeviceInfo();

    // Create capture timer
    if (!m_captureTimer) {
        m_captureTimer = new QTimer(this);
        connect(m_captureTimer, &QTimer::timeout, this, &ScrcpyCapture::captureFrame);
    }
    m_captureTimer->start(1000 / m_targetFps);

    emit captureStarted();
}

void ScrcpyCapture::stopCapture()
{
    if (!m_capturing)
        return;

    qCDebug(lcScrcpyCapture) << "Stopping capture (captured" << m_frameCount << "frames)";
    m_capturing = false;

    if (m_captureTimer) {
        m_captureTimer->stop();
    }

    emit captureStopped();
}

// ─── Frame capture ────────────────────────────────────────────────────

void ScrcpyCapture::captureFrame()
{
    if (!m_capturing || !m_hwnd)
        return;

    // Portable fallback: use QScreen::grabWindow()
    // This works on all desktop platforms without platform-specific APIs
    QScreen *screen = QGuiApplication::primaryScreen();
    if (!screen) {
        return;
    }

    // grabWindow with WId — captures the specific window
    QPixmap pixmap = screen->grabWindow(static_cast<WId>(m_hwnd));
    if (pixmap.isNull())
        return;

    QImage image = pixmap.toImage();
    if (image.isNull())
        return;

    const int w = image.width();
    const int h = image.height();

    // Track size changes
    if (w != m_lastWidth || h != m_lastHeight) {
        m_lastWidth = w;
        m_lastHeight = h;
        emit frameSizeChanged(w, h);
        qCDebug(lcScrcpyCapture) << "Frame size:" << w << "x" << h;
    }

    // Ensure consistent format for the provider
    if (image.format() != QImage::Format_ARGB32
        && image.format() != QImage::Format_ARGB32_Premultiplied
        && image.format() != QImage::Format_RGB32) {
        image = image.convertToFormat(QImage::Format_ARGB32);
    }

    m_frameProvider->updateFrame(image);
    ++m_frameCount;
    emit frameReady();
}

// ─── Manager linkage ──────────────────────────────────────────────────

void ScrcpyCapture::setPhoneMirrorManager(QObject *manager)
{
    m_manager = qobject_cast<PhoneMirrorManager *>(manager);
    qCDebug(lcScrcpyCapture) << "PhoneMirrorManager linked:" << (m_manager != nullptr);
}

void ScrcpyCapture::fetchDeviceInfo()
{
    if (!m_manager)
        return;

    m_adbPath = m_manager->adbPath();
    qCDebug(lcScrcpyCapture) << "ADB path:" << m_adbPath;

    m_deviceSerial = m_manager->getDeviceSerial();
    qCDebug(lcScrcpyCapture) << "Device serial:" << m_deviceSerial;

    const QString resStr = m_manager->getDeviceResolution();
    if (!resStr.isEmpty() && resStr.contains(QLatin1Char('x'))) {
        const QStringList parts = resStr.split(QLatin1Char('x'));
        if (parts.size() == 2) {
            bool okW = false, okH = false;
            const int w = parts[0].toInt(&okW);
            const int h = parts[1].toInt(&okH);
            if (okW && okH) {
                m_deviceWidth = w;
                m_deviceHeight = h;
                qCDebug(lcScrcpyCapture) << "Device resolution:" << w << "x" << h;
            }
        }
    }
}

// ─── Coordinate mapping ──────────────────────────────────────────────

bool ScrcpyCapture::isLandscape() const
{
    return m_lastWidth > m_lastHeight;
}

QPair<int, int> ScrcpyCapture::convertToDeviceCoords(float relX, float relY) const
{
    int deviceX, deviceY;

    if (isLandscape()) {
        // Landscape: effective width = portrait height, effective height = portrait width
        deviceX = static_cast<int>(relX * m_deviceHeight);
        deviceY = static_cast<int>(relY * m_deviceWidth);
    } else {
        // Portrait: direct mapping
        deviceX = static_cast<int>(relX * m_deviceWidth);
        deviceY = static_cast<int>(relY * m_deviceHeight);
    }

    // Clamp
    deviceX = qBound(0, deviceX, m_deviceWidth - 1);
    deviceY = qBound(0, deviceY, m_deviceHeight - 1);

    return {deviceX, deviceY};
}

// ─── ADB async runner ─────────────────────────────────────────────────

void ScrcpyCapture::runAdbAsync(const QStringList &args)
{
    if (m_adbPath.isEmpty())
        return;

    QStringList fullArgs;
    if (!m_deviceSerial.isEmpty())
        fullArgs << QStringLiteral("-s") << m_deviceSerial;
    fullArgs << args;

    // Fire-and-forget process (auto-deletes on finish)
    auto *proc = new QProcess(this);
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            proc, &QProcess::deleteLater);
    connect(proc, &QProcess::errorOccurred, proc, &QProcess::deleteLater);
    proc->start(m_adbPath, fullArgs);
}

// ─── Touch input ──────────────────────────────────────────────────────

void ScrcpyCapture::sendTap(float relX, float relY)
{
    if (m_adbPath.isEmpty() || m_deviceWidth <= 0)
        return;

    const auto [dx, dy] = convertToDeviceCoords(relX, relY);

    qCDebug(lcScrcpyCapture) << "ADB tap: rel(" << relX << relY << ") -> device("
                              << dx << dy << ")"
                              << (isLandscape() ? "[landscape]" : "[portrait]");

    runAdbAsync({
        QStringLiteral("shell"), QStringLiteral("input"),
        QStringLiteral("tap"),
        QString::number(dx), QString::number(dy)
    });
}

void ScrcpyCapture::sendSwipe(float relX1, float relY1,
                               float relX2, float relY2,
                               int durationMs)
{
    if (m_adbPath.isEmpty() || m_deviceWidth <= 0)
        return;

    const auto [x1, y1] = convertToDeviceCoords(relX1, relY1);
    const auto [x2, y2] = convertToDeviceCoords(relX2, relY2);

    qCDebug(lcScrcpyCapture) << "ADB swipe:" << x1 << y1 << "->" << x2 << y2
                              << "duration=" << durationMs << "ms"
                              << (isLandscape() ? "[landscape]" : "[portrait]");

    runAdbAsync({
        QStringLiteral("shell"), QStringLiteral("input"),
        QStringLiteral("swipe"),
        QString::number(x1), QString::number(y1),
        QString::number(x2), QString::number(y2),
        QString::number(durationMs)
    });
}

void ScrcpyCapture::sendTouchEvent(float relX, float relY, bool pressed)
{
    if (pressed) {
        m_touchStartX = relX;
        m_touchStartY = relY;
        m_touchMoved = false;
        qCDebug(lcScrcpyCapture) << "Touch START at rel(" << relX << relY << ")";
    } else {
        qCDebug(lcScrcpyCapture) << "Touch END at rel(" << relX << relY << ")";
        const float dx = std::abs(relX - m_touchStartX);
        const float dy = std::abs(relY - m_touchStartY);

        if (m_touchMoved && (dx > 0.05f || dy > 0.05f)) {
            qCDebug(lcScrcpyCapture) << "Detected SWIPE (dx=" << dx << "dy=" << dy << ")";
            sendSwipe(m_touchStartX, m_touchStartY, relX, relY, 200);
        } else {
            qCDebug(lcScrcpyCapture) << "Detected TAP";
            sendTap(m_touchStartX, m_touchStartY);
        }
    }
}

void ScrcpyCapture::sendTouchMove(float relX, float relY)
{
    Q_UNUSED(relX)
    Q_UNUSED(relY)
    m_touchMoved = true;
}

// =====================================================================
// ScrcpyCaptureItem
// =====================================================================

ScrcpyCaptureItem::ScrcpyCaptureItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setAcceptedMouseButtons(Qt::LeftButton);
    qCDebug(lcScrcpyCapture) << "ScrcpyCaptureItem created";
}

int ScrcpyCaptureItem::frameWidth() const
{
    return m_capture ? m_capture->frameWidth() : 0;
}

int ScrcpyCaptureItem::frameHeight() const
{
    return m_capture ? m_capture->frameHeight() : 0;
}

bool ScrcpyCaptureItem::isStreaming() const
{
    return m_capture != nullptr && m_capture->isCapturing();
}

void ScrcpyCaptureItem::setCapture(ScrcpyCapture *capture)
{
    m_capture = capture;
    if (capture) {
        connect(capture, &ScrcpyCapture::frameReady,
                this, &ScrcpyCaptureItem::onFrameReady);
        connect(capture, &ScrcpyCapture::error,
                this, &ScrcpyCaptureItem::onCaptureError);
    }
}

void ScrcpyCaptureItem::connectToManager(QObject *manager)
{
    // Disconnect previous
    if (m_manager) {
        m_manager->disconnect(this);
    }

    m_manager = manager;
    if (!manager)
        return;

    qCDebug(lcScrcpyCapture) << "ScrcpyCaptureItem connecting to manager";

    // Use PhoneMirrorManager signals
    auto *pmm = qobject_cast<PhoneMirrorManager *>(manager);
    if (!pmm)
        return;

    connect(pmm, &PhoneMirrorManager::scrcpyStarted,
            this, &ScrcpyCaptureItem::onScrcpyStarted, Qt::QueuedConnection);
    connect(pmm, &PhoneMirrorManager::scrcpyStopped,
            this, &ScrcpyCaptureItem::onScrcpyStopped, Qt::QueuedConnection);
    connect(pmm, &PhoneMirrorManager::scrcpyError,
            this, &ScrcpyCaptureItem::onScrcpyError, Qt::QueuedConnection);

    // If already running, kick off capture
    if (pmm->isRunning() && pmm->scrcpyWindowHandle()) {
        qCDebug(lcScrcpyCapture) << "Manager already has running scrcpy";
        QTimer::singleShot(100, this, [this, hwnd = pmm->scrcpyWindowHandle()]() {
            onScrcpyStarted(hwnd);
        });
    }
}

void ScrcpyCaptureItem::handleClick(float x, float y)
{
    if (m_capture && m_capture->isCapturing()) {
        const float relX = x / static_cast<float>(width());
        const float relY = y / static_cast<float>(height());
        m_capture->sendTap(relX, relY);
    }
}

void ScrcpyCaptureItem::detach()
{
    qCDebug(lcScrcpyCapture) << "ScrcpyCaptureItem detaching (pausing capture)";
    if (m_capture)
        m_capture->stopCapture();
}

void ScrcpyCaptureItem::reattach()
{
    qCDebug(lcScrcpyCapture) << "ScrcpyCaptureItem reattaching (resuming capture)";
    auto *pmm = qobject_cast<PhoneMirrorManager *>(m_manager);
    if (pmm && pmm->isRunning() && m_capture) {
        const int hwnd = pmm->scrcpyWindowHandle();
        if (hwnd) {
            m_capture->setWindowHandle(hwnd);
            m_capture->startCapture();
            emit streamStarted();
        }
    }
}

void ScrcpyCaptureItem::componentComplete()
{
    QQuickItem::componentComplete();
    qCDebug(lcScrcpyCapture) << "ScrcpyCaptureItem component complete";
}

// ─── Mouse events ─────────────────────────────────────────────────────

void ScrcpyCaptureItem::mousePressEvent(QMouseEvent *event)
{
    if (m_capture && m_capture->isCapturing()) {
        const QPointF pos = event->position();
        const float relX = static_cast<float>(pos.x() / width());
        const float relY = static_cast<float>(pos.y() / height());
        m_capture->sendTouchEvent(relX, relY, true);
    }
    event->accept();
}

void ScrcpyCaptureItem::mouseReleaseEvent(QMouseEvent *event)
{
    if (m_capture && m_capture->isCapturing()) {
        const QPointF pos = event->position();
        const float relX = static_cast<float>(pos.x() / width());
        const float relY = static_cast<float>(pos.y() / height());
        m_capture->sendTouchEvent(relX, relY, false);
    }
    event->accept();
}

void ScrcpyCaptureItem::mouseMoveEvent(QMouseEvent *event)
{
    if (m_capture && m_capture->isCapturing()) {
        const QPointF pos = event->position();
        const float relX = static_cast<float>(pos.x() / width());
        const float relY = static_cast<float>(pos.y() / height());
        m_capture->sendTouchMove(relX, relY);
    }
    event->accept();
}

// ─── Private slots ────────────────────────────────────────────────────

void ScrcpyCaptureItem::onScrcpyStarted(int hwnd)
{
    qCDebug(lcScrcpyCapture) << "Scrcpy started, hwnd=" << hwnd;

    if (!m_capture) {
        qCDebug(lcScrcpyCapture) << "No capture instance set!";
        return;
    }

    m_capture->setWindowHandle(hwnd);
    QTimer::singleShot(200, m_capture, &ScrcpyCapture::startCapture);
    emit streamStarted();
}

void ScrcpyCaptureItem::onScrcpyStopped()
{
    qCDebug(lcScrcpyCapture) << "Scrcpy stopped";
    if (m_capture)
        m_capture->stopCapture();
    emit streamStopped();
}

void ScrcpyCaptureItem::onScrcpyError(const QString &msg)
{
    qCDebug(lcScrcpyCapture) << "Error:" << msg;
    if (m_capture)
        m_capture->stopCapture();
    emit errorOccurred(msg);
}

void ScrcpyCaptureItem::onFrameReady()
{
    ++m_frameCounter;
    emit frameRefresh();
}

void ScrcpyCaptureItem::onCaptureError(const QString &msg)
{
    emit errorOccurred(msg);
}

#endif // Q_OS_MOBILE
