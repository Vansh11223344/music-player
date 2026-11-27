import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpectrumVisualizer3D extends StatefulWidget {
  final bool isPlaying;
  final double lowGain;
  final double midGain;
  final double highGain;

  const SpectrumVisualizer3D({
    super.key,
    required this.isPlaying,
    required this.lowGain,
    required this.midGain,
    required this.highGain,
  });

  @override
  State<SpectrumVisualizer3D> createState() => _SpectrumVisualizer3DState();
}

class _SpectrumVisualizer3DState extends State<SpectrumVisualizer3D>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 24;
  static const double _restingLevel = 0.045;

  late final AnimationController _animController;
  final List<double> _barHeights = List<double>.filled(
    _barCount,
    _restingLevel,
  );
  final List<double> _peakHeights = List<double>.filled(
    _barCount,
    _restingLevel,
  );
  final List<int> _peakHoldFrames = List<int>.filled(_barCount, 0);

  double _leftVu = 0;
  double _rightVu = 0;
  double _phase = 0;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);

    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  void _tick() {
    _phase += 0.016;

    if (!widget.isPlaying) {
      for (int i = 0; i < _barCount; i++) {
        _barHeights[i] = math.max(_restingLevel, _barHeights[i] * 0.88);
        _peakHeights[i] = math.max(_barHeights[i], _peakHeights[i] - 0.018);
        _peakHoldFrames[i] = 0;
      }
      _leftVu *= 0.84;
      _rightVu *= 0.84;

      final isSettled = _barHeights.every((height) => height <= 0.05);
      if (isSettled) {
        _leftVu = 0;
        _rightVu = 0;
        _animController.stop();
      }

      _frame++;
      setState(() {});
      return;
    }

    for (int i = 0; i < _barCount; i++) {
      final bandGain = i < 8
          ? widget.lowGain
          : i < 16
          ? widget.midGain
          : widget.highGain;
      final position = i / (_barCount - 1);
      final phaseOffset = i * 0.43;

      final wave = i < 8
          ? math.sin(_phase * 2.7 + phaseOffset).abs() * 0.62 +
                math.sin(_phase * 1.35 + phaseOffset * 0.55).abs() * 0.38
          : i < 16
          ? math.sin(_phase * 3.8 + phaseOffset).abs() * 0.58 +
                math.cos(_phase * 1.9 + phaseOffset * 0.7).abs() * 0.42
          : math.sin(_phase * 5.2 + phaseOffset).abs() * 0.55 +
                math.sin(_phase * 2.6 + phaseOffset * 1.2).abs() * 0.45;

      final envelope = 0.18 + (1 - (position - 0.5).abs() * 0.45) * wave;
      final target = (envelope * (bandGain.clamp(0.0, 3.5) / 1.65)).clamp(
        _restingLevel,
        0.96,
      );
      _barHeights[i] = _lerp(_barHeights[i], target, 0.22);

      if (_barHeights[i] >= _peakHeights[i] - 0.015) {
        _peakHeights[i] = _barHeights[i];
        _peakHoldFrames[i] = 12;
      } else if (_peakHoldFrames[i] > 0) {
        _peakHoldFrames[i]--;
      } else {
        _peakHeights[i] = math.max(_barHeights[i], _peakHeights[i] - 0.012);
      }
    }

    final avgLow = (_barHeights[0] + _barHeights[2] + _barHeights[4]) / 3;
    final avgMidHigh = (_barHeights[10] + _barHeights[18]) / 2;
    _leftVu = _lerp(_leftVu, avgLow * 0.65 + avgMidHigh * 0.35, 0.22);
    _rightVu = _lerp(_rightVu, avgLow * 0.55 + avgMidHigh * 0.45, 0.22);

    _frame++;
    setState(() {});
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void didUpdateWidget(covariant SpectrumVisualizer3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          height: compact ? 68 : 76,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF131622).withValues(alpha: 0.92),
                      const Color(0xFF10131C).withValues(alpha: 0.82),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.92),
                      const Color(0xFFF4F8FC).withValues(alpha: 0.88),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : accent).withValues(
                alpha: isDark ? 0.12 : 0.16,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.24)
                    : const Color(0xFF64748B).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.055 : 0.045),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              _buildVuMeter(
                label: 'L',
                level: _leftVu,
                isDark: isDark,
                accent: accent,
                compact: compact,
              ),
              SizedBox(width: compact ? 7 : 10),
              Expanded(
                child: CustomPaint(
                  painter: _SpectrumBarsPainter(
                    barHeights: _barHeights,
                    peakHeights: _peakHeights,
                    frame: _frame,
                    isPlaying: widget.isPlaying,
                    isDark: isDark,
                    accent: accent,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              SizedBox(width: compact ? 7 : 10),
              _buildVuMeter(
                label: 'R',
                level: _rightVu,
                isDark: isDark,
                accent: accent,
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVuMeter({
    required String label,
    required double level,
    required bool isDark,
    required Color accent,
    required bool compact,
  }) {
    final segments = compact ? 6 : 8;
    final litSegments = (level * segments).round();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.48)
                : const Color(0xFF64748B),
            fontSize: compact ? 8 : 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        SizedBox(height: compact ? 3 : 4),
        Column(
          children: List.generate(segments, (i) {
            final segmentIndex = segments - 1 - i;
            final isLit = segmentIndex < litSegments && widget.isPlaying;
            final intensity = 0.18 + (segmentIndex / segments) * 0.16;

            return Container(
              width: 10,
              height: compact ? 3 : 3.5,
              margin: EdgeInsets.symmetric(vertical: compact ? 0.5 : 0.65),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isLit
                    ? Color.lerp(accent, Colors.white, intensity)
                    : (isDark
                          ? accent.withValues(alpha: 0.12)
                          : const Color(0xFFCBD5E1).withValues(alpha: 0.55)),
                boxShadow: isLit
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SpectrumBarsPainter extends CustomPainter {
  final List<double> barHeights;
  final List<double> peakHeights;
  final int frame;
  final bool isPlaying;
  final bool isDark;
  final Color accent;

  _SpectrumBarsPainter({
    required this.barHeights,
    required this.peakHeights,
    required this.frame,
    required this.isPlaying,
    required this.isDark,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final count = barHeights.length;
    final gap = math.min(2.2, size.width / count * 0.28);
    final barWidth = (size.width - (count - 1) * gap) / count;
    final bounds = Offset.zero & size;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.72),
        radius: 1.25,
        colors: [
          accent.withValues(alpha: isPlaying ? 0.12 : 0.035),
          accent.withValues(alpha: 0),
        ],
      ).createShader(bounds);
    canvas.drawRect(bounds, glowPaint);

    final trackPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF334155)).withValues(
        alpha: isDark ? 0.045 : 0.055,
      );
    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, size.height),
          const Radius.circular(3),
        ),
        trackPaint,
      );
    }

    final topColor = Color.lerp(accent, Colors.white, isDark ? 0.24 : 0.12)!;
    final baseColor = Color.lerp(
      accent,
      isDark ? Colors.black : const Color(0xFF0F172A),
      isDark ? 0.18 : 0.08,
    )!;

    for (int i = 0; i < count; i++) {
      final height = (barHeights[i] * size.height).clamp(3.0, size.height);
      final x = i * (barWidth + gap);
      final y = size.height - height;
      final rect = Rect.fromLTWH(x, y, barWidth, height);
      final radius = Radius.circular(math.min(3.5, barWidth / 2));

      if (isPlaying && barHeights[i] > 0.55) {
        final barGlowPaint = Paint()
          ..color = accent.withValues(alpha: isDark ? 0.14 : 0.09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), barGlowPaint);
      }

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topColor,
            accent,
            baseColor.withValues(alpha: isDark ? 0.72 : 0.62),
          ],
        ).createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), barPaint);

      final peakY = size.height - peakHeights[i] * size.height;
      final peakPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: isPlaying ? (isDark ? 0.72 : 0.8) : 0.35,
        )
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x + 1, peakY),
        Offset(x + barWidth - 1, peakY),
        peakPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumBarsPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.isDark != isDark ||
      oldDelegate.accent != accent;
}
