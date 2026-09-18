import { Module } from '@nestjs/common';
import { LeaderboardService } from './leaderboard.service.js';

@Module({
  providers: [LeaderboardService]
})
export class LeaderboardModule {}
