#include "clock.h"
#include "settingsmanager.h"

#include <QDateTime>
#include <QTime>

Clock::Clock(SettingsManager *settingsManager, QObject *parent)
    : QObject(parent)
    , m_settingsManager(settingsManager)
{
    connect(&m_timer, &QTimer::timeout, this, &Clock::update_time);
    m_timer.start(1000); // Update every second
}

void Clock::update_time()
{
    if (!m_settingsManager->showClock()) {
        emit timeChanged(QString());
        return;
    }

    QTime currentTime = QTime::currentTime();
    const bool showSeconds = m_settingsManager->clockShowSeconds();

    if (m_settingsManager->clockFormat24Hour()) {
        const QString fmt = showSeconds ? QStringLiteral("HH:mm:ss") : QStringLiteral("HH:mm");
        emit timeChanged(currentTime.toString(fmt));
    } else {
        int hour12 = currentTime.hour() % 12;
        if (hour12 == 0)
            hour12 = 12;
        QString hourMin = QStringLiteral("%1:%2")
                              .arg(hour12, 2, 10, QLatin1Char('0'))
                              .arg(currentTime.minute(), 2, 10, QLatin1Char('0'));
        if (showSeconds) {
            hourMin += QStringLiteral(":%1").arg(currentTime.second(), 2, 10, QLatin1Char('0'));
        }
        const QString amPm = (currentTime.hour() >= 12) ? QStringLiteral("PM") : QStringLiteral("AM");
        emit timeChanged(hourMin + QStringLiteral(" ") + amPm);
    }
}
