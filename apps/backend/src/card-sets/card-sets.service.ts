import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class CardSetsService {
  constructor(private readonly prisma: PrismaService) {}

  findEnabled() {
    return this.prisma.cardSet.findMany({
      where: { isEnabled: true },
      orderBy: { name: 'asc' },
    });
  }

  async findByCode(code: string) {
    const cardSet = await this.prisma.cardSet.findUnique({ where: { code } });
    if (!cardSet || !cardSet.isEnabled) {
      throw new NotFoundException(`Card set "${code}" not found`);
    }
    return cardSet;
  }

  async findEnabledById(id: string) {
    const cardSet = await this.prisma.cardSet.findUnique({ where: { id } });
    if (!cardSet || !cardSet.isEnabled) {
      throw new NotFoundException(`Card set "${id}" not found`);
    }
    return cardSet;
  }
}
