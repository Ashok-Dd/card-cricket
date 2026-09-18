import { Module } from '@nestjs/common';
import { RewardsService } from './rewards.service.js';

@Module({
  providers: [RewardsService]
})
export class RewardsModule {}
