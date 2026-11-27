import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_player_service.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  SharedPreferences? _store;
  bool _isDarkMode = true;
  bool _shuffleEnabled = false;
  Timer? _eqSaveTimer;

  bool get isDarkMode => _isDarkMode;
  bool get shuffleEnabled => _shuffleEnabled;
  double? get savedLowGain => _store?.getDouble('eq_low');
  double? get savedMidGain => _store?.getDouble('eq_mid');
  double? get savedHighGain => _store?.getDouble('eq_high');

  Future<void> load() async {
    _store = await SharedPreferences.getInstance();
    _isDarkMode = _store?.getBool('dark_mode') ?? true;
    _shuffleEnabled = _store?.getBool('shuffle_enabled') ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await _store?.setBool('dark_mode', value);
  }

  Future<void> setShuffleEnabled(bool value) async {
    _shuffleEnabled = value;
    notifyListeners();
    await _store?.setBool('shuffle_enabled', value);
  }

  void persistEqSoon(AudioPlayerService playerService) {
    _eqSaveTimer?.cancel();
    _eqSaveTimer = Timer(const Duration(milliseconds: 250), () async {
      final store = _store;
      if (store == null) return;
      await Future.wait([
        store.setDouble('eq_low', playerService.lowGain),
        store.setDouble('eq_mid', playerService.midGain),
        store.setDouble('eq_high', playerService.highGain),
      ]);
    });
  }

  @override
  void dispose() {
    _eqSaveTimer?.cancel();
    super.dispose();
  }
}
