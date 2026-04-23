/*
 * Embedded DHU Item for OCTAVE (C++ port)
 *
 * A QQuickItem that displays captured DHU frames from the "dhuframe"
 * image provider.  Connects to AndroidAutoManager to receive window-ready
 * signals and renders frames by incrementing a counter that triggers
 * QML Image source refreshes.
 *
 * Register in QML as:
 *   qmlRegisterType<EmbeddedDhuItem>("OCTAVE.AndroidAuto", 1, 0,
 *                                     "EmbeddedDhuItem");
 *
 * Desktop-only — excluded on mobile builds.
 */

#ifndef EMBEDDEDDHUITEM_H
#define EMBEDDEDDHUITEM_H

#ifndef Q_OS_MOBILE

#include <QObject>
#include <QQuickItem>
#include <QTimer>

#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(lcEmbeddedDhu)

// Forward declaration — avoids pulling in the full manager header
class AndroidAutoManager;

class EmbeddedDhuItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isStreaming  READ isStreaming  NOTIFY streamStarted)
    Q_PROPERTY(int  frameCounter READ frameCounter NOTIFY frameRefresh)

public:
    explicit EmbeddedDhuItem(QQuickItem *parent = nullptr);
    ~EmbeddedDhuItem() override;

    bool isStreaming() const;
    int  frameCounter() const;

signals:
    void streamStarted();
    void streamStopped();
    void errorOccurred(const QString &message);
    void frameRefresh();

public slots:
    void connectToManager(QObject *manager);
    void detach();
    void reattach();

protected:
    void componentComplete() override;

private slots:
    void onDhuStarted(int windowHandle);
    void onDhuStateChanged(bool embedded);
    void onFrameReady();

private:
    AndroidAutoManager *m_manager  = nullptr;
    bool                m_streaming = false;
    int                 m_frameCounter = 0;
};

#else // Q_OS_MOBILE — mobile stub

#include <QQuickItem>
#include <QtQml/qqmlregistration.h>

class EmbeddedDhuItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit EmbeddedDhuItem(QQuickItem *parent = nullptr) : QQuickItem(parent) {}
};

#endif // Q_OS_MOBILE
#endif // EMBEDDEDDHUITEM_H
