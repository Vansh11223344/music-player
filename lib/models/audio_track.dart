import 'dart:typed_data';

class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String path;
  final bool isAsset;
  final String format;
  final Duration duration;
  final Uint8List? artworkBytes;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.path,
    required this.isAsset,
    required this.format,
    this.duration = Duration.zero,
    this.artworkBytes,
  });

  AudioTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? path,
    bool? isAsset,
    String? format,
    Duration? duration,
    Uint8List? artworkBytes,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      path: path ?? this.path,
      isAsset: isAsset ?? this.isAsset,
      format: format ?? this.format,
      duration: duration ?? this.duration,
      artworkBytes: artworkBytes ?? this.artworkBytes,
    );
  }
}
