import { Injectable } from '@nestjs/common';
import type { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { ListPlayersQueryDto } from './dto/list-players-query.dto.js';

@Injectable()
export class PlayersService {
  constructor(private readonly prisma: PrismaService) {}

  async findMany(query: ListPlayersQueryDto) {
    const where: Prisma.PlayerWhereInput = {
      ...(query.search && {
        OR: [
          { name: { contains: query.search, mode: 'insensitive' } },
          { displayName: { contains: query.search, mode: 'insensitive' } },
        ],
      }),
      ...(query.country && { country: query.country }),
      ...(query.role && { role: query.role }),
      ...(query.team && { team: query.team }),
      ...(query.cardSetId && { statistics: { some: { cardSetId: query.cardSetId } } }),
    };

    const [data, total] = await Promise.all([
      this.prisma.player.findMany({
        where,
        include: query.cardSetId
          ? { statistics: { where: { cardSetId: query.cardSetId } } }
          : undefined,
        orderBy: { name: 'asc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.player.count({ where }),
    ]);

    return {
      data,
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
    };
  }

  findById(id: string) {
    return this.prisma.player.findUnique({
      where: { id },
      include: { statistics: { include: { cardSet: true } } },
    });
  }
}
