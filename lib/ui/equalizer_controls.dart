import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../models/eq_preset.dart';
import '../services/app_preferences.dart';
import '../services/audio_player_service.dart';
import 'widgets/glass_card.dart';

class EqualizerControls extends StatefulWidget {
  final AudioPlayerService playerService;

  const EqualizerControls({super.key, required this.playerService});

  @override
  State<EqualizerControls> createState() => _EqualizerControlsState();
}

class _EqualizerControlsState extends State<EqualizerControls>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF00F5FF);

  late final AnimationController _presetController;
  Animation<double>? _lowAnimation;
  Animation<double>? _midAnimation;
  Animation<double>? _highAnimation;

  @override
  void initState() {
    super.initState();
    _presetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(_applyAnimationValues);
  }

  void _applyAnimationValues() {
    if (_lowAnimation == null ||
        _midAnimation == null ||
        _highAnimation == null) {
      return;
    }

    widget.playerService
      ..setLowGain(_lowAnimation!.value)
      ..setMidGain(_midAnimation!.value)
      ..setHighGain(_highAnimation!.value);
    AppPreferences.instance.persistEqSoon(widget.playerService);
  }

  void _glideToPreset(double low, double mid, double high) {
    _lowAnimation = Tween<double>(
      begin: widget.playerService.lowGain,
      end: low,
    ).animate(CurvedAnimation(parent: _presetController, curve: Curves.easeOutCubic));

    _midAnimation = Tween<double>(
      begin: widget.playerService.midGain,
      end: mid,
    ).animate(CurvedAnimation(parent: _presetController, curve: Curves.easeOutCubic));

    _highAnimation = Tween<double>(
      begin: widget.playerService.highGain,
      end: high,
    ).animate(CurvedAnimation(parent: _presetController, curve: Curves.easeOutCubic));

    _presetController.forward(from: 0);
  }

  @override
  void dispose() {
    _presetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = dark ? Colors.white : const Color(0xFF1E1B2E);
    final mutedText = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ListenableBuilder(
      listenable: widget.playerService,
      builder: (context, _) {
        final service = widget.playerService;

        return GlassCard(
          radius: 28,
          padding: const EdgeInsets.all(22),
          blurSigma: 24,
          opacity: dark ? 0.09 : 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make it yours',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.isEqActive
                              ? 'REAL-TIME 3-BAND HARMONICS'
                              : 'STUDIO DSP READY',
                          style: TextStyle(
                            color: mutedText,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glass Pill Reset Button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => _glideToPreset(1, 1, 1),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset'),
                          style: TextButton.styleFrom(
                            foregroundColor: _accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Glowing Frequency Response Wave Preview
              Container(
                height: 48,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: (dark ? Colors.black : Colors.white).withValues(
                    alpha: dark ? 0.22 : 0.65,
                  ),
                  border: Border.all(
                    color: (dark ? Colors.white : const Color(0xFFCBD5E1)).withValues(
                      alpha: dark ? 0.08 : 0.75,
                    ),
                  ),
                  boxShadow: !dark
                      ? [
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: CustomPaint(
                  painter: _FrequencyCurvePainter(
                    lowDb: service.lowDb,
                    midDb: service.midDb,
                    highDb: service.highDb,
                    dark: dark,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3-Band Equalizer Glass Fader Sliders
              _buildBandSlider(
                title: 'Low',
                subtitle: 'Deep Bass & Warmth',
                icon: Icons.graphic_eq_rounded,
                accent: const Color(0xFF00F5FF), // Cyan
                db: service.lowDb,
                onChanged: service.setLowDb,
                dark: dark,
              ),
              const SizedBox(height: 10),
              _buildBandSlider(
                title: 'Mid',
                subtitle: 'Vocals & Acoustic Zen',
                icon: Icons.multitrack_audio_rounded,
                accent: const Color(0xFFC084FC), // Lavender / Purple
                db: service.midDb,
                onChanged: service.setMidDb,
                dark: dark,
              ),
              const SizedBox(height: 10),
              _buildBandSlider(
                title: 'High',
                subtitle: 'Air, Sparkle & Detail',
                icon: Icons.surround_sound_rounded,
                accent: const Color(0xFFFF6584), // Rose Pink
                db: service.highDb,
                onChanged: service.setHighDb,
                dark: dark,
              ),
              const SizedBox(height: 18),

              // Presets Title
              Text(
                'HARMONIC PRESETS',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),

              // Glass Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: EqPreset.presets.map((preset) {
                    final isSelected =
                        (service.lowGain - preset.lowGain).abs() < 0.08 &&
                        (service.midGain - preset.midGain).abs() < 0.08 &&
                        (service.highGain - preset.highGain).abs() < 0.08;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _glideToPreset(
                              preset.lowGain,
                              preset.midGain,
                              preset.highGain,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: dark
                                            ? [
                                                _accent.withValues(alpha: 0.32),
                                                const Color(0xFFC084FC).withValues(alpha: 0.28),
                                              ]
                                            : [
                                                const Color(0xFF0284C7),
                                                const Color(0xFF9333EA),
                                              ],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : (dark ? Colors.white : Colors.white).withValues(
                                        alpha: dark ? 0.05 : 0.65,
                                      ),
                                border: Border.all(
                                    color: isSelected
                                        ? (dark ? _accent.withValues(alpha: 0.8) : Colors.transparent)
                                        : (dark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : const Color(0xFFCBD5E1)),
                                    width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: (dark ? _accent : const Color(0xFF0284C7))
                                              .withValues(alpha: dark ? 0.25 : 0.20),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                preset.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : mutedText,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBandSlider({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required double db,
    required ValueChanged<double> onChanged,
    required bool dark,
  }) {
    final formattedDb = db > 0
        ? '+${db.toStringAsFixed(1)} dB'
        : '${db.toStringAsFixed(1)} dB';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.04 : 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.08 : 0.20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF1E1B2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  formattedDb,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: accent.withValues(alpha: 0.18),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: db,
              min: -24,
              max: 12,
              onChanged: (val) {
                onChanged(val);
                AppPreferences.instance.persistEqSoon(widget.playerService);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyCurvePainter extends CustomPainter {
  final double lowDb;
  final double midDb;
  final double highDb;
  final bool dark;

  _FrequencyCurvePainter({
    required this.lowDb,
    required this.midDb,
    required this.highDb,
    this.dark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Normalizing -24 to +12 dB into y offset
    double dbToY(double db) {
      final normalized = (db + 24) / 36; // 0.0 to 1.0
      return h - (normalized * h * 0.85 + h * 0.075);
    }

    final p0 = Offset(0, dbToY(lowDb));
    final p1 = Offset(w * 0.25, dbToY(lowDb));
    final p2 = Offset(w * 0.50, dbToY(midDb));
    final p3 = Offset(w * 0.75, dbToY(highDb));
    final p4 = Offset(w, dbToY(highDb));

    final path = Path()..moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p1.dx, p2.dy, p2.dx, p2.dy);
    path.cubicTo(w * 0.65, p2.dy, p3.dx, p3.dy, p4.dx, p4.dy);

    // Subtle center zero-dB reference dashed line
    final refPaint = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF0F172A)).withValues(
        alpha: dark ? 0.12 : 0.10,
      )
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), refPaint);

    // Glowing frequency gradient stroke (electric neon in dark, rich vibrant jewel tones in light)
    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: dark
            ? const [Color(0xFF00F5FF), Color(0xFFC084FC), Color(0xFFFF6584)]
            : const [Color(0xFF0284C7), Color(0xFF9333EA), Color(0xFFE11D48)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _FrequencyCurvePainter oldDelegate) {
    return oldDelegate.lowDb != lowDb ||
        oldDelegate.midDb != midDb ||
        oldDelegate.highDb != highDb ||
        oldDelegate.dark != dark;
  }
}
