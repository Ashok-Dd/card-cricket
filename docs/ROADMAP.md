# Roadmap

Full original spec: `docs/SPEC.md` sections 59–62.

## Build order (do not skip ahead to polish before the engine is correct)

1. **Foundation** — Flutter project, theme, routing, architecture skeleton; NestJS backend, database, auth.
2. **Cricket data** — players, statistics, card sets, card model, images, admin/data management.
3. **Rooms** — create/join room, room codes, lobby, ready system.
4. **Game engine** — shuffle, distribution, turn system, statistic selection, comparison, tie handling, card transfer, elimination, winner detection. All server-authoritative (see `docs/GAME_RULES.md`).
5. **Real-time** — WebSockets, reconnection, state sync, event validation, recovery.
6. **Economy** — wallet, coin ledger, rewards, entry rooms, refunds, idempotency (see `docs/ECONOMY.md`).
7. **Visual polish** — card animations, flip/shine/glow/particles, collection animation, victory celebration, sound, haptics (see `docs/CARD_DESIGN.md`).
8. **Testing** — 2p and 6p games, disconnect/reconnect, ties (2-way, 3+ way, chained), elimination, final victory, duplicate requests, coin exploits, race conditions, server recovery.

## MVP scope

Auth, Home, Create Room, Join Room, Lobby (2–6 players), card sets IPL/ODI/TEST/T20, cricket cards with stats, real-time gameplay with server shuffle/equal distribution/turn system/stat selection/comparison/same-card tie-breaker/card transfer/elimination/winner detection, reconnection, virtual coins with entry rooms, wallet + transaction history, basic profile, How to Play, premium animations, round + final victory celebrations.

## Explicitly deferred (design for extensibility, don't build yet)

Matchmaking, friends, private/public rooms, leaderboards/rankings, achievements/XP/levels, seasons/leagues/tournaments, daily missions/streaks, card collection/upgrades, more rarities, cosmetics/frames/emotes, spectator mode, replay system, match history detail, advanced stats, country competitions, women's cricket, historical/legends sets, seasonal/tournament-specific card sets, live events.

## Current status

- [x] Repo scaffolded: `apps/mobile` (Flutter) + `apps/backend` (NestJS), docs and CLAUDE.md rules in place.
- [x] Auth module — register/login/JWT, `GET /auth/me`, `JwtAuthGuard` reusable across modules.
- [x] Welcome-reward coin ledger (`WalletService.creditWelcomeReward`, `GET /wallet`, `GET /wallet/transactions`) — first real use of the `docs/ECONOMY.md` ledger pattern; entry-based rooms, game rewards, etc. still to come.
- [x] Player/card-set/card data model + read APIs (`GET /players`, `GET /card-sets`, `GET /card-sets/:code/cards`) + a small dev seed (8 players across IPL/ODI/TEST/T20, including an exact Ashwin ODI card matching the reference image) — NOT the full production player database yet.
- [x] Rooms & lobby — `POST /rooms`, `GET /rooms/:code`, join/ready/leave/start, room codes, `RoomPlayer` membership+ready state, host reassignment on leave.
- [x] Real-time layer — `GameGateway` with JWT-authenticated WebSocket connections (`socket.handshake.auth.token`), `room:subscribe`/`game:subscribe` channel joins, live `room:updated`/`game:starting` broadcasts wired into `RoomsService`. Single-instance only (in-memory `GameLockService` + Redis via `ioredis-mock` on this machine — see backend `CLAUDE.md`); real distributed locking/Redis is a documented follow-up for multi-instance deployment.
- [x] Game engine (server-authoritative) — `GameEngineService`: secure Fisher-Yates shuffle, equal-as-possible deal, turn-by-turn statistic selection, cricket-correct comparison (lower wins for economy rate/bowling average/bowling strike rate, higher wins otherwise), the exact same-cards tie rule (frozen comparison set, `usedStatistics` tracking, no redraw), card collection, elimination, win detection. Full round/event history persisted to `GameRound`/`GameRoundCard`/`GameEvent`. Verified end-to-end with real 2-player matches over live WebSocket connections (see backend `CLAUDE.md` for the verification approach).
- [x] Coin economy — entry deduction at match start, winner reward (entry pool redistribution + flat completion bonus), all through the immutable ledger. `WalletService.refundGameEntry` exists as a ledger primitive but nothing calls it yet — there's no abort/forfeit flow to trigger a refund from (see known gaps below).
- [x] Flutter client — real auth (login/register/JWT persisted via secure storage), home/create-room/join-room/lobby (WebSocket-driven) screens, `CricketCard` widget per `docs/CARD_DESIGN.md` (placeholder art, real stat layout), full game screen (stat selection, comparison reveal, tie banner, elimination, victory celebration with confetti), wallet, minimal profile and how-to-play. `flutter analyze`/`flutter test` clean; verified running live against the real backend.
- [ ] Deliberately deferred beyond this pass: Settings, full animated tutorial, Achievements/XP/Missions/Leaderboards, automatic turn-timeout/auto-play, multi-instance distributed locking, deeper visual polish (ambient particles, sound, elaborate 3D flip) beyond what's already implemented.

### Known gaps (narrow, but real — not yet handled)

- No mid-match "leave game" / forfeit action, and no automatic turn-timeout — a disconnected player's turn simply waits forever for them to reconnect and act. `RoomsService`'s own `leave()` only applies pre-game (lobby).
- `RoomsService.join()`/`setReady()`/`leave()`/`start()` aren't behind a per-room lock the way the game engine is behind `GameLockService` — two genuinely simultaneous requests against the same room (e.g. two joins landing in the same instant when only one seat is left) could theoretically both pass the capacity check. Narrow and unlikely, but real; would need the same per-key async lock pattern as `GameLockService` if it ever matters.
