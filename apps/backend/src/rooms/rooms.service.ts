import {
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CardSetsService } from '../card-sets/card-sets.service.js';
import { CardsService } from '../cards/cards.service.js';
import { GameEngineService } from '../game/game-engine.service.js';
import { GameServerEvent } from '../game/game-events.constants.js';
import { RealtimeService } from '../game/realtime.service.js';
import { GameStatus, RoomStatus } from '../generated/prisma/client.js';
import { LobbyService } from '../lobby/lobby.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import type { CreateRoomDto } from './dto/create-room.dto.js';
import { generateRoomCode } from './room-code.util.js';

const MAX_CODE_ATTEMPTS = 5;

@Injectable()
export class RoomsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly lobbyService: LobbyService,
    private readonly cardSetsService: CardSetsService,
    private readonly cardsService: CardsService,
    private readonly walletService: WalletService,
    private readonly gameEngine: GameEngineService,
    private readonly realtime: RealtimeService,
  ) {}

  private async generateUniqueCode(): Promise<string> {
    for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
      const code = generateRoomCode();
      const existing = await this.prisma.room.findUnique({ where: { code } });
      if (!existing) {
        return code;
      }
    }
    throw new HttpException('Could not allocate a room code, try again', HttpStatus.CONFLICT);
  }

  private async assertCanAfford(userId: string, entryAmount: number): Promise<void> {
    if (entryAmount <= 0) {
      return;
    }
    const wallet = await this.walletService.getWallet(userId);
    const balance = wallet?.balance ?? 0;
    if (balance < entryAmount) {
      throw new HttpException(
        `Insufficient coins: this room requires ${entryAmount}`,
        HttpStatus.PAYMENT_REQUIRED,
      );
    }
  }

  async create(hostId: string, dto: CreateRoomDto) {
    await this.cardSetsService.findEnabledById(dto.cardSetId);
    await this.assertCanAfford(hostId, dto.entryAmount);

    if (dto.deckSize !== undefined) {
      const available = await this.cardsService.countCardsForCardSet(dto.cardSetId);
      if (dto.deckSize > available) {
        throw new HttpException(
          `This card set only has ${available} cards — can't deal a ${dto.deckSize}-card deck`,
          HttpStatus.BAD_REQUEST,
        );
      }
    }

    const code = await this.generateUniqueCode();
    const room = await this.prisma.room.create({
      data: {
        code,
        hostId,
        cardSetId: dto.cardSetId,
        entryAmount: dto.entryAmount,
        maxPlayers: dto.maxPlayers,
        deckSize: dto.deckSize,
      },
    });
    await this.lobbyService.addMember(room.id, hostId, true);

    return this.getByCode(room.code);
  }

  private async findRoomOrThrow(code: string) {
    const room = await this.prisma.room.findUnique({ where: { code } });
    if (!room) {
      throw new NotFoundException(`Room "${code}" not found`);
    }
    return room;
  }

  async getByCode(code: string) {
    const room = await this.findRoomOrThrow(code);
    const players = await this.lobbyService.listMembers(room.id);

    return {
      ...room,
      players,
      currentPlayers: players.length,
      potentialRewardPool: room.entryAmount * room.maxPlayers,
    };
  }

  async join(code: string, userId: string) {
    const room = await this.findRoomOrThrow(code);

    if (room.status !== RoomStatus.LOBBY) {
      throw new ConflictException(`Room "${code}" is ${room.status.toLowerCase()}`);
    }

    const players = await this.lobbyService.listMembers(room.id);
    const alreadyMember = players.some((p) => p.userId === userId);

    if (!alreadyMember) {
      if (players.length >= room.maxPlayers) {
        throw new ConflictException(`Room "${code}" is full`);
      }
      await this.assertCanAfford(userId, room.entryAmount);
      await this.lobbyService.addMember(room.id, userId, false);
    }

    const snapshot = await this.getByCode(code);
    this.realtime.broadcastToRoom(code, GameServerEvent.RoomUpdated, snapshot);
    return snapshot;
  }

  async setReady(code: string, userId: string, ready: boolean) {
    const room = await this.findRoomOrThrow(code);
    if (room.status !== RoomStatus.LOBBY) {
      throw new ConflictException(`Room "${code}" is ${room.status.toLowerCase()}`);
    }
    await this.lobbyService.setReady(room.id, userId, ready);

    const snapshot = await this.getByCode(code);
    this.realtime.broadcastToRoom(code, GameServerEvent.RoomUpdated, snapshot);
    return snapshot;
  }

  async leave(code: string, userId: string) {
    const room = await this.findRoomOrThrow(code);
    await this.lobbyService.removeMember(room.id, userId);

    const remaining = await this.lobbyService.listMembers(room.id);

    if (remaining.length === 0) {
      await this.prisma.room.update({
        where: { id: room.id },
        data: { status: RoomStatus.CANCELLED },
      });
      return;
    }

    if (room.hostId === userId) {
      const nextHost = remaining[0];
      await this.prisma.room.update({
        where: { id: room.id },
        data: { hostId: nextHost.userId },
      });
    }

    const snapshot = await this.getByCode(code);
    this.realtime.broadcastToRoom(code, GameServerEvent.RoomUpdated, snapshot);
    return snapshot;
  }

  /// Creates the Game/GamePlayer scaffold (status WAITING), then hands off
  /// to GameEngineService.startGame() to actually shuffle/deal/deduct entry
  /// and flip everything to IN_PROGRESS.
  async start(code: string, hostId: string) {
    const room = await this.findRoomOrThrow(code);

    if (room.hostId !== hostId) {
      throw new ForbiddenException('Only the host can start the game');
    }
    if (room.status !== RoomStatus.LOBBY) {
      throw new ConflictException(`Room "${code}" is ${room.status.toLowerCase()}`);
    }

    const players = await this.lobbyService.listMembers(room.id);
    if (players.length < 2) {
      throw new ConflictException('At least 2 players are required to start');
    }
    if (!players.every((p) => p.isReady)) {
      throw new ConflictException('All players must be ready to start');
    }

    const game = await this.prisma.$transaction(async (tx) => {
      const createdGame = await tx.game.create({
        data: { roomId: room.id, cardSetId: room.cardSetId, status: GameStatus.WAITING },
      });

      await tx.gamePlayer.createMany({
        data: players.map((player, index) => ({
          gameId: createdGame.id,
          userId: player.userId,
          seatOrder: index,
        })),
      });

      await tx.room.update({
        where: { id: room.id },
        data: { status: RoomStatus.IN_PROGRESS },
      });

      return createdGame;
    });

    await this.gameEngine.startGame(game.id);

    this.realtime.broadcastToRoom(code, GameServerEvent.GameStarting, { gameId: game.id });

    return { gameId: game.id };
  }
}
