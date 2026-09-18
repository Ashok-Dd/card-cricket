import { Test } from '@nestjs/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlayerRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PlayersService } from './players.service.js';

describe('PlayersService', () => {
  let playersService: PlayersService;
  let prisma: {
    player: { findMany: ReturnType<typeof vi.fn>; count: ReturnType<typeof vi.fn> };
  };

  beforeEach(async () => {
    prisma = {
      player: {
        findMany: vi.fn().mockResolvedValue([]),
        count: vi.fn().mockResolvedValue(0),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [PlayersService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    playersService = moduleRef.get(PlayersService);
  });

  it('builds a search + cardSetId + role filter and paginates', async () => {
    await playersService.findMany({
      search: 'ashwin',
      cardSetId: '11111111-1111-1111-1111-111111111111',
      role: PlayerRole.BOWLER,
      page: 2,
      pageSize: 10,
    });

    expect(prisma.player.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: [
            { name: { contains: 'ashwin', mode: 'insensitive' } },
            { displayName: { contains: 'ashwin', mode: 'insensitive' } },
          ],
          role: PlayerRole.BOWLER,
          statistics: { some: { cardSetId: '11111111-1111-1111-1111-111111111111' } },
        }),
        skip: 10, // (page 2 - 1) * pageSize 10
        take: 10,
      }),
    );
  });

  it('returns pagination metadata computed from the total count', async () => {
    prisma.player.count.mockResolvedValue(45);

    const result = await playersService.findMany({ page: 1, pageSize: 20 });

    expect(result).toMatchObject({ page: 1, pageSize: 20, total: 45, totalPages: 3 });
  });
});
