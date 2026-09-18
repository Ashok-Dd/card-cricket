import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { RedisModule } from './redis/redis.module.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { PlayersModule } from './players/players.module.js';
import { CardSetsModule } from './card-sets/card-sets.module.js';
import { CardsModule } from './cards/cards.module.js';
import { RoomsModule } from './rooms/rooms.module.js';
import { LobbyModule } from './lobby/lobby.module.js';
import { WalletModule } from './wallet/wallet.module.js';
import { RewardsModule } from './rewards/rewards.module.js';
import { AchievementsModule } from './achievements/achievements.module.js';
import { LeaderboardModule } from './leaderboard/leaderboard.module.js';
import { AdminModule } from './admin/admin.module.js';
import { GameModule } from './game/game.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Infra (global, exported once for the whole app)
    PrismaModule,
    RedisModule,
    // Domain modules — see docs/ARCHITECTURE.md for what each owns
    AuthModule,
    UsersModule,
    PlayersModule,
    CardSetsModule,
    CardsModule,
    RoomsModule,
    LobbyModule,
    GameModule,
    WalletModule,
    RewardsModule,
    AchievementsModule,
    LeaderboardModule,
    AdminModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
