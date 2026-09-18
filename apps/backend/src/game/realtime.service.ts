import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

/// Thin broadcast wrapper around the Socket.IO server instance, which only
/// exists once GameGateway has initialized (see GameGateway.afterInit).
/// RoomsService depends on this (RoomsModule imports GameModule) to push
/// live updates after REST mutations — GameModule never depends back on
/// RoomsModule.
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server?: Server;

  setServer(server: Server): void {
    this.server = server;
  }

  broadcastToRoom(roomCode: string, event: string, payload: unknown): void {
    if (!this.server) {
      this.logger.warn(`Dropped ${event} for room ${roomCode} — socket server not ready`);
      return;
    }
    this.server.to(`room:${roomCode}`).emit(event, payload);
  }

  broadcastToGame(gameId: string, event: string, payload: unknown): void {
    if (!this.server) {
      this.logger.warn(`Dropped ${event} for game ${gameId} — socket server not ready`);
      return;
    }
    this.server.to(`game:${gameId}`).emit(event, payload);
  }

  emitToUser(userId: string, event: string, payload: unknown): void {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }
}
