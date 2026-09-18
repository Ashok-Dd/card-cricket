import { Module } from '@nestjs/common';
import { CardSetsModule } from '../card-sets/card-sets.module.js';
import { CardsModule } from '../cards/cards.module.js';
import { GameModule } from '../game/game.module.js';
import { LobbyModule } from '../lobby/lobby.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { RoomsController } from './rooms.controller.js';
import { RoomsService } from './rooms.service.js';

@Module({
  // GameModule is one-directional here — GameModule never imports
  // RoomsModule — to avoid a circular module dependency.
  imports: [LobbyModule, CardSetsModule, CardsModule, WalletModule, GameModule],
  providers: [RoomsService],
  controllers: [RoomsController],
})
export class RoomsModule {}
