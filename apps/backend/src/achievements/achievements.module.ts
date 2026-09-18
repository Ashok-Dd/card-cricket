import { Module } from '@nestjs/common';
import { AchievementsService } from './achievements.service.js';

@Module({
  providers: [AchievementsService]
})
export class AchievementsModule {}
