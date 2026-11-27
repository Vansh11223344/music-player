import 'dart:math' as math;
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_manager.dart';
import 'equalizer_controls.dart';
import 'widgets/album_artwork.dart';
import 'widgets/glass_card.dart';
import 'widgets/spectrum_visualizer_3d.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF00F5FF);

  Color _dominantColor = _accent;
  final AudioPlayerService _playerService = AudioPlayerService();
  final PlaylistManager _playlistManager = PlaylistManager();
  late final AnimationController _playPauseController;
  late final AnimationController _auroraController;
  late final ValueNotifier<bool> _playbackState;

  bool _isScrubbing = false;
  double _scrubValue = 0;

  @override
  void initState() {
    super.initState();
    _playbackState = ValueNotifier(_playerService.isPlaying);
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _playerService.isPlaying ? 1 : 0,
    );

    // Ambient breathing background (animates during playback)
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    _playerService.addListener(_syncPlayPauseAnimation);
    _playlistManager.restoreShuffle(AppPreferences.instance.shuffleEnabled);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playerService.initEngine();
      if (_playlistManager.currentTrack != null &&
          !_playerService.isPlaying &&
          !_playerService.isPaused) {
        await _playerService.playTrack(_playlistManager.currentTrack!);
      }
    });
  }

  bool get _isDark => AppPreferences.instance.isDarkMode;
  Color get _background =>
      _isDark ? const Color(0xFF0C0A14) : const Color(0xFFF1F5F9);
  Color get _surface =>
      _isDark ? const Color(0xFF161326) : const Color(0xFFFFFFFF);
  Color get _muted =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _primaryText => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _activeAccent =>
      _isDark ? const Color(0xFF00F5FF) : const Color(0xFF0284C7);

  void _syncPlayPauseAnimation() {
    _playbackState.value = _playerService.isPlaying;
    if (_playerService.isPlaying) {
      _playPauseController.forward();
      if (!_auroraController.isAnimating) {
        _auroraController.repeat(reverse: true);
      }
    } else {
      _playPauseController.reverse();
      _auroraController.stop();
    }
  }

  void _updateDominantColor(Color color) {
    if (mounted && color != _dominantColor) {
      setState(() => _dominantColor = color);
    }
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    _auroraController.dispose();
    _playbackState.dispose();
    _playerService.removeListener(_syncPlayPauseAnimation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final compact = MediaQuery.sizeOf(context).width < 400;

        return Scaffold(
          backgroundColor: _background,
          extendBodyBehindAppBar: true,
          appBar: _buildGlassAppBar(compact),
          body: Stack(
            children: [
              // Dynamic Relaxing Aurora Ambient Mesh Background
              _buildDynamicAuroraBackground(),

              // Foreground Scrollable Views
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                12,
                                110,
                              ),
                              child: Column(
                                children: [
                                  _buildHeroDeck(),
                                  const SizedBox(height: 20),
                                  _buildPlaylistCard(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                24,
                                110,
                              ),
                              child: EqualizerControls(
                                playerService: _playerService,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
                      child: Column(
                        children: [
                          _buildHeroDeck(),
                          const SizedBox(height: 18),
                          EqualizerControls(playerService: _playerService),
                          const SizedBox(height: 18),
                          _buildPlaylistCard(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildMiniPlayer(),
        );
      },
    );
  }

  PreferredSizeWidget _buildGlassAppBar(bool compact) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(66),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AppBar(
            backgroundColor: _background.withValues(
              alpha: _isDark ? 0.43 : 0.53,
            ),
            surfaceTintColor: Colors.transparent,
            shape: Border(
              bottom: BorderSide(
                color: (_isDark ? Colors.white : _activeAccent).withValues(
                  alpha: _isDark ? 0.10 : 0.14,
                ),
                width: 0.8,
              ),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isDark
                      ? [
                          Colors.white.withValues(alpha: 0.045),
                          _activeAccent.withValues(alpha: 0.018),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.38),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                ),
              ),
            ),
            titleSpacing: compact ? 12 : 20,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: compact ? 34 : 38,
                    height: compact ? 34 : 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VANSH STUDIO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (!compact)
                        Text(
                          'ZEN HARMONY & AUDIO',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 8.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _isDark
                    ? 'Switch to light theme'
                    : 'Switch to dark theme',
                onPressed: () => AppPreferences.instance.setDarkMode(!_isDark),
                icon: Icon(
                  _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: _activeAccent,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Add music',
                onPressed: _handlePickAudioFiles,
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: _activeAccent,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicAuroraBackground() {
    return AnimatedBuilder(
      animation: _auroraController,
      builder: (context, _) {
        final t = _auroraController.value;
        final isDark = _isDark;

        return Positioned.fill(
          child: Stack(
            children: [
              // Base Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _background,
                      Color.alphaBlend(
                        _dominantColor.withValues(alpha: isDark ? 0.16 : 0.08),
                        _background,
                      ),
                      _background,
                    ],
                  ),
                ),
              ),

              // Floating Relaxing Neon Cyan Aurora Orb
              Positioned(
                top: -80 + math.sin(t * math.pi) * 40,
                left: -60 + math.cos(t * math.pi) * 30,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFF00F5FF,
                        ).withValues(alpha: isDark ? 0.22 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Relaxing Royal Violet & Magenta Orb
              Positioned(
                bottom: 80 + math.cos(t * math.pi) * 50,
                right: -80 + math.sin(t * math.pi) * 40,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFFA855F7,
                        ).withValues(alpha: isDark ? 0.24 : 0.14),
                        const Color(
                          0xFFEC4899,
                        ).withValues(alpha: isDark ? 0.12 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePickAudioFiles() async {
    final result = await _playlistManager.pickAudioFiles();
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: ${result.trackTitle ?? "Audio"}'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: const Color(0xFF8F3535),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildHeroDeck({bool heroArtwork = false}) {
    return ListenableBuilder(
      listenable: Listenable.merge([_playerService, _playlistManager]),
      builder: (context, _) {
        final track =
            _playlistManager.currentTrack ?? _playerService.currentTrack;
        final currentPosition = _playerService.currentPosition;
        final totalDuration = _playerService.totalDuration;
        final maxSeconds = totalDuration.inMilliseconds > 0
            ? totalDuration.inMilliseconds / 1000
            : 1.0;
        final currentSeconds = _isScrubbing
            ? _scrubValue
            : (currentPosition.inMilliseconds / 1000).clamp(0.0, maxSeconds);

        return GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          blurSigma: 26,
          opacity: _isDark ? 0.08 : 0.85,
          tintColor: _dominantColor,
          border: Border.all(
            color: _dominantColor.withValues(alpha: _isDark ? 0.22 : 0.26),
            width: 1.1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Now Playing Status Pill
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _playerService.isPlaying ? _activeAccent : _muted,
                      shape: BoxShape.circle,
                      boxShadow: _playerService.isPlaying
                          ? [
                              BoxShadow(
                                color: _activeAccent.withValues(alpha: 0.75),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _playerService.isPlaying ? 'NOW PLAYING' : 'YOUR PLAYER',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  _buildRepeatControl(),
                ],
              ),
              const SizedBox(height: 18),

              // Animated Hero Artwork Deck
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(
                      Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ),
                    ),
                    child: child,
                  ),
                ),
                child: Hero(
                  tag: heroArtwork ? 'mini-player-art' : 'track-artwork',
                  child: AlbumArtwork(
                    key: ValueKey(track?.id ?? 'empty-artwork'),
                    trackTitle: track?.title ?? 'Vansh Studio',
                    isPlaying: _playerService.isPlaying,
                    artworkBytes: track?.artworkBytes,
                    onDominantColor: _updateDominantColor,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Track Info in Relaxing Typography
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(
                      Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ),
                    ),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(track?.id ?? 'empty-track'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'Choose something to play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artist ?? 'Your music library',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Spectrum Visualizer inside Frosted Glass
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SpectrumVisualizer3D(
                  isPlaying: _playerService.isPlaying,
                  lowGain: _playerService.lowGain,
                  midGain: _playerService.midGain,
                  highGain: _playerService.highGain,
                ),
              ),
              const SizedBox(height: 6),

              // Progress Scrubber Slider
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: _activeAccent,
                  inactiveTrackColor: _primaryText.withValues(alpha: 0.12),
                  thumbColor: _isDark ? Colors.white : _activeAccent,
                  overlayColor: _activeAccent.withValues(
                    alpha: _isScrubbing ? 0.30 : 0.15,
                  ),
                  trackHeight: 3.5,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: _isScrubbing ? 9 : 6,
                    elevation: _isScrubbing ? 8 : 2,
                  ),
                ),
                child: Slider(
                  value: currentSeconds.clamp(0.0, maxSeconds),
                  min: 0,
                  max: maxSeconds,
                  onChangeStart: (value) {
                    setState(() {
                      _isScrubbing = true;
                      _scrubValue = value;
                    });
                  },
                  onChanged: (value) {
                    setState(() => _scrubValue = value);
                  },
                  onChangeEnd: (value) {
                    _isScrubbing = false;
                    _playerService.seek(
                      Duration(milliseconds: (value * 1000).round()),
                    );
                  },
                ),
              ),

              // Elapsed & Total Time Labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(
                        _isScrubbing
                            ? Duration(
                                milliseconds: (_scrubValue * 1000).round(),
                              )
                            : currentPosition,
                      ),
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _formatDuration(totalDuration),
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tactile Neumorphic-Glass Transport Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGlassCircleButton(
                    icon: _playlistManager.isShuffleEnabled
                        ? Icons.shuffle_on_rounded
                        : Icons.shuffle_rounded,
                    tooltip: 'Shuffle',
                    color: _playlistManager.isShuffleEnabled
                        ? _activeAccent
                        : _muted,
                    onPressed: _playlistManager.toggleShuffle,
                  ),
                  _buildGlassCircleButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous',
                    color: _primaryText,
                    onPressed: _playlistManager.previousTrack,
                  ),
                  // Glowing Center Play/Pause Glass Orb
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00F5FF), Color(0xFFA855F7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00F5FF,
                          ).withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 32,
                      tooltip: _playerService.isPlaying ? 'Pause' : 'Play',
                      onPressed: () {
                        if (_playlistManager.currentTrack == null &&
                            _playlistManager.tracks.isNotEmpty) {
                          _playlistManager.playTrackAtIndex(0);
                        } else {
                          _playerService.togglePlayPause();
                        }
                      },
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseController,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _buildGlassCircleButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next',
                    color: _primaryText,
                    onPressed: _playlistManager.nextTrack,
                  ),
                  _buildGlassCircleButton(
                    icon: Icons.queue_music_rounded,
                    tooltip: 'Playlist',
                    color: _muted,
                    onPressed: _openPlaylistSheet,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (_isDark ? Colors.white : Colors.black).withValues(
          alpha: _isDark ? 0.06 : 0.04,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: _isDark ? 0.12 : 0.35),
        ),
      ),
      child: IconButton(
        iconSize: 22,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }

  Widget _buildRepeatControl() {
    final mode = _playlistManager.loopMode;
    String label;
    IconData icon;
    switch (mode) {
      case LoopMode.all:
        label = 'ALL';
        icon = Icons.repeat_rounded;
        break;
      case LoopMode.one:
        label = 'ONE';
        icon = Icons.repeat_one_rounded;
        break;
      case LoopMode.none:
        label = 'OFF';
        icon = Icons.repeat_rounded;
        break;
    }

    final active = mode != LoopMode.none;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: active
                ? _activeAccent.withValues(alpha: _isDark ? 0.15 : 0.12)
                : (_isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.05,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? _activeAccent.withValues(alpha: _isDark ? 0.45 : 0.60)
                  : Colors.white.withValues(alpha: _isDark ? 0.10 : 0.30),
            ),
          ),
          child: InkWell(
            key: const ValueKey('repeat-mode-control'),
            borderRadius: BorderRadius.circular(16),
            onTap: _playlistManager.toggleLoopMode,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: active ? _activeAccent : _muted),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? _activeAccent : _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildMiniPlayer() {
    return ListenableBuilder(
      listenable: Listenable.merge([_playerService, _playlistManager]),
      builder: (context, _) {
        final track =
            _playlistManager.currentTrack ?? _playerService.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              blurSigma: 24,
              opacity: _isDark ? 0.14 : 0.88,
              tintColor: _dominantColor,
              border: Border.all(
                color: _dominantColor.withValues(alpha: _isDark ? 0.20 : 0.23),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('mini-player-expand'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openExpandedPlayer,
                      child: Row(
                        children: [
                          Hero(
                            tag: 'mini-player-art',
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF00F5FF),
                                    Color(0xFFA855F7),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 28,
                    onPressed: _playerService.togglePlayPause,
                    icon: Icon(
                      _playerService.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: _activeAccent,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open playlist',
                    onPressed: _openPlaylistSheet,
                    icon: Icon(Icons.queue_music_rounded, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExpandedPlayer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: _background.withValues(alpha: _isDark ? 0.78 : 0.88),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    _buildHeroDeck(heroArtwork: true),
                    const SizedBox(height: 18),
                    EqualizerControls(playerService: _playerService),
                    const SizedBox(height: 18),
                    _buildPlaylistCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaylistSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: _background.withValues(alpha: _isDark ? 0.78 : 0.88),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                child: _buildPlaylistCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistCard() {
    return ListenableBuilder(
      listenable: _playlistManager,
      builder: (context, _) {
        final tracks = _playlistManager.tracks;
        final currentIndex = _playlistManager.currentIndex;

        return GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          blurSigma: 24,
          opacity: _isDark ? 0.08 : 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Up next',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'YOUR PLAYLIST',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (_isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tracks.length} TRACKS',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add music',
                    onPressed: _handlePickAudioFiles,
                    icon: Icon(Icons.add_rounded, color: _activeAccent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Add music to start your playlist',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isCurrent = index == currentIndex;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? _activeAccent.withValues(
                                alpha: _isDark ? 0.12 : 0.10,
                              )
                            : (_isDark ? Colors.white : Colors.white)
                                  .withValues(alpha: _isDark ? 0.03 : 0.60),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCurrent
                              ? _activeAccent.withValues(
                                  alpha: _isDark ? 0.40 : 0.55,
                                )
                              : (_isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? _activeAccent.withValues(alpha: 0.20)
                                  : (_isDark ? Colors.white : Colors.black)
                                        .withValues(
                                          alpha: _isDark ? 0.06 : 0.04,
                                        ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCurrent
                                  ? Icons.graphic_eq_rounded
                                  : Icons.music_note_rounded,
                              color: isCurrent ? _activeAccent : _muted,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? _activeAccent : _primaryText,
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!track.isAsset)
                                IconButton(
                                  tooltip: 'Remove track',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _playlistManager.removeTrack(index),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: _muted,
                                  ),
                                ),
                              ValueListenableBuilder<bool>(
                                valueListenable: _playbackState,
                                builder: (context, isPlaying, _) {
                                  return IconButton(
                                    tooltip: isCurrent && isPlaying
                                        ? 'Pause'
                                        : 'Play',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      if (isCurrent) {
                                        _playerService.togglePlayPause();
                                      } else {
                                        _playlistManager.playTrackAtIndex(
                                          index,
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      isCurrent && isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isCurrent
                                          ? _activeAccent
                                          : _muted,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () => _playlistManager.playTrackAtIndex(index),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
