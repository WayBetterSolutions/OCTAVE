#include "audioanalyzer.h"

#include <QUrl>
#include <QFileInfo>
#include <QProcess>
#include <QtConcurrent>
#include <QLoggingCategory>

#include <algorithm>
#include <numeric>
#include <cstring>

Q_LOGGING_CATEGORY(lcAudioAnalyzer, "octave.audioanalyzer")

// ════════════════════════════════════════════════════════════════
// Construction / destruction
// ════════════════════════════════════════════════════════════════

AudioAnalyzer::AudioAnalyzer(QObject *parent)
    : QObject(parent)
{
    m_qualityBars[QStringLiteral("Low")]     = 16;
    m_qualityBars[QStringLiteral("Medium")]  = 32;
    m_qualityBars[QStringLiteral("High")]    = 48;
    m_qualityBars[QStringLiteral("Extreme")] = 64;
    m_qualityBars[QStringLiteral("Insane")]  = 96;

    // Initialise current levels to zeros
    m_currentLevels.reserve(m_numBars);
    for (int i = 0; i < m_numBars; ++i)
        m_currentLevels.append(0);

    connect(&m_watcher, &QFutureWatcher<AnalysisResult>::finished,
            this, &AudioAnalyzer::onAnalysisDone);
}

AudioAnalyzer::~AudioAnalyzer()
{
    m_watcher.cancel();
    m_watcher.waitForFinished();
}

// ════════════════════════════════════════════════════════════════
// Minimal in-place radix-2 Cooley-Tukey FFT
// ════════════════════════════════════════════════════════════════

