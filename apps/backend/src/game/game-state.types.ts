/// The live, authoritative game state — held in Redis (see RedisService),
/// never trusted from the client. Persistent history (GameRound,
/// GameRoundCard, GameEvent, final GamePlayer fields) is written to
/// Postgres as each round resolves. See docs/GAME_RULES.md.
export interface GamePlayerState {
  userId: string;
  cardIds: string[]; // ordered pile; index 0 is always the current top card
  isEliminated: boolean;
  cardsWonCount: number;
  /// Starts at TURN_TIMEOUT_STARTING_LIVES (game-engine.service.ts) and is
  /// decremented only by letting the 30s turn timer expire — an anti-stall
  /// penalty, separate from the normal "ran out of cards" elimination.
  /// Reaching 0 eliminates the player outright, even mid-deck.
  livesRemaining: number;
}

export interface TieState {
  /// Players still contesting this tie-break sub-sequence. The current
  /// player keeps calling stats throughout — see game-engine.service.ts for
  /// why turn control isn't handed off mid-tie.
  contestingPlayerIds: string[];
  /// Statistics already tried in this tie sequence — can't be reused until
  /// the tie resolves (docs/GAME_RULES.md).
  usedStatistics: string[];
}

export interface GameState {
  gameId: string;
  roomId: string;
  cardSetId: string;
  entryAmount: number;
  roundNumber: number;
  currentPlayerId: string;
  players: GamePlayerState[];
  /// Everyone active when the current round began — used at collection time
  /// so outright losers (never part of a tie) still hand their card over.
  roundActivePlayerIds: string[];
  tieState: TieState | null;
  eliminationOrder: string[];
  eventSequence: number;
  status: 'PLAYER_TURN' | 'GAME_FINISHED';
  winnerId?: string;
}
