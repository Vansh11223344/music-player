# Vansh Studio Music Player

A Flutter music player for bundled and user-selected audio. It combines
playback, track navigation, seeking, and a three-band equalizer with an
animated cover-art treatment and a modern, compact listening interface.

## Features

- Plays three bundled WAV demo tracks and audio files selected through the
  device's file picker.
- Play/pause, seek, previous/next, and repeat all/one/off.
- Displays the current track, elapsed time, and total duration.
- Provides Low, Mid, and High EQ sliders, presets, and a Reset action.
- Reads embedded artist and cover metadata from selected audio files when
  available; extracts a dominant cover color and animates the app background.
- Includes shuffle, a persistent light/dark theme, and saved EQ settings.
- Adds a compact mini-player with a Hero transition, plus a playlist bottom
  sheet with the active track highlighted.
- Starts paused on first launch and restores the selected track, playback
  position, and play/pause state on later launches. Imported audio files and
  the playlist are kept in app-local storage.
- Adapts the layout for compact phones, landscape screens, and wider displays.
- Uses animated, track-colored vinyl artwork, live playback indicators, and a
  spectrum display; repeat mode is a compact All/One/Off control.

The central playback button pauses while a track is playing and resumes while
paused. If playback has been stopped or the track has ended, pressing Play
restarts the selected track. A separate Stop button is intentionally omitted:
Play/Pause is the everyday playback toggle, while restarting is available
through that same button.

## Architecture

```text
lib/
├── main.dart
├── models/
│   ├── audio_track.dart
│   └── eq_preset.dart
├── services/
│   ├── audio_player_service.dart
│   ├── app_preferences.dart
│   └── playlist_manager.dart
└── ui/
    ├── player_screen.dart
    ├── equalizer_controls.dart
    └── widgets/
        ├── album_artwork.dart
        ├── glass_card.dart
        └── spectrum_visualizer_3d.dart
assets/audio/
assets/images/
└── app_icon.png
scripts/generate_audio.py
test/
├── widget_test.dart
├── player_logic_test.dart
├── preferences_test.dart
└── picker_test.dart
```

- **`AudioTrack` and `EqPreset`** hold track metadata and named EQ settings.
- Selected-file metadata is read off the UI isolate; local cover images are
  carried with their track when embedded art is available.
- **`AudioPlayerService`** owns the SoLoud engine, active track and voice,
  playback state, seek position timer, and EQ gain values. It notifies the UI
  when these values change.
- **`PlaylistManager`** owns the queue, bundled demo tracks, file picking,
  previous/next navigation, shuffle history, and repeat behavior.
- **`AppPreferences`** stores the selected theme, EQ gains, and shuffle state
  using `shared_preferences`.
- **`PlayerScreen`** connects the services to playback, progress, and queue UI.
  **`EqualizerControls`** connects EQ sliders and presets to the audio service.
- **`AlbumArtwork`** displays embedded cover art when present, extracts its
  dominant color with `palette_generator`, and falls back to generated
  track-colored vinyl artwork when metadata is unavailable.
- **`SpectrumVisualizer3D`** paints animated bars that respond visually to
  playback state and EQ settings.

## Visual assets

The theme-matched app icon (`assets/images/app_icon.png`) was generated with
Antigravity. The player uses embedded cover art from selected audio files when
available; otherwise, its animated vinyl artwork and spectrum visualizer are
rendered by the app.

## Packages

| Package | Use |
| --- | --- |
| Flutter SDK | Application UI, layout, animation, and widget testing. |
| `flutter_soloud` (`^4.1.7`) | Audio playback and the real-time parametric EQ filter. |
| `file_picker` (`^13.4.1`) | Lets users select audio files from device storage. |
| `audio_metadata_reader` | Reads local audio tags and embedded cover images. |
| `palette_generator` | Finds a dominant color from track artwork. |
| `google_fonts` | Applies the Manrope typeface consistently. |
| `shared_preferences` | Persists EQ values, shuffle, and theme selection. |
| `flutter_test` | Widget and logic tests. |
| `flutter_lints` | Dart/Flutter static-analysis rules. |

The `pubspec.yaml` also declares `just_audio` and `audio_session`, but neither
is currently imported by the app; SoLoud is the active playback engine and
equalizer. Background playback and lock-screen media controls are not
implemented.

## Equalizer implementation

The service activates SoLoud's parametric EQ filter, configures three bands,
sets the filter window size and wet mix, and applies each band's gain. Fader
values are represented in decibels and converted to linear gain using:

```text
gain = 10^(dB / 20)
dB = 20 * log10(gain)
```

The sliders expose a range of `-24 dB` to `+12 dB`. `0 dB` maps to unity gain
(`1.0x`), which is the flat setting. Changing a slider updates the
corresponding SoLoud band gain while playback is active. Presets animate the
gains toward their target values; Reset returns all three bands to `0 dB`.
The latest gains are saved after the user stops adjusting the sliders and are
restored when the app next starts.

The Low/Mid/High frequency captions in the UI communicate the intended bands.
The current code sets the EQ's band count and gains; it does not configure
custom per-band center frequencies or bandwidths.

## Development approach, tools, and challenges

- **Copilot SDK in VS Code (AI coding assistant):** used to inspect and extend
  the Flutter code, preserve the existing playback/EQ architecture,
  implement the responsive visual redesign, add metadata/palette extraction
  and preferences, and add widget coverage for control behavior and screen
  sizes.
- **Flutter and Dart SDKs:** used to format Dart, run tests and static analysis,
  and build the Android release APK.
- **Package APIs and package managers:** used to add palette extraction,
  Manrope typography, shared preference storage, and local audio metadata
  support.
- **PowerShell on Windows:** used to inspect project files and run the Flutter
  and Gradle commands.
- **Python:** `scripts/generate_audio.py` is provided to generate the bundled
  demo WAV tracks.

Two practical issues encountered during development were the Gradle daemon
running out of native memory with an 8 GiB heap configured on a 7 GiB machine,
and fixed-width UI elements overflowing narrow phone screens. The Gradle heap
and worker count were reduced in `android/gradle.properties`, and responsive
layouts are covered by widget tests at phone, landscape, and tablet sizes.

## Run and validate

From the project directory:

```powershell
flutter pub get
flutter run
```

For Android, connect a device or start an emulator first. To run checks:

```powershell
flutter test
flutter analyze
```

Build a universal release APK for broad Android device compatibility:

```powershell
flutter build apk --release
```

For a smaller APK for 64-bit ARM phones, build only the `arm64-v8a` target:

```powershell
flutter build apk --release --target-platform android-arm64
```

Both commands write to
`build/app/outputs/flutter-apk/app-release.apk`; copy or rename the first APK
before running the second if you want to keep both. The arm64-only APK can be
installed only on compatible 64-bit ARM devices.
