import { Injectable, NotFoundException } from '@nestjs/common';
import { RedisService } from '../redis/redis.service.js';
import type { GameState } from './game-state.types.js';

@Injectable()
export class GameStateStore {
  constructor(private readonly redis: RedisService) {}

  private key(gameId: string): string {
    return `game:${gameId}`;
  }

  async load(gameId: string): Promise<GameState> {
    const raw = await this.redis.client.get(this.key(gameId));
    if (!raw) {
      throw new NotFoundException(`No live state for game "${gameId}"`);
    }
    return JSON.parse(raw) as GameState;
  }

  async tryLoad(gameId: string): Promise<GameState | null> {
    const raw = await this.redis.client.get(this.key(gameId));
    return raw ? (JSON.parse(raw) as GameState) : null;
  }

  async save(state: GameState): Promise<void> {
    await this.redis.client.set(this.key(state.gameId), JSON.stringify(state));
  }
}
