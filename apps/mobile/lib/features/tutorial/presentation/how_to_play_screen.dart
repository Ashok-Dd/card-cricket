import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';

const _steps = [
  (Icons.meeting_room_outlined, 'Join a Room', 'Create a room or join one with a code. 2-6 players per match.'),
  (Icons.style_outlined, 'Get Your Cards', 'The server shuffles and deals cricket player cards equally to everyone.'),
  (Icons.touch_app_outlined, 'Take Your Turn', 'On your turn, pick a statistic from your top card — Runs, Wickets, Strike Rate, and more.'),
  (Icons.compare_arrows, 'Compare', 'Everyone\'s top card is compared on that statistic. Highest (or lowest, for bowling economy/average) wins.'),
  (Icons.bolt, 'Ties', 'If it\'s a tie, nobody draws a new card — the same tied players pick another statistic from those same cards.'),
  (Icons.collections_bookmark_outlined, 'Collect Cards', 'The round winner takes every other active player\'s top card and gets the next turn.'),
  (Icons.remove_circle_outline, 'Elimination', 'A player with zero cards is eliminated but can keep watching.'),
  (Icons.emoji_events_outlined, 'Win', 'Collect every card in the game to become the champion and earn coins.'),
];

/// Minimal static explainer — not the fully animated version from
/// docs/SPEC.md §38, which is future polish work.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('How to Play', style: AppTextStyles.title)),
      body: AppBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _steps.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final (icon, title, body) = _steps[index];
            return GlassPanel(
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: AppColors.navyDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${index + 1}. ',
                              style: AppTextStyles.title.copyWith(color: AppColors.gold),
                            ),
                            Text(title, style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(body, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
