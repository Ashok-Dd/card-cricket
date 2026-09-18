# Card Cricket — Original Master Development Prompt

This is the full, verbatim master specification supplied by the user on 2026-09-18. It is preserved here as the canonical long-form reference. `CLAUDE.md` and the other files in `docs/` (`GAME_RULES.md`, `ARCHITECTURE.md`, `ECONOMY.md`, `CARD_DESIGN.md`, `ROADMAP.md`) are condensed, actionable derivatives of this document — prefer those for day-to-day work, and come back to this file when a derivative seems ambiguous or incomplete.

Note: the spec title says "CARD CRICKET" and its body refers to the game as "Cricket Clash". The user has since confirmed the product name is **Card Cricket** — treat every "Cricket Clash" mention below as superseded by that decision.

---

## 1. PROJECT OVERVIEW

Build a **premium mobile-only online multiplayer cricket card game** called **Cricket Clash**.

The game combines:

* Cricket player collectible cards
* Top-Trumps-style statistic comparison
* Real-time multiplayer
* Room-based gameplay
* Multiple cricket formats/card sets
* Virtual coin economy
* Competitive progression
* Premium gaming UI
* High-quality animations, effects, sounds, and celebrations

This is a **mobile application**, not a website.

The mobile client must be built using:

**Flutter + Dart**

The backend should be:

**NestJS + TypeScript**

Recommended infrastructure:

* PostgreSQL — persistent data
* Redis — live game state, rooms, caching and real-time coordination
* WebSockets / Socket.IO — real-time multiplayer
* Object storage/CDN — player/card images
* REST APIs — authentication, profiles, card data, wallet, history, etc.

The architecture must be production-oriented and scalable rather than a simple college/demo application.

---

# 2. CORE GAME CONCEPT

Each card represents a real cricket player.

Every card contains multiple statistics.

Example statistics:

* Total Runs
* Total Wickets
* Strike Rate
* Batting Average
* Bowling Average
* Best Batting Score
* Best Bowling Figures
* Economy Rate
* Centuries
* Half Centuries
* Fours
* Sixes
* Matches
* Innings
* Catches
* Stumpings where applicable

The exact statistics depend on the selected cricket format/card set.

Players compete by selecting one statistic from their current top card.

Example:

Player A's card:

> Strike Rate: 151.2

Player B's card:

> Strike Rate: 137.8

Player C's card:

> Strike Rate: 142.4

Player A wins because 151.2 is the highest.

---

# 3. MULTIPLAYER

Support:

* Minimum: 2 players
* Maximum: 6 players

The game must support:

* 2-player matches
* 3-player matches
* 4-player matches
* 5-player matches
* 6-player matches

Players should be able to:

1. Create a room
2. Receive a room code
3. Share the room code
4. Other players join using the code
5. Lobby displays connected players
6. Host starts the game when requirements are satisfied

Future matchmaking can be added later.

---

# 4. CARD SETS / CRICKET FORMATS

The game must support multiple card sets.

Initial card sets:

1. IPL
2. ODI
3. TEST
4. T20

The architecture must NOT hardcode these four sets.

It must support adding future card sets without rebuilding the entire application.

Potential future sets:

* T20 Internationals
* ODI World Cup
* T20 World Cup
* Champions Trophy
* Asia Cup
* IPL individual seasons
* IPL Legends
* World Cricket Legends
* Indian Cricket Legends
* International Legends
* Women's Cricket
* Domestic Cricket
* Country-specific collections
* Decade-based collections
* Special tournament collections
* Franchise-specific collections

The database must determine which card sets are available.

---

# 5. PLAYER DATABASE ARCHITECTURE

Do NOT create completely separate player entities for every format.

Use a central player entity.

Example:

```text
Player
  id: virat_kohli
  name: Virat Kohli
  country: India
  role: Batsman
  image: ...
```

Then maintain format/card-set-specific statistics.

Example:

```text
Virat Kohli
    IPL statistics
    ODI statistics
    TEST statistics
    T20 statistics
```

Therefore:

**One player + multiple statistical profiles.**

The same player can appear in multiple card sets but with the appropriate statistics.

Never compare:

```text
IPL Strike Rate
vs
ODI Strike Rate
```

inside the same game.

All cards in a match must belong to the same compatible card set/format.

---

# 6. LARGE PLAYER DATABASE

The system should support **hundreds or thousands of cricket players**.

