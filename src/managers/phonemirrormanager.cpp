#ifndef Q_OS_MOBILE

#include "phonemirrormanager.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QRegularExpression>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

Q_LOGGING_CATEGORY(lcPhoneMirror, "octave.phonemirror")

// ─── Helpers ──────────────────────────────────────────────────────────

static QStringList commonScrcpyPaths()
{
#ifdef Q_OS_WIN
    const QString home = QDir::homePath();
    return {
        QStringLiteral("C:/scrcpy/scrcpy.exe"),
        QStringLiteral("C:/Program Files/scrcpy/scrcpy.exe"),
        QStringLiteral("C:/Program Files (x86)/scrcpy/scrcpy.exe"),
        home + QStringLiteral("/scrcpy/scrcpy.exe"),
        home + QStringLiteral("/Downloads/scrcpy-win64-v3.1/scrcpy.exe"),
        home + QStringLiteral("/Downloads/scrcpy/scrcpy.exe"),
    };
#else
    const QString home = QDir::homePath();
    return {
        QStringLiteral("/usr/bin/scrcpy"),
        QStringLiteral("/usr/local/bin/scrcpy"),
        QStringLiteral("/snap/bin/scrcpy"),
        home + QStringLiteral("/.local/bin/scrcpy"),
    };
#endif
}

static QStringList commonAdbPaths()
{
#ifdef Q_OS_WIN
    const QString home = QDir::homePath();
    return {
        QStringLiteral("C:/scrcpy/adb.exe"),
        QStringLiteral("C:/Program Files/Android/platform-tools/adb.exe"),
        QStringLiteral("C:/Program Files (x86)/Android/platform-tools/adb.exe"),
        home + QStringLiteral("/scrcpy/adb.exe"),
        home + QStringLiteral("/AppData/Local/Android/Sdk/platform-tools/adb.exe"),
    };
#else
    const QString home = QDir::homePath();
    return {
        QStringLiteral("/usr/bin/adb"),
        QStringLiteral("/usr/local/bin/adb"),
        home + QStringLiteral("/Android/Sdk/platform-tools/adb"),
    };
#endif
}

// ─── Constructor / Destructor ─────────────────────────────────────────

PhoneMirrorManager::PhoneMirrorManager(QObject *parent)
    : QObject(parent)
{
    m_scrcpyPath = findScrcpy();
    m_adbPath    = findAdb();

    // Window poll timer — used after starting scrcpy to find its window
    m_windowPollTimer.setInterval(100);
    connect(&m_windowPollTimer, &QTimer::timeout, this, &PhoneMirrorManager::findScrcpyWindow);
}

PhoneMirrorManager::~PhoneMirrorManager()
{
    cleanup();
}

// ─── Properties ───────────────────────────────────────────────────────

bool PhoneMirrorManager::isScrcpyInstalled() const
{
    return !getEffectiveScrcpyPath().isEmpty();
}

QString PhoneMirrorManager::scrcpyPath() const
{
    return getEffectiveScrcpyPath();
}

QString PhoneMirrorManager::adbPath() const
{
    return m_adbPath;
}

bool PhoneMirrorManager::isRunning() const
{
    return m_process != nullptr
        && m_process->state() != QProcess::NotRunning;
}

int PhoneMirrorManager::scrcpyWindowHandle() const
{
    return m_scrcpyHwnd;
}

// ─── Slots ────────────────────────────────────────────────────────────

void PhoneMirrorManager::setScrcpyPath(const QString &path)
{
    const QString oldEffective = getEffectiveScrcpyPath();
    m_customScrcpyPath = path.trimmed();

    if (m_customScrcpyPath.isEmpty())
        m_scrcpyPath = findScrcpy();

    const QString newEffective = getEffectiveScrcpyPath();
    if (oldEffective != newEffective) {
        emit scrcpyPathChanged();
        qCDebug(lcPhoneMirror) << "Effective scrcpy path:" << newEffective;
    }
}

