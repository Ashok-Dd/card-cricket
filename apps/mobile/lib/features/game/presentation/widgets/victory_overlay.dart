import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/game_state.dart';
import '../../../../shared/widgets/premium_button.dart';

/// The big moment (docs/SPEC.md §34) — only shown once per match, unlike the
/// lightweight per-round reward effects.
class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    required this.finished,
    required this.isWinner,
    required this.onDone,
    super.key,
  });

  final GameFinishedEvent finished;
  final bool isWinner;
  final VoidCallback onDone;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.isWinner) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(color: AppColors.black.withValues(alpha: 0.85)),
          if (widget.isWinner)
            ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              maxBlastForce: 12,
              minBlastForce: 6,
              numberOfParticles: 24,
              gravity: 0.25,
              colors: const [AppColors.gold, AppColors.goldBright, AppColors.electricGreen, Colors.white],
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.navyElevated, AppColors.navyDark],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.isWinner ? AppColors.gold : AppColors.glassBorder,
                    width: 1.5,
                  ),
                  boxShadow: widget.isWinner
                      ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4)]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isWinner
                            ? AppColors.goldGradient
                            : LinearGradient(colors: [AppColors.navySurface, AppColors.navy]),
                      ),
                      child: Icon(
                        widget.isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                        size: 46,
                        color: widget.isWinner ? AppColors.navyDark : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.isWinner ? 'CHAMPION!' : 'DEFEATED',
                      style: AppTextStyles.hero.copyWith(
                        fontSize: 34,
                        color: widget.isWinner ? AppColors.gold : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.isWinner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.electricGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.electricGreen.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '+${widget.finished.coinsEarned} COINS',
                          style: AppTextStyles.title.copyWith(color: AppColors.electricGreen),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Rounds Played: ${widget.finished.roundsPlayed}', style: AppTextStyles.body),
                    const SizedBox(height: 2),
                    Text('Cards Collected: ${widget.finished.cardsCollected}', style: AppTextStyles.body),
                    const SizedBox(height: 28),
                    PremiumButton(label: 'Back to Home', onPressed: widget.onDone, expand: false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
