import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';

/// Prisma 7 requires an explicit driver adapter at the client boundary
/// instead of a `url` in schema.prisma (see prisma.config.ts for the CLI/
/// migrate-side connection string).
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
      // Prisma's interactive-transaction defaults (maxWait 2s, timeout 5s)
      // assume a low-latency local database. Against a remote/serverless
      // Postgres (this project runs on Neon) each round trip can already
      // cost several hundred ms, which was blowing the default budget
      // before a transaction even got a chance to run its own queries
      // (P2028 "Unable to start a transaction in the given time" on every
      // register() call, which is a tiny 2-insert transaction).
      transactionOptions: { maxWait: 15_000, timeout: 20_000 },
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('Connected to PostgreSQL via Prisma');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
