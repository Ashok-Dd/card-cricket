import { randomInt } from 'node:crypto';
import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CardsService } from '../cards/cards.service.js';
import { GameStatus, RoomStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { GameLockService } from './game-lock.service.js';
import { GameServerEvent } from './game-events.constants.js';
import { GameStateStore } from './game-state.store.js';
import type { GamePlayerState, GameState } from './game-state.types.js';
import { GameTurnTimerService } from './game-turn-timer.service.js';
import { RealtimeService } from './realtime.service.js';
import { determineWinners, extractComparisonValue, isSelectableStatistic } from './stat-comparison.util.js';

/// How long a player has to pick a statistic before the server forfeits
/// their turn for them (docs/GAME_RULES.md's "post-timeout statistic
/// selection" edge case). Matches the client's own cosmetic countdown
/// (game_screen.dart's `_turnDurationSeconds`) — keep both in sync.
const TURN_TIMEOUT_MS = 30_000;

/// Anti-stall lives: letting the turn timer expire costs one, independent of
/// the normal "ran out of cards" elimination. Reaching 0 ends the game for
/// that player outright, however many cards they still hold.
const TURN_TIMEOUT_STARTING_LIVES = 3;

@Injectable()
export class GameEngineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cardsService: CardsService,
    private readonly walletService: WalletService,
    private readonly stateStore: GameStateStore,
    private readonly lock: GameLockService,
    private readonly realtime: RealtimeService,
    private readonly config: ConfigService,
    private readonly turnTimer: GameTurnTimerService,
  ) {}

  /// Shuffles + deals, debits every player's entry, and writes the initial
  /// live GameState. Called by RoomsService.start() right after it creates
  /// the Game/GamePlayer rows. No broadcast here — a client's first
  /// game:state arrives when it calls game:subscribe after navigating in.
  startGame(gameId: string): Promise<void> {
    return this.lock.withLock(gameId, () => this.doStartGame(gameId));
  }

  private async doStartGame(gameId: string): Promise<void> {
    const game = await this.prisma.game.findUnique({
      where: { id: gameId },
      include: { room: true, players: { orderBy: { seatOrder: 'asc' } } },
    });
    if (!game) {
      throw new NotFoundException(`Game "${gameId}" not found`);
    }

    const cards = await this.cardsService.getEligibleCardsForCardSet(game.cardSetId);
    if (cards.length < game.players.length) {
      throw new BadRequestException('Not enough cards in this card set to deal to every player');
    }

    // Shuffling the full pool first, then slicing, gives a uniformly random
    // deckSize-sized subset AND a randomized deal order in one step — a
    // room's chosen deck size (e.g. 50/100/200) never favors highest-rated
    // cards over others (room.deckSize null means "use every eligible
    // card", today's original behavior).
    let shuffled = fisherYatesShuffle(cards.map((card) => card.id));
    if (game.room.deckSize != null) {
      shuffled = shuffled.slice(0, game.room.deckSize);
    }
    const piles: string[][] = game.players.map(() => []);
    shuffled.forEach((cardId, index) => {
      piles[index % game.players.length]!.push(cardId);
    });

    await this.prisma.$transaction(async (tx) => {
      for (const player of game.players) {
        await this.walletService.deductGameEntry(tx, player.userId, gameId, game.room.entryAmount);
      }
      await tx.game.update({ where: { id: gameId }, data: { status: GameStatus.IN_PROGRESS, startedAt: new Date() } });
    });

    const players: GamePlayerState[] = game.players.map((player, index) => ({
      userId: player.userId,
      cardIds: piles[index]!,
      isEliminated: false,
      cardsWonCount: 0,
      livesRemaining: TURN_TIMEOUT_STARTING_LIVES,
    }));

    const state: GameState = {
      gameId,
      roomId: game.roomId,
      cardSetId: game.cardSetId,
      entryAmount: game.room.entryAmount,
      roundNumber: 1,
      currentPlayerId: players[0]!.userId,
      players,
      roundActivePlayerIds: players.map((p) => p.userId),
      tieState: null,
      eliminationOrder: [],
      eventSequence: 0,
      status: 'PLAYER_TURN',
    };

    await this.stateStore.save(state);
    this.scheduleTurnTimeout(state);
  }

  async getStateForUser(gameId: string, userId: string) {
    const state = await this.stateStore.load(gameId);
    return this.buildPersonalizedState(state, userId);
  }

  private async buildPersonalizedState(state: GameState, userId: string) {
    const me = state.players.find((p) => p.userId === userId);
    if (!me) {
      throw new ForbiddenException('You are not a player in this game');
    }

    const myTopCardId = me.cardIds[0] ?? null;
    const myCard = myTopCardId ? await this.getCardWithStats(myTopCardId) : null;

    return {
      gameId: state.gameId,
      cardSetId: state.cardSetId,
      roundNumber: state.roundNumber,
      currentPlayerId: state.currentPlayerId,
      status: state.status,
      winnerId: state.winnerId ?? null,
      tieState: state.tieState,
      players: state.players.map((p) => ({
        userId: p.userId,
        cardCount: p.cardIds.length,
        isEliminated: p.isEliminated,
        isCurrentTurn: p.userId === state.currentPlayerId,
        livesRemaining: p.livesRemaining,
      })),
      myCard: myCard
        ? {
            id: myCard.id,
            rarity: myCard.rarity,
            rating: myCard.rating,
            imageUrl: myCard.imageUrl,
            player: myCard.player,
            statistics: myCard.statistics,
            selectableStatistics: myCard.selectableFields,
          }
        : null,
    };
  }

  private async getCardWithStats(cardId: string) {
    const card = await this.prisma.card.findUnique({
      where: { id: cardId },
      include: { player: true, statistics: true, cardSet: true },
    });
    if (!card) {
      throw new NotFoundException(`Card "${cardId}" not found`);
    }
    const schema = card.cardSet.statSchema as { batting: string[]; bowling: string[] };
    const schemaFields = [...schema.batting, ...schema.bowling];
    const statsRecord = card.statistics as unknown as Record<string, unknown>;
    const selectableFields = schemaFields.filter((field) =>
      isSelectableStatistic(field, schemaFields, statsRecord),
    );
    return { ...card, selectableFields };
  }

  selectStatistic(gameId: string, userId: string, statistic: string): Promise<void> {
    return this.lock.withLock(gameId, () => this.doSelectStatistic(gameId, userId, statistic));
  }

  private async doSelectStatistic(gameId: string, userId: string, statistic: string): Promise<void> {
    const state = await this.stateStore.load(gameId);

    if (state.status === 'GAME_FINISHED') {
      throw new BadRequestException('This game has already finished');
    }
    if (state.currentPlayerId !== userId) {
      throw new ForbiddenException("It isn't your turn");
    }
    if (state.tieState && state.tieState.usedStatistics.includes(statistic)) {
      throw new BadRequestException(`"${statistic}" was already used in this tie — choose another`);
    }

    const comparisonPlayerIds = state.tieState
      ? state.tieState.contestingPlayerIds
      : state.players.filter((p) => !p.isEliminated).map((p) => p.userId);

    const playersById = new Map(state.players.map((p) => [p.userId, p]));
    const comparisonCardIds = new Map(
      comparisonPlayerIds.map((id) => [id, playersById.get(id)!.cardIds[0]!]),
    );

    const myCardId = comparisonCardIds.get(userId) ?? playersById.get(userId)!.cardIds[0]!;
    const myCard = await this.getCardWithStats(myCardId);
    if (!myCard.selectableFields.includes(statistic)) {
      throw new BadRequestException(`"${statistic}" isn't a valid selection for your current card`);
    }

    // Past this point the pick is genuinely happening — cancel the pending
    // timeout for this decision so it can't also fire (the next decision
    // point reschedules a fresh one below).
    this.turnTimer.clear(gameId);

    const revealedCards = await Promise.all(
      Array.from(comparisonCardIds.entries()).map(async ([playerId, cardId]) => {
        const card = await this.getCardWithStats(cardId);
        const raw = (card.statistics as unknown as Record<string, unknown>)[statistic];
        const { comparisonValue, displayValue } = extractComparisonValue(statistic, raw);
        return { playerId, comparisonValue, displayValue, card };
      }),
    );
    const values: Record<string, number | null> = Object.fromEntries(
      revealedCards.map((r) => [r.playerId, r.comparisonValue]),
    );
    const winners = determineWinners(values, statistic);

    // The full played card (player, stats, art) is deliberately revealed to
    // everyone here — that's exactly what a real Top Trumps comparison does;
    // hidden-hand secrecy only applies to cards that haven't been played
    // yet. winnerUserIds is explicit so the client never has to re-derive
    // who won from raw values (docs/GAME_RULES.md server-authority rule).
    // `value` is the raw display value (a number for plain stats, the
    // original "4/25" string for bestBowling) — never the internal
    // comparison score, which is a client-irrelevant implementation detail.
    const comparison = {
      statistic,
      winnerUserIds: winners,
      cards: revealedCards.map((r) => ({
        userId: r.playerId,
        value: r.displayValue,
        card: {
          id: r.card.id,
          rarity: r.card.rarity,
          rating: r.card.rating,
          imageUrl: r.card.imageUrl,
          player: r.card.player,
          statistics: r.card.statistics,
        },
      })),
    };
    this.realtime.broadcastToGame(gameId, GameServerEvent.ComparisonResult, comparison);

    state.eventSequence += 1;
    await this.recordEvent(state, GameServerEvent.ComparisonResult, { statistic, values, winners });

    if (winners.length > 1) {
      await this.handleTie(state, statistic, values, winners);
      return;
    }

    await this.handleRoundResolved(state, statistic, values, winners[0] ?? userId);
  }

  private async handleTie(
    state: GameState,
    statistic: string,
    values: Record<string, number | null>,
    contestingPlayerIds: string[],
  ): Promise<void> {
    const usedStatistics = [...(state.tieState?.usedStatistics ?? []), statistic];
    state.tieState = { contestingPlayerIds, usedStatistics };

    await this.writeGameRound(state, statistic, values, null, true);

    this.realtime.broadcastToGame(state.gameId, GameServerEvent.GameTie, {
      statistic,
      contestingPlayerIds,
    });

    await this.stateStore.save(state);
    await this.broadcastFreshState(state);
    this.scheduleTurnTimeout(state);
  }

  private async handleRoundResolved(
    state: GameState,
    statistic: string,
    values: Record<string, number | null>,
    winnerId: string,
  ): Promise<void> {
    const gameRound = await this.writeGameRound(state, statistic, values, winnerId, false);

    const winner = state.players.find((p) => p.userId === winnerId)!;
    const loserIds = state.roundActivePlayerIds.filter((id) => id !== winnerId);

    // Every card that took part in this round is "played" — including the
    // winner's own — and none of them may remain on top of their owner's
    // deck afterward. The winner's own played card returns to the BOTTOM of
    // their own deck (first), followed by the cards collected from each
    // loser (in seat order) — this is what actually advances the winner to
    // their *next* card instead of replaying the same one every round.
    const winnersOwnPlayedCard = winner.cardIds.shift();
    const collectedCardIds: string[] = [];

    for (const loserId of loserIds) {
      const loser = state.players.find((p) => p.userId === loserId)!;
      const collectedCardId = loser.cardIds.shift();
      if (collectedCardId) {
        collectedCardIds.push(collectedCardId);
        winner.cardsWonCount += 1;
        await this.prisma.gameRoundCard.create({
          data: { gameRoundId: gameRound.id, cardId: collectedCardId, ownerUserId: winnerId },
        });
      }
    }

    if (winnersOwnPlayedCard) {
      winner.cardIds.push(winnersOwnPlayedCard);
      await this.prisma.gameRoundCard.create({
        data: { gameRoundId: gameRound.id, cardId: winnersOwnPlayedCard, ownerUserId: winnerId },
      });
    }
    winner.cardIds.push(...collectedCardIds);

    this.realtime.broadcastToGame(state.gameId, GameServerEvent.CardsCollected, {
      winnerId,
      collectedCardIds,
    });

    const newlyEliminated: string[] = [];
    for (const loserId of loserIds) {
      const loser = state.players.find((p) => p.userId === loserId)!;
      if (loser.cardIds.length === 0 && !loser.isEliminated) {
        loser.isEliminated = true;
        state.eliminationOrder.push(loserId);
        newlyEliminated.push(loserId);
      }
    }

    for (const eliminatedId of newlyEliminated) {
      const round = state.roundNumber;
      await this.prisma.gamePlayer.updateMany({
        where: { gameId: state.gameId, userId: eliminatedId },
        data: { isEliminated: true, eliminatedAtRound: round },
      });
      this.realtime.broadcastToGame(state.gameId, GameServerEvent.PlayerEliminated, {
        userId: eliminatedId,
        atRound: round,
      });
    }

    await this.prisma.gamePlayer.updateMany({
      where: { gameId: state.gameId, userId: winnerId },
      data: { cardsWonCount: winner.cardsWonCount },
    });

    const remaining = state.players.filter((p) => !p.isEliminated);

    state.tieState = null;

    if (remaining.length <= 1) {
      await this.finishGame(state, winnerId);
      return;
    }

    state.roundNumber += 1;
    state.currentPlayerId = winnerId;
    state.roundActivePlayerIds = remaining.map((p) => p.userId);

    await this.stateStore.save(state);
    await this.broadcastFreshState(state);
    this.scheduleTurnTimeout(state);
  }

  /// A player let their turn timer run out without picking a statistic —
  /// forfeits their current top card to the next player in turn order
  /// (exactly like losing a round to them outright) and spends one of their
  /// TURN_TIMEOUT_STARTING_LIVES. Reaching 0 lives eliminates them
  /// immediately, taking whatever remains of their deck with them so the
  /// "owns every card" win condition stays reachable.
  private async handleTurnTimeout(gameId: string, expectedDecisionKey: string): Promise<void> {
    await this.lock.withLock(gameId, async () => {
      const state = await this.stateStore.tryLoad(gameId);
      if (!state || state.status === 'GAME_FINISHED') return;
      // A real selection already resolved this exact decision point between
      // when this timer was scheduled and when it fired — stale, no-op.
      if (this.decisionKeyFor(state) !== expectedDecisionKey) return;

      const timedOutId = state.currentPlayerId;
      const timedOut = state.players.find((p) => p.userId === timedOutId)!;

      const activeIds = state.players.filter((p) => !p.isEliminated).map((p) => p.userId);
      const idx = activeIds.indexOf(timedOutId);
      const nextPlayerId = activeIds[(idx + 1) % activeIds.length]!;
      const nextPlayer = state.players.find((p) => p.userId === nextPlayerId)!;

      const gameRound = await this.writeGameRound(state, 'TIMEOUT_FORFEIT', {}, nextPlayerId, false);

      const forfeitedCardId = timedOut.cardIds.shift();
      if (forfeitedCardId) {
        nextPlayer.cardIds.push(forfeitedCardId);
        nextPlayer.cardsWonCount += 1;
        await this.prisma.gameRoundCard.create({
          data: { gameRoundId: gameRound.id, cardId: forfeitedCardId, ownerUserId: nextPlayerId },
        });
      }

      timedOut.livesRemaining -= 1;
      state.eventSequence += 1;
      await this.recordEvent(state, GameServerEvent.TurnTimedOut, {
        userId: timedOutId,
        livesRemaining: timedOut.livesRemaining,
        forfeitedToUserId: nextPlayerId,
      });
      this.realtime.broadcastToGame(gameId, GameServerEvent.TurnTimedOut, {
        userId: timedOutId,
        livesRemaining: timedOut.livesRemaining,
        forfeitedToUserId: nextPlayerId,
      });

      const livesExhausted = timedOut.livesRemaining <= 0;
      if ((livesExhausted || timedOut.cardIds.length === 0) && !timedOut.isEliminated) {
        if (livesExhausted && timedOut.cardIds.length > 0) {
          // Lives-exhausted elimination is final even with cards still in
          // hand — they can't just sit frozen with an eliminated player
          // forever, so the rest of the deck moves on with the round.
          nextPlayer.cardIds.push(...timedOut.cardIds);
          timedOut.cardIds = [];
        }
        timedOut.isEliminated = true;
        state.eliminationOrder.push(timedOutId);
        await this.prisma.gamePlayer.updateMany({
          where: { gameId, userId: timedOutId },
          data: { isEliminated: true, eliminatedAtRound: state.roundNumber },
        });
        this.realtime.broadcastToGame(gameId, GameServerEvent.PlayerEliminated, {
          userId: timedOutId,
          atRound: state.roundNumber,
          reason: livesExhausted ? 'TIMEOUT_LIVES_EXHAUSTED' : 'OUT_OF_CARDS',
        });
      }

      await this.prisma.gamePlayer.updateMany({
        where: { gameId, userId: nextPlayerId },
        data: { cardsWonCount: nextPlayer.cardsWonCount },
      });

      const remaining = state.players.filter((p) => !p.isEliminated);
      state.tieState = null;

      if (remaining.length <= 1) {
        await this.finishGame(state, remaining[0]?.userId ?? nextPlayerId);
        return;
      }

      state.roundNumber += 1;
      state.currentPlayerId = nextPlayerId;
      state.roundActivePlayerIds = remaining.map((p) => p.userId);

      await this.stateStore.save(state);
      await this.broadcastFreshState(state);
      this.scheduleTurnTimeout(state);
    });
  }

  /// A player voluntarily concedes an in-progress match. Their entire
  /// remaining deck moves immediately to the next player in turn order
  /// (exactly like a lives-exhausted timeout elimination) so the "owns
  /// every card" win condition stays reachable, and the game either ends
  /// (if only one player is left) or continues to that next player's fresh
  /// turn. Unlike a timeout, this never touches `livesRemaining` — it's a
  /// deliberate quit, not an anti-stall penalty.
  forfeitMatch(gameId: string, userId: string): Promise<void> {
    return this.lock.withLock(gameId, () => this.doForfeitMatch(gameId, userId));
  }

  private async doForfeitMatch(gameId: string, userId: string): Promise<void> {
    const state = await this.stateStore.load(gameId);

    if (state.status === 'GAME_FINISHED') {
      throw new BadRequestException('This game has already finished');
    }
    const forfeiter = state.players.find((p) => p.userId === userId);
    if (!forfeiter) {
      throw new ForbiddenException('You are not a player in this game');
    }
    if (forfeiter.isEliminated) {
      throw new BadRequestException('You are already eliminated from this game');
    }

    // Whatever decision was pending (this player's own turn, or someone
    // else's) no longer matters once they've quit — clear it now so a
    // stale timeout can't also fire for a state this is about to replace.
    this.turnTimer.clear(gameId);

    const activeIds = state.players.filter((p) => !p.isEliminated).map((p) => p.userId);
    const idx = activeIds.indexOf(userId);
    const nextPlayerId = activeIds[(idx + 1) % activeIds.length]!;
    const nextPlayer = state.players.find((p) => p.userId === nextPlayerId)!;

    const gameRound = await this.writeGameRound(state, 'FORFEIT', {}, nextPlayerId, false);

    if (forfeiter.cardIds.length > 0) {
      for (const cardId of forfeiter.cardIds) {
        await this.prisma.gameRoundCard.create({
          data: { gameRoundId: gameRound.id, cardId, ownerUserId: nextPlayerId },
        });
      }
      nextPlayer.cardsWonCount += forfeiter.cardIds.length;
      nextPlayer.cardIds.push(...forfeiter.cardIds);
      forfeiter.cardIds = [];
    }

    forfeiter.isEliminated = true;
    state.eliminationOrder.push(userId);
    await this.prisma.gamePlayer.updateMany({
      where: { gameId, userId },
      data: { isEliminated: true, eliminatedAtRound: state.roundNumber },
    });
    this.realtime.broadcastToGame(gameId, GameServerEvent.PlayerEliminated, {
      userId,
      atRound: state.roundNumber,
      reason: 'FORFEITED',
    });

    await this.prisma.gamePlayer.updateMany({
      where: { gameId, userId: nextPlayerId },
      data: { cardsWonCount: nextPlayer.cardsWonCount },
    });

    const remaining = state.players.filter((p) => !p.isEliminated);
    state.tieState = null;

    if (remaining.length <= 1) {
      await this.finishGame(state, remaining[0]?.userId ?? nextPlayerId);
      return;
    }

    state.roundNumber += 1;
    state.currentPlayerId = nextPlayerId;
    state.roundActivePlayerIds = remaining.map((p) => p.userId);

    await this.stateStore.save(state);
    await this.broadcastFreshState(state);
    this.scheduleTurnTimeout(state);
  }

  /// Identifies "whose decision is this, and which decision" — mirrors the
  /// Flutter client's own key (game_screen.dart's `_decisionKeyFor`). A tie
  /// keeps the same currentPlayerId across several picks (the same player
  /// chooses again on a fresh, unused stat), so the tie-sequence length is
  /// folded in too — otherwise a stale timer from an earlier pick in the
  /// same tie would look identical to the current one.
  private decisionKeyFor(state: GameState): string {
    const tieStep = state.tieState?.usedStatistics.length ?? 0;
    return `${state.currentPlayerId}:${state.roundNumber}:${tieStep}`;
  }

  private scheduleTurnTimeout(state: GameState): void {
    const decisionKey = this.decisionKeyFor(state);
    this.turnTimer.schedule(state.gameId, TURN_TIMEOUT_MS, () =>
      this.handleTurnTimeout(state.gameId, decisionKey),
    );
  }

  private async finishGame(state: GameState, winnerId: string): Promise<void> {
    this.turnTimer.clear(state.gameId);
    state.status = 'GAME_FINISHED';
    state.winnerId = winnerId;

    const numPlayers = state.players.length;
    const pool = state.entryAmount * numPlayers;
    const bonus = Number(this.config.get('ECONOMY_MATCH_WIN_BONUS_COINS') ?? 200);
    const totalReward = pool + bonus;

    await this.prisma.$transaction(async (tx) => {
      await tx.game.update({
        where: { id: state.gameId },
        data: { status: GameStatus.FINISHED, winnerId, finishedAt: new Date() },
      });
      await tx.room.update({ where: { id: state.roomId }, data: { status: RoomStatus.FINISHED } });

      const ranked = [winnerId, ...[...state.eliminationOrder].reverse()];
      for (let i = 0; i < ranked.length; i++) {
        await tx.gamePlayer.updateMany({
          where: { gameId: state.gameId, userId: ranked[i] },
          data: { finalRank: i + 1 },
        });
      }

      if (totalReward > 0) {
        await this.walletService.creditGameReward(
          tx,
          winnerId,
          state.gameId,
          totalReward,
          `Match win (entry pool ${pool} + bonus ${bonus})`,
        );
      }
    });

    await this.stateStore.save(state);

    const winner = state.players.find((p) => p.userId === winnerId)!;
    this.realtime.broadcastToGame(state.gameId, GameServerEvent.GameFinished, {
      winnerId,
      coinsEarned: totalReward,
      roundsPlayed: state.roundNumber,
      cardsCollected: winner.cardsWonCount,
    });
    if (totalReward > 0) {
      this.realtime.emitToUser(winnerId, GameServerEvent.WalletUpdated, { coinsEarned: totalReward });
    }
    // Also push a final game:state so any client treating that as the
    // single source of truth (not just listening for game:finished) still
    // sees status flip to GAME_FINISHED.
    await this.broadcastFreshState(state);
  }

  private async writeGameRound(
    state: GameState,
    statistic: string,
    values: Record<string, number | null>,
    winnerId: string | null,
    wasTie: boolean,
  ) {
    const tieSequenceStep = state.tieState?.usedStatistics.length ?? 0;
    return this.prisma.gameRound.create({
      data: {
        gameId: state.gameId,
        roundNumber: state.roundNumber,
        tieSequenceStep,
        statistic,
        values,
        winnerId,
        wasTie,
      },
    });
  }

  private async recordEvent(state: GameState, type: string, payload: unknown): Promise<void> {
    await this.prisma.gameEvent.create({
      data: { gameId: state.gameId, type, payload: payload as never, sequence: state.eventSequence },
    });
  }

  private async broadcastFreshState(state: GameState): Promise<void> {
    for (const player of state.players) {
      const personalized = await this.buildPersonalizedState(state, player.userId);
      this.realtime.emitToUser(player.userId, GameServerEvent.GameState, personalized);
    }
  }
}

function fisherYatesShuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [result[i], result[j]] = [result[j]!, result[i]!];
  }
  return result;
}
