# Game Rules

Authoritative source for how a match actually plays out. The server implements exactly this; the client only renders it. Full original spec: `docs/SPEC.md` sections 8–16 and 46.

## Players & rooms

- 2–6 players per match.
- Host creates a room → gets a room code → shares it → others join with the code → lobby shows connected players and ready state → host starts once requirements are met (min players, everyone ready, entry coins available if applicable).

## Game start (server does all of this, atomically)

1. Validate room, player count, card set, entry requirements.
2. Fetch eligible cards for the chosen card set.
3. Securely shuffle (server-side RNG only — never trust/accept a client-provided order).
4. If the room specified a deck size (e.g. 50/100/200 cards instead of the set's full pool), take that many cards from the front of the already-shuffled list — this gives a uniformly random subset, not a bias toward higher-rated cards.
5. Distribute the (possibly trimmed) cards as equally as possible into per-player piles.
6. Determine starting player.
7. Create `GameState`, broadcast the initial state (each client gets only what it needs — its own top card, opponents' card counts/turn info, not opponents' hidden decks).

## Turn system

- Exactly one player has the active turn.
- The active player is shown the statistics available on their current top card as buttons (e.g. RUNS, WICKETS, STRIKE RATE, AVERAGE, BEST SCORE, 100s, SIXES) — every stat that has a non-null value on that card, including BEST BOWLING (see "Comparison" below for how a bowling-figures stat is judged).
- The player taps a statistic — they never type/submit a value. The client sends "I select `strike_rate`"; the server looks up the actual value from its own authoritative card data.

## Turn timeout — anti-stall lives

- Each player has 30 seconds to pick a statistic once it's their turn to choose (client shows a countdown ring; the **server** owns the actual deadline and enforces it independently of what the client displays).
- If the timer expires without a pick, the server auto-forfeits: the stalling player's current top card moves to the next player in turn order exactly as if they'd lost the round outright, and the turn passes to that next player.
- Every player starts a match with 3 lives. A life is spent **only** by letting the timer expire — losing a round normally never costs a life.
- Reaching 0 lives eliminates that player immediately, however many cards they still hold; their entire remaining deck moves to the next player in turn order so the "owns every card" win condition stays reachable.
- An eliminated player (by lives or by running out of cards) may leave the room right away instead of being forced to spectate until the match ends.

## Comparison

- Server evaluates the chosen statistic across every active (non-eliminated) player's current top card.
- Highest value wins the round — **except** economy rate, bowling average, and bowling strike rate, where the lowest value wins (cricket-correct: a lower economy/average is the better bowling performance).
- BEST BOWLING (a "wickets/runs conceded" figure, e.g. "4/25") uses the standard cricket rule instead of a plain number comparison: more wickets always wins outright; among equal wickets, fewer runs conceded wins.
- Server broadcasts the full result set; client animates the reveal.

## Tie rule — exact, no exceptions

If two or more players tie on the highest value for the chosen statistic:

- Do **not** draw, reveal, or replace any cards. The exact same top cards stay in play for the tied players.
- Tied players choose again from a **different, not-yet-used statistic** on those same cards (server enforces "not already used in this tie sequence").
- Repeat until the tie breaks. The server owns and tracks the tie sequence/used-statistics set for that comparison.
- Only after a tie resolves does card collection happen.

## Card collection

- The round winner collects the top card from every losing (non-tied-out) player.
- Collected-card ordering into the winner's pile must be deterministic per the server's rules (not client-decided, not random at collection time).
- The winner takes the next turn.

## Elimination

- A player reaching zero cards is eliminated: removed from comparisons, but stays connected as a spectator (not force-disconnected) until the match ends. UI must clearly mark `ELIMINATED`.

## Win condition

- A player wins by owning all cards in the game. Only the server may declare a winner — the client must never self-declare victory.

## Edge cases the server must handle

2-player and 6-player games; disconnect/reconnect mid-turn; leaving lobby or game; network flakiness; server restart/recovery; concurrent/duplicate/out-of-order/delayed WebSocket messages; invalid or post-timeout statistic selection; repeated ties (2-way, 3+ way, multi-level); multiple players hitting zero cards simultaneously; final-round conditions; actions against an already-started or already-ended game/room; room-full and invalid-room-code joins; duplicate room joins; duplicate reward/transaction requests; race conditions; reconnecting mid round-result animation.

## Reconnection

Connection states: `CONNECTED / RECONNECTING / DISCONNECTED / SERVER_UNAVAILABLE / SYNCING`.

On reconnect: re-authenticate if needed → identify the active game → pull the current authoritative `GameState` from the server → resync the client fully → resume. The client must never assume it remembers what happened while disconnected; the server is always the source of truth (see `docs/ARCHITECTURE.md` for the state machine and persistence strategy).
