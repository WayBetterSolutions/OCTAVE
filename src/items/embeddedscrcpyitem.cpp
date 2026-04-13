#ifndef Q_OS_MOBILE

#include "embeddedscrcpyitem.h"
#include "../managers/phonemirrormanager.h"

#include <QQuickWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

Q_LOGGING_CATEGORY(lcEmbeddedScrcpy, "octave.scrcpy.embedded")

// ─── Constructor / Destructor ─────────────────────────────────────────

EmbeddedScrcpyItem::EmbeddedScrcpyItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    m_updateTimer.setInterval(16); // ~60 Hz repositioning
    connect(&m_updateTimer, &QTimer::timeout,
            this, &EmbeddedScrcpyItem::updateEmbeddedWindow);

    // React to geometry changes
    connect(this, &QQuickItem::widthChanged,
            this, &EmbeddedScrcpyItem::updateEmbeddedWindow);
    connect(this, &QQuickItem::heightChanged,
            this, &EmbeddedScrcpyItem::updateEmbeddedWindow);
    connect(this, &QQuickItem::xChanged,
            this, &EmbeddedScrcpyItem::updateEmbeddedWindow);
    connect(this, &QQuickItem::yChanged,
            this, &EmbeddedScrcpyItem::updateEmbeddedWindow);
}

EmbeddedScrcpyItem::~EmbeddedScrcpyItem()
{
    m_updateTimer.stop();
}

// ─── Properties ───────────────────────────────────────────────────────

bool EmbeddedScrcpyItem::isStreaming() const
{
    return m_embedded && m_scrcpyHwnd != 0 && !m_isHidden;
}

// ─── Manager connection ───────────────────────────────────────────────

void EmbeddedScrcpyItem::connectToManager(QObject *manager)
{
    // Disconnect previous
    if (m_manager) {
        disconnect(m_manager, nullptr, this, nullptr);
    }

    m_manager = qobject_cast<PhoneMirrorManager *>(manager);
    if (!m_manager)
        return;

    qCDebug(lcEmbeddedScrcpy) << "Connecting to manager";

    connect(m_manager, &PhoneMirrorManager::scrcpyStarted,
            this, &EmbeddedScrcpyItem::onScrcpyStarted, Qt::QueuedConnection);
    connect(m_manager, &PhoneMirrorManager::scrcpyStopped,
            this, &EmbeddedScrcpyItem::onScrcpyStopped, Qt::QueuedConnection);
    connect(m_manager, &PhoneMirrorManager::scrcpyError,
            this, &EmbeddedScrcpyItem::onScrcpyError, Qt::QueuedConnection);

    // If already running, embed immediately
    if (m_manager->isRunning() && m_manager->scrcpyWindowHandle()) {
        qCDebug(lcEmbeddedScrcpy) << "Manager already has running scrcpy, hwnd="
                                   << m_manager->scrcpyWindowHandle();
        QTimer::singleShot(100, this, [this]() {
            embedOrShow(m_manager->scrcpyWindowHandle());
        });
    }
}

// ─── Detach / Reattach ────────────────────────────────────────────────

void EmbeddedScrcpyItem::detach()
{
    qCDebug(lcEmbeddedScrcpy) << "Detaching (hiding)";
    m_updateTimer.stop();
    m_isHidden = true;

#ifdef Q_OS_WIN
    if (m_scrcpyHwnd && IsWindow(reinterpret_cast<HWND>(static_cast<intptr_t>(m_scrcpyHwnd)))) {
        ShowWindow(reinterpret_cast<HWND>(static_cast<intptr_t>(m_scrcpyHwnd)), SW_HIDE);
    }
#endif
}

void EmbeddedScrcpyItem::reattach()
{
    qCDebug(lcEmbeddedScrcpy) << "Reattaching (showing)";

    if (m_manager && m_manager->isRunning()) {
        const int hwnd = m_manager->scrcpyWindowHandle();
        if (hwnd) {
            QTimer::singleShot(50, this, [this, hwnd]() {
                embedOrShow(hwnd);
            });
        }
    } else {
        qCDebug(lcEmbeddedScrcpy) << "No running scrcpy to reattach";
    }
}

void EmbeddedScrcpyItem::componentComplete()
{
    QQuickItem::componentComplete();
    qCDebug(lcEmbeddedScrcpy) << "Component complete";
}

// ─── Signal handlers ──────────────────────────────────────────────────

void EmbeddedScrcpyItem::onScrcpyStarted(int hwnd)
{
    qCDebug(lcEmbeddedScrcpy) << "Received scrcpy started signal, hwnd=" << hwnd;

#ifdef Q_OS_WIN
    // Hide immediately to prevent flicker
    HWND winHandle = reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd));
    if (IsWindow(winHandle)) {
        ShowWindow(winHandle, SW_HIDE);
        SetWindowPos(winHandle, nullptr, -5000, -5000, 0, 0,
                     SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    }
#endif

    m_scrcpyHwnd = hwnd;
    QTimer::singleShot(200, this, [this, hwnd]() {
        embedOrShow(hwnd);
    });
}

