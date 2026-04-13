#ifndef EMBEDDEDSCRCPYITEM_H
#define EMBEDDEDSCRCPYITEM_H

#ifndef Q_OS_MOBILE

#include <QQuickItem>
#include <QTimer>
#include <QPointF>

#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(lcEmbeddedScrcpy)

class PhoneMirrorManager;

class EmbeddedScrcpyItem : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isStreaming READ isStreaming NOTIFY streamStarted)

public:
    explicit EmbeddedScrcpyItem(QQuickItem *parent = nullptr);
    ~EmbeddedScrcpyItem() override;

    bool isStreaming() const;

signals:
    void streamStarted();
    void streamStopped();
    void errorOccurred(const QString &message);

public slots:
    Q_INVOKABLE void connectToManager(QObject *manager);
    void detach();
    void reattach();

protected:
    void componentComplete() override;

private slots:
    void onScrcpyStarted(int hwnd);
    void onScrcpyStopped();
    void onScrcpyError(const QString &message);
    void updateEmbeddedWindow();

private:
    // Platform-specific embedding
    void embedOrShow(int hwnd);
    int  getQtWindowHandle() const;
    void cleanupEmbed();

    // Members
    PhoneMirrorManager *m_manager = nullptr;
    int m_scrcpyHwnd = 0;
    bool m_embedded = false;
    int m_parentHwnd = 0;
    bool m_isHidden = false;

    QTimer m_updateTimer;
};

#endif // Q_OS_MOBILE
#endif // EMBEDDEDSCRCPYITEM_H
