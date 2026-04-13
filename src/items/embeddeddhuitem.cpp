/*
 * Embedded DHU Item for OCTAVE (C++ port)
 *
 * Connects to AndroidAutoManager, listens for dhuWindowReady /
 * dhuEmbeddedChanged signals, and exposes a frameCounter property
 * that QML binds to in order to refresh an Image element sourced from
 * "image://dhuframe/<counter>".
 *
 * Desktop-only — excluded on mobile builds.
 */

#ifndef Q_OS_MOBILE

#include "embeddeddhuitem.h"
#include "../managers/androidautomanager.h"

#include <QLoggingCategory>

Q_LOGGING_CATEGORY(lcEmbeddedDhu, "octave.embeddeddhu")

// =====================================================================
//  Construction / destruction
// =====================================================================

EmbeddedDhuItem::EmbeddedDhuItem(QQuickItem *parent)
    : QQuickItem(parent)
{
}

EmbeddedDhuItem::~EmbeddedDhuItem() = default;

// =====================================================================
//  Property accessors
// =====================================================================

bool EmbeddedDhuItem::isStreaming() const
{
    return m_streaming;
}

int EmbeddedDhuItem::frameCounter() const
{
    return m_frameCounter;
}

// =====================================================================
//  Slots
// =====================================================================

void EmbeddedDhuItem::connectToManager(QObject *managerObj)
{
    // Disconnect from previous manager
    if (m_manager) {
        disconnect(m_manager, &AndroidAutoManager::dhuWindowReady,
                   this, &EmbeddedDhuItem::onDhuStarted);
        disconnect(m_manager, &AndroidAutoManager::dhuEmbeddedChanged,
                   this, &EmbeddedDhuItem::onDhuStateChanged);

        // Also disconnect from capture's frameReady
        auto *capture = qobject_cast<DhuCapture *>(
            m_manager->dhuCapture());
        if (capture) {
            disconnect(capture, &DhuCapture::frameReady,
                       this, &EmbeddedDhuItem::onFrameReady);
        }
    }

    m_manager = qobject_cast<AndroidAutoManager *>(managerObj);
    if (!m_manager) {
        qCWarning(lcEmbeddedDhu) << "connectToManager: invalid manager";
        return;
    }

    qCDebug(lcEmbeddedDhu) << "Connecting to AndroidAutoManager";

    connect(m_manager, &AndroidAutoManager::dhuWindowReady,
            this, &EmbeddedDhuItem::onDhuStarted,
            Qt::QueuedConnection);
    connect(m_manager, &AndroidAutoManager::dhuEmbeddedChanged,
            this, &EmbeddedDhuItem::onDhuStateChanged,
            Qt::QueuedConnection);

    // Connect to the capture's frameReady signal for counter updates
    auto *capture = qobject_cast<DhuCapture *>(m_manager->dhuCapture());
    if (capture) {
        connect(capture, &DhuCapture::frameReady,
                this, &EmbeddedDhuItem::onFrameReady,
                Qt::QueuedConnection);
    }

    // If manager already has a running DHU, start streaming
    if (m_manager->isDhuEmbedded() && m_manager->dhuWindowHandle()) {
        qCDebug(lcEmbeddedDhu)
            << "Manager already has DHU running, hwnd="
            << m_manager->dhuWindowHandle();
        onDhuStarted(m_manager->dhuWindowHandle());
    }
}

void EmbeddedDhuItem::detach()
{
    qCDebug(lcEmbeddedDhu) << "Detaching (pausing)";
    m_streaming = false;
    emit streamStopped();
}

void EmbeddedDhuItem::reattach()
{
    qCDebug(lcEmbeddedDhu) << "Reattaching (resuming)";

    if (m_manager && m_manager->isDhuEmbedded()) {
        m_streaming = true;
        emit streamStarted();
    } else {
        qCDebug(lcEmbeddedDhu) << "No running DHU to reattach";
    }
}

// =====================================================================
//  QQuickItem override
// =====================================================================

void EmbeddedDhuItem::componentComplete()
{
    QQuickItem::componentComplete();
    qCDebug(lcEmbeddedDhu) << "Component complete";
}

// =====================================================================
//  Private slots
// =====================================================================

void EmbeddedDhuItem::onDhuStarted(int windowHandle)
{
    qCDebug(lcEmbeddedDhu) << "DHU started, hwnd=" << windowHandle;

    m_streaming = true;
    emit streamStarted();
}

void EmbeddedDhuItem::onDhuStateChanged(bool embedded)
{
    if (!embedded) {
        qCDebug(lcEmbeddedDhu) << "DHU stopped";
        m_streaming = false;
        m_frameCounter = 0;
        emit streamStopped();
    }
}

void EmbeddedDhuItem::onFrameReady()
{
    if (!m_streaming)
        return;

    ++m_frameCounter;
    emit frameRefresh();
}

#endif // Q_OS_MOBILE
