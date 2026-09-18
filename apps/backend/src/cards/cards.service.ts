import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class CardsService {
  constructor(private readonly prisma: PrismaService) {}

  /// Every card belonging to a card set, with the player + stat snapshot
  /// needed to render it. This is also what Phase 4's game engine will call
  /// to build the shuffled deck for a match — see docs/GAME_RULES.md.
  getEligibleCardsForCardSet(cardSetId: string) {
    return this.prisma.card.findMany({
      where: { cardSetId },
      include: { player: true, statistics: true },
      orderBy: { rating: 'desc' },
    });
  }

  /// How many cards actually exist in a set — used to validate a room's
  /// requested deck size (RoomsService.create) before a match ever starts.
  countCardsForCardSet(cardSetId: string) {
    return this.prisma.card.count({ where: { cardSetId } });
  }
}
