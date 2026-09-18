# Architecture

Full original spec: `docs/SPEC.md` sections 39–54.

## Data model (PostgreSQL)

Central principle: **one player, many statistical profiles** — never fork a player per card set.

```
users
players                 -- id, name, country, role, batting/bowling style, team, era, image, active/retired
player_statistics        -- playerId, cardSetId, stat blob (runs, wickets, SR, avg, best score, 100s/50s, econ, catches, ...)
card_sets                 -- IPL / ODI / TEST / T20 / future sets — DB-driven, never hardcoded
cards                      -- generated from player + card_set + statistics + rarity/rating/image/version
games
game_players
game_rounds
game_events
wallets
coin_transactions          -- immutable ledger, see docs/ECONOMY.md
achievements / user_achievements
missions / user_missions
```

Rules:
- Never compare stats from two different card sets in the same match (e.g. IPL strike rate vs ODI strike rate).
- Rarity tiers (Common/Rare/Epic/Legendary/Iconic) are extensible — model as data, not a fixed enum baked deep into logic.
- Card-set metadata (card count, supported stats, enabled/disabled) is fetched by the client at runtime, never hardcoded in Flutter.

## Redis

Live/ephemeral coordination only — not the system of record:
- Active rooms, lobby state, active games, whose turn it is, tie-sequence state
- WebSocket coordination across server instances, reconnection bookkeeping
- Distributed locks (e.g. around coin entry reservation), caching, rate limiting

Persistent match history and final results land in PostgreSQL.

## Backend modules (NestJS)

```
AuthModule  UsersModule  PlayersModule  CardSetsModule  CardsModule
RoomsModule  LobbyModule  GameModule  WalletModule  RewardsModule
AchievementsModule  LeaderboardModule  AdminModule
GameGateway (WebSocket gateway — the real-time authority surface)
```

REST surface: `/auth /users /players /card-sets /rooms /wallet /profile`.

## Game state machine

```
WAITING → STARTING → DEALING → PLAYER_TURN → STATISTIC_SELECTED → COMPARING
  → (TIE → back to STATISTIC_SELECTED with same cards) → ROUND_RESULT
  → COLLECTING_CARDS → NEXT_TURN → (PLAYER_ELIMINATED)* → GAME_FINISHED
```

Explicit states prevent invalid transitions (e.g. accepting a statistic selection when it isn't PLAYER_TURN, or double-processing a COMPARING result).

`GameState` shape (server-held, partially projected to clients): `gameId, roomId, cardSetId, status, roundNumber, currentPlayerId, players[], activeCards, playerCardCounts, selectedStatistic, tieState, roundState, winnerId, createdAt, updatedAt`. Never send a client another player's hidden deck.

## WebSocket event contract

Typed, versioned events, e.g.:

```
room:joined  room:updated  game:starting  game:state  turn:started
statistic:selected  comparison:started  comparison:result  game:tie
cards:collected  player:eliminated  game:finished  wallet:updated
player:reconnected  player:disconnected  error
```

Use event IDs/sequence numbers; clients must be safe against duplicate and reordered events (idempotent handlers, last-write-wins on sequence number, or explicit ack).

## Server authority checklist

Client may only ever *request*; server always *decides*: shuffle, card ownership/order, current turn, valid actions, statistic values, comparisons, tie handling, card transfer, elimination, winner, coin deduction/reward, match completion.

## Security baseline

JWT auth, secure token storage on-device, server-side authorization on every room/game/wallet action, input validation, rate limiting, WebSocket auth on connect, idempotency keys on money-affecting requests, DB transactions around multi-row mutations, anti-replay protection, duplicate-event protection.

## Flutter feature-based structure

```
lib/
  core/        constants, theme, routing, network, storage, audio, animations, error, utils
  features/
    auth/ home/ lobby/ game/ card_sets/ wallet/ profile/ tutorial/ settings/
      each: data/ domain/ presentation/ (presentation splits into screens/ widgets/ animations/ state/ for game)
  shared/      widgets, models, extensions
```

Keep UI, state, business logic, repositories, network, and models in separate layers — no business logic in widgets, no giant service classes.
