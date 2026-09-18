import { Injectable } from '@nestjs/common';

/// Serializes every mutation to a given game behind a per-gameId promise
/// chain, so concurrent/duplicate WebSocket messages for the same game
/// can't race each other (docs/GAME_RULES.md "race conditions", "duplicate
/// statistic selection", "multiple simultaneous messages").
///
/// Single-instance only: this is an in-memory Map, not a distributed lock.
/// Running more than one backend process would need a real Redis lock
/// (e.g. SET NX) instead — a documented follow-up, not needed here.
@Injectable()
export class GameLockService {
  private readonly chains = new Map<string, Promise<unknown>>();

  async withLock<T>(gameId: string, fn: () => Promise<T>): Promise<T> {
    const previous = this.chains.get(gameId) ?? Promise.resolve();
    const run = previous.then(fn, fn);
    // Swallow errors here so the chain itself never breaks for the next
    // caller — the actual error still propagates to whoever awaits `run`.
    this.chains.set(
      gameId,
      run.catch(() => undefined),
    );
    return run;
  }
}
