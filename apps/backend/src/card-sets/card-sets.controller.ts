import { Controller, Get, Param } from '@nestjs/common';
import { CardsService } from '../cards/cards.service.js';
import { CardSetsService } from './card-sets.service.js';

@Controller('card-sets')
export class CardSetsController {
  constructor(
    private readonly cardSetsService: CardSetsService,
    private readonly cardsService: CardsService,
  ) {}

  @Get()
  findEnabled() {
    return this.cardSetsService.findEnabled();
  }

  @Get(':code')
  findByCode(@Param('code') code: string) {
    return this.cardSetsService.findByCode(code);
  }

  @Get(':code/cards')
  async findCards(@Param('code') code: string) {
    const cardSet = await this.cardSetsService.findByCode(code);
    return this.cardsService.getEligibleCardsForCardSet(cardSet.id);
  }
}
