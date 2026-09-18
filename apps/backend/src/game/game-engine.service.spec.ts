import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { CardsService } from '../cards/cards.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { GameEngineService } from './game-engine.service.js';
import { GameLockService } from './game-lock.service.js';
import { GameStateStore } from './game-state.store.js';
import type { GameState } from './game-state.types.js';
import { GameTurnTimerService } from './game-turn-timer.service.js';
import { RealtimeService } from './realtime.service.js';

const CARD_SET = { batting: ['runs', 'strikeRate'], bowling: ['economyRate', 'wickets'] };

function makeCard(id: string, stats: Record<string, number | null>) {
  return {
    id,
    rarity: 'RARE',
    rating: 80,
    imageUrl: null,
    player: { id: `player-${id}`, name: `Player ${id}` },
    statistics: stats,
    cardSet: { statSchema: CARD_SET },
  };
}

function makeState(overrides: Partial<GameState> = {}): GameState {
  return {
    gameId: 'game-1',
    roomId: 'room-1',
    cardSetId: 'card-set-1',
    entryAmount: 0,
    roundNumber: 1,
    currentPlayerId: 'p1',
    players: [
      { userId: 'p1', cardIds: ['card-p1'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
      { userId: 'p2', cardIds: ['card-p2'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
    ],
    roundActivePlayerIds: ['p1', 'p2'],
    tieState: null,
    eliminationOrder: [],
    eventSequence: 0,
    status: 'PLAYER_TURN',
    ...overrides,
  };
}

function makeStateStore() {
  let current: GameState | null = null;
  return {
    load: vi.fn(async () => current as GameState),
    tryLoad: vi.fn(async () => current),
    save: vi.fn(async (s: GameState) => {
      current = s;
    }),
    setState(s: GameState) {
      current = s;
    },
    getCurrent: () => current as GameState,
  };
}

describe('GameEngineService.selectStatistic', () => {
  let engine: GameEngineService;
  let prisma: { card: { findUnique: ReturnType<typeof vi.fn> }; gameRound: { create: ReturnType<typeof vi.fn> }; gameRoundCard: { create: ReturnType<typeof vi.fn> }; gamePlayer: { updateMany: ReturnType<typeof vi.fn> }; gameEvent: { create: ReturnType<typeof vi.fn> }; $transaction: ReturnType<typeof vi.fn>; game: { update: ReturnType<typeof vi.fn> }; room: { update: ReturnType<typeof vi.fn> } };
  let stateStore: ReturnType<typeof makeStateStore>;
  let cardsById: Map<string, ReturnType<typeof makeCard>>;
  let realtime: { broadcastToGame: ReturnType<typeof vi.fn>; emitToUser: ReturnType<typeof vi.fn> };
  let walletService: { creditGameReward: ReturnType<typeof vi.fn>; deductGameEntry: ReturnType<typeof vi.fn> };

  function setup(state: GameState, cards: Array<ReturnType<typeof makeCard>>) {
    stateStore.setState(state);
    cardsById = new Map(cards.map((c) => [c.id, c]));
    prisma.card.findUnique.mockImplementation(({ where }: { where: { id: string } }) =>
      Promise.resolve(cardsById.get(where.id) ?? null),
    );
  }

  beforeEach(async () => {
    prisma = {
      card: { findUnique: vi.fn() },
      gameRound: { create: vi.fn().mockResolvedValue({ id: 'round-1' }) },
      gameRoundCard: { create: vi.fn() },
      gamePlayer: { updateMany: vi.fn() },
      gameEvent: { create: vi.fn() },
      game: { update: vi.fn() },
      room: { update: vi.fn() },
      $transaction: vi.fn(async (callback: (tx: unknown) => unknown) =>
        callback({ game: prisma.game, room: prisma.room, gamePlayer: prisma.gamePlayer }),
      ),
    };
    realtime = { broadcastToGame: vi.fn(), emitToUser: vi.fn() };
    walletService = { creditGameReward: vi.fn(), deductGameEntry: vi.fn() };
    stateStore = makeStateStore();

    const moduleRef = await Test.createTestingModule({
      providers: [
        GameEngineService,
        { provide: PrismaService, useValue: prisma },
        { provide: CardsService, useValue: { getEligibleCardsForCardSet: vi.fn() } },
        { provide: WalletService, useValue: walletService },
        { provide: GameStateStore, useValue: stateStore },
        GameLockService,
        GameTurnTimerService,
        { provide: RealtimeService, useValue: realtime },
        { provide: ConfigService, useValue: { get: () => undefined } },
      ],
    }).compile();

    engine = moduleRef.get(GameEngineService);
  });

  it('higher-is-better: the higher runs value wins outright and collects the loser card', async () => {
    setup(makeState(), [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 50 })]);
    await engine.selectStatistic('game-1', 'p1', 'runs');

    const state = stateStore.getCurrent();
    expect(state.players.find((p) => p.userId === 'p1')!.cardIds).toEqual(['card-p1', 'card-p2']);
    expect(state.players.find((p) => p.userId === 'p2')!.isEliminated).toBe(true);
    expect(state.currentPlayerId).toBe('p1');
  });

  it('lower-is-better: the lower economy rate wins (cricket-correct comparison)', async () => {
    setup(makeState({ currentPlayerId: 'p1' }), [
      makeCard('card-p1', { economyRate: 3.5 }),
      makeCard('card-p2', { economyRate: 9.0 }),
    ]);
    await engine.selectStatistic('game-1', 'p1', 'economyRate');

    const state = stateStore.getCurrent();
    expect(state.players.find((p) => p.userId === 'p1')!.cardIds).toContain('card-p2');
  });

  it('a tied value keeps both cards in play and records the used statistic', async () => {
    setup(makeState(), [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 100 })]);
    await engine.selectStatistic('game-1', 'p1', 'runs');

    const state = stateStore.getCurrent();
    expect(state.tieState).toEqual({ contestingPlayerIds: ['p1', 'p2'], usedStatistics: ['runs'] });
    // Same cards, nobody collected anything.
    expect(state.players.find((p) => p.userId === 'p1')!.cardIds).toEqual(['card-p1']);
    expect(state.players.find((p) => p.userId === 'p2')!.cardIds).toEqual(['card-p2']);
  });

  it('rejects reusing a statistic already tried in the current tie sequence', async () => {
    const tied = makeState({ tieState: { contestingPlayerIds: ['p1', 'p2'], usedStatistics: ['runs'] } });
    setup(tied, [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 100 })]);

    await expect(engine.selectStatistic('game-1', 'p1', 'runs')).rejects.toThrow(BadRequestException);
  });

  it('rejects a selection from a player whose turn it is not', async () => {
    setup(makeState({ currentPlayerId: 'p1' }), [
      makeCard('card-p1', { runs: 100 }),
      makeCard('card-p2', { runs: 50 }),
    ]);

    await expect(engine.selectStatistic('game-1', 'p2', 'runs')).rejects.toThrow(ForbiddenException);
  });

  it('declares a winner and credits the reward once only one player remains', async () => {
    const state = makeState({
      players: [
        { userId: 'p1', cardIds: ['card-p1'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
        { userId: 'p2', cardIds: ['card-p2'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
      ],
      roundActivePlayerIds: ['p1', 'p2'],
    });
    setup(state, [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 50 })]);

    await engine.selectStatistic('game-1', 'p1', 'runs');

    expect(walletService.creditGameReward).toHaveBeenCalledWith(
      expect.anything(),
      'p1',
      'game-1',
      expect.any(Number),
      expect.any(String),
    );
    const finalState = stateStore.getCurrent();
    expect(finalState.status).toBe('GAME_FINISHED');
    expect(finalState.winnerId).toBe('p1');
  });

  it('never replays a played card: the winner\'s deck advances to the next card every round', async () => {
    // p1 holds A,B,C,D,E (in that order) and wins every round on "runs", so
    // the turn stays with p1 throughout. p2 holds five throwaway cards so
    // it has something to lose each round without being eliminated early
    // enough to cut the scenario short. After each round, p1's own played
    // card must have moved to the bottom of their deck (behind the card
    // just collected from p2) and the NEXT card must be the new current
    // one — never the same card twice in a row.
    const state = makeState({
      players: [
        { userId: 'p1', cardIds: ['A', 'B', 'C', 'D', 'E'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
        { userId: 'p2', cardIds: ['y1', 'y2', 'y3', 'y4', 'y5'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
      ],
      roundActivePlayerIds: ['p1', 'p2'],
      currentPlayerId: 'p1',
    });
    const cards = [
      ...['A', 'B', 'C', 'D', 'E'].map((id) => makeCard(id, { runs: 100 })),
      ...['y1', 'y2', 'y3', 'y4', 'y5'].map((id) => makeCard(id, { runs: 50 })),
    ];
    setup(state, cards);

    // The card played each round, in order, must never repeat: A, then B,
    // then C, then D, then E — each one the NEW top-of-deck card, not the
    // one just played.
    const expectedCardPlayedEachRound = ['A', 'B', 'C', 'D', 'E'];
    const seenCurrentCards: string[] = [];

    for (let round = 0; round < 5; round += 1) {
      const before = stateStore.getCurrent();
      const p1Before = before.players.find((p) => p.userId === 'p1')!;
      const cardAboutToBePlayed = p1Before.cardIds[0];
      expect(cardAboutToBePlayed).toBe(expectedCardPlayedEachRound[round]);
      seenCurrentCards.push(cardAboutToBePlayed);

      await engine.selectStatistic('game-1', 'p1', 'runs');

      const after = stateStore.getCurrent();
      const p1After = after.players.find((p) => p.userId === 'p1')!;
      // The just-played card must not still be sitting on top of the deck.
      expect(p1After.cardIds[0]).not.toBe(cardAboutToBePlayed);
      // ...and it must have gone to the bottom of the winner's own deck, not
      // vanished or been left in the middle.
      expect(p1After.cardIds).toContain(cardAboutToBePlayed);
      expect(after.currentPlayerId).toBe('p1');
    }

    // Every round played a genuinely different card — nothing repeated.
    expect(new Set(seenCurrentCards).size).toBe(5);
  });

  describe('turn timeout (anti-stall lives)', () => {
    afterEach(() => {
      vi.useRealTimers();
    });

    it('forfeits the stalling player\'s current card to the next player and spends one life', async () => {
      // Both players need a second card so round 1's loser isn't eliminated
      // outright — the point of this test is round 2's timeout, not round 1.
      const state = makeState({
        players: [
          { userId: 'p1', cardIds: ['card-p1', 'reserve-1'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
          { userId: 'p2', cardIds: ['card-p2', 'reserve-p2'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
        ],
      });
      setup(state, [
        makeCard('card-p1', { runs: 100 }),
        makeCard('reserve-1', { runs: 1 }),
        makeCard('card-p2', { runs: 50 }),
        makeCard('reserve-p2', { runs: 1 }),
      ]);
      vi.useFakeTimers();

      // p1 wins round 1 outright, so the turn stays with p1 for round 2 —
      // that's the decision the 30s timer below is timing out on.
      await engine.selectStatistic('game-1', 'p1', 'runs');
      expect(stateStore.getCurrent().currentPlayerId).toBe('p1');
      expect(stateStore.getCurrent().players.find((p) => p.userId === 'p2')!.isEliminated).toBe(false);

      await vi.advanceTimersByTimeAsync(30_000);

      const finalState = stateStore.getCurrent();
      const p1 = finalState.players.find((p) => p.userId === 'p1')!;
      const p2 = finalState.players.find((p) => p.userId === 'p2')!;

      expect(p1.livesRemaining).toBe(2);
      expect(p1.isEliminated).toBe(false);
      // p1's round-2 top card ('reserve-1') was forfeited to p2 — not lost,
      // not duplicated.
      expect(p2.cardIds).toContain('reserve-1');
      expect(finalState.currentPlayerId).toBe('p2');
      expect(finalState.roundNumber).toBe(3);
      expect(realtime.broadcastToGame).toHaveBeenCalledWith(
        'game-1',
        'turn:timedOut',
        expect.objectContaining({ userId: 'p1', livesRemaining: 2, forfeitedToUserId: 'p2' }),
      );
    });

    it('eliminates a player outright once their lives run out, handing their whole deck to the next player', async () => {
      const state = makeState({
        players: [
          {
            userId: 'p1',
            cardIds: ['card-p1', 'reserve-1', 'reserve-2'],
            isEliminated: false,
            cardsWonCount: 0,
            livesRemaining: 1,
          },
          {
            userId: 'p2',
            cardIds: ['card-p2', 'reserve-p2'],
            isEliminated: false,
            cardsWonCount: 0,
            livesRemaining: 3,
          },
        ],
        currentPlayerId: 'p1',
      });
      setup(state, [
        makeCard('card-p1', { runs: 100 }),
        makeCard('reserve-1', { runs: 1 }),
        makeCard('reserve-2', { runs: 1 }),
        makeCard('card-p2', { runs: 50 }),
        makeCard('reserve-p2', { runs: 1 }),
      ]);
      vi.useFakeTimers();

      // p1 wins round 1 outright (keeps the turn for round 2, with only one
      // life left) — p2 still has a second card, so this doesn't end the
      // game on its own.
      await engine.selectStatistic('game-1', 'p1', 'runs');
      expect(stateStore.getCurrent().currentPlayerId).toBe('p1');
      expect(stateStore.getCurrent().players.find((p) => p.userId === 'p2')!.isEliminated).toBe(false);

      // p1 stalls out their last life on round 2's decision.
      await vi.advanceTimersByTimeAsync(30_000);

      const finalState = stateStore.getCurrent();
      const p1 = finalState.players.find((p) => p.userId === 'p1')!;
      const p2 = finalState.players.find((p) => p.userId === 'p2')!;

      expect(p1.livesRemaining).toBe(0);
      expect(p1.isEliminated).toBe(true);
      expect(p1.cardIds).toEqual([]); // the whole deck moved on, not just the top card
      expect(p2.cardIds.length).toBe(5); // their own 2 + p1's forfeited card + p1's remaining 2
      expect(finalState.status).toBe('GAME_FINISHED');
      expect(finalState.winnerId).toBe('p2');
      expect(walletService.creditGameReward).toHaveBeenCalledWith(
        expect.anything(),
        'p2',
        'game-1',
        expect.any(Number),
        expect.any(String),
      );
    });
  });

  describe('forfeitMatch', () => {
    it("ends the game immediately in a 2-player match, handing the forfeiter's whole deck to the opponent", async () => {
      const state = makeState({
        players: [
          { userId: 'p1', cardIds: ['card-p1', 'reserve-1'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
          { userId: 'p2', cardIds: ['card-p2'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
        ],
      });
      setup(state, [
        makeCard('card-p1', { runs: 100 }),
        makeCard('reserve-1', { runs: 1 }),
        makeCard('card-p2', { runs: 50 }),
      ]);

      await engine.forfeitMatch('game-1', 'p1');

      const final = stateStore.getCurrent();
      const p1 = final.players.find((p) => p.userId === 'p1')!;
      const p2 = final.players.find((p) => p.userId === 'p2')!;

      expect(p1.isEliminated).toBe(true);
      expect(p1.cardIds).toEqual([]);
      expect(p2.cardIds).toEqual(expect.arrayContaining(['card-p1', 'reserve-1', 'card-p2']));
      expect(p2.cardIds.length).toBe(3);
      expect(final.status).toBe('GAME_FINISHED');
      expect(final.winnerId).toBe('p2');
      expect(realtime.broadcastToGame).toHaveBeenCalledWith(
        'game-1',
        'player:eliminated',
        expect.objectContaining({ userId: 'p1', reason: 'FORFEITED' }),
      );
      expect(walletService.creditGameReward).toHaveBeenCalledWith(
        expect.anything(),
        'p2',
        'game-1',
        expect.any(Number),
        expect.any(String),
      );
    });

    it('passes the forfeiter\'s deck to the next player and continues when 3+ players remain', async () => {
      const state = makeState({
        players: [
          { userId: 'p1', cardIds: ['card-p1'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
          { userId: 'p2', cardIds: ['card-p2'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
          { userId: 'p3', cardIds: ['card-p3'], isEliminated: false, cardsWonCount: 0, livesRemaining: 3 },
        ],
        roundActivePlayerIds: ['p1', 'p2', 'p3'],
      });
      setup(state, [
        makeCard('card-p1', { runs: 100 }),
        makeCard('card-p2', { runs: 50 }),
        makeCard('card-p3', { runs: 30 }),
      ]);

      await engine.forfeitMatch('game-1', 'p2');

      const final = stateStore.getCurrent();
      const p2 = final.players.find((p) => p.userId === 'p2')!;
      const p3 = final.players.find((p) => p.userId === 'p3')!;

      expect(p2.isEliminated).toBe(true);
      expect(p2.cardIds).toEqual([]);
      expect(p3.cardIds).toContain('card-p2');
      expect(final.status).not.toBe('GAME_FINISHED');
      expect(final.currentPlayerId).toBe('p3');
      expect(final.roundActivePlayerIds).toEqual(['p1', 'p3']);
    });

    it('rejects forfeiting a game that already finished', async () => {
      const state = makeState({ status: 'GAME_FINISHED' });
      setup(state, [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 50 })]);

      await expect(engine.forfeitMatch('game-1', 'p1')).rejects.toThrow(BadRequestException);
    });

    it('rejects forfeiting when not a player in this game', async () => {
      setup(makeState(), [makeCard('card-p1', { runs: 100 }), makeCard('card-p2', { runs: 50 })]);

      await expect(engine.forfeitMatch('game-1', 'ghost')).rejects.toThrow(ForbiddenException);
    });
  });
});
