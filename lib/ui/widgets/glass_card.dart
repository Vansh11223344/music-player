import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium, ultra-smooth Glassmorphic container with frosted blur,
/// subtle dual-layer hairline specular border, and ambient floating shadow.
/// Beautifully calibrated for both obsidian dark mode and crystalline light mode.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final Color? tintColor;
  final double opacity;
  final Border? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
    this.blurSigma = 24.0,
    this.tintColor,
    this.opacity = 0.08,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTint = tintColor ?? Colors.white;
    final lightTint = Color.lerp(Colors.white, baseTint, 0.12)!;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // Multi-stop glass gradient: obsidian frost in dark, luminous crystal in light
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      baseTint.withValues(alpha: opacity * 1.5),
                      baseTint.withValues(alpha: opacity * 0.6),
                    ]
                  : [
                      lightTint.withValues(alpha: 0.82),
                      Color.lerp(
                        Colors.white,
                        baseTint,
                        0.035,
                      )!.withValues(alpha: 0.58),
                    ],
            ),
            border:
                border ??
                Border.all(
                  color: (isDark ? Colors.white : Colors.white).withValues(
                    alpha: isDark ? 0.16 : 0.85,
                  ),
                  width: isDark ? 1.2 : 1.5,
                ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.32)
                    : const Color(0xFF64748B).withValues(alpha: 0.09),
                blurRadius: isDark ? 28 : 24,
                offset: const Offset(0, 10),
              ),
              if (tintColor != null)
                BoxShadow(
                  color: baseTint.withValues(alpha: isDark ? 0.10 : 0.07),
                  blurRadius: 28,
                  spreadRadius: -5,
                  offset: const Offset(0, 5),
                ),
              if (!isDark)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.60),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}