Do not populate only famous players.

Include, where data/licensing permits:

* Current players
* Former players
* Legends
* International players
* IPL players
* Domestic players
* Different generations
* Different countries
* Different roles
* Women's cricket where supported

Player data should support:

* Name
* Display name
* Country
* Country flag
* Role
* Batting style
* Bowling style
* Team/franchise
* Career period
* Player image
* Active/retired status
* Supported card sets
* Statistics
* Rarity
* Card version

The architecture must support historical and seasonal statistics.

---

# 7. CARD MODEL

A card should be treated as a game entity generated from:

```text
Player
+
Card Set
+
Statistics
+
Card Metadata
```

Example:

```text
Card
  playerId
  cardSetId
  rarity
  rating
  stats
  image
```

Possible rarity system:

* Common
* Rare
* Epic
* Legendary
* Iconic

Keep the rarity system extensible.

---

# 8. GAME START

When the host starts the game:

The **server** must:

1. Validate the room
2. Validate player count
3. Validate card set
4. Validate entry requirements
5. Retrieve eligible cards
6. Securely shuffle the deck
7. Distribute cards equally
8. Determine starting player
9. Create game state
10. Broadcast initial game state

The client must NEVER perform the authoritative shuffle.

Do not trust the mobile client for:

* Card order
* Card ownership
* Statistic values
* Winner determination
* Coin balances
* Rewards
* Turn validation

The server is authoritative.

---

# 9. CARD DISTRIBUTION

Cards should be distributed as equally as possible.

The server maintains each player's pile/deck.

Each player should only need the information required to render their current card and game state.

Do not unnecessarily send the complete hidden deck of every player to every client.

---

# 10. TURN SYSTEM

Only one player controls the current turn.

The current player sees statistic-selection buttons.

Example:

```text
STRIKE RATE
RUNS
WICKETS
AVERAGE
BEST SCORE
CENTURIES
SIXES
```

The player selects a statistic by tapping a button.

They do NOT manually enter a value.

The server validates the selected statistic.

---

# 11. ROUND COMPARISON

Once a statistic is selected:

The server evaluates that statistic for every active player's top card.

Example:

```text
Player A → 151.2
Player B → 138.7
Player C → 144.9
Player D → 129.4
```

Highest value wins.

The server broadcasts the result.

The UI should reveal the values with an exciting comparison animation.

---

# 12. CRITICAL TIE RULE

If two or more players have exactly the same highest value:

**DO NOT draw another card.**

**DO NOT reveal a new card.**

**DO NOT replace the current cards.**

The exact same cards remain in play.

The tied players use another statistic from those same cards.

Example:

```text
Strike Rate

Player A → 145.5
Player B → 145.5
```

Tie.

Now:

```text
Runs

Player A → 5,240
Player B → 4,981
```

Player A wins.

If another tie occurs, continue selecting another valid statistic from the same cards.

The system must prevent selecting a statistic already used in that tie sequence unless the game rules explicitly allow it.

The server controls the tie sequence.

---

# 13. WINNER CARD COLLECTION

After determining the winner:

The winner collects the top card from every losing player.

Example:

```text
Before:
A → 10 cards
B → 10 cards
C → 10 cards

A wins.

After:
A → 12 cards
B → 9 cards
C → 9 cards
```

The exact ordering of collected cards must be deterministic according to the server's game rules.

The winner receives the next turn.

---

# 14. ELIMINATION

A player with zero cards is eliminated.

They should no longer participate in comparisons.

They may remain connected as a spectator until the game ends.

The UI should clearly display:

```text
ELIMINATED
```

Do not immediately disconnect eliminated players.

---

# 15. WIN CONDITION

Default win condition:

**A player wins when they own all cards in the game.**

The server declares the winner.

Never allow the client to declare itself winner.

---

# 16. EDGE CASES

Handle all of the following:

* 2 players
* 6 players
* Player disconnect during turn
* Player reconnect
* Player leaves lobby
* Player leaves game
* Temporary network failure
* Server restart/recovery
* Multiple simultaneous messages
* Duplicate statistic selection
* Invalid statistic selection
* Selection after timeout
* Repeated ties
* 2-way tie
* 3+ player tie
* Tie after several tie-breakers
* Player reaching zero cards
* Multiple players reaching zero cards
* Final round
* Game already ended
* Room already started
* Room full
* Invalid room code
* Duplicate room join
* Duplicate reward request
* Duplicate transaction
* Race conditions
* Delayed WebSocket events
* Reordered events
* Reconnection during round result animation

