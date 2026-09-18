import { Module } from '@nestjs/common';
import { PlayersService } from './players.service.js';
import { PlayersController } from './players.controller.js';

@Module({
  providers: [PlayersService],
  controllers: [PlayersController]
})
export class PlayersModule {}
