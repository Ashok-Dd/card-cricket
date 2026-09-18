import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Redis } from 'ioredis';
import RedisMock from 'ioredis-mock';

/// Redis holds live/ephemeral game coordination state (active rooms, lobby
/// state, turn state, tie-sequence state, the authoritative in-progress
/// GameState blob). Persistent match history lives in PostgreSQL via Prisma.
/// See docs/ARCHITECTURE.md.
///
/// REDIS_MOCK=true swaps in an in-memory, single-process ioredis-mock client
/// instead of a real Redis connection — used on machines without a working
/// Docker/WSL setup (see the dev-environment memory). Same `.client` API
/// either way; production must leave REDIS_MOCK unset.
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private _client!: Redis;

  get client(): Redis {
    return this._client;
  }

  onModuleInit(): void {
    if (process.env.REDIS_MOCK === 'true') {
      this._client = new RedisMock();
      this.logger.warn('Using in-memory ioredis-mock (REDIS_MOCK=true) — not for production');
      return;
    }

    // lazyConnect: nothing at boot time strictly requires Redis to already
    // be connected — the app must not refuse to start just because Redis
    // happens to be briefly unavailable.
    this._client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
      lazyConnect: true,
    });
    this._client.on('error', (error) => this.logger.warn(`Redis error: ${error.message}`));
  }

  async onModuleDestroy(): Promise<void> {
    if (this._client.status !== 'end') {
      await this._client.quit().catch(() => undefined);
    }
  }
}