---

# 17. NETWORK RECONNECTION

Network interruption must NOT destroy the player's match.

Implement:

```text
CONNECTED
RECONNECTING
DISCONNECTED
SERVER_UNAVAILABLE
SYNCING
```

When reconnecting:

1. Authenticate again if required
2. Identify active game
3. Request current authoritative game state
4. Synchronize the client
5. Restore exact game state
6. Resume gameplay

Do not depend on the client remembering what happened.

The server state is the source of truth.

---

# 18. VIRTUAL COIN ECONOMY

Add a **virtual in-game coin system**.

Coins are game currency only.

Initial version:

* No cash withdrawal
* No cash-out
* No conversion to real money
* No real-money wagering

The economy should be designed modularly so future features can be added safely and separately.

---

# 19. COIN EARNING

Players can earn virtual coins through:

* Welcome reward
* Daily login
* Winning matches
* Completing matches
* Missions
* Achievements
* Streaks
* Events
* Tournament rewards
* Seasonal rewards
* Other server-controlled rewards

Example:

```text
Daily Reward → +100 coins
Match Win → +500 coins
Achievement → +1000 coins
```

Values should be configurable from the backend.

Do NOT hardcode the economy into Flutter.

---

# 20. ENTRY-BASED ROOMS

Allow rooms to have virtual coin entry amounts.

Example:

```text
FREE
100 COINS
500 COINS
1,000 COINS
5,000 COINS
```

Before joining:

```text
Entry: 1,000 coins
Players: 6
Virtual Reward Pool: 6,000 coins
```

The actual reward distribution must be controlled by the server and configured game rules.

The client must never calculate or award coins authoritatively.

---

# 21. COIN TRANSACTION LEDGER

Do not rely only on:

```text
user.balance
```

Maintain an immutable transaction ledger.

Example:

```text
CoinTransaction

id
userId
type
amount
balanceAfter
gameId
description
createdAt
```

Transaction types:

```text
WELCOME_REWARD
DAILY_REWARD
GAME_ENTRY
GAME_REWARD
ACHIEVEMENT_REWARD
TOURNAMENT_REWARD
REFUND
ADMIN_ADJUSTMENT
```

Every transaction must have an idempotency/unique identifier.

Prevent:

* Double deduction
* Double rewards
* Negative balances
* Replay attacks
* Duplicate victory rewards
* Fake game completion
* Reconnect exploits

Use database transactions where required.

---

# 22. ENTRY RESERVATION

When a player enters a coin-based match:

The server should verify the balance.

Reserve or deduct the required virtual coins atomically.

If a match fails because of a technical/server issue, implement a controlled refund mechanism.

The system must distinguish:

```text
AVAILABLE
RESERVED
SPENT
REFUNDED
```

where appropriate.

---

# 23. WALLET SCREEN

Create a premium wallet screen.

Display:

```text
Current Balance
```

and transaction history:

```text
+500   Match Victory
-100   Match Entry
+100   Daily Reward
+1000  Achievement
```

Animate coin balance changes.

Use:

* Coin particles
* Counter animation
* Glow
* Sound
* Haptic feedback

---

# 24. ROOM CREATION FLOW

Create Room screen:

```text
Select Card Set
    IPL
    ODI
    TEST
    T20

Select Entry
    Free
    100
    500
    1000
    5000

Players
    2–6

Create Room
```

Show:

* Selected card set
* Entry amount
* Player limit
* Expected virtual reward pool
* Room code after creation

---

# 25. JOIN ROOM FLOW

Join Room screen:

```text
ENTER ROOM CODE
```

Validate the code server-side.

Possible states:

* Room not found
* Room full
* Game already started
* Invalid code
* Insufficient coins
* Successfully joined

---

# 26. LOBBY

Premium lobby screen.

Display:

* Room code
* Copy/share button
* Selected card set
* Entry amount
* Player slots
* Connected players
* Ready status
* Host indicator
* Player avatars
* Start button for host

Example:

```text
CRICKET CLASH

ROOM: AX72KP

IPL
1,000 COINS

● Ashok — Host
● Player 2
● Player 3
○ Waiting
○ Waiting
○ Waiting

3 / 6 Players

[ READY ]

[ START GAME ]
```

