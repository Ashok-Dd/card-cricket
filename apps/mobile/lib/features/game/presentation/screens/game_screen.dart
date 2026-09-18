import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/sound_service.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/game_state.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/widgets/cricket_card.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/lives_indicator.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../auth/domain/auth_controller.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../../../shared/widgets/player_avatar.dart';
import '../widgets/comparison_overlay.dart';
import '../widgets/stat_button.dart';
import '../widgets/turn_timer_ring.dart';
import '../widgets/victory_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({required this.gameId, super.key});
  final String gameId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// How long a comparison/elimination stays on screen before the board moves
/// on — long enough to actually read who won and why, short enough not to
/// feel sluggish. See the game-screen review that prompted this: the reveal
/// used to vanish the instant a fresh game:state arrived (often the same
/// frame), which made it impossible to tell who won a round.
const _revealDuration = Duration(milliseconds: 3200);
const _flashDuration = Duration(milliseconds: 2600);

/// Must match the server's own TURN_TIMEOUT_MS (game-engine.service.ts) —
/// this countdown is a display of the real deadline, not just cosmetic: the
/// server forfeits the turn on its own clock regardless of what the client
/// shows, so a mismatch here would only make the UI lie about when that
/// happens, not change the actual outcome.
const _turnDurationSeconds = 30;

class _GameScreenState extends ConsumerState<GameScreen> {
  GameStateSnapshot? _state;
  ComparisonResult? _comparison;
  GameTieEvent? _tie;
  GameFinishedEvent? _finished;
  String? _flashMessage;

  /// Identifies "whose decision is this, and which decision" — not just
  /// whose turn it is. A tie keeps the same currentPlayerId across several
  /// game:state updates (the same player picks again on a fresh, unused
  /// stat), so keying the timer reset off currentPlayerId alone left the
  /// countdown paused-then-resumed from wherever it was instead of starting
  /// a fresh 30s for that new pick. roundNumber + how many stats have been
  /// used in the current tie sequence makes each distinct decision point
  /// produce a different key even when the player doesn't change.
  String? _decisionKey;
  int _turnSecondsRemaining = _turnDurationSeconds;

  /// True from the moment a stat is tapped until the server's response
  /// (a fresh game:state, a comparison reveal, or a rejection) arrives —
  /// blocks a second tap in that window instead of silently emitting a
  /// second `statistic:selected` before the first has even been processed.
  bool _isSelectingStat = false;

  /// True from confirming the forfeit dialog until the server's response
  /// (game:finished, or a fresh game:state once eliminated) arrives — a
  /// full-screen loader here so it's unmistakable that forfeiting is being
  /// processed, not just a silent no-op.
  bool _isForfeiting = false;

  Timer? _revealTimer;
  Timer? _flashTimer;
  Timer? _turnTicker;

  late final SocketService _socket;
  late final SoundService _sound;
  void Function(dynamic)? _onGameState;
  void Function(dynamic)? _onComparison;
  void Function(dynamic)? _onTie;
  void Function(dynamic)? _onCardsCollected;
  void Function(dynamic)? _onTurnTimedOut;
  void Function(dynamic)? _onEliminated;
  void Function(dynamic)? _onFinished;
  void Function(dynamic)? _onError;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _sound = ref.read(soundServiceProvider);
    _socket.emit('game:subscribe', {'gameId': widget.gameId});

