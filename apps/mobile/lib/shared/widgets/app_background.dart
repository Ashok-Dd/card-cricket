import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The backdrop every screen sits on: the deep navy→black gradient plus two
/// soft, off-screen-anchored radial glows for depth. Defined once so no
/// screen hand-rolls its own `DecoratedBox(gradient: ...)`.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Glow(color: AppColors.gold.withValues(alpha: 0.10), size: 280),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Glow(color: AppColors.neonBlue.withValues(alpha: 0.08), size: 320),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