---

# 27. HOME SCREEN

Premium gaming home screen.

Primary actions:

```text
PLAY ONLINE
CREATE ROOM
JOIN ROOM
```

Secondary actions:

```text
HOW TO PLAY
WALLET
PROFILE
SETTINGS
```

Show:

* Coin balance
* Current level
* Daily reward
* Recent match
* Featured card set
* Missions
* Events

Avoid making the screen visually cluttered.

---

# 28. GAME SCREEN

The game screen is the most important screen.

It should display:

### Top

* Round number
* Room/game status
* Connection indicator
* Coin/entry information where relevant

### Other players

For each active player:

* Avatar
* Name
* Card count
* Turn indicator
* Eliminated state

Do not reveal hidden cards.

### Center

Opponent/card comparison area.

### Bottom

Current player's card.

Display:

* Player image
* Player name
* Country
* Team
* Role
* Rating
* Relevant statistics

### Statistic selection

Large, clear buttons.

Example:

```text
RUNS
WICKETS
STRIKE RATE
AVERAGE
BEST SCORE
100s
50s
SIXES
```

Only valid statistics should be selectable.

---

# 29. CARD DESIGN

Cards are the visual heart of the game.

Create a reusable:

```text
CricketCard
```

component.

Card design should include:

* Player image
* Player name
* Country flag
* Team
* Role
* Rating
* Statistics
* Card set
* Rarity
* Premium border
* Gradient
* Shadow
* Reflection
* Subtle glow

Possible visual hierarchy:

```text
ICONIC
LEGENDARY
EPIC
RARE
COMMON
```

Each rarity should have its own visual treatment.

Do not overuse effects.

Readability must remain excellent.

---

# 30. PREMIUM VISUAL STYLE

Overall visual direction:

**Modern sports esports + collectible card game.**

Suggested foundation:

* Deep black
* Deep navy
* Dark green
* Electric green
* Neon blue
* Gold
* White
* Subtle gradients

Use:

* Glass effects
* Metallic reflections
* Soft glow
* Depth
* Shadows
* Card highlights
* Dynamic lighting

Avoid:

* Generic Flutter UI
* Plain Material cards
* Excessive gradients
* Excessive blur
* Clutter
* Emoji-based UI
* Slow animations

The result should look like a commercially designed mobile game.

---

# 31. CARD ANIMATIONS

Implement polished animations for:

### Card dealing

Cards fly from the deck to players.

### Card flip

3D-style reveal animation.

### Statistic selection

Selected statistic:

* Scales slightly
* Glows
* Locks
* Sends visual feedback

### Comparison

Reveal values with staged animation.

Example:

```text
151.2
   ↓
138.7
   ↓
144.9
```

Then highlight the winning value.

### Winner

Winning card:

* Glow
* Scale
* Particle burst
* Highlight

### Collection

Cards visually fly from losing players toward the winner's pile.

### Turn transition

Clear animation showing the new active player.

---

# 32. TIE ANIMATION

When a tie happens:

Show:

```text
TIE!
```

Use a special visual effect.

Then show:

```text
CHOOSE ANOTHER STAT
```

Keep the same cards visible.

Clearly communicate that the same cards are being used.

---

# 33. REWARD ANIMATIONS

When a player wins a round:

Show a lightweight reward effect.

Examples:

* Coin sparkle
* Small particle burst
* Card collection animation
* Winner glow

Do NOT use huge confetti after every tiny action.

---

# 34. FINAL VICTORY

When the game ends:

Create a major celebration.

Include:

* Full-screen victory animation
* Confetti explosion
* Golden particles
* Trophy
* Winner banner
* Player card
* Coins earned
* Cards collected
* Match statistics
* Sound
* Haptic feedback

Example:

```text
CHAMPION!

ASHOK

ALL CARDS COLLECTED

+3,000 COINS

Rounds Won: 12
Cards Collected: 30
```

Make this moment feel rewarding.

---

# 35. AUDIO

Support:

* Button click
* Card flip
* Card selection
* Countdown
* Tie
* Comparison
* Round victory
* Card collection
* Coin reward
* Final victory
* Error
* Room join
* Player ready

Settings:

```text
Sound Effects ON/OFF
Music ON/OFF
Haptics ON/OFF
```

Use audio sparingly and intelligently.

---

# 36. PROFILE

Profile screen:

