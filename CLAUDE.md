# Card Cricket

Premium mobile-only, real-time multiplayer cricket card game (Top-Trumps-style stat battles with collectible cricket player cards). Not a website — a mobile game with an esports/collectible-card visual identity.

This file is the entry point for working in this repo. Deeper rules live in `docs/`. Sub-project conventions live in `apps/mobile/CLAUDE.md` and `apps/backend/CLAUDE.md`.

## Monorepo layout

```
card_cricket/
  apps/
    mobile/     Flutter + Dart client
    backend/    NestJS + TypeScript server
  docs/         Design & rules references (read before implementing game logic or UI)
  .claude/      Harness config (agents, skills, settings) — not game code
```

## Tech stack (fixed — do not swap without discussion)

- Mobile: Flutter + Dart, Riverpod, GoRouter, Dio, Socket.IO/WebSocket client
- Backend: NestJS + TypeScript, PostgreSQL, Redis, Socket.IO (WebSocket gateway)
- Primary target platform: Android (keep iOS/web buildable, don't block on them)

## The one rule that overrides all others

**The server is the sole authority for every piece of gameplay truth.** Shuffle, card ownership, turn order, statistic values, comparison results, tie handling, card transfer, elimination, winner declaration, coin balances, and rewards are ALL computed and decided server-side. The Flutter client sends intents ("I select Strike Rate") and renders whatever state the server broadcasts — it never computes a game outcome, a coin balance, or a winner itself. See `docs/GAME_RULES.md` and `docs/ARCHITECTURE.md`.

## Must-read before touching game logic or economy code

- `docs/GAME_RULES.md` — turn system, comparison, the same-cards tie rule, elimination, win condition, edge cases
- `docs/ARCHITECTURE.md` — data model, backend modules, WebSocket event contract, game state machine, reconnection
- `docs/ECONOMY.md` — virtual coin ledger, transaction types, idempotency, entry reservation
- `docs/CARD_DESIGN.md` — the visual spec for the `CricketCard` widget, derived from reference images the user provides

## Non-negotiable architecture constraints

1. **One player, many statistical profiles.** Never create a separate player entity per card set. `Player` is central; each card set (IPL/ODI/TEST/T20/future sets) attaches its own `player_statistics` profile to the same player. Never compare stats across different formats in one match.
2. **Card sets are data, not code.** IPL/ODI/TEST/T20 are just rows in the database, not hardcoded enums baked into business logic. Adding a new set (e.g. "IPL Legends", "T20 World Cup") must never require an app rebuild — only new data.
3. **Tie rule is exact:** on a tied statistic, do NOT redraw or reveal new cards. The same cards stay in play; tied players pick a different, previously-unused statistic from those same cards until the tie breaks.
4. **Coins are virtual only.** No cash-out, no real-money conversion, no wagering, in the initial build. Every coin movement goes through an immutable `coin_transactions` ledger with an idempotency key — never just increment/decrement `user.balance` directly.
5. **Config over hardcoding.** Reward amounts, entry tiers, card-set metadata, and rarity tiers are backend-configurable, not hardcoded into the Flutter client.

## Working style for this repo

- Feature-based folder structure on both sides (see the two sub-project CLAUDE.md files) — no giant God-classes/widgets, no business logic in UI.
- Build incrementally per `docs/ROADMAP.md`'s phase order: foundation → cricket data → rooms → game engine → real-time → economy → visual polish → testing. Don't jump ahead to polish before the game engine is correct and server-authoritative.
- When adding a new card set or player, it's a data/content change (seed data, admin API), not a code change.
- The user will supply reference card images over time; treat each as a design input for `docs/CARD_DESIGN.md` and the `CricketCard` widget, not a one-off.
