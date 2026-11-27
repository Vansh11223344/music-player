import 'dart:convert';
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

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'path': path,
    'isAsset': isAsset,
    'format': format,
    'durationMs': duration.inMilliseconds,
    'artwork': artworkBytes == null ? null : base64Encode(artworkBytes!),
  };

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    final artwork = json['artwork'] as String?;
    return AudioTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      path: json['path'] as String,
      isAsset: json['isAsset'] as bool,
      format: json['format'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      artworkBytes: artwork == null ? null : base64Decode(artwork),
    );
  }

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
