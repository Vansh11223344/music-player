import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/app_preferences.dart';
import 'services/audio_player_service.dart';
import 'services/playlist_manager.dart';
import 'ui/player_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = AppPreferences.instance;
  await preferences.load();
  await PlaylistManager().restoreLibrary();
  final playerService = AudioPlayerService();
  final lowGain = preferences.savedLowGain;
  final midGain = preferences.savedMidGain;
  final highGain = preferences.savedHighGain;
  if (lowGain != null) playerService.setLowGain(lowGain);
  if (midGain != null) playerService.setMidGain(midGain);
  if (highGain != null) playerService.setHighGain(highGain);
  runApp(const MusicEqApp());
}

class MusicEqApp extends StatelessWidget {
  const MusicEqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final dark = AppPreferences.instance.isDarkMode;
        final baseTheme = ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: dark
              ? const Color(0xFF0C0A14)
              : const Color(0xFFF1F5F9),
          sliderTheme: const SliderThemeData(
            showValueIndicator: ShowValueIndicator.never,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00F5FF),
            brightness: dark ? Brightness.dark : Brightness.light,
            surface: dark ? const Color(0xFF161326) : Colors.white,
          ),
        );
        return MaterialApp(
          title: 'Vansh Studio',
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            textTheme: GoogleFonts.manropeTextTheme(baseTheme.textTheme),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: dark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          home: const PlayerScreen(),
        );
      },
    );
  }
}