void EmbeddedScrcpyItem::onScrcpyStopped()
{
    qCDebug(lcEmbeddedScrcpy) << "scrcpy stopped";
    cleanupEmbed();
    emit streamStopped();
}

void EmbeddedScrcpyItem::onScrcpyError(const QString &message)
{
    qCDebug(lcEmbeddedScrcpy) << "Error:" << message;
    cleanupEmbed();
    emit errorOccurred(message);
}

// ─── Embedding logic ─────────────────────────────────────────────────

int EmbeddedScrcpyItem::getQtWindowHandle() const
{
    QQuickWindow *qw = window();
    if (qw)
        return static_cast<int>(qw->winId());
    return 0;
}

void EmbeddedScrcpyItem::cleanupEmbed()
{
    m_updateTimer.stop();
    m_scrcpyHwnd = 0;
    m_embedded = false;
    m_parentHwnd = 0;
    m_isHidden = false;
}

void EmbeddedScrcpyItem::embedOrShow(int hwnd)
{
#ifdef Q_OS_WIN
    HWND winHandle = reinterpret_cast<HWND>(static_cast<intptr_t>(hwnd));
    if (!IsWindow(winHandle)) {
        qCDebug(lcEmbeddedScrcpy) << "Window no longer exists";
        emit errorOccurred(QStringLiteral("scrcpy window no longer exists"));
        return;
    }

    m_parentHwnd = getQtWindowHandle();
    if (!m_parentHwnd) {
        qCDebug(lcEmbeddedScrcpy) << "Could not get parent window handle";
        emit errorOccurred(QStringLiteral("Could not get parent window handle"));
        return;
    }

    HWND parentHandle = reinterpret_cast<HWND>(static_cast<intptr_t>(m_parentHwnd));
    HWND currentParent = GetParent(winHandle);

    if (currentParent != parentHandle) {
        qCDebug(lcEmbeddedScrcpy) << "Embedding window" << hwnd << "into" << m_parentHwnd;

        // Hide first
        ShowWindow(winHandle, SW_HIDE);

        // Remove decorations, make child
        LONG style = GetWindowLongW(winHandle, GWL_STYLE);
        style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_BORDER);
        style |= WS_CHILD | WS_VISIBLE;
        SetWindowLongW(winHandle, GWL_STYLE, style);

        // Remove from taskbar
        LONG exStyle = GetWindowLongW(winHandle, GWL_EXSTYLE);
        exStyle = (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
        SetWindowLongW(winHandle, GWL_EXSTYLE, exStyle);

        // Set parent
        SetParent(winHandle, parentHandle);
    } else {
        qCDebug(lcEmbeddedScrcpy) << "Window already parented correctly, just showing";
    }

    m_scrcpyHwnd = hwnd;
    m_embedded = true;
    m_isHidden = false;

    // Position within our QQuickItem bounds
    const QPointF scenePos = mapToScene(QPointF(0, 0));
    const int x = static_cast<int>(scenePos.x());
    const int y = static_cast<int>(scenePos.y());
    const int w = static_cast<int>(width());
    const int h = static_cast<int>(height());

    qCDebug(lcEmbeddedScrcpy) << "Positioning window at (" << x << y << ") size"
                               << w << "x" << h;

    if (w > 0 && h > 0)
        MoveWindow(winHandle, x, y, w, h, TRUE);

    ShowWindow(winHandle, SW_SHOW);

    // Start continuous repositioning
    m_updateTimer.start();

    emit streamStarted();
    qCDebug(lcEmbeddedScrcpy) << "Window embedded/shown successfully";

#else
    // On non-Windows platforms, window embedding via reparenting is not
    // directly supported in this implementation.  The capture-based
    // approach (ScrcpyCaptureItem) is preferred on Linux/macOS.
    Q_UNUSED(hwnd)
    qCDebug(lcEmbeddedScrcpy) << "Window embedding only supported on Windows";
    emit errorOccurred(QStringLiteral("Window embedding only supported on Windows — use capture mode"));
#endif
}

void EmbeddedScrcpyItem::updateEmbeddedWindow()
{
    if (!m_scrcpyHwnd || !m_embedded || m_isHidden)
        return;

#ifdef Q_OS_WIN
    HWND winHandle = reinterpret_cast<HWND>(static_cast<intptr_t>(m_scrcpyHwnd));
    if (!IsWindow(winHandle)) {
        cleanupEmbed();
        emit streamStopped();
        return;
    }

    const QPointF scenePos = mapToScene(QPointF(0, 0));
    const int x = static_cast<int>(scenePos.x());
    const int y = static_cast<int>(scenePos.y());
    const int w = static_cast<int>(width());
    const int h = static_cast<int>(height());

    if (w <= 0 || h <= 0)
        return;

    MoveWindow(winHandle, x, y, w, h, TRUE);
#endif
}

#endif // Q_OS_MOBILE
