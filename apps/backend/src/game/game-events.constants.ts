/// Typed WebSocket event names for the game gateway. See
/// docs/ARCHITECTURE.md ("WebSocket event contract") and
/// src/game/game.gateway.ts before adding one. Client -> server events are
/// requests only; the server decides everything (docs/GAME_RULES.md).
export const GameClientEvent = {
  /// Join the socket channel for a room's lobby updates. Does not itself
  /// join the room as a player — that's the REST POST /rooms/:code/join.
  SubscribeRoom: 'room:subscribe',
  /// Join the socket channel for a game and receive a personalized
  /// game:state snapshot. Also how a reconnecting client resyncs.
  SubscribeGame: 'game:subscribe',
  /// The one real gameplay action: "I choose this statistic."
  SelectStatistic: 'statistic:selected',
  /// A player voluntarily concedes an in-progress match — an immediate,
  /// deliberate "I quit", distinct from the anti-stall timeout/lives system
  /// (game-engine.service.ts's TURN_TIMEOUT_STARTING_LIVES).
  ForfeitMatch: 'game:forfeit',
} as const;

export const GameServerEvent = {
  RoomUpdated: 'room:updated',
  GameStarting: 'game:starting',
  GameState: 'game:state',
  ComparisonResult: 'comparison:result',
  GameTie: 'game:tie',
  CardsCollected: 'cards:collected',
  /// A player let their 30s turn expire without picking a statistic — their
  /// current card was forfeited to the next player and a life was spent.
  TurnTimedOut: 'turn:timedOut',
  PlayerEliminated: 'player:eliminated',
  GameFinished: 'game:finished',
  WalletUpdated: 'wallet:updated',
  Error: 'error',
} as const;