void PhoneMirrorManager::setAudioEnabled(bool enabled)
{
    if (m_audioEnabled == enabled)
        return;

    qCDebug(lcPhoneMirror) << "Audio forwarding:" << enabled;
    m_audioEnabled = enabled;

    if (isRunning()) {
        qCDebug(lcPhoneMirror) << "Restarting scrcpy to apply audio setting change";
        stopScrcpy();
        QTimer::singleShot(300, this, &PhoneMirrorManager::startScrcpy);
    }
}

void PhoneMirrorManager::setVolume(float /*volume*/)
{
    // Volume control placeholder — not implemented
}

bool PhoneMirrorManager::hasConnectedDevice()
{
    const QString output = runAdb({QStringLiteral("devices")});
    if (output.isEmpty())
        return false;

    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    // First line is "List of devices attached"
    for (int i = 1; i < lines.size(); ++i) {
        const QString &line = lines[i];
        if (line.trimmed().isEmpty())
            continue;
        if (line.contains(QLatin1String("device"))
            && !line.contains(QLatin1String("offline"))) {
            return true;
        }
    }
    return false;
}

QString PhoneMirrorManager::getDeviceSerial()
{
    const QString output = runAdb({QStringLiteral("devices")});
    if (output.isEmpty())
        return {};

    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (int i = 1; i < lines.size(); ++i) {
        const QString &line = lines[i];
        if (line.trimmed().isEmpty())
            continue;
        if (line.contains(QLatin1String("device"))
            && !line.contains(QLatin1String("offline"))) {
            const QStringList parts = line.split(QRegularExpression(QStringLiteral("\\s+")),
                                                  Qt::SkipEmptyParts);
            if (!parts.isEmpty())
                return parts.first();
        }
    }
    return {};
}

QString PhoneMirrorManager::getDeviceName()
{
    const QString output = runAdb({
        QStringLiteral("shell"), QStringLiteral("getprop"),
        QStringLiteral("ro.product.model")
    });
    return output.trimmed();
}

QString PhoneMirrorManager::getDeviceResolution()
{
    const QString output = runAdb({
        QStringLiteral("shell"), QStringLiteral("wm"), QStringLiteral("size")
    });
    if (output.isEmpty())
        return {};

    // Output format: "Physical size: 1080x2400"
    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        if (line.contains(QLatin1String("Physical size:"))) {
            const int colonIdx = line.indexOf(QLatin1Char(':'));
            if (colonIdx >= 0)
                return line.mid(colonIdx + 1).trimmed();
        }
    }
    return {};
}

QString PhoneMirrorManager::getInstallInstructions()
{
#ifdef Q_OS_WIN
    return QStringLiteral(
        "To install scrcpy:\n\n"
        "1. Download from: https://github.com/Genymobile/scrcpy/releases\n"
        "2. Extract to C:\\scrcpy or your preferred location\n"
        "3. Set the path in Settings > Phone Mirror\n"
        "4. Restart OCTAVE\n\n"
        "Note: scrcpy includes ADB. Enable USB debugging on your phone."
    );
#else
    return QStringLiteral(
        "To install scrcpy:\n\n"
        "Ubuntu/Debian: sudo apt install scrcpy\n"
        "Arch Linux: sudo pacman -S scrcpy\n"
        "macOS: brew install scrcpy\n\n"
        "Make sure USB debugging is enabled on your phone."
    );
#endif
}

