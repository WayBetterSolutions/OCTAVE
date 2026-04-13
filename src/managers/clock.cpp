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

    if (m_settingsManager->clockFormat24Hour()) {
        // "%H:%M" equivalent
        emit timeChanged(currentTime.toString(QStringLiteral("HH:mm")));
    } else {
        // "%I:%M %p" equivalent, with uppercase AM/PM
        QString hourMin = currentTime.toString(QStringLiteral("hh:mm"));
        QString amPm = currentTime.toString(QStringLiteral("AP"));

        // Qt uses 'hh' for 24-hour by default; use the 12-hour approach:
        int hour12 = currentTime.hour() % 12;
        if (hour12 == 0)
            hour12 = 12;
        hourMin = QStringLiteral("%1:%2")
                      .arg(hour12, 2, 10, QLatin1Char('0'))
                      .arg(currentTime.minute(), 2, 10, QLatin1Char('0'));
        amPm = (currentTime.hour() >= 12) ? QStringLiteral("PM") : QStringLiteral("AM");

        emit timeChanged(hourMin + QStringLiteral(" ") + amPm);
    }
}
