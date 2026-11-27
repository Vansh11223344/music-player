import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/audio_track.dart';
import 'app_preferences.dart';
import 'audio_player_service.dart';

enum LoopMode { none, all, one }

typedef _TrackMetadata = ({String? title, String? artist, Uint8List? artwork});

_TrackMetadata _readTrackMetadata(String path) {
  final metadata = readMetadata(File(path), getImage: true);
  return (
    title: metadata.title,
    artist: metadata.artist,
    artwork: metadata.pictures.isEmpty ? null : metadata.pictures.first.bytes,
  );
}

class PickResult {
  final bool success;
  final String? trackTitle;
  final String? errorMessage;

  const PickResult({required this.success, this.trackTitle, this.errorMessage});
}

class PlaylistManager extends ChangeNotifier {
  static final PlaylistManager _instance = PlaylistManager._internal();
  factory PlaylistManager() => _instance;
  PlaylistManager._internal() {
    _initDefaultTracks();
    _playerService.onTrackFinished = _handleTrackFinished;
  }

  final AudioPlayerService _playerService = AudioPlayerService();
  final List<AudioTrack> _tracks = [];
  int _currentIndex = 0;
  LoopMode _loopMode = LoopMode.all;
  bool _isShuffleEnabled = false;
  final List<int> _shuffleHistory = [];
  int _shuffleHistoryCursor = -1;

  List<AudioTrack> get tracks => List.unmodifiable(_tracks);
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack =>
      _tracks.isNotEmpty && _currentIndex >= 0 && _currentIndex < _tracks.length
      ? _tracks[_currentIndex]
      : null;
  LoopMode get loopMode => _loopMode;
  bool get isShuffleEnabled => _isShuffleEnabled;

  void restoreShuffle(bool enabled) {
    _isShuffleEnabled = enabled;
    _shuffleHistory
      ..clear()
      ..add(_currentIndex);
    _shuffleHistoryCursor = 0;
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    _shuffleHistory
      ..clear()
      ..add(_currentIndex);
    _shuffleHistoryCursor = 0;
    AppPreferences.instance.setShuffleEnabled(_isShuffleEnabled);
    notifyListeners();
  }

  void _initDefaultTracks() {
    _tracks.addAll([
      const AudioTrack(
        id: 'track_groove',
        title: 'Neon Groove Beat',
        artist: 'Bundled Demo (Bass & Highs)',
        path: 'assets/audio/groove_beat.wav',
        isAsset: true,
        format: 'WAV 44.1kHz',
      ),
      const AudioTrack(
        id: 'track_synth',
        title: 'Synthwave Pulse',
        artist: 'Bundled Demo (Retrowave Mids)',
        path: 'assets/audio/synth_wave.wav',
        isAsset: true,
        format: 'WAV 44.1kHz',
      ),
      const AudioTrack(
        id: 'track_acoustic',
        title: 'Acoustic Horizon',
        artist: 'Bundled Demo (Warm Harmonics)',
        path: 'assets/audio/acoustic_chill.wav',
        isAsset: true,
        format: 'WAV 44.1kHz',
      ),
    ]);
  }

  /// Toggle loop mode: all -> one -> none -> all
  void toggleLoopMode() {
    switch (_loopMode) {
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.none;
        break;
      case LoopMode.none:
        _loopMode = LoopMode.all;
        break;
    }
    notifyListeners();
  }

