import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_music_eq/services/app_preferences.dart';
import 'package:flutter_music_eq/services/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme and equalizer values persist between launches', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences.instance;
    await preferences.load();

    await preferences.setDarkMode(false);
    final player = AudioPlayerService()
      ..setLowGain(2.0)
      ..setMidGain(0.75)
      ..setHighGain(1.5);
    preferences.persistEqSoon(player);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final store = await SharedPreferences.getInstance();
    expect(store.getBool('dark_mode'), isFalse);
    expect(store.getDouble('eq_low'), closeTo(2.0, 0.001));
    expect(store.getDouble('eq_mid'), closeTo(0.75, 0.001));
    expect(store.getDouble('eq_high'), closeTo(1.5, 0.001));

    await preferences.setDarkMode(true);
  });

  test('playback state persists for the next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences.instance;
    await preferences.load();

    await preferences.savePlaybackState(
      trackId: 'local_track',
      positionMs: 125000,
      wasPlaying: true,
    );

    expect(preferences.savedPlaybackTrackId, 'local_track');
    expect(preferences.savedPlaybackPositionMs, 125000);
    expect(preferences.savedPlaybackWasPlaying, isTrue);

    await preferences.savePlaybackState(
      trackId: 'local_track',
      positionMs: 125000,
      wasPlaying: false,
    );
    expect(preferences.savedPlaybackWasPlaying, isFalse);
  });
}
