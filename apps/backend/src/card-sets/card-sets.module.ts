import { Module } from '@nestjs/common';
import { CardsModule } from '../cards/cards.module.js';
import { CardSetsController } from './card-sets.controller.js';
import { CardSetsService } from './card-sets.service.js';

@Module({
  imports: [CardsModule],
  providers: [CardSetsService],
  controllers: [CardSetsController],
  exports: [CardSetsService],
})
export class CardSetsModule {}
