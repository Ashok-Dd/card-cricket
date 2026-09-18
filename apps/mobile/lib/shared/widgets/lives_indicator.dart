import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Small heart row showing the anti-stall lives a player has left — spent
/// only by letting the 30s turn timer expire (docs/GAME_RULES.md's
/// "post-timeout statistic selection" edge case), never by losing a round
/// normally.
class LivesIndicator extends StatelessWidget {
  const LivesIndicator({required this.livesRemaining, this.totalLives = 3, this.size = 12, super.key});

  final int livesRemaining;
  final int totalLives;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < totalLives; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: Icon(
              i < livesRemaining ? Icons.favorite : Icons.favorite_border,
              size: size,
              color: i < livesRemaining ? AppColors.danger : AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}
