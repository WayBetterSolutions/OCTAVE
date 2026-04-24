#ifndef AUDIOANALYZER_H
#define AUDIOANALYZER_H

#include <QObject>
#include <QVariantList>
#include <QString>
#include <QByteArray>
#include <QMap>
#include <QVector>
#include <QFuture>
#include <QFutureWatcher>

#include <vector>
#include <complex>
#include <cmath>

class AudioAnalyzer : public QObject
{
    Q_OBJECT

public:
    explicit AudioAnalyzer(QObject *parent = nullptr);
    ~AudioAnalyzer() override;

signals:
    void fftDataChanged(const QVariantList &levels);
    void analysisComplete();
    void analysisStarted();

public slots:
    void analyze_file(const QString &filePath);
    void update_position(float positionSeconds);
    void set_active(bool active);
    QVariantList get_current_levels() const;
    int get_num_bars() const;
    bool is_analyzed() const;
    void clear();
    void set_quality(const QString &quality);

private:
    // ── FFT helpers (no external deps) ─────────────────────────
    static void fft_radix2(std::vector<std::complex<float>> &x);
    static std::vector<float> hannWindow(int N);

    // ── Audio decoding + analysis ──────────────────────────────
    struct AnalysisResult {
        std::vector<std::vector<int>> fftData;
        bool success = false;
    };

    static AnalysisResult analyzeAudio(const QString &filePath, int numBars, double chunkDuration);

    void onAnalysisDone();

    // ── Quality tier → bar count ───────────────────────────────
    QMap<QString, int> m_qualityBars;

    // ── Pre-computed FFT data ──────────────────────────────────
    //    Outer vector: one entry per time chunk (~100 ms)
    //    Inner vector: bar levels 0-8
    std::vector<std::vector<int>> m_fftData;

    QString      m_currentFile;
    int          m_numBars        = 32;
    double       m_chunkDuration  = 0.1;   // seconds

    QVariantList m_currentLevels;          // mirrors m_numBars zeros

    bool         m_isActive       = false;
    bool         m_analyzing      = false;

    // Latest file requested while a previous analysis was still running.
    // Processed once onAnalysisDone completes the current job so fast
    // "skip" sequences don't leave the visualizer stuck on the old track's
    // data (or blank if the old track was never analyzed).
    QString      m_pendingFile;

    // Async worker
    QFutureWatcher<AnalysisResult> m_watcher;
};

#endif // AUDIOANALYZER_H
