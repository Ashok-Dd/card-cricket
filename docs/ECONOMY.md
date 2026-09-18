# Virtual Coin Economy

Full original spec: `docs/SPEC.md` sections 18–23. Coins are virtual game currency only — no cash-out, no real-money conversion, no wagering in this build. Design it so a future real-money layer could be bolted on without reworking the ledger, but do not build that layer now.

## Earning coins (server-controlled, amounts configurable, not hardcoded in Flutter)

Welcome reward, daily login, match win, match completion, missions, achievements, streaks, events, tournament/seasonal rewards.

## Entry-based rooms

Rooms may require a virtual coin entry (FREE / 100 / 500 / 1,000 / 5,000). Client shows entry cost, player count, and expected reward pool before joining — but never computes or awards the payout itself; that's server-side, from configured game rules.

## Ledger, not just a balance column

Do not rely solely on `wallets.balance`. Maintain an immutable `coin_transactions` table:

```
id  userId  type  amount  balanceAfter  gameId  description  createdAt
```

Transaction types: `WELCOME_REWARD DAILY_REWARD GAME_ENTRY GAME_REWARD ACHIEVEMENT_REWARD TOURNAMENT_REWARD REFUND ADMIN_ADJUSTMENT`.

Every transaction carries a unique/idempotency key. Guard against: double deduction, double reward, negative balance, replay attacks, duplicate victory rewards, fake game completion, reconnect exploits. Use DB transactions for any multi-step balance mutation.

## Entry reservation lifecycle

On joining a coin-entry match: verify balance → atomically reserve/deduct. States to distinguish where relevant: `AVAILABLE / RESERVED / SPENT / REFUNDED`. If a match fails for a technical/server reason, run a controlled refund path (not a silent write to balance).

## Wallet screen (client)

Shows current balance and a transaction history feed (e.g. `+500 Match Victory`, `-100 Match Entry`, `+100 Daily Reward`). Balance changes get a small celebratory treatment (counter animation, glow, sound, haptic) — see `docs/CARD_DESIGN.md` / animation notes for tone (subtle, not overblown, reserved for real wins).