void AudioAnalyzer::fft_radix2(std::vector<std::complex<float>> &x)
{
    const int N = static_cast<int>(x.size());
    if (N <= 1)
        return;

    // Bit-reversal permutation
    for (int i = 1, j = 0; i < N; ++i) {
        int bit = N >> 1;
        while (j & bit) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        if (i < j)
            std::swap(x[i], x[j]);
    }

    // Butterfly stages
    for (int len = 2; len <= N; len <<= 1) {
        const float angle = -2.0f * static_cast<float>(M_PI) / static_cast<float>(len);
        const std::complex<float> wlen(std::cos(angle), std::sin(angle));
        for (int i = 0; i < N; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (int j = 0; j < len / 2; ++j) {
                std::complex<float> u = x[i + j];
                std::complex<float> v = x[i + j + len / 2] * w;
                x[i + j]             = u + v;
                x[i + j + len / 2]   = u - v;
                w *= wlen;
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// Hann window
// ════════════════════════════════════════════════════════════════

std::vector<float> AudioAnalyzer::hannWindow(int N)
{
    std::vector<float> w(N);
    for (int i = 0; i < N; ++i)
        w[i] = 0.5f * (1.0f - std::cos(2.0f * static_cast<float>(M_PI) * static_cast<float>(i) / static_cast<float>(N)));
    return w;
}

// ════════════════════════════════════════════════════════════════
// Next power of two (for zero-padding to radix-2 length)
// ════════════════════════════════════════════════════════════════

static int nextPow2(int n)
{
    int p = 1;
    while (p < n)
        p <<= 1;
    return p;
}

// ════════════════════════════════════════════════════════════════
// Worker: decode audio file and compute per-chunk FFT levels
// Runs on a QtConcurrent thread — must NOT touch Qt GUI objects.
//
// Uses ffmpeg CLI to decode audio to raw PCM float data, matching
// the Python version's use of PyAV.  QAudioDecoder was previously
// used here but fails silently on worker threads due to event-loop
// and thread-affinity issues with the GStreamer/FFmpeg backends.
// ════════════════════════════════════════════════════════════════

AudioAnalyzer::AnalysisResult AudioAnalyzer::analyzeAudio(
    const QString &filePath, int numBars, double chunkDuration)
{
    AnalysisResult result;

    // ── Decode via ffmpeg CLI → raw 32-bit float, 8 kHz, mono ────
    QProcess proc;
    proc.setProgram(QStringLiteral("ffmpeg"));
    proc.setArguments({
        QStringLiteral("-i"), filePath,
        QStringLiteral("-f"), QStringLiteral("f32le"),   // raw 32-bit float LE
        QStringLiteral("-acodec"), QStringLiteral("pcm_f32le"),
        QStringLiteral("-ar"), QStringLiteral("8000"),   // 8 kHz
        QStringLiteral("-ac"), QStringLiteral("1"),      // mono
        QStringLiteral("-v"), QStringLiteral("quiet"),
        QStringLiteral("-")                              // output to stdout
    });

    proc.start(QIODevice::ReadOnly);

    if (!proc.waitForFinished(30000)) {
        qCWarning(lcAudioAnalyzer) << "ffmpeg timed out or failed to start for" << filePath;
        proc.kill();
        return result;
    }

    if (proc.exitCode() != 0) {
        qCWarning(lcAudioAnalyzer) << "ffmpeg exited with code" << proc.exitCode()
                                   << "for" << filePath;
        return result;
    }

    QByteArray pcmBuffer = proc.readAllStandardOutput();

    if (pcmBuffer.isEmpty()) {
        qCWarning(lcAudioAnalyzer) << "ffmpeg produced no audio data for" << filePath;
        return result;
    }

    // ── PCM data is now a contiguous float array at 8 kHz mono ─
    const auto *samples     = reinterpret_cast<const float *>(pcmBuffer.constData());
    const int   sampleCount = pcmBuffer.size() / static_cast<int>(sizeof(float));
    const int   sampleRate  = 8000;

    if (sampleCount == 0)
        return result;

    // Normalise
    float maxVal = 0.0f;
    for (int i = 0; i < sampleCount; ++i)
        maxVal = std::max(maxVal, std::abs(samples[i]));

    std::vector<float> normalised(sampleCount);
    if (maxVal > 0.0f) {
        for (int i = 0; i < sampleCount; ++i)
            normalised[i] = samples[i] / maxVal;
    } else {
        std::fill(normalised.begin(), normalised.end(), 0.0f);
    }

    // ── Chunk into ~chunkDuration windows and FFT each ─────────
    const int chunkSize = static_cast<int>(sampleRate * chunkDuration);
    const int numChunks = sampleCount / chunkSize;

    if (numChunks == 0)
        return result;

    const int fftSize = nextPow2(chunkSize);
    const auto window = hannWindow(chunkSize);

    // First pass: raw magnitudes per chunk per bar
    std::vector<std::vector<float>> rawFftData(numChunks);

    for (int c = 0; c < numChunks; ++c) {
        const int offset = c * chunkSize;

        // Zero-padded, windowed complex buffer
        std::vector<std::complex<float>> buf(fftSize, {0.0f, 0.0f});
        for (int i = 0; i < chunkSize; ++i)
            buf[i] = {normalised[offset + i] * window[i], 0.0f};

        fft_radix2(buf);

        // Magnitude of positive frequencies, skip DC
        // For a real signal FFT of size N, positive frequencies are bins 1..N/2-1
        // This matches Python's: fft = fft[1:len(fft)//2]  after rfft
        const int halfFFT = fftSize / 2;
        std::vector<float> mag(halfFFT - 1);
        for (int i = 0; i < static_cast<int>(mag.size()); ++i)
            mag[i] = std::abs(buf[i + 1]);   // +1 to skip DC

        if (mag.empty()) {
            rawFftData[c].assign(numBars, 0.0f);
            continue;
        }

        // Logarithmic bin edges — match Python's np.logspace(0, log10(len(fft)), numBars+1)
        // np.logspace(0, log10(N), M) produces M values from 10^0=1 to 10^log10(N)=N
        const int fftLen = static_cast<int>(mag.size());
        std::vector<int> logIndices(numBars + 1);
        for (int i = 0; i <= numBars; ++i) {
            double t = static_cast<double>(i) / numBars;
            double logVal = std::pow(static_cast<double>(fftLen), t);
            int idx = static_cast<int>(logVal);
            logIndices[i] = std::clamp(idx, 0, fftLen);
        }

        // Bin into bars
        std::vector<float> levels(numBars, 0.0f);
        for (int b = 0; b < numBars; ++b) {
            int startIdx = logIndices[b];
            int endIdx   = logIndices[b + 1];
            if (endIdx > startIdx) {
                float sum = 0.0f;
                for (int i = startIdx; i < endIdx; ++i)
                    sum += mag[i];
                levels[b] = sum / static_cast<float>(endIdx - startIdx);
            }
        }

        rawFftData[c] = std::move(levels);
    }

    // ── Global normalisation (95th percentile, matching Python) ─
    std::vector<float> allValues;
    allValues.reserve(numChunks * numBars);
    for (const auto &chunk : rawFftData)
        for (float v : chunk)
            if (v > 0.0f)
                allValues.push_back(v);

    float globalMax = 1.0f;
    if (!allValues.empty()) {
        std::sort(allValues.begin(), allValues.end());
        int idx95 = static_cast<int>(allValues.size() * 0.95);
        idx95 = std::min(idx95, static_cast<int>(allValues.size()) - 1);
        globalMax = allValues[idx95];
        if (globalMax <= 0.0f)
            globalMax = 1.0f;
    }

    // ── Second pass: normalise → 0-8 integer levels ────────────
    result.fftData.resize(numChunks);
    for (int c = 0; c < numChunks; ++c) {
        result.fftData[c].resize(numBars);
        for (int b = 0; b < numBars; ++b) {
            float norm = rawFftData[c][b] / globalMax;
            norm = std::min(1.0f, norm);
            norm = std::pow(norm, 0.6f);                   // perceptual curve
            result.fftData[c][b] = static_cast<int>(norm * 8.0f);
        }
    }

    result.success = true;
    return result;
}

// ════════════════════════════════════════════════════════════════
// Public slots
// ════════════════════════════════════════════════════════════════

void AudioAnalyzer::analyze_file(const QString &filePath)
{
    qCInfo(lcAudioAnalyzer) << "analyze_file called with:" << filePath;

    if (filePath.isEmpty() || !QFileInfo::exists(filePath)) {
        qCWarning(lcAudioAnalyzer) << "Invalid file path for analysis:" << filePath;
        return;
    }

    // Already analyzed this file
    if (filePath == m_currentFile && !m_fftData.empty()) {
        qCInfo(lcAudioAnalyzer) << "File already analyzed:" << filePath;
        return;
    }

    // Already busy
    if (m_analyzing) {
        qCInfo(lcAudioAnalyzer) << "Analysis already in progress, skipping";
        return;
    }

    m_currentFile = filePath;
    m_analyzing   = true;

    emit analysisStarted();
    qCInfo(lcAudioAnalyzer) << "Starting audio analysis for:" << filePath;

    // Capture locals for the lambda (numBars, chunkDuration)
    const int    bars     = m_numBars;
    const double chunkDur = m_chunkDuration;

    QFuture<AnalysisResult> future = QtConcurrent::run(
        [filePath, bars, chunkDur]() {
            return AudioAnalyzer::analyzeAudio(filePath, bars, chunkDur);
        });

    m_watcher.setFuture(future);
}

void AudioAnalyzer::onAnalysisDone()
{
    m_analyzing = false;

    AnalysisResult result = m_watcher.result();
    if (result.success) {
        m_fftData = std::move(result.fftData);
        emit analysisComplete();
        qCInfo(lcAudioAnalyzer) << "Analysis complete:"
                                << m_fftData.size() << "chunks generated";
    } else {
        m_fftData.clear();
        qCWarning(lcAudioAnalyzer) << "Analysis failed for" << m_currentFile;
    }
}

void AudioAnalyzer::update_position(float positionSeconds)
{
    if (m_fftData.empty() || !m_isActive)
        return;

    int chunkIndex = static_cast<int>(positionSeconds * 10.0f);
    chunkIndex = std::clamp(chunkIndex, 0, static_cast<int>(m_fftData.size()) - 1);

    const auto &newLevels = m_fftData[chunkIndex];

    // Build QVariantList and compare
    QVariantList varList;
    varList.reserve(static_cast<int>(newLevels.size()));
    for (int v : newLevels)
        varList.append(v);

    if (varList != m_currentLevels) {
        m_currentLevels = varList;
        emit fftDataChanged(m_currentLevels);
    }
}

void AudioAnalyzer::set_active(bool active)
{
    qCInfo(lcAudioAnalyzer) << "set_active called with:" << active
                            << ", has FFT data:" << m_fftData.size() << "chunks";
    m_isActive = active;
    if (!active) {
        // Emit zeros to clear the visualizer
        m_currentLevels.clear();
        m_currentLevels.reserve(m_numBars);
        for (int i = 0; i < m_numBars; ++i)
            m_currentLevels.append(0);
        emit fftDataChanged(m_currentLevels);
    }
}

QVariantList AudioAnalyzer::get_current_levels() const
{
    return m_currentLevels;
}

int AudioAnalyzer::get_num_bars() const
{
    return m_numBars;
}

bool AudioAnalyzer::is_analyzed() const
{
    return !m_fftData.empty();
}

void AudioAnalyzer::clear()
{
    m_fftData.clear();
    m_currentFile.clear();

    m_currentLevels.clear();
    m_currentLevels.reserve(m_numBars);
    for (int i = 0; i < m_numBars; ++i)
        m_currentLevels.append(0);
}

void AudioAnalyzer::set_quality(const QString &quality)
{
    int newBars = m_qualityBars.value(quality, 32);
    if (newBars == m_numBars)
        return;

    qCInfo(lcAudioAnalyzer) << "Visualizer quality changed to" << quality
                            << ":" << newBars << "bars";
    m_numBars = newBars;

    m_currentLevels.clear();
    m_currentLevels.reserve(m_numBars);
    for (int i = 0; i < m_numBars; ++i)
        m_currentLevels.append(0);

    // Clear cached analysis so next track uses new bar count
    m_fftData.clear();
    m_currentFile.clear();
}