void PhoneMirrorManager::startScrcpy()
{
    // Already running?
    if (isRunning()) {
        qCDebug(lcPhoneMirror) << "scrcpy already running, emitting existing handle";
        if (m_scrcpyHwnd)
            emit scrcpyStarted(m_scrcpyHwnd);
        return;
    }

    // Already starting?
    if (m_isStarting) {
        qCDebug(lcPhoneMirror) << "scrcpy already starting, ignoring duplicate request";
        return;
    }

    const QString effectivePath = getEffectiveScrcpyPath();
    if (effectivePath.isEmpty()) {
        emit scrcpyError(QStringLiteral("scrcpy not installed"));
        return;
    }

    if (!hasConnectedDevice()) {
        emit scrcpyError(QStringLiteral("No Android device connected"));
        return;
    }

    const QString serial = getDeviceSerial();
    m_isStarting = true;

    // Build command arguments
    QStringList args;
    args << QStringLiteral("--video-codec=h264")
         << QStringLiteral("--video-bit-rate=8M")
         << QStringLiteral("--max-fps=60")
         << QStringLiteral("--window-borderless")
         << QStringLiteral("--stay-awake");

    if (!m_audioEnabled)
        args << QStringLiteral("--no-audio");

    if (!serial.isEmpty())
        args << QStringLiteral("-s") << serial;

    qCDebug(lcPhoneMirror) << "Starting scrcpy:" << effectivePath << args;

    // Create the process
    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_process = new QProcess(this);
    m_process->setWorkingDirectory(QFileInfo(effectivePath).absolutePath());

    // Handle process finish
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus status) {
        Q_UNUSED(exitCode)
        Q_UNUSED(status)
        m_windowPollTimer.stop();
        m_scrcpyHwnd = 0;
        m_isStarting = false;
        emit scrcpyStopped();
        emit isRunningChanged();
    });

    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        Q_UNUSED(err)
        m_isStarting = false;
        m_windowPollTimer.stop();
        const QString msg = m_process ? m_process->errorString()
                                      : QStringLiteral("Unknown process error");
        qCDebug(lcPhoneMirror) << "Process error:" << msg;
        emit scrcpyError(msg);
        emit isRunningChanged();
    });

    m_process->start(effectivePath, args);
    emit isRunningChanged();

    // Start polling for the window handle
    m_windowPollCount = 0;
    m_windowPollTimer.start();
}

void PhoneMirrorManager::stopScrcpy()
{
    qCDebug(lcPhoneMirror) << "Stopping scrcpy";

    m_windowPollTimer.stop();
    m_scrcpyHwnd = 0;
    m_isStarting = false;

    if (m_process) {
        m_process->terminate();
        if (!m_process->waitForFinished(2000)) {
            qCWarning(lcPhoneMirror) << "scrcpy did not terminate within 2s, killing";
            m_process->kill();
            m_process->waitForFinished(1000);
        }
        m_process->deleteLater();
        m_process = nullptr;
    }

    emit scrcpyStopped();
    emit isRunningChanged();
}

void PhoneMirrorManager::cleanup()
{
    stopScrcpy();
}

// ─── Private helpers ──────────────────────────────────────────────────

QString PhoneMirrorManager::getBundledToolsDir() const
{
    // In development the binary sits in build/, tools/scrcpy is at project root
    const QString appDir = QCoreApplication::applicationDirPath();
    QDir dir(appDir);

    // Try sibling (development layout: build/../tools/scrcpy)
    if (dir.cdUp() && dir.cd(QStringLiteral("tools")) && dir.cd(QStringLiteral("scrcpy")))
        return dir.absolutePath();

    // Try from app dir itself (PyInstaller / deployed layout)
    dir = QDir(appDir);
    if (dir.cd(QStringLiteral("tools")) && dir.cd(QStringLiteral("scrcpy")))
        return dir.absolutePath();

    return {};
}

QString PhoneMirrorManager::getEffectiveScrcpyPath() const
{
    if (!m_customScrcpyPath.isEmpty() && checkScrcpy(m_customScrcpyPath))
        return m_customScrcpyPath;
    return m_scrcpyPath;
}

bool PhoneMirrorManager::checkScrcpy(const QString &path) const
{
    if (path.isEmpty() || !QFileInfo::exists(path))
        return false;

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(path, {QStringLiteral("--version")});
    if (!proc.waitForFinished(5000))
        return false;
    return proc.exitCode() == 0;
}

QString PhoneMirrorManager::findScrcpy() const
{
    // Check bundled location first
    const QString bundledDir = getBundledToolsDir();
    if (!bundledDir.isEmpty()) {
#ifdef Q_OS_WIN
        const QString bundled = bundledDir + QStringLiteral("/scrcpy.exe");
#else
        const QString bundled = bundledDir + QStringLiteral("/scrcpy");
#endif
        if (QFileInfo::exists(bundled) && checkScrcpy(bundled)) {
            qCDebug(lcPhoneMirror) << "Using bundled scrcpy:" << bundled;
            return bundled;
        }
    }

    // Check PATH via QStandardPaths
    const QString inPath = QStandardPaths::findExecutable(QStringLiteral("scrcpy"));
    if (!inPath.isEmpty())
        return inPath;

    // Check common install locations
    for (const QString &path : commonScrcpyPaths()) {
        if (checkScrcpy(path))
            return path;
    }

    return {};
}

