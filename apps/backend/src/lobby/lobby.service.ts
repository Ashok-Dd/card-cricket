import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

/// Lobby membership + ready state (RoomPlayer) — distinct from GamePlayer,
/// which only exists once the host starts the match. See docs/GAME_RULES.md.
@Injectable()
export class LobbyService {
  constructor(private readonly prisma: PrismaService) {}

  /// Idempotent: joining a room you're already in just returns your existing
  /// membership instead of erroring (docs/GAME_RULES.md "duplicate room join").
  async addMember(roomId: string, userId: string, isReady = false) {
    const existing = await this.prisma.roomPlayer.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (existing) {
      return existing;
    }
    return this.prisma.roomPlayer.create({ data: { roomId, userId, isReady } });
  }

  setReady(roomId: string, userId: string, ready: boolean) {
    return this.prisma.roomPlayer.update({
      where: { roomId_userId: { roomId, userId } },
      data: { isReady: ready },
    });
  }

  removeMember(roomId: string, userId: string) {
    return this.prisma.roomPlayer.delete({
      where: { roomId_userId: { roomId, userId } },
    });
  }

  listMembers(roomId: string) {
    return this.prisma.roomPlayer.findMany({
      where: { roomId },
      orderBy: { joinedAt: 'asc' },
      include: { user: { select: { id: true, username: true, avatarUrl: true } } },
    });
  }
}
