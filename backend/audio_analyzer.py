"""
Audio Analyzer for Waveform Visualization
Analyzes audio files using FFT to generate real-time waveform visualization data.
"""

from PySide6.QtCore import QObject, Signal, Slot, QTimer
import numpy as np
import os

from backend.logging_config import get_logger
logger = get_logger(__name__)

# Try to import av for audio decoding
try:
    import av
    AV_AVAILABLE = True
except ImportError:
    AV_AVAILABLE = False
    logger.warning("PyAV not available - waveform visualization will be disabled")


class AudioAnalyzer(QObject):
    """
    Analyzes audio files to generate FFT visualization data.
    Pre-computes FFT for entire track, then provides data based on playback position.
    """

    # Signal emitted with FFT levels as a list of integers (0-8)
    fftDataChanged = Signal(list)

    # Signal emitted when analysis is complete
    analysisComplete = Signal()

    # Signal emitted when analysis starts
    analysisStarted = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        # FFT data storage - list of lists, each inner list is FFT levels for a time chunk
        self._fft_data = []
        self._current_file = ""
        self._num_bars = 60  # Number of frequency bars
        self._chunk_duration = 0.1  # 100ms chunks (10 chunks per second)

        # Current levels for smooth animation
        self._current_levels = [0] * self._num_bars
        self._target_levels = [0] * self._num_bars

        # Animation timer - 80ms (12.5 FPS) is smooth enough for visualization
        self._animation_timer = QTimer(self)
        self._animation_timer.setInterval(80)
        self._animation_timer.timeout.connect(self._animate_levels)

        # Track if we're actively playing
        self._is_active = False

    @Slot(str)
    def analyze_file(self, file_path: str):
        """
        Analyze an audio file and pre-compute FFT visualization data.
        Called when a new track starts playing.
        """
        logger.info(f"analyze_file called with: {file_path}")

        if not AV_AVAILABLE:
            logger.warning("PyAV not available, skipping analysis")
            return

        if not file_path or not os.path.exists(file_path):
            logger.warning(f"Invalid file path for analysis: {file_path}")
            return

        # Skip if already analyzed
        if file_path == self._current_file and self._fft_data:
            logger.info(f"File already analyzed: {file_path}")
            return

        self._current_file = file_path
        self._fft_data = []

        self.analysisStarted.emit()
        logger.info(f"Starting audio analysis for: {file_path}")

        try:
            self._analyze_audio(file_path)
            self.analysisComplete.emit()
            logger.info(f"Analysis complete: {len(self._fft_data)} chunks generated")
        except Exception as e:
            logger.error(f"Error analyzing audio: {e}", exc_info=True)
            self._fft_data = []

    def _analyze_audio(self, file_path: str):
        """
        Decode audio and compute FFT for visualization.
        Uses PyAV for decoding.
        """
        try:
            container = av.open(file_path)
            audio_stream = next((s for s in container.streams if s.type == 'audio'), None)

            if not audio_stream:
                logger.debug("No audio stream found")
                return

            # Decode all audio frames
            samples = []
            sample_rate = audio_stream.rate or 44100

            for frame in container.decode(audio_stream):
                # Convert to numpy array
                frame_data = frame.to_ndarray()

                # If stereo, convert to mono by averaging channels
                if len(frame_data.shape) > 1:
                    frame_data = frame_data.mean(axis=0)

                samples.append(frame_data)

            container.close()

            if not samples:
                logger.debug("No audio samples decoded")
                return

            # Concatenate all samples
            all_samples = np.concatenate(samples).astype(np.float32)

            # Normalize samples
            max_val = np.max(np.abs(all_samples))
            if max_val > 0:
                all_samples = all_samples / max_val

            # Downsample to ~8kHz for faster processing
            downsample_factor = max(1, sample_rate // 8000)
            all_samples = all_samples[::downsample_factor]
            effective_rate = sample_rate // downsample_factor

            # Compute FFT for time chunks
            chunk_size = int(effective_rate * self._chunk_duration)
            num_chunks = len(all_samples) // chunk_size

            if num_chunks == 0:
                logger.debug("Audio too short for analysis")
                return

            # First pass: collect raw FFT magnitudes
            raw_fft_data = []
            for i in range(num_chunks):
                chunk = all_samples[i * chunk_size:(i + 1) * chunk_size]

                # Apply window function to reduce spectral leakage
                window = np.hanning(len(chunk))
                windowed = chunk * window

                # Compute FFT
                fft = np.abs(np.fft.rfft(windowed))
                fft = fft[1:len(fft)//2]  # Skip DC, use lower half

                if len(fft) == 0:
                    raw_fft_data.append([0.0] * self._num_bars)
                    continue

                # Split into frequency bands with logarithmic spacing for better bass response
                # Use log spacing to give more bins to lower frequencies
                log_indices = np.logspace(0, np.log10(len(fft)), self._num_bars + 1, dtype=int)
                log_indices = np.clip(log_indices, 0, len(fft))

                levels = []
                for j in range(self._num_bars):
                    start_idx = log_indices[j]
                    end_idx = log_indices[j + 1]
                    if end_idx > start_idx:
                        band = fft[start_idx:end_idx]
                        levels.append(np.mean(band))
                    else:
                        levels.append(0.0)

                raw_fft_data.append(levels)

            # Find global max for normalization (use 95th percentile to avoid outliers)
            all_values = [v for chunk in raw_fft_data for v in chunk if v > 0]
            if all_values:
                global_max = np.percentile(all_values, 95)
            else:
                global_max = 1.0

            # Second pass: normalize and map to 0-8 range
            for levels in raw_fft_data:
                normalized = []
                for level in levels:
                    if global_max > 0:
                        norm = level / global_max
                        # Apply power curve for more dynamic range
                        norm = min(1.0, norm) ** 0.6
                        normalized.append(int(norm * 8))
                    else:
                        normalized.append(0)
                self._fft_data.append(normalized)

        except Exception as e:
            logger.error(f"FFT analysis error: {e}")
            self._fft_data = []

    @Slot(float)
    def update_position(self, position_seconds: float):
        """
        Update target FFT levels based on current playback position.
        Called periodically from QML during playback.
        """
        if not self._fft_data:
            self._target_levels = [0] * self._num_bars
            return

        # Each chunk is 100ms, so position in chunks is position * 10
        chunk_index = int(position_seconds * 10)
        chunk_index = max(0, min(chunk_index, len(self._fft_data) - 1))

        self._target_levels = self._fft_data[chunk_index]

        # Log occasionally (every ~2 seconds)
        if chunk_index % 20 == 0:
            max_level = max(self._target_levels) if self._target_levels else 0
            logger.debug(f"Position: {position_seconds:.1f}s, chunk: {chunk_index}, max level: {max_level}")

    @Slot(bool)
    def set_active(self, active: bool):
        """Enable or disable the animation."""
        logger.info(f"set_active called with: {active}, has FFT data: {len(self._fft_data)} chunks")
        self._is_active = active
        if active:
            if not self._animation_timer.isActive():
                self._animation_timer.start()
                logger.info("Animation timer started")
        else:
            self._target_levels = [0] * self._num_bars

    def _animate_levels(self):
        """
        Smoothly animate current levels toward target levels.
        Asymmetric rise/decay for punchy visuals.
        """
        changed = False

        for i in range(self._num_bars):
            if self._is_active:
                # Move toward target
                if self._current_levels[i] < self._target_levels[i]:
                    # Fast rise
                    self._current_levels[i] = min(self._current_levels[i] + 2, self._target_levels[i])
                    changed = True
                elif self._current_levels[i] > self._target_levels[i]:
                    # Slower decay
                    self._current_levels[i] = max(self._current_levels[i] - 1, self._target_levels[i])
                    changed = True
            else:
                # Decay when not active
                if self._current_levels[i] > 0:
                    self._current_levels[i] = max(0, self._current_levels[i] - 1)
                    changed = True

        if changed:
            self.fftDataChanged.emit(self._current_levels.copy())
        elif not self._is_active:
            # Stop timer when not active and decay complete (all levels at 0)
            self._animation_timer.stop()
            logger.debug("Animation timer stopped - decay complete")

        # Log occasionally to confirm animation is running
        if hasattr(self, '_animate_log_counter'):
            self._animate_log_counter += 1
        else:
            self._animate_log_counter = 0

        if self._animate_log_counter % 40 == 0:  # Every 2 seconds
            max_level = max(self._current_levels) if self._current_levels else 0
            logger.debug(f"Animation tick: active={self._is_active}, changed={changed}, max_level={max_level}")

    @Slot(result=list)
    def get_current_levels(self) -> list:
        """Get current FFT levels for QML."""
        return self._current_levels.copy()

    @Slot(result=int)
    def get_num_bars(self) -> int:
        """Get number of frequency bars."""
        return self._num_bars

    @Slot(result=bool)
    def is_analyzed(self) -> bool:
        """Check if current file has been analyzed."""
        return len(self._fft_data) > 0

    @Slot()
    def clear(self):
        """Clear analysis data."""
        self._fft_data = []
        self._current_file = ""
        self._current_levels = [0] * self._num_bars
        self._target_levels = [0] * self._num_bars
