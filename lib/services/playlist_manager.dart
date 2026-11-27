import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path_provider/path_provider.dart';
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
    _playerService.addListener(_schedulePlaybackStateSave);
  }

  final AudioPlayerService _playerService = AudioPlayerService();
  final List<AudioTrack> _tracks = [];
  int _currentIndex = 0;
  LoopMode _loopMode = LoopMode.all;
  bool _isShuffleEnabled = false;
  final List<int> _shuffleHistory = [];
  int _shuffleHistoryCursor = -1;
  Timer? _playbackSaveTimer;
  Directory? _libraryDirectory;

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

  Future<void> restoreLibrary() async {
    try {
      final directory = await _getLibraryDirectory();
      final manifest = File(
        '${directory.path}${Platform.pathSeparator}library.json',
      );
      if (!await manifest.exists()) return;

      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      final importedTracks = <AudioTrack>[];
      for (final value in json['tracks'] as List<dynamic>? ?? []) {
        final track = AudioTrack.fromJson(value as Map<String, dynamic>);
        if (!track.isAsset && await File(track.path).exists()) {
          importedTracks.add(track);
        }
      }
      _tracks.addAll(importedTracks);

      final selectedTrackId = json['currentTrackId'] as String?;
      final selectedIndex = _tracks.indexWhere(
        (track) => track.id == selectedTrackId,
      );
      if (selectedIndex >= 0) _currentIndex = selectedIndex;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not restore the local music library: $error');
    }
  }

  Future<Directory> _getLibraryDirectory() async {
    final cachedDirectory = _libraryDirectory;
    if (cachedDirectory != null) return cachedDirectory;
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}imported_audio',
    );
    await directory.create(recursive: true);
    _libraryDirectory = directory;
    return directory;
  }

  Future<void> _saveLibrary() async {
    try {
      final directory = await _getLibraryDirectory();
      final manifest = File(
        '${directory.path}${Platform.pathSeparator}library.json',
      );
      final importedTracks = _tracks
          .where((track) => !track.isAsset)
          .map((track) => track.toJson())
          .toList();
      await manifest.writeAsString(
        jsonEncode({
          'tracks': importedTracks,
          'currentTrackId': currentTrack?.id,
        }),
        flush: true,
      );
    } catch (error) {
      debugPrint('Could not save the local music library: $error');
    }
  }

  void _schedulePlaybackStateSave() {
    if (_playerService.currentTrack == null ||
        (!_playerService.isPlaying && !_playerService.isPaused) ||
        _playbackSaveTimer != null) {
      return;
    }
    _playbackSaveTimer = Timer(const Duration(seconds: 1), () {
      _playbackSaveTimer = null;
      persistPlaybackStateNow();
    });
  }

  void persistPlaybackStateNow() {
    _playbackSaveTimer?.cancel();
    _playbackSaveTimer = null;
    final track = _playerService.currentTrack;
    if (track == null) return;
    unawaited(
      AppPreferences.instance.savePlaybackState(
        trackId: track.id,
        positionMs: _playerService.currentPosition.inMilliseconds,
        wasPlaying: _playerService.isPlaying,
      ),
    );
  }

  Future<void> togglePlayPause() async {
    if (_playerService.currentTrack == null) {
      final track = currentTrack;
      if (track != null) await _playerService.playTrack(track);
    } else {
      _playerService.togglePlayPause();
    }
    persistPlaybackStateNow();
  }

  Future<void> restorePlayback() async {
    if (_playerService.currentTrack != null) return;

    final savedTrackId = AppPreferences.instance.savedPlaybackTrackId;
    if (savedTrackId == null) {
      final track = currentTrack;
      if (track != null) {
        await _playerService.playTrack(track, startPaused: true);
      }
      return;
    }

    final savedIndex = _tracks.indexWhere((track) => track.id == savedTrackId);
    if (savedIndex < 0) {
      final track = currentTrack;
      if (track != null) {
        await _playerService.playTrack(track, startPaused: true);
      }
      return;
    }

    _currentIndex = savedIndex;
    final track = _tracks[_currentIndex];
    notifyListeners();
    final wasPlaying = AppPreferences.instance.savedPlaybackWasPlaying;
    final success = await _playerService.playTrack(
      track,
      startPaused: !wasPlaying,
    );
    if (!success) return;
    _playerService.seek(
      Duration(milliseconds: AppPreferences.instance.savedPlaybackPositionMs),
    );
    persistPlaybackStateNow();
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
    unawaited(_saveLibrary());
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
    unawaited(_saveLibrary());
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
    unawaited(_saveLibrary());
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
        final sourcePath = file.path;
        if (sourcePath == null || sourcePath.isEmpty) {
          debugPrint('No readable file path returned for ${file.name}.');
          continue;
        }
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          debugPrint('Selected file does not exist on disk: $sourcePath');
          continue;
        }

        final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
        final nameExtension = file.name.lastIndexOf('.') > 0
            ? file.name.substring(file.name.lastIndexOf('.') + 1)
            : null;
        final extensionCandidate = (file.extension ?? nameExtension ?? 'audio')
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .toLowerCase();
        final extension = extensionCandidate.isEmpty
            ? 'audio'
            : extensionCandidate;
        final directory = await _getLibraryDirectory();
        final storedFile = File(
          '${directory.path}${Platform.pathSeparator}$id.$extension',
        );
        await sourceFile.copy(storedFile.path);
        final filePath = storedFile.path;

        final fileName = file.name;
        final ext = extension.toUpperCase();
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
          id: id,
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

      if (newTracks.isEmpty) {
        return const PickResult(
          success: false,
          errorMessage: 'No valid file path returned by file dialog.',
        );
      }

      _tracks.addAll(newTracks);
      // Auto-select and play the first imported track
      _currentIndex = _tracks.length - newTracks.length;
      await _saveLibrary();
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
      debugPrint('Error importing audio files: $e');
      return PickResult(
        success: false,
        errorMessage: 'Failed to import audio files: $e',
      );
    }
  }

  /// Remove track at index
  Future<void> removeTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    if (_tracks.length <= 1) return; // Keep at least one

    final bool removingCurrent = index == _currentIndex;
    final removedTrack = _tracks.removeAt(index);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _tracks.length) {
      _currentIndex = _tracks.length - 1;
    }
    if (_isShuffleEnabled) {
      _shuffleHistory
        ..clear()
        ..add(_currentIndex);
      _shuffleHistoryCursor = 0;
    }

    notifyListeners();
    await _saveLibrary();

    if (removingCurrent) {
      await _playerService.playTrack(_tracks[_currentIndex]);
    }

    final directory = await _getLibraryDirectory();
    final removedFile = File(removedTrack.path);
    if (!removedTrack.isAsset &&
        removedFile.parent.path == directory.path &&
        await removedFile.exists()) {
      try {
        await removedFile.delete();
      } catch (error) {
        debugPrint('Could not delete imported audio file: $error');
      }
    }
  }
}
