import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { CardsModule } from '../cards/cards.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { GameEngineService } from './game-engine.service.js';
import { GameGateway } from './game.gateway.js';
import { GameLockService } from './game-lock.service.js';
import { GameStateStore } from './game-state.store.js';
import { GameTurnTimerService } from './game-turn-timer.service.js';
import { GamesController } from './games.controller.js';
import { RealtimeService } from './realtime.service.js';

@Module({
  imports: [
    CardsModule,
    WalletModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') ?? 'dev-secret-change-me',
      }),
    }),
  ],
  controllers: [GamesController],
  providers: [
    GameGateway,
    RealtimeService,
    GameEngineService,
    GameLockService,
    GameStateStore,
    GameTurnTimerService,
  ],
  exports: [RealtimeService, GameEngineService],
})
export class GameModule {}
