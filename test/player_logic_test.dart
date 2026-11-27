import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music_eq/models/eq_preset.dart';
import 'package:flutter_music_eq/services/audio_player_service.dart';
import 'package:flutter_music_eq/services/playlist_manager.dart';

void main() {
  group('AudioPlayerService Math & Presets', () {
    final service = AudioPlayerService();

    test('dB to Gain and Gain to dB conversion', () {
      // 0 dB should map to ~1.0 gain (Flat)
      expect((service.dbToGain(0.0) - 1.0).abs(), lessThan(0.01));
      expect((service.gainToDb(1.0) - 0.0).abs(), lessThan(0.01));

      // +6 dB is approx 2x gain
      expect((service.dbToGain(6.0) - 1.995).abs(), lessThan(0.05));

      // -6 dB is approx 0.5x gain
      expect((service.dbToGain(-6.0) - 0.501).abs(), lessThan(0.05));
    });

    test('Presets contain expected bands and flat preset', () {
      expect(EqPreset.flat.lowGain, equals(1.0));
      expect(EqPreset.flat.midGain, equals(1.0));
      expect(EqPreset.flat.highGain, equals(1.0));
      expect(EqPreset.presets.length, greaterThanOrEqualTo(5));
    });
  });

  group('PlaylistManager Logic', () {
    final playlist = PlaylistManager();

    test('Initializes with 3 bundled demo tracks', () {
      expect(playlist.tracks.length, equals(3));
      expect(playlist.currentTrack, isNotNull);
      expect(playlist.currentTrack!.title, equals('Neon Groove Beat'));
      expect(playlist.currentTrack!.isAsset, isTrue);
    });

    test('Loop mode toggles correctly', () {
      expect(playlist.loopMode, equals(LoopMode.all));
      playlist.toggleLoopMode();
      expect(playlist.loopMode, equals(LoopMode.one));
      playlist.toggleLoopMode();
      expect(playlist.loopMode, equals(LoopMode.none));
      playlist.toggleLoopMode();
      expect(playlist.loopMode, equals(LoopMode.all));
    });

    test('Shuffle mode toggles and can be restored', () {
      playlist.restoreShuffle(false);
      expect(playlist.isShuffleEnabled, isFalse);
      playlist.toggleShuffle();
      expect(playlist.isShuffleEnabled, isTrue);
      playlist.restoreShuffle(false);
      expect(playlist.isShuffleEnabled, isFalse);
    });
  });
}