```text
Avatar
Username
Level
Coins

Games Played
Games Won
Rounds Won
Cards Collected
Win Percentage

Favorite Player
```

Future:

* Achievements
* Badges
* Match history
* Card collection
* Statistics
* Leaderboards

---

# 37. PROGRESSION

Design the architecture for:

* XP
* Levels
* Achievements
* Daily missions
* Streaks
* Badges
* Seasonal progression
* Leagues
* Tournaments
* Card collections
* Cosmetics

These can be implemented after the MVP.

---

# 38. HOW TO PLAY

Create an interactive tutorial.

Teach:

1. Join a room
2. Receive cards
3. View your top card
4. Choose a statistic
5. Compare values
6. Win the round
7. Collect cards
8. Handle ties
9. Eliminate opponents
10. Win by collecting all cards

Use animated cards instead of a text-heavy tutorial.

---

# 39. FLUTTER ARCHITECTURE

Use feature-based architecture.

Suggested structure:

```text
lib/

  core/
    constants/
    theme/
    routing/
    network/
    storage/
    audio/
    animations/
    error/
    utils/

  features/

    auth/
      data/
      domain/
      presentation/

    home/
      presentation/

    lobby/
      data/
      domain/
      presentation/

    game/
      data/
      domain/
      presentation/
        screens/
        widgets/
        animations/
        state/

    card_sets/
      data/
      domain/
      presentation/

    wallet/
      data/
      domain/
      presentation/

    profile/
      data/
      domain/
      presentation/

    tutorial/
      presentation/

    settings/
      presentation/

  shared/
    widgets/
    models/
    extensions/
```

Use clean separation between:

```text
UI
State
Business logic
Repositories
Network
Models
```

---

# 40. FLUTTER TECHNOLOGY

Recommended:

* Flutter
* Dart
* Riverpod
* GoRouter
* Dio
* Socket.IO/WebSocket client
* Local secure storage
* Cached network images
* Flutter animation APIs
* A suitable particle/confetti package where needed
* Haptic feedback
* Audio package

Use `const` widgets wherever possible.

Avoid unnecessary rebuilds.

---

# 41. BACKEND ARCHITECTURE

Use:

**NestJS + TypeScript**

Suggested modules:

```text
AuthModule
UsersModule
PlayersModule
CardSetsModule
CardsModule
RoomsModule
LobbyModule
GameModule
WalletModule
RewardsModule
AchievementsModule
LeaderboardModule
AdminModule
```

WebSocket gateway:

```text
GameGateway
```

REST APIs:

```text
/auth
/users
/players
/card-sets
/rooms
/wallet
/profile
```

---

# 42. DATABASE

Use PostgreSQL.

Core tables/entities should include:

```text
users
players
player_statistics
card_sets
cards
games
game_players
game_rounds
game_events
wallets
coin_transactions
achievements
user_achievements
missions
user_missions
```

Design relationships carefully.

Do not duplicate player data unnecessarily.

---

# 43. REDIS

Use Redis for:

* Active rooms
* Lobby state
* Active games
* Turn state
* Temporary game state
* WebSocket coordination
* Reconnection state
* Distributed locks where required
* Caching
* Rate limiting

Persistent match history should ultimately be stored in PostgreSQL.

---

# 44. SERVER GAME STATE

The server should maintain state similar to:

```text
GameState

gameId
roomId
cardSetId
status
roundNumber
currentPlayerId
players[]
activeCards
playerCardCounts
selectedStatistic
tieState
roundState
winnerId
createdAt
updatedAt
```

Do not expose hidden information unnecessarily.

---

# 45. GAME STATE MACHINE

Implement explicit game states.

Example:

```text
WAITING
STARTING
DEALING
PLAYER_TURN
STATISTIC_SELECTED
COMPARING
TIE
ROUND_RESULT
COLLECTING_CARDS
NEXT_TURN
PLAYER_ELIMINATED
GAME_FINISHED
```

This prevents invalid transitions.

---

# 46. SERVER AUTHORITY

The server is the only authority for:

* Shuffle
* Card ownership
* Card order
* Current turn
* Valid actions
* Statistic values
* Comparison
* Tie handling
* Card transfer
* Elimination
* Winner
* Coin deduction
* Coin rewards
* Match completion

The Flutter application is a rendering/input client.

---

# 47. SECURITY

Implement:

