import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service.js';
import { GameClientEvent, GameServerEvent } from './game-events.constants.js';
import { GameEngineService } from './game-engine.service.js';
import { RealtimeService } from './realtime.service.js';

interface AuthenticatedUser {
  id: string;
  email: string;
  username: string;
}

/// The real-time surface (see docs/ARCHITECTURE.md). Every handler trusts
/// only `socket.data.user.id` (verified in handleConnection) — never a
/// userId the client claims in a payload.
@WebSocketGateway({ cors: { origin: '*' } })
export class GameGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(GameGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly gameEngine: GameEngineService,
  ) {}

  afterInit(server: Server): void {
    this.realtime.setServer(server);
  }

  handleConnection(socket: Socket): void {
    const token = this.extractToken(socket);
    if (!token) {
      socket.disconnect(true);
      return;
    }

    try {
      const payload = this.jwtService.verify<{ sub: string; email: string; username: string }>(token, {
        secret: this.config.get<string>('JWT_SECRET') ?? 'dev-secret-change-me',
      });
      const user: AuthenticatedUser = { id: payload.sub, email: payload.email, username: payload.username };
      socket.data.user = user;
      socket.join(`user:${user.id}`);
      this.logger.log(`Socket ${socket.id} authenticated as ${user.username}`);
    } catch {
      socket.disconnect(true);
    }
  }

  handleDisconnect(socket: Socket): void {
    this.logger.log(`Socket disconnected: ${socket.id}`);
  }

  private extractToken(socket: Socket): string | null {
    const auth = socket.handshake.auth as Record<string, unknown> | undefined;
    if (typeof auth?.token === 'string') return auth.token;
    const query = socket.handshake.query as Record<string, unknown> | undefined;
    if (typeof query?.token === 'string') return query.token;
    return null;
  }

  private currentUser(socket: Socket): AuthenticatedUser | undefined {
    return socket.data.user as AuthenticatedUser | undefined;
  }

  @SubscribeMessage(GameClientEvent.SubscribeRoom)
  async onSubscribeRoom(socket: Socket, data: { roomCode: string }): Promise<void> {
    const user = this.currentUser(socket);
    if (!user) return;

    const isMember = await this.prisma.roomPlayer.findFirst({
      where: { userId: user.id, room: { code: data.roomCode } },
    });
    if (!isMember) {
      socket.emit(GameServerEvent.Error, { message: 'You are not in this room' });
      return;
    }

    await socket.join(`room:${data.roomCode}`);
  }

  @SubscribeMessage(GameClientEvent.SubscribeGame)
  async onSubscribeGame(socket: Socket, data: { gameId: string }): Promise<void> {
    const user = this.currentUser(socket);
    if (!user) return;

    const isMember = await this.prisma.gamePlayer.findFirst({
      where: { userId: user.id, gameId: data.gameId },
    });
    if (!isMember) {
      socket.emit(GameServerEvent.Error, { message: 'You are not a player in this game' });
      return;
    }

    await socket.join(`game:${data.gameId}`);

    try {
      const state = await this.gameEngine.getStateForUser(data.gameId, user.id);
      socket.emit(GameServerEvent.GameState, state);
    } catch (error) {
      socket.emit(GameServerEvent.Error, { message: (error as Error).message });
    }
  }

  @SubscribeMessage(GameClientEvent.SelectStatistic)
  async onSelectStatistic(socket: Socket, data: { gameId: string; statistic: string }): Promise<void> {
    const user = this.currentUser(socket);
    if (!user) return;

    try {
      await this.gameEngine.selectStatistic(data.gameId, user.id, data.statistic);
    } catch (error) {
      socket.emit(GameServerEvent.Error, { message: (error as Error).message });
    }
  }
}
