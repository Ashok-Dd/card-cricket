import { ConflictException, ForbiddenException, HttpException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CardSetsService } from '../card-sets/card-sets.service.js';
import { CardsService } from '../cards/cards.service.js';
import { GameEngineService } from '../game/game-engine.service.js';
import { RealtimeService } from '../game/realtime.service.js';
import { RoomStatus } from '../generated/prisma/client.js';
import { LobbyService } from '../lobby/lobby.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { RoomsService } from './rooms.service.js';

const ROOM_ID = 'room-1';
const CODE = 'ABCDEF';

function makeRoom(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: ROOM_ID,
    code: CODE,
    hostId: 'host-1',
    cardSetId: 'card-set-1',
    entryAmount: 0,
    maxPlayers: 2,
    status: RoomStatus.LOBBY,
    ...overrides,
  };
}

function makePlayer(userId: string, isReady = false) {
  return { id: `rp-${userId}`, roomId: ROOM_ID, userId, isReady, joinedAt: new Date() };
}

describe('RoomsService', () => {
  let roomsService: RoomsService;
  let prisma: {
    room: {
      findUnique: ReturnType<typeof vi.fn>;
      create: ReturnType<typeof vi.fn>;
      update: ReturnType<typeof vi.fn>;
    };
    $transaction: ReturnType<typeof vi.fn>;
  };
  let lobbyService: {
    listMembers: ReturnType<typeof vi.fn>;
    addMember: ReturnType<typeof vi.fn>;
    setReady: ReturnType<typeof vi.fn>;
    removeMember: ReturnType<typeof vi.fn>;
  };
  let cardSetsService: { findEnabledById: ReturnType<typeof vi.fn> };
  let cardsService: { countCardsForCardSet: ReturnType<typeof vi.fn> };
  let walletService: { getWallet: ReturnType<typeof vi.fn> };
  let gameEngine: { startGame: ReturnType<typeof vi.fn> };
  let realtime: { broadcastToRoom: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    prisma = {
      room: { findUnique: vi.fn(), create: vi.fn(), update: vi.fn() },
      $transaction: vi.fn(),
    };
    lobbyService = {
      listMembers: vi.fn(),
      addMember: vi.fn(),
      setReady: vi.fn(),
      removeMember: vi.fn(),
    };
    cardSetsService = { findEnabledById: vi.fn() };
    cardsService = { countCardsForCardSet: vi.fn() };
    walletService = { getWallet: vi.fn() };
    gameEngine = { startGame: vi.fn().mockResolvedValue(undefined) };
    realtime = { broadcastToRoom: vi.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        RoomsService,
        { provide: PrismaService, useValue: prisma },
        { provide: LobbyService, useValue: lobbyService },
        { provide: CardSetsService, useValue: cardSetsService },
        { provide: CardsService, useValue: cardsService },
        { provide: WalletService, useValue: walletService },
        { provide: GameEngineService, useValue: gameEngine },
        { provide: RealtimeService, useValue: realtime },
      ],
    }).compile();

    roomsService = moduleRef.get(RoomsService);
  });

  describe('create', () => {
    it('rejects a deckSize larger than the card set actually has', async () => {
      cardSetsService.findEnabledById.mockResolvedValue({ id: 'card-set-1', isEnabled: true });
      cardsService.countCardsForCardSet.mockResolvedValue(120);

      await expect(
        roomsService.create('host-1', { cardSetId: 'card-set-1', entryAmount: 0, maxPlayers: 2, deckSize: 200 }),
      ).rejects.toThrow(HttpException);
      expect(prisma.room.create).not.toHaveBeenCalled();
    });

    it('creates the room with the requested deckSize when it fits the pool', async () => {
      cardSetsService.findEnabledById.mockResolvedValue({ id: 'card-set-1', isEnabled: true });
      cardsService.countCardsForCardSet.mockResolvedValue(500);
      prisma.room.findUnique.mockResolvedValueOnce(null); // code-uniqueness check
      prisma.room.create.mockResolvedValue(makeRoom({ deckSize: 100 }));
      prisma.room.findUnique.mockResolvedValueOnce(makeRoom({ deckSize: 100 })); // getByCode's lookup
      lobbyService.listMembers.mockResolvedValue([makePlayer('host-1')]);

      await roomsService.create('host-1', { cardSetId: 'card-set-1', entryAmount: 0, maxPlayers: 2, deckSize: 100 });

      expect(prisma.room.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ deckSize: 100 }) }),
      );
    });
  });

  describe('join', () => {
    it('rejects when the room is full', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ maxPlayers: 2 }));
      lobbyService.listMembers.mockResolvedValue([makePlayer('a'), makePlayer('b')]);

      await expect(roomsService.join(CODE, 'newcomer')).rejects.toThrow(ConflictException);
      expect(lobbyService.addMember).not.toHaveBeenCalled();
    });

    it('rejects when the room already started', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ status: RoomStatus.IN_PROGRESS }));

      await expect(roomsService.join(CODE, 'newcomer')).rejects.toThrow(ConflictException);
    });

    it('rejects when the joiner cannot afford the entry amount', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ entryAmount: 500, maxPlayers: 6 }));
      lobbyService.listMembers.mockResolvedValue([makePlayer('host-1')]);
      walletService.getWallet.mockResolvedValue({ balance: 100 });

      await expect(roomsService.join(CODE, 'newcomer')).rejects.toThrow(HttpException);
      expect(lobbyService.addMember).not.toHaveBeenCalled();
    });

    it('is idempotent for a player who already joined', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ maxPlayers: 6 }));
      lobbyService.listMembers.mockResolvedValue([makePlayer('host-1'), makePlayer('existing')]);

      await roomsService.join(CODE, 'existing');

      expect(lobbyService.addMember).not.toHaveBeenCalled();
      expect(walletService.getWallet).not.toHaveBeenCalled();
    });
  });

  describe('start', () => {
    it('rejects a non-host caller', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ hostId: 'host-1' }));

      await expect(roomsService.start(CODE, 'not-the-host')).rejects.toThrow(ForbiddenException);
    });

    it('rejects when not everyone is ready', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ hostId: 'host-1' }));
      lobbyService.listMembers.mockResolvedValue([
        makePlayer('host-1', true),
        makePlayer('p2', false),
      ]);

      await expect(roomsService.start(CODE, 'host-1')).rejects.toThrow(ConflictException);
    });

    it('creates one GamePlayer per lobby member and flips the room to IN_PROGRESS', async () => {
      prisma.room.findUnique.mockResolvedValue(makeRoom({ hostId: 'host-1' }));
      lobbyService.listMembers.mockResolvedValue([
        makePlayer('host-1', true),
        makePlayer('p2', true),
        makePlayer('p3', true),
      ]);

      const tx = {
        game: { create: vi.fn().mockResolvedValue({ id: 'game-1' }) },
        gamePlayer: { createMany: vi.fn().mockResolvedValue({ count: 3 }) },
        room: { update: vi.fn() },
      };
      prisma.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
        callback(tx),
      );

      const result = await roomsService.start(CODE, 'host-1');

      expect(result).toEqual({ gameId: 'game-1' });
      expect(tx.gamePlayer.createMany).toHaveBeenCalledWith({
        data: expect.arrayContaining([
          expect.objectContaining({ gameId: 'game-1', userId: 'host-1', seatOrder: 0 }),
          expect.objectContaining({ gameId: 'game-1', userId: 'p2', seatOrder: 1 }),
          expect.objectContaining({ gameId: 'game-1', userId: 'p3', seatOrder: 2 }),
        ]),
      });
      expect(tx.room.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: { status: 'IN_PROGRESS' } }),
      );
      expect(gameEngine.startGame).toHaveBeenCalledWith('game-1');
      expect(realtime.broadcastToRoom).toHaveBeenCalledWith(
        CODE,
        'game:starting',
        expect.objectContaining({ gameId: 'game-1' }),
      );
    });
  });
});
