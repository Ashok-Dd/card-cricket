import { Module } from '@nestjs/common';
import { AdminService } from './admin.service.js';

@Module({
  providers: [AdminService]
})
export class AdminModule {}