    // Deliberately does NOT touch `_comparison` — the reveal is dismissed
    // only by `_revealTimer`, never by the next state update arriving (the
    // underlying board is free to update card counts/turn behind the
    // still-visible overlay).
    _onGameState = (data) {
      if (!mounted) return;
      final newState = GameStateSnapshot.fromJson(Map<String, dynamic>.from(data as Map));
      final newDecisionKey = _decisionKeyFor(newState);
      final decisionChanged = newDecisionKey != _decisionKey;
      setState(() {
        _state = newState;
        _isSelectingStat = false;
        _isForfeiting = false;
        if (_state!.tieState == null) _tie = null;
        if (decisionChanged) {
          _decisionKey = newDecisionKey;
          _turnSecondsRemaining = _turnDurationSeconds;
        }
      });
      if (decisionChanged) _restartTurnTicker();
    };
    _onComparison = (data) {
      if (!mounted) return;
      _revealTimer?.cancel();
      final comparison = ComparisonResult.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() {
        _comparison = comparison;
        _isSelectingStat = false;
      });
      final selfId = _selfId;
      if (comparison.winnerUserIds.length > 1) {
        _sound.play(GameSound.tie);
      } else if (selfId != null && comparison.winnerUserIds.contains(selfId)) {
        _sound.play(GameSound.roundWin);
      } else {
        _sound.play(GameSound.roundLose);
      }
      _revealTimer = Timer(_revealDuration, () {
        if (mounted) setState(() => _comparison = null);
      });
    };
    _onTie = (data) {
      if (!mounted) return;
      setState(() => _tie = GameTieEvent.fromJson(Map<String, dynamic>.from(data as Map)));
    };
    _onCardsCollected = (_) {};
    _onTurnTimedOut = (data) {
      if (!mounted) return;
      _flashTimer?.cancel();
      final event = GameTurnTimedOutEvent.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() => _flashMessage = "${_nameFor(event.userId)} ran out of time — card forfeited!");
      _flashTimer = Timer(_flashDuration, () {
        if (mounted) setState(() => _flashMessage = null);
      });
    };
    _onEliminated = (data) {
      if (!mounted) return;
      _flashTimer?.cancel();
      final userId = (data as Map)['userId'] as String;
      setState(() => _flashMessage = '${_nameFor(userId)} was eliminated!');
      _flashTimer = Timer(_flashDuration, () {
        if (mounted) setState(() => _flashMessage = null);
      });
    };
    _onFinished = (data) {
      if (!mounted) return;
      final finished = GameFinishedEvent.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() {
        _finished = finished;
        _isForfeiting = false;
      });
      _sound.play(finished.winnerId == _selfId ? GameSound.victory : GameSound.defeat);
      ref.invalidate(walletProvider);
    };
    _onError = (data) {
      if (!mounted) return;
      final message = (data as Map)['message']?.toString() ?? 'Something went wrong';
      setState(() {
        _isSelectingStat = false;
        _isForfeiting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    };

    _socket.on('game:state', _onGameState!);
    _socket.on('comparison:result', _onComparison!);
    _socket.on('game:tie', _onTie!);
    _socket.on('cards:collected', _onCardsCollected!);
    _socket.on('turn:timedOut', _onTurnTimedOut!);
    _socket.on('player:eliminated', _onEliminated!);
    _socket.on('game:finished', _onFinished!);
    _socket.on('error', _onError!);
  }

  /// A "new decision" is a new roundNumber, OR — while a tie is being
  /// resolved — a new entry in usedStatistics, even though currentPlayerId
  /// stays the same throughout that tie sequence (see the field comment on
  /// `_decisionKey`).
  String _decisionKeyFor(GameStateSnapshot s) {
    final tieStep = s.tieState?.usedStatistics.length ?? 0;
    return '${s.currentPlayerId}:${s.roundNumber}:$tieStep';
  }

  void _restartTurnTicker() {
    _turnTicker?.cancel();
    _turnTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Paused while a reveal is showing — the countdown is "time to think
      // about your next pick", not "time to sit through an animation".
      if (_comparison != null) return;
      if (_turnSecondsRemaining <= 0) return;
      setState(() => _turnSecondsRemaining--);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _flashTimer?.cancel();
    _turnTicker?.cancel();
    _socket.off('game:state', _onGameState);
    _socket.off('comparison:result', _onComparison);
    _socket.off('game:tie', _onTie);
    _socket.off('cards:collected', _onCardsCollected);
    _socket.off('turn:timedOut', _onTurnTimedOut);
    _socket.off('player:eliminated', _onEliminated);
    _socket.off('game:finished', _onFinished);
    _socket.off('error', _onError);
    super.dispose();
  }

  String _nameFor(String userId) => userId == _selfId ? 'You' : 'Opponent';

  String? get _selfId => ref.read(authControllerProvider).valueOrNull?.id;

  Future<void> _confirmForfeit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navyElevated,
        title: Text('Forfeit match?', style: AppTextStyles.title),
        content: Text(
          'You\'ll lose your entire deck to your opponent and this counts as a loss. This can\'t be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: AppTextStyles.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Forfeit', style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _isForfeiting = true);
      _socket.emit('game:forfeit', {'gameId': widget.gameId});
    }
  }

  void _selectStatistic(String statistic) {
    if (_isSelectingStat) return;
    setState(() => _isSelectingStat = true);
    _sound.play(GameSound.tap);
    _socket.emit('statistic:selected', {'gameId': widget.gameId, 'statistic': statistic});
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: state == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    _buildBoard(state),
                    if (_tie != null && _finished == null) _TieBanner(tie: _tie!),
                    if (_comparison != null && _finished == null)
                      ComparisonOverlay(comparison: _comparison!, selfId: _selfId),
                    if (_isForfeiting && _finished == null) const _ForfeitingOverlay(),
                    if (_finished != null)
                      VictoryOverlay(
                        finished: _finished!,
                        isWinner: _finished!.winnerId == _selfId,
                        onDone: () => context.go('/home'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  /// No `Spacer`/`Expanded` anywhere here on purpose: this whole board is
  /// wrapped in a `SingleChildScrollView`, which gives its child unbounded
  /// height — flexible-space widgets don't work in that context, and
  /// mixing them back in is exactly how the original 135px overflow
  /// happened (fixed-size children + Spacer summed past this device's
  /// available height, with nothing able to shrink). Instead: fixed gaps,
  /// and a card width computed from the available height via
  /// `LayoutBuilder` so it fits *without* scrolling on the common case —
  /// scrolling is only the safety net for anything unusual.
  void _showDeckCounts(GameStateSnapshot state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.navyElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('DECK COUNTS', style: AppTextStyles.overline),
            const SizedBox(height: 14),
            for (final p in state.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          p.isCurrentTurn ? Icons.play_arrow : Icons.person_outline,
                          size: 16,
                          color: p.isCurrentTurn ? AppColors.electricGreen : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.userId == _selfId ? 'You' : 'Opponent',
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.isEliminated ? 'OUT' : '${p.cardCount} cards',
                          style: AppTextStyles.title.copyWith(
                            color: p.isEliminated ? AppColors.danger : AppColors.gold,
                          ),
                        ),
                        if (!p.isEliminated) ...[
                          const SizedBox(width: 8),
                          LivesIndicator(livesRemaining: p.livesRemaining),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(GameStateSnapshot state) {
    final selfId = _selfId;
    final selfPlayer = state.players.where((p) => p.userId == selfId).firstOrNull;
    final opponentPlayer = state.players.where((p) => p.userId != selfId).firstOrNull;
    final myCard = state.myCard;
    final isMyTurn = state.status == 'PLAYER_TURN' && state.currentPlayerId == selfId;
    final usedStats = state.tieState?.usedStatistics ?? const [];
    final selectable = myCard?.selectableStatistics.where((s) => !usedStats.contains(s)).toList() ?? const [];
    final selfEliminated = selfPlayer?.isEliminated ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The hero image inside CricketCard shrank (see cricket_card.dart),
        // which frees up vertical budget to make the card noticeably wider
        // instead — was 0.28/170-230, both bumped to match.
        final cardWidth = (constraints.maxHeight * 0.34).clamp(190.0, 260.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ROUND ${state.roundNumber}', style: AppTextStyles.overline),
                    Row(
                      children: [
                        if (!isMyTurn && opponentPlayer != null && !opponentPlayer.isEliminated) ...[
                          TurnTimerRing(
                            isActive: true,
                            secondsRemaining: _turnSecondsRemaining,
                            size: 22,
                            child: const _MiniOpponentAvatar(),
                          ),
                          const SizedBox(width: 6),
                        ] else ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.electricGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isMyTurn ? 'YOUR TURN' : "OPPONENT'S TURN",
                          style: AppTextStyles.overline.copyWith(
                            color: isMyTurn ? AppColors.electricGreen : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!selfEliminated)
                          IconButton(
                            onPressed: _isForfeiting ? null : () => _confirmForfeit(),
                            icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.danger),
                            tooltip: 'Forfeit match',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 14),
                        IconButton(
                          onPressed: () => _showDeckCounts(state),
                          icon: const Icon(Icons.style_outlined, size: 20, color: AppColors.textSecondary),
                          tooltip: 'Show deck counts',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_flashMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_flashMessage!, style: AppTextStyles.body),
                ),
              const SizedBox(height: 16),
              if (myCard != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TurnTimerRing(
                      isActive: isMyTurn,
                      secondsRemaining: _turnSecondsRemaining,
                      size: 34,
                      child: PlayerAvatar(
                        role: myCard.player.role,
                        name: myCard.player.displayName,
                        country: myCard.player.country,
                        imageUrl: myCard.player.imageUrl ?? myCard.imageUrl,
                        size: 26,
                        ringColor: isMyTurn ? AppColors.electricGreen : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'YOU  •  ${selfPlayer?.cardCount ?? '—'} CARDS',
                      style: AppTextStyles.overline,
                    ),
                    if (selfPlayer != null) ...[
                      const SizedBox(width: 8),
                      LivesIndicator(livesRemaining: selfPlayer.livesRemaining),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                CricketCard(card: myCard, width: cardWidth),
              ],
              const SizedBox(height: 16),
              if (selfEliminated)
                _EliminatedPanel(onLeaveRoom: () => context.go('/home'))
              else if (_isSelectingStat)
                const _SubmittingStatIndicator()
              else if (isMyTurn && selectable.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: selectable
                      .map((stat) => StatButton(
                            label: CricketCard.statLabels[stat] ?? stat,
                            onTap: () => _selectStatistic(stat),
                          ))
                      .toList(),
                )
              else
                SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      isMyTurn ? 'No selectable stats left' : 'Waiting for opponent…',
                      style: AppTextStyles.body,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown from the moment forfeiting is confirmed until the server responds
/// — a full-screen block rather than just the small stat-button spinner,
/// since forfeiting immediately ends the match for this player and should
/// read as unmistakably "this is happening now", not a quiet no-op.
class _ForfeitingOverlay extends StatelessWidget {
  const _ForfeitingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.black.withValues(alpha: 0.75),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Forfeiting match…', style: AppTextStyles.title),
          ],
        ),
      ),
    );
  }
}

/// A generic silhouette for the header's compact opponent turn-timer ring —
/// unlike the self avatar, the opponent's actual card (and so their role
/// icon) is hidden per docs/GAME_RULES.md, so this can't show anything
/// player-specific.
class _MiniOpponentAvatar extends StatelessWidget {
  const _MiniOpponentAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 8,
      backgroundColor: AppColors.navyElevated,
      child: Icon(Icons.person, size: 11, color: AppColors.textSecondary),
    );
  }
}

/// Shown instead of the stat buttons once the self player is eliminated but
/// the match is still going — docs/GAME_RULES.md allows staying connected
/// as a spectator, but the player should be free to walk away right then
/// instead of being stuck watching until the match ends.
class _EliminatedPanel extends StatelessWidget {
  const _EliminatedPanel({required this.onLeaveRoom});
  final VoidCallback onLeaveRoom;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 16,
      borderColor: AppColors.danger.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close, size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text('YOU\'RE OUT', style: AppTextStyles.overline.copyWith(color: AppColors.danger)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You can keep watching this match or leave now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          PremiumButton(
            label: 'Leave Room',
            onPressed: onLeaveRoom,
            variant: PremiumButtonVariant.secondary,
            expand: false,
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the stat buttons for the brief window between tapping
/// one and the server's response arriving — a spinner here (rather than
/// just disabling the buttons) is what actually stops a player from
/// mashing a second tap during a slow connection, thinking the first one
/// didn't register.
class _SubmittingStatIndicator extends StatelessWidget {
  const _SubmittingStatIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Submitting…', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _TieBanner extends StatelessWidget {
  const _TieBanner({required this.tie});
  final GameTieEvent tie;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 20, spreadRadius: 1)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 18, color: AppColors.navyDark),
              const SizedBox(width: 8),
              Text(
                'TIE! CHOOSE ANOTHER STAT',
                style: AppTextStyles.button.copyWith(color: AppColors.navyDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
