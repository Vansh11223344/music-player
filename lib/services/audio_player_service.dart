import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/audio_track.dart';
import '../models/eq_preset.dart';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  AudioTrack? _currentTrack;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // 3-Band Equalizer Gains (Linear Multipliers: 0.0 = muted/-inf dB, 1.0 = flat/0 dB, 4.0 = max boost/+12 dB)
  double _lowGain = 1.0;
  double _midGain = 1.0;
  double _highGain = 1.0;
  bool _isEqActive = false;

  Timer? _positionTimer;
  VoidCallback? onTrackFinished;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  AudioTrack? get currentTrack => _currentTrack;

  double get lowGain => _lowGain;
  double get midGain => _midGain;
  double get highGain => _highGain;
  bool get isEqActive => _isEqActive;

  // dB helpers: gain = 10^(dB/20), dB = 20*log10(gain)
  double gainToDb(double gain) {
    if (gain <= 0.001) return -24.0;
    return (20.0 * math.log(gain) / math.ln10).clamp(-24.0, 12.0);
  }

  double dbToGain(double db) {
    return math.pow(10.0, db / 20.0).toDouble().clamp(0.0, 4.0);
  }

  double get lowDb => gainToDb(_lowGain);
  double get midDb => gainToDb(_midGain);
  double get highDb => gainToDb(_highGain);

  /// Initialize SoLoud audio engine and configure real-time Equalizer filter
  Future<void> initEngine() async {
    if (_isInitialized) return;

    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }
      _isInitialized = true;

      // Activate parametric EQ filter globally
      _setupEqualizer();
      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService initEngine error: $e');
    }
  }

  void _setupEqualizer() {
    try {
      final eq = SoLoud.instance.filters.parametricEqFilter;
      if (!eq.isActive) {
        eq.activate();
      }
      // Set STFT window size to 512 for responsive, low-latency filtering
      eq.stftWindowSize.value = 512;
      // Configure 3 frequency bands: Low (~30-150Hz), Mid (~700Hz), High (~16000Hz)
      eq.numBands.value = 3;
      eq.wet.value = 1.0;

      // Apply initial gains
      eq.bandGain(0).value = _lowGain;
      eq.bandGain(1).value = _midGain;
      eq.bandGain(2).value = _highGain;

      _isEqActive = true;
    } catch (e) {
      debugPrint('Error setting up parametric EQ: $e');
      _isEqActive = false;
    }
  }

  /// Sets Low Band Gain (Index 0: Bass ~30-150 Hz)
  void setLowGain(double gain) {
    _lowGain = gain.clamp(0.0, 4.0);
    _applyBandGain(0, _lowGain);
    notifyListeners();
  }

  /// Sets Mid Band Gain (Index 1: Vocals/Instruments ~700 Hz)
  void setMidGain(double gain) {
    _midGain = gain.clamp(0.0, 4.0);
    _applyBandGain(1, _midGain);
    notifyListeners();
  }

  /// Sets High Band Gain (Index 2: Treble/Air ~16,000 Hz)
  void setHighGain(double gain) {
    _highGain = gain.clamp(0.0, 4.0);
    _applyBandGain(2, _highGain);
    notifyListeners();
  }

  /// Sets gains by Decibels (-24 dB to +12 dB)
  void setLowDb(double db) => setLowGain(dbToGain(db));
  void setMidDb(double db) => setMidGain(dbToGain(db));
  void setHighDb(double db) => setHighGain(dbToGain(db));

  /// Reset Equalizer to Flat (1.0x / 0.0 dB)
  void resetEq() {
    _lowGain = 1.0;
    _midGain = 1.0;
    _highGain = 1.0;
    _applyBandGain(0, 1.0);
    _applyBandGain(1, 1.0);
    _applyBandGain(2, 1.0);
    notifyListeners();
  }

  /// Apply predefined EQ Preset
  void applyPreset(EqPreset preset) {
    _lowGain = preset.lowGain;
    _midGain = preset.midGain;
    _highGain = preset.highGain;
    _applyBandGain(0, _lowGain);
    _applyBandGain(1, _midGain);
    _applyBandGain(2, _highGain);
    notifyListeners();
  }

  void _applyBandGain(int bandIndex, double gain) {
    try {
      final eq = SoLoud.instance.filters.parametricEqFilter;
      if (!eq.isActive) {
        eq.activate();
      }
      eq.bandGain(bandIndex).value = gain;
    } catch (e) {
      debugPrint('Failed to set EQ band $bandIndex gain: $e');
    }
  }

  /// Play an AudioTrack. Returns true on success, false if file could not be decoded.
  Future<bool> playTrack(AudioTrack track) async {
    await initEngine();

    // Stop current track
    await stop();

    _currentTrack = track;
    _currentPosition = Duration.zero;

    try {
      AudioSource source;
      if (track.isAsset) {
        source = await SoLoud.instance.loadAsset(track.path);
      } else {
        // Dual-strategy for local device files:
        // 1. First attempt loading file directly with normalized path
        try {
          final normalizedPath = track.path.replaceAll('/', '\\');
          source = await SoLoud.instance.loadFile(normalizedPath);
        } catch (loadErr) {
          debugPrint(
            'loadFile failed ($loadErr), trying loadMem byte stream fallback...',
          );
          // 2. Fallback: Read file bytes into memory via Dart File I/O
          final file = File(track.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            source = await SoLoud.instance.loadMem(track.title, bytes);
          } else {
            throw Exception('File does not exist: ${track.path}');
          }
        }
      }

      _currentSource = source;
      _totalDuration = SoLoud.instance.getLength(source);

      // Play with looping = false so we can advance automatically
      _currentHandle = SoLoud.instance.play(source);
      _isPlaying = true;
      _isPaused = false;

      // Ensure EQ gains remain applied to newly active voice stream
      _applyBandGain(0, _lowGain);
      _applyBandGain(1, _midGain);
      _applyBandGain(2, _highGain);

      _startPositionTimer();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error playing track ${track.title}: $e');
      _isPlaying = false;
      _isPaused = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle Play / Pause
  void togglePlayPause() {
    final handle = _currentHandle;
    final source = _currentSource;

    if (handle == null ||
        source == null ||
        !SoLoud.instance.getIsValidVoiceHandle(handle)) {
      final track = _currentTrack;
      if (track != null) {
        unawaited(playTrack(track));
      }
      return;
    }

    try {
      if (_isPlaying) {
        SoLoud.instance.setPause(handle, true);
        _isPlaying = false;
        _isPaused = true;
        _positionTimer?.cancel();
      } else {
        SoLoud.instance.setPause(handle, false);
        _isPlaying = true;
        _isPaused = false;
        _startPositionTimer();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }

  /// Seek to target Duration
  void seek(Duration position) {
    if (_currentHandle == null || !_isInitialized) return;

    final target = position.clamp(Duration.zero, _totalDuration);
    try {
      SoLoud.instance.seek(_currentHandle!, target);
      _currentPosition = target;
      notifyListeners();
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    _positionTimer?.cancel();
    _positionTimer = null;

    if (_currentHandle != null) {
      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_currentHandle!)) {
          SoLoud.instance.stop(_currentHandle!);
        }
      } catch (_) {}
      _currentHandle = null;
    }

    if (_currentSource != null) {
      try {
        await SoLoud.instance.disposeSource(_currentSource!);
      } catch (_) {}
      _currentSource = null;
    }

    _isPlaying = false;
    _isPaused = false;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentHandle == null || !_isPlaying) return;

      try {
        if (SoLoud.instance.getIsValidVoiceHandle(_currentHandle!)) {
          final pos = SoLoud.instance.getPosition(_currentHandle!);
          _currentPosition = pos;

          // Check if track ended
          if (_totalDuration > Duration.zero &&
              pos >= _totalDuration - const Duration(milliseconds: 150)) {
            _onFinished();
          } else {
            notifyListeners();
          }
        } else {
          // Handle became invalid (track ended)
          _onFinished();
        }
      } catch (_) {
        _onFinished();
      }
    });
  }

  void _onFinished() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _isPlaying = false;
    _isPaused = false;
    _currentPosition = _totalDuration;
    notifyListeners();

    onTrackFinished?.call();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    super.dispose();
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
