import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A countdown ring around a player's avatar for the active turn — green
/// above 20s, orange 10-20s, red under 10s. Purely a display of the real
/// deadline: the server enforces the actual 30s timeout and auto-forfeit
/// on its own clock regardless of what this shows (game-engine.service.ts
/// TURN_TIMEOUT_MS) — a mismatch here would only make the UI lie about
/// when that happens, not change the real outcome.
class TurnTimerRing extends StatelessWidget {
  const TurnTimerRing({
    required this.child,
    required this.isActive,
    required this.secondsRemaining,
    this.totalSeconds = 30,
    this.size = 48,
    super.key,
  });

  final Widget child;
  final bool isActive;
  final int secondsRemaining;
  final int totalSeconds;
  final double size;

  Color get _ringColor {
    final fraction = secondsRemaining / totalSeconds;
    if (fraction > 2 / 3) return AppColors.electricGreen;
    if (fraction > 1 / 3) return Colors.orange;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: (secondsRemaining / totalSeconds).clamp(0, 1),
                strokeWidth: 3,
                color: _ringColor,
                backgroundColor: _ringColor.withValues(alpha: 0.15),
              ),
            ),
          Padding(padding: EdgeInsets.all(isActive ? 5 : 0), child: child),
        ],
      ),
    );
  }
}
