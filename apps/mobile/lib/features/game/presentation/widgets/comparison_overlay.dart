import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/game_state.dart';
import '../../../../shared/widgets/cricket_card.dart';
import '../../../../shared/widgets/player_avatar.dart';

/// The reveal moment — deliberately just player portraits + the compared
/// value, not the full CricketCard (a full card here was cramped and
/// overlapping on real devices, and isn't needed: the point of this moment
/// is "who won", not the whole stat sheet). The server already decided the
/// winner (`winnerUserIds`) — this never re-derives it from raw values.
class ComparisonOverlay extends StatelessWidget {
  const ComparisonOverlay({required this.comparison, required this.selfId, super.key});

  final ComparisonResult comparison;
  final String? selfId;

  @override
  Widget build(BuildContext context) {
    // A tie's `winnerUserIds` deliberately lists every contesting player
    // (that's how the server tells the client "these are the ones still in
    // it"), so checking membership alone made BOTH tied players see "YOU
    // WIN THIS ROUND!" here — the tie banner only corrected the picture a
    // moment later via a separate event, layered on top of the wrong
    // message underneath instead of replacing it. An outright win requires
    // exactly one winner.
    final isOutrightWin = comparison.winnerUserIds.length == 1;
    final iWon = isOutrightWin && comparison.winnerUserIds.contains(selfId);

    return Positioned.fill(
      child: Container(
        color: AppColors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('COMPARING', style: AppTextStyles.overline.copyWith(color: AppColors.gold)),
            const SizedBox(height: 4),
            Text(
              CricketCard.statLabels[comparison.statistic] ?? comparison.statistic,
              style: AppTextStyles.headline,
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 20,
              children: [
                for (final revealed in comparison.cards)
                  _RevealedPlayer(
                    revealed: revealed,
                    // No individual "WINNER" badge during a tie either —
                    // nobody has actually won this comparison yet.
                    isWinner: isOutrightWin && comparison.winnerUserIds.contains(revealed.userId),
                    isSelf: revealed.userId == selfId,
                  ),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                gradient: iWon ? AppColors.goldGradient : null,
                color: iWon ? null : AppColors.glassFill,
                borderRadius: BorderRadius.circular(24),
                border: iWon ? null : Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                iWon ? 'YOU WIN THIS ROUND!' : _loserLabel(),
                style: AppTextStyles.button.copyWith(color: iWon ? AppColors.navyDark : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _loserLabel() {
    if (comparison.winnerUserIds.length > 1) return "IT'S A TIE";
    return 'OPPONENT WINS THIS ROUND';
  }
}

class _RevealedPlayer extends StatelessWidget {
  const _RevealedPlayer({required this.revealed, required this.isWinner, required this.isSelf});

  final RevealedCard revealed;
  final bool isWinner;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    // Fully opaque either way — a washed-out translucent loser read as
    // "broken UI" rather than a deliberate loss; the ring color, badge, and
    // scale already make the winner unmistakable without dimming anyone.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.electricGreen,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: AppColors.electricGreen.withValues(alpha: 0.6), blurRadius: 10)],
            ),
            child: Text('WINNER', style: AppTextStyles.overline.copyWith(color: AppColors.navyDark, fontSize: 10)),
          )
        else
          const SizedBox(height: 22),
        AnimatedScale(
          scale: isWinner ? 1.1 : 0.92,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: PlayerAvatar(
            role: revealed.card.player.role,
            name: revealed.card.player.displayName,
            country: revealed.card.player.country,
            imageUrl: revealed.card.player.imageUrl ?? revealed.card.imageUrl,
            size: 96,
            ringColor: isWinner ? AppColors.electricGreen : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isSelf ? 'YOU' : revealed.card.player.displayName,
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(
            fontSize: 14,
            color: isWinner ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${revealed.value ?? "—"}',
          style: AppTextStyles.displayLarge.copyWith(
            fontSize: 26,
            color: isWinner ? AppColors.electricGreen : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
