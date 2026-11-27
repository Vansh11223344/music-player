import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class AlbumArtwork extends StatefulWidget {
  final String trackTitle;
  final bool isPlaying;
  final ValueChanged<Color>? onDominantColor;
  final Uint8List? artworkBytes;

  const AlbumArtwork({
    super.key,
    required this.trackTitle,
    required this.isPlaying,
    this.onDominantColor,
    this.artworkBytes,
  });

  @override
  State<AlbumArtwork> createState() => _AlbumArtworkState();
}

class _AlbumArtworkState extends State<AlbumArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  // Calming, friendly, relaxing pastel aurora palettes
  static const _palettes = [
    [Color(0xFF00F5FF), Color(0xFF6366F1), Color(0xFFA855F7)], // Cyan -> Indigo -> Violet
    [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)], // Sky -> Lavender -> Soft Purple
    [Color(0xFF2DD4BF), Color(0xFF3B82F6), Color(0xFF9333EA)], // Mint Teal -> Ocean -> Deep Violet
    [Color(0xFFF472B6), Color(0xFFA855F7), Color(0xFF06B6D4)], // Warm Rose -> Orchid -> Cyber Cyan
  ];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
    }
    _extractDominantColor(widget.trackTitle);
  }

  @override
  void didUpdateWidget(covariant AlbumArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _pulseController.stop();
      }
    }
    if (widget.trackTitle != oldWidget.trackTitle ||
        !identical(widget.artworkBytes, oldWidget.artworkBytes)) {
      _extractDominantColor(widget.trackTitle);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        _palettes[widget.trackTitle.hashCode.abs() % _palettes.length];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 340.0);
        final artworkBytes = widget.artworkBytes;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulseValue = widget.isPlaying ? _pulseController.value : 0.0;
              final auraSpread = 20.0 + pulseValue * 16.0;

              return Container(
                width: size,
                height: size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  // Deep frosted glass in dark, crystalline luminous pearlescent frost in light
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            palette[0].withValues(alpha: 0.18),
                            palette[1].withValues(alpha: 0.12),
                            palette[2].withValues(alpha: 0.22),
                          ]
                        : [
                            palette[0].withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.90),
                            palette[2].withValues(alpha: 0.12),
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.24 : 0.85),
                    width: isDark ? 1.5 : 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.first.withValues(
                        alpha: (isDark ? 0.30 : 0.18) + pulseValue * 0.10,
                      ),
                      blurRadius: auraSpread + 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: palette.last.withValues(
                        alpha: (isDark ? 0.25 : 0.14) + pulseValue * 0.08,
                      ),
                      blurRadius: auraSpread + 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Backdrop blur inside the container
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: const SizedBox.expand(),
                    ),

                    // Custom user artwork if available
                    if (artworkBytes != null)
                      Image.memory(
                        artworkBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.expand(),
                      ),
                    if (artworkBytes != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.50),
                            ],
                          ),
                        ),
                      ),

                    // Calming Ambient Light Orbs
                    Positioned(
                      top: -size * 0.15,
                      left: -size * 0.15,
                      child: Container(
                        width: size * 0.70,
                        height: size * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.first.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -size * 0.15,
                      right: -size * 0.15,
                      child: Container(
                        width: size * 0.70,
                        height: size * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.last.withValues(alpha: 0.20),
                        ),
                      ),
                    ),

                    // The Floating Glass Vinyl / Aura Turntable Disc
                    Center(
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _rotationController.value * math.pi * 2,
                            child: _buildGlassVinyl(size, palette, isDark),
                          );
                        },
                      ),
                    ),

                    // Floating Calming Mode Badge (Bottom-Right)
                    Positioned(
                      bottom: 18,
                      right: 18,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: isDark ? 0.35 : 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (isDark ? Colors.white : const Color(0xFFCBD5E1))
                                    .withValues(alpha: isDark ? 0.22 : 0.90),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.black : const Color(0xFF64748B))
                                      .withValues(alpha: isDark ? 0.20 : 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.isPlaying ? 'HARMONY' : 'RELAX',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _extractDominantColor(String title) async {
    final palette = _palettes[title.hashCode.abs() % _palettes.length];
    final artworkBytes = widget.artworkBytes;
    if (artworkBytes != null) {
      try {
        final generator = await PaletteGenerator.fromImageProvider(
          MemoryImage(artworkBytes),
          size: const Size(64, 64),
          maximumColorCount: 12,
        );
        if (mounted && widget.trackTitle == title) {
          widget.onDominantColor?.call(
            generator.dominantColor?.color ?? palette.first,
          );
        }
        return;
      } catch (error) {
        debugPrint('Could not extract embedded cover art palette: $error');
      }
    }

    if (mounted && widget.trackTitle == title) {
      widget.onDominantColor?.call(palette.first);
    }
  }

  Widget _buildGlassVinyl(double size, List<Color> palette, bool isDark) {
    final discSize = size * 0.70;

    return Container(
      width: discSize,
      height: discSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Frosted Glass Vinyl Base with subtle holographic sheen
        gradient: RadialGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B2E).withValues(alpha: 0.92),
                  const Color(0xFF12101E).withValues(alpha: 0.95),
                  const Color(0xFF090812).withValues(alpha: 0.98),
                ]
              : [
                  const Color(0xFF2D2A3E).withValues(alpha: 0.92),
                  const Color(0xFF1F1D2C).withValues(alpha: 0.95),
                  const Color(0xFF14121E).withValues(alpha: 0.98),
                ],
          stops: const [0.2, 0.7, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.28 : 0.45),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.first.withValues(alpha: isDark ? 0.28 : 0.20),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Holographic Etched Microgrooves
          for (var i = 0; i < 6; i++)
            Container(
              width: discSize * (0.44 + i * 0.095),
              height: discSize * (0.44 + i * 0.095),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07 + (i % 2) * 0.04),
                  width: 1.2,
                ),
              ),
            ),

          // Glowing Center Label with relaxing gradient
          Container(
            width: discSize * 0.36,
            height: discSize * 0.36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.first, palette[1], palette.last],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.first.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: discSize * 0.09,
                height: discSize * 0.09,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF090812)
                      : const Color(0xFF14121E),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