  /// Play track at index
  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _currentIndex = index;
    if (_isShuffleEnabled) _recordShuffleTrack(index);
    notifyListeners();
    await _playerService.playTrack(_tracks[_currentIndex]);
  }

  /// Play Next track
  Future<void> nextTrack() async {
    if (_tracks.isEmpty) return;
    if (_isShuffleEnabled) {
      if (_shuffleHistoryCursor < _shuffleHistory.length - 1) {
        _shuffleHistoryCursor++;
        _currentIndex = _shuffleHistory[_shuffleHistoryCursor];
      } else {
        final unplayed = List<int>.generate(_tracks.length, (index) => index)
          ..removeWhere(_shuffleHistory.contains);
        if (unplayed.isEmpty && _loopMode == LoopMode.none) {
          await _playerService.stop();
          return;
        }
        final options = unplayed.isEmpty
            ? List<int>.generate(_tracks.length, (index) => index)
            : unplayed;
        _currentIndex = options[Random().nextInt(options.length)];
        _recordShuffleTrack(_currentIndex);
      }
    } else if (_currentIndex < _tracks.length - 1) {
      _currentIndex++;
    } else {
      if (_loopMode == LoopMode.none) {
        await _playerService.stop();
        return;
      }
      _currentIndex = 0; // Wrap around
    }
    notifyListeners();
    await _playerService.playTrack(_tracks[_currentIndex]);
  }

  /// Play Previous track
  Future<void> previousTrack() async {
    if (_tracks.isEmpty) return;
    if (_playerService.currentPosition.inSeconds > 3) {
      _playerService.seek(Duration.zero);
      return;
    }

    if (_isShuffleEnabled && _shuffleHistoryCursor > 0) {
      _shuffleHistoryCursor--;
      _currentIndex = _shuffleHistory[_shuffleHistoryCursor];
    } else if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _tracks.length - 1; // Wrap to end
    }
    if (_isShuffleEnabled && _shuffleHistoryCursor <= 0) {
      _recordShuffleTrack(_currentIndex);
    }
    notifyListeners();
    await _playerService.playTrack(_tracks[_currentIndex]);
  }

  void _recordShuffleTrack(int index) {
    if (_shuffleHistoryCursor >= 0 &&
        _shuffleHistory[_shuffleHistoryCursor] == index) {
      return;
    }
    if (_shuffleHistoryCursor < _shuffleHistory.length - 1) {
      _shuffleHistory.removeRange(
        _shuffleHistoryCursor + 1,
        _shuffleHistory.length,
      );
    }
    _shuffleHistory.add(index);
    _shuffleHistoryCursor = _shuffleHistory.length - 1;
  }

  void _handleTrackFinished() {
    if (_loopMode == LoopMode.one) {
      _playerService.playTrack(_tracks[_currentIndex]);
    } else if (_loopMode == LoopMode.all) {
      nextTrack();
    } else {
      if (_currentIndex < _tracks.length - 1) {
        nextTrack();
      } else {
        _playerService.stop();
      }
    }
  }

  /// Robust audio file picker supporting Windows, Android, macOS, Linux
  Future<PickResult> pickAudioFiles() async {
    try {
      List<PlatformFile> pickedFiles = [];

      // 1. First attempt: standard audio file picker
      try {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'mp3',
            'wav',
            'ogg',
            'flac',
            'opus',
            'MP3',
            'WAV',
            'OGG',
            'FLAC',
            'OPUS',
            'm4a',
            'aac',
            'M4A',
            'AAC',
          ],
        );
      } catch (pickerErr) {
        debugPrint(
          'Custom extension picker failed, trying FileType.any: $pickerErr',
        );
        // 2. Fallback attempt: Any file type (avoids OS filter crashes)
        pickedFiles = await FilePicker.pickFiles(type: FileType.any);
      }

      if (pickedFiles.isEmpty) {
        return const PickResult(success: false); // User cancelled dialog
      }

      final List<AudioTrack> newTracks = [];
      for (final file in pickedFiles) {
        if (file.path != null && file.path!.isNotEmpty) {
          final filePath = file.path!;
          final fileObj = File(filePath);

          if (!await fileObj.exists()) {
            debugPrint('Selected file does not exist on disk: $filePath');
            continue;
          }

          final fileName = file.name;
          final ext = file.extension?.toUpperCase() ?? 'AUDIO';
          final fallbackTitle = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          String? metadataTitle;
          String? metadataArtist;
          Uint8List? artworkBytes;
          try {
            final metadata = await Isolate.run(
              () => _readTrackMetadata(filePath),
            );
            metadataTitle = metadata.title;
            metadataArtist = metadata.artist;
            artworkBytes = metadata.artwork;
          } catch (error) {
            debugPrint('Could not read audio metadata for $fileName: $error');
          }

          final track = AudioTrack(
            id: 'local_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
            title: metadataTitle?.trim().isNotEmpty == true
                ? metadataTitle!.trim()
                : fallbackTitle,
            artist: metadataArtist?.trim().isNotEmpty == true
                ? metadataArtist!.trim()
                : 'Local Device File',
            path: filePath,
            isAsset: false,
            format: ext,
            artworkBytes: artworkBytes,
          );
          newTracks.add(track);
        }
      }

      if (newTracks.isEmpty) {
        return const PickResult(
          success: false,
          errorMessage: 'No valid file path returned by file dialog.',
        );
      }

      _tracks.addAll(newTracks);
      // Auto-select and play the first imported track
      _currentIndex = _tracks.length - newTracks.length;
      notifyListeners();

      final playSuccess = await _playerService.playTrack(
        _tracks[_currentIndex],
      );

      if (playSuccess) {
        return PickResult(
          success: true,
          trackTitle: _tracks[_currentIndex].title,
        );
      } else {
        return PickResult(
          success: false,
          errorMessage:
              'Selected audio format (${_tracks[_currentIndex].format}) could not be decoded. Please choose an MP3, WAV, OGG, or FLAC file.',
        );
      }
    } catch (e) {
      debugPrint('Error picking audio files: $e');
      return PickResult(
        success: false,
        errorMessage: 'Failed to open file picker: $e',
      );
    }
  }

  /// Remove track at index
  void removeTrack(int index) {
    if (index < 0 || index >= _tracks.length) return;
    if (_tracks.length <= 1) return; // Keep at least one

    final bool removingCurrent = index == _currentIndex;
    _tracks.removeAt(index);

    if (_currentIndex >= _tracks.length) {
      _currentIndex = _tracks.length - 1;
    }
    if (_isShuffleEnabled) {
      _shuffleHistory
        ..clear()
        ..add(_currentIndex);
      _shuffleHistoryCursor = 0;
    }

    notifyListeners();

    if (removingCurrent) {
      _playerService.playTrack(_tracks[_currentIndex]);
    }
  }
}
