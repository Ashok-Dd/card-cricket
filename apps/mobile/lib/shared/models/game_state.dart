import 'card_model.dart';

class GamePlayerPublic {
  const GamePlayerPublic({
    required this.userId,
    required this.cardCount,
    required this.isEliminated,
    required this.isCurrentTurn,
    required this.livesRemaining,
  });

  final String userId;
  final int cardCount;
  final bool isEliminated;
  final bool isCurrentTurn;
  // Anti-stall lives — spent only by letting the 30s turn timer expire, not
  // by losing a round normally. Reaching 0 eliminates a player outright.
  final int livesRemaining;

  factory GamePlayerPublic.fromJson(Map<String, dynamic> json) => GamePlayerPublic(
        userId: json['userId'] as String,
        cardCount: json['cardCount'] as int,
        isEliminated: json['isEliminated'] as bool,
        isCurrentTurn: json['isCurrentTurn'] as bool,
        livesRemaining: json['livesRemaining'] as int,
      );
}

class TieStateInfo {
  const TieStateInfo({required this.contestingPlayerIds, required this.usedStatistics});

  final List<String> contestingPlayerIds;
  final List<String> usedStatistics;

  factory TieStateInfo.fromJson(Map<String, dynamic> json) => TieStateInfo(
        contestingPlayerIds: (json['contestingPlayerIds'] as List<dynamic>).cast<String>(),
        usedStatistics: (json['usedStatistics'] as List<dynamic>).cast<String>(),
      );
}

/// The personalized snapshot from GET /games/:id or the game:state /
/// game:subscribe events — the caller's own top card is fully revealed,
/// everyone else is counts/turn/elimination only. Never trust a client to
/// know more than this.
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.gameId,
    required this.cardSetId,
    required this.roundNumber,
    required this.currentPlayerId,
    required this.status,
    required this.winnerId,
    required this.tieState,
    required this.players,
    required this.myCard,
  });

  final String gameId;
  final String cardSetId;
  final int roundNumber;
  final String currentPlayerId;
  final String status; // 'PLAYER_TURN' | 'GAME_FINISHED'
  final String? winnerId;
  final TieStateInfo? tieState;
  final List<GamePlayerPublic> players;
  final CardModel? myCard;

  bool get isMyTurn => myCard != null && status == 'PLAYER_TURN';

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) => GameStateSnapshot(
        gameId: json['gameId'] as String,
        cardSetId: json['cardSetId'] as String,
        roundNumber: json['roundNumber'] as int,
        currentPlayerId: json['currentPlayerId'] as String,
        status: json['status'] as String,
        winnerId: json['winnerId'] as String?,
        tieState: json['tieState'] != null
            ? TieStateInfo.fromJson(json['tieState'] as Map<String, dynamic>)
            : null,
        players: (json['players'] as List<dynamic>)
            .map((p) => GamePlayerPublic.fromJson(p as Map<String, dynamic>))
            .toList(),
        myCard: json['myCard'] != null
            ? CardModel.fromJson(json['myCard'] as Map<String, dynamic>)
            : null,
      );
}

/// One participant's actual played card, revealed for this comparison —
/// see docs/GAME_RULES.md: once a card is played its stats are public,
/// exactly like a real Top Trumps reveal.
class RevealedCard {
  const RevealedCard({required this.userId, required this.value, required this.card});

  final String userId;
  // A plain number for most stats, but a "4/25"-style string for
  // bestBowling — the server sends the raw display value as-is, never an
  // internal comparison-only encoding (see stat-comparison.util.ts on the
  // backend). Rendered with a plain `$value` interpolation either way.
  final Object? value;
  final CardModel card;

  factory RevealedCard.fromJson(Map<String, dynamic> json) => RevealedCard(
        userId: json['userId'] as String,
        value: json['value'] as Object?,
        card: CardModel.fromJson(json['card'] as Map<String, dynamic>),
      );
}

class ComparisonResult {
  const ComparisonResult({required this.statistic, required this.winnerUserIds, required this.cards});

  final String statistic;
  final List<String> winnerUserIds;
  final List<RevealedCard> cards;

  factory ComparisonResult.fromJson(Map<String, dynamic> json) => ComparisonResult(
        statistic: json['statistic'] as String,
        winnerUserIds: (json['winnerUserIds'] as List<dynamic>).cast<String>(),
        cards: (json['cards'] as List<dynamic>)
            .map((c) => RevealedCard.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class GameTieEvent {
  const GameTieEvent({required this.statistic, required this.contestingPlayerIds});

  final String statistic;
  final List<String> contestingPlayerIds;

  factory GameTieEvent.fromJson(Map<String, dynamic> json) => GameTieEvent(
        statistic: json['statistic'] as String,
        contestingPlayerIds: (json['contestingPlayerIds'] as List<dynamic>).cast<String>(),
      );
}

/// A player let their 30s turn expire without picking a statistic — the
/// server auto-forfeited their current card and spent one of their lives.
class GameTurnTimedOutEvent {
  const GameTurnTimedOutEvent({
    required this.userId,
    required this.livesRemaining,
    required this.forfeitedToUserId,
  });

  final String userId;
  final int livesRemaining;
  final String forfeitedToUserId;

  factory GameTurnTimedOutEvent.fromJson(Map<String, dynamic> json) => GameTurnTimedOutEvent(
        userId: json['userId'] as String,
        livesRemaining: json['livesRemaining'] as int,
        forfeitedToUserId: json['forfeitedToUserId'] as String,
      );
}

class GameFinishedEvent {
  const GameFinishedEvent({
    required this.winnerId,
    required this.coinsEarned,
    required this.roundsPlayed,
    required this.cardsCollected,
  });

  final String winnerId;
  final int coinsEarned;
  final int roundsPlayed;
  final int cardsCollected;

  factory GameFinishedEvent.fromJson(Map<String, dynamic> json) => GameFinishedEvent(
        winnerId: json['winnerId'] as String,
        coinsEarned: json['coinsEarned'] as int,
        roundsPlayed: json['roundsPlayed'] as int,
        cardsCollected: json['cardsCollected'] as int,
      );
}
