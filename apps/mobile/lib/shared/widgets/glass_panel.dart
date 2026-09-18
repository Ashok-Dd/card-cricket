import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The one "surface" treatment used everywhere a card/panel/row needs to sit
/// above the background gradient — a faint gradient fill, a hairline
/// highlight border, and a soft shadow. Replaces bare `Container`s and
/// `ListTile`s across the app so every panel reads consistently.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.borderColor,
    this.glowColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            AppColors.navySurface.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: borderColor ?? AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? Colors.black).withValues(alpha: glowColor != null ? 0.25 : 0.35),
            blurRadius: glowColor != null ? 24 : 16,
            spreadRadius: glowColor != null ? 1 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