QString PhoneMirrorManager::findAdb() const
{
    // Check bundled location first
    const QString bundledDir = getBundledToolsDir();
    if (!bundledDir.isEmpty()) {
#ifdef Q_OS_WIN
        const QString bundled = bundledDir + QStringLiteral("/adb.exe");
#else
        const QString bundled = bundledDir + QStringLiteral("/adb");
#endif
        if (QFileInfo::exists(bundled)) {
            qCDebug(lcPhoneMirror) << "Using bundled adb:" << bundled;
            return bundled;
        }
    }

    // Check PATH
    const QString inPath = QStandardPaths::findExecutable(QStringLiteral("adb"));
    if (!inPath.isEmpty())
        return inPath;

    // Check common install locations
    for (const QString &path : commonAdbPaths()) {
        if (QFileInfo::exists(path))
            return path;
    }

    return {};
}

QString PhoneMirrorManager::runAdb(const QStringList &args, int timeoutMs) const
{
    if (m_adbPath.isEmpty())
        return {};

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(m_adbPath, args);
    if (!proc.waitForFinished(timeoutMs))
        return {};
    if (proc.exitCode() != 0)
        return {};
    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}

// ─── Window finding ───────────────────────────────────────────────────

void PhoneMirrorManager::findScrcpyWindow()
{
    ++m_windowPollCount;

    // Give up after 10 seconds (100 polls * 100 ms)
    if (m_windowPollCount > 100) {
        m_windowPollTimer.stop();
        m_isStarting = false;
        qCDebug(lcPhoneMirror) << "Could not find scrcpy window after 10s";
        emit scrcpyError(QStringLiteral("Could not find scrcpy window"));
        return;
    }

    // Process died before we found the window
    if (!m_process || m_process->state() == QProcess::NotRunning) {
        m_windowPollTimer.stop();
        m_isStarting = false;
        const QString stderr = m_process ? QString::fromUtf8(m_process->readAllStandardError()) : QString();
        qCDebug(lcPhoneMirror) << "scrcpy exited before window found:" << stderr.left(200);
        emit scrcpyError(QStringLiteral("scrcpy failed: ") + stderr.left(100));
        return;
    }

#ifdef Q_OS_WIN
    int hwnd = findWindowByPid(m_process->processId());
    if (hwnd) {
        m_windowPollTimer.stop();
        m_scrcpyHwnd = hwnd;
        m_isStarting = false;
        qCDebug(lcPhoneMirror) << "Found scrcpy window:" << hwnd;
        emit scrcpyStarted(hwnd);
    }
#else
    // On Linux / macOS, use QScreen::grabWindow approach —
    // just emit process PID as a "handle" for the capture system
    // The capture side will use QScreen::grabWindow or X11 to capture
    if (m_windowPollCount >= 15) {
        // After 1.5 seconds, assume window is up
        m_windowPollTimer.stop();
        m_scrcpyHwnd = static_cast<int>(m_process->processId());
        m_isStarting = false;
        qCDebug(lcPhoneMirror) << "Using PID as window handle:" << m_scrcpyHwnd;
        emit scrcpyStarted(m_scrcpyHwnd);
    }
#endif
}

#ifdef Q_OS_WIN
int PhoneMirrorManager::findWindowByPid(qint64 targetPid) const
{
    struct EnumData {
        DWORD pid;
        HWND  result;
    } data;
    data.pid = static_cast<DWORD>(targetPid);
    data.result = nullptr;

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        auto *d = reinterpret_cast<EnumData *>(lParam);
        DWORD windowPid = 0;
        GetWindowThreadProcessId(hwnd, &windowPid);
        if (windowPid == d->pid && IsWindowVisible(hwnd)) {
            d->result = hwnd;
            return FALSE; // stop enumeration
        }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&data));

    return static_cast<int>(reinterpret_cast<intptr_t>(data.result));
}
#endif

#endif // Q_OS_MOBILE
