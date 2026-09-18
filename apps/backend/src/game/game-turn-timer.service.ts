import { Injectable, Logger } from '@nestjs/common';

/// Schedules the server-side 30s turn-timeout enforcement (docs/GAME_RULES.md
/// lists "invalid or post-timeout statistic selection" as a required edge
/// case — the client's own countdown is cosmetic only, this is what actually
/// makes a timeout real). One pending timer per game at a time: every call
/// to `schedule` for a gameId replaces whatever was pending before, which is
/// exactly right because a fresh call only ever happens when a new decision
/// point begins (see GameEngineService.scheduleTurnTimeout) — the previous
/// decision, if any, is already over.
///
/// Single-instance only, same documented limitation as GameLockService: an
/// in-memory Map, not a distributed scheduler. Fine for one backend process;
/// would need a durable/shared job queue to run more than one.
@Injectable()
export class GameTurnTimerService {
  private readonly logger = new Logger(GameTurnTimerService.name);
  private readonly timers = new Map<string, NodeJS.Timeout>();

  schedule(gameId: string, durationMs: number, onExpire: () => Promise<void>): void {
    this.clear(gameId);
    const timeout = setTimeout(() => {
      this.timers.delete(gameId);
      onExpire().catch((err: unknown) => {
        this.logger.error(`Turn-timeout handler failed for game ${gameId}`, err as Error);
      });
    }, durationMs);
    // Never let a pending turn timer keep the Node process alive on its own
    // (e.g. during tests or graceful shutdown).
    timeout.unref?.();
    this.timers.set(gameId, timeout);
  }

  clear(gameId: string): void {
    const existing = this.timers.get(gameId);
    if (existing) {
      clearTimeout(existing);
      this.timers.delete(gameId);
    }
  }
}