* JWT authentication
* Secure token storage
* Server-side authorization
* Input validation
* Rate limiting
* Room authorization
* WebSocket authentication
* Idempotency
* Database transactions
* Atomic coin operations
* Game state validation
* Anti-replay protection
* Duplicate event protection

Never trust values sent from the mobile application.

For example, the client should send:

```text
"select statistic = strike_rate"
```

Not:

```text
"my strike rate = 151.2"
```

The server obtains the actual value from the authoritative card data.

---

# 48. REAL-TIME EVENTS

Design typed events.

Examples:

```text
room:joined
room:updated
game:starting
game:state
turn:started
statistic:selected
comparison:started
comparison:result
game:tie
cards:collected
player:eliminated
game:finished
wallet:updated
player:reconnected
player:disconnected
error
```

Use event IDs/sequence numbers where useful.

Clients must handle duplicate and delayed events safely.

---

# 49. GAME RECOVERY

If the backend restarts or a player reconnects:

The system must recover the authoritative match state where possible.

Do not rely entirely on in-memory Flutter state.

Use Redis/database persistence strategy appropriate for active matches.

---

# 50. CARD SET MANAGEMENT

Card sets must be database-driven.

Admin should eventually be able to:

* Create card set
* Edit card set
* Enable/disable set
* Add players
* Remove players
* Update statistics
* Update images
* Set rarity
* Configure card count
* Configure supported statistics

Flutter should fetch card-set metadata dynamically.

Do NOT hardcode:

```text
IPL = 100 cards
ODI = 150 cards
```

The backend should provide actual values.

---

# 51. PLAYER SEARCH

Build efficient search.

Support:

```text
Player name
Country
Role
Card set
Team
Era
Year
```

For large datasets:

* Server-side pagination
* Search indexes
* Caching
* Optimized API responses

Do not download thousands of player records unnecessarily.

---

# 52. IMAGE MANAGEMENT

Player images should be optimized.

Use:

* CDN
* Compression
* Appropriate resolutions
* Cached network images
* Lazy loading

Do not load full-resolution images when thumbnails are sufficient.

---

# 53. PERFORMANCE

The application must feel fast.

Target:

**Smooth 60 FPS experience where device capability permits.**

Priorities:

* Avoid unnecessary widget rebuilds
* Use `const`
* Efficient Riverpod providers
* Lazy loading
* Image caching
* Minimal API calls
* Efficient WebSocket updates
* Dispose animation/controllers correctly
* Avoid memory leaks
* Avoid excessive blur
* Avoid expensive shadows everywhere
* Avoid unnecessarily large images
* Keep animations short and responsive

---

# 54. RESPONSIVE MOBILE DESIGN

Support:

* Small phones
* Normal phones
* Large phones
* Different aspect ratios
* Android
* iOS

Primary target:

**Android**

But keep the Flutter application cross-platform.

Use responsive layouts rather than fixed pixel positioning.

---

# 55. ERROR STATES

Create polished error screens/dialogs.

Examples:

```text
ROOM NOT FOUND

This room doesn't exist or has expired.
```

```text
ROOM FULL

This room already has 6 players.
```

```text
INSUFFICIENT COINS

You need 1,000 coins to enter this room.
```

```text
CONNECTION LOST

Trying to reconnect...
```

```text
GAME ENDED

This match has already finished.
```

Do not use generic ugly error messages.

---

# 56. LOADING STATES

Avoid generic spinners where possible.

Use game-themed loading:

* Shuffling cards
* Card skeletons
* Animated deck
* Glowing card backs

Loading should feel like part of the game.

---

# 57. MICRO-INTERACTIONS

Implement subtle interactions:

* Button press animation
* Card tilt
* Card glow
* Haptic feedback
* Statistic selection
* Ready status
* Player join
* Countdown
* Card count changes
* Coin balance changes
* Winner transitions

The app should feel responsive to every action.

---

# 58. UI DESIGN PRINCIPLE

The game must always make these things obvious:

1. Whose turn is it?
2. What card do I have?
3. What statistics can I choose?
4. What statistic was selected?
5. What are the compared values?
6. Who won?
7. Which cards were collected?
8. How many cards does each player have?
9. What happens next?

Do not sacrifice usability for visual effects.

---

# 59. MVP

Build the first production-quality MVP with:

### Mobile

