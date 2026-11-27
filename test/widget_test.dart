import 'dart:ui' show Size;

import 'package:flutter/material.dart'
    show DraggableScrollableSheet, Slider, ValueKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music_eq/main.dart';
import 'package:flutter_music_eq/services/app_preferences.dart';
import 'package:flutter_music_eq/ui/widgets/album_artwork.dart';

void main() {
  testWidgets('MusicEqApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicEqApp());

    // Verify the player, equalizer, and playback controls are present.
    expect(find.text('VANSH STUDIO'), findsOneWidget);
    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(4));
    expect(find.byTooltip('Stop'), findsNothing);
  });

  testWidgets('repeat control cycles through all, one, and off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicEqApp());

    expect(find.text('ALL'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('repeat-mode-control')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('ONE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repeat-mode-control')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('OFF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repeat-mode-control')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('ALL'), findsOneWidget);
  });

  testWidgets('mini player opens the playlist bottom sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicEqApp());

    await tester.tap(find.byTooltip('Open playlist'));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('YOUR PLAYLIST'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini player expands through its Hero transition', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicEqApp());

    await tester.tap(find.byKey(const ValueKey('mini-player-expand')));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(AlbumArtwork), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme toggle switches between dark and light', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicEqApp());

    expect(find.byTooltip('Switch to light theme'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pump();
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
    await AppPreferences.instance.setDarkMode(true);
    await tester.pump();
  });

  testWidgets('MusicEqApp fits phone, landscape, and tablet layouts', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const screenSizes = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(844, 390),
      Size(600, 960),
      Size(900, 1200),
    ];

    tester.view.physicalSize = screenSizes.first;
    await tester.pumpWidget(const MusicEqApp());

    for (final screenSize in screenSizes) {
      tester.view.physicalSize = screenSize;
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Screen size: $screenSize',
      );
      expect(find.text('Reset'), findsOneWidget);
    }
  });
}