* Flutter
* Authentication
* Home
* Create Room
* Join Room
* Lobby
* 2–6 players
* Card set selection
* IPL
* ODI
* TEST
* T20
* Cricket cards
* Card statistics
* Real-time gameplay
* Server shuffle
* Equal distribution
* Turn system
* Statistic selection
* Comparison
* Same-card tie breaker
* Card transfer
* Elimination
* Winner detection
* Reconnection
* Virtual coins
* Coin entry rooms
* Wallet
* Transaction history
* Basic profile
* How to Play
* Premium animations
* Round celebration
* Final victory celebration

---

# 60. FUTURE FEATURES

Design the architecture so these can be added later:

* Matchmaking
* Friends
* Friend requests
* Private rooms
* Public rooms
* Leaderboards
* Rankings
* Achievements
* XP
* Levels
* Seasons
* Leagues
* Tournaments
* Daily missions
* Streaks
* Card collection
* Card upgrades
* More rarities
* Cosmetics
* Player frames
* Emotes
* Spectator mode
* Replay system
* Match history
* Advanced statistics
* Country competitions
* Women's cricket
* Historical cricket
* Tournament-specific sets
* Seasonal card sets
* Events

---

# 61. DEVELOPMENT PRINCIPLE

Do not build this as a simple CRUD application.

It should feel like:

**A real-time competitive cricket game with collectible cards.**

Prioritize:

```text
Game correctness
+
Server authority
+
Fast networking
+
Premium UI
+
Smooth animations
+
Clear UX
+
Scalable architecture
+
Security
```

over unnecessary complexity.

---

# 62. IMPLEMENTATION ORDER

Build incrementally.

### Phase 1 — Foundation

* Flutter project
* Theme
* Routing
* Architecture
* Backend
* Database
* Authentication

### Phase 2 — Cricket Data

* Players
* Statistics
* Card sets
* Card model
* Images
* Admin/data management

### Phase 3 — Rooms

* Create room
* Join room
* Room code
* Lobby
* Ready system

### Phase 4 — Game Engine

* Shuffle
* Distribution
* Turn system
* Statistic selection
* Comparison
* Tie system
* Card transfer
* Elimination
* Winner

### Phase 5 — Real-Time

* WebSockets
* Reconnection
* State synchronization
* Event validation
* Recovery

### Phase 6 — Economy

* Wallet
* Coin ledger
* Rewards
* Entry rooms
* Refund handling
* Idempotency

### Phase 7 — Visual Polish

* Card animations
* Flip
* Shine
* Glow
* Particles
* Collection animations
* Victory celebration
* Sound
* Haptics

### Phase 8 — Testing

Test:

* 2-player games
* 6-player games
* Disconnects
* Reconnects
* Ties
* Multiple ties
* Elimination
* Final victory
* Duplicate requests
* Coin exploits
* Race conditions
* Server recovery

---

# 63. CODE QUALITY

Write production-quality code.

Requirements:

* Strong typing
* Clear naming
* Small reusable components
* Feature-based architecture
* Repository pattern where appropriate
* Centralized constants
* Centralized theme
* Typed API models
* Typed WebSocket events
* Error handling
* Logging
* Validation
* Unit tests
* Integration tests
* Game-engine tests

Avoid:

* Giant widgets
* Giant service classes
* Hardcoded game rules
* Hardcoded player data
* Hardcoded coin balances
* Hardcoded room state
* Business logic inside UI
* Client-authoritative gameplay

---

# 64. MOST IMPORTANT RULE

The game must be **server-authoritative**.

The Flutter client should essentially say:

```text
"I want to select Strike Rate."
```

The server decides:

```text
Is it your turn?
Is Strike Rate valid?
What is your actual card?
What are the other players' values?
Who wins?
Who receives the cards?
What is the next turn?
What coins are awarded?
```

Then the server sends the result to every client.

This prevents cheating and keeps every player's game state synchronized.

---

# 65. FINAL PRODUCT VISION

The finished application should feel like a combination of:

**Cricket + Collectible Cards + Competitive Multiplayer + Top-Trumps-style Gameplay + Esports Presentation**

It should be:

* Fast
* Competitive
* Addictive through gameplay progression
* Visually premium
* Easy to understand
* Difficult to exploit
* Scalable to large player/card databases
* Ready for future card sets
* Ready for future competitive modes

The experience should make players feel:

> "I'm playing a real cricket battle, not filling out a statistics form."

Build the product with a **mobile-game mindset**, not a generic business-app mindset.
