import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CoinTransactionType, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

/// Coin balances are never mutated directly — every change is a new
/// coin_transactions row plus the resulting Wallet.balance, written together,
/// inside a caller-supplied transaction. See docs/ECONOMY.md at the repo root.
@Injectable()
export class WalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /// Shared ledger primitive: idempotent (a repeated call with the same
  /// idempotencyKey is a no-op), and refuses to push a balance negative.
  private async applyDelta(
    tx: Prisma.TransactionClient,
    userId: string,
    type: CoinTransactionType,
    amount: number,
    idempotencyKey: string,
    options: { gameId?: string; description?: string } = {},
  ): Promise<void> {
    const existing = await tx.coinTransaction.findUnique({ where: { idempotencyKey } });
    if (existing) {
      return;
    }

    const wallet = await tx.wallet.findUnique({ where: { userId } });
    const currentBalance = wallet?.balance ?? 0;
    const newBalance = currentBalance + amount;

    if (newBalance < 0) {
      throw new HttpException(
        `Insufficient coins (balance ${currentBalance}, needs ${-amount})`,
        HttpStatus.PAYMENT_REQUIRED,
      );
    }

    if (wallet) {
      await tx.wallet.update({ where: { userId }, data: { balance: newBalance } });
    } else {
      await tx.wallet.create({ data: { userId, balance: newBalance } });
    }

    await tx.coinTransaction.create({
      data: {
        userId,
        type,
        amount,
        balanceAfter: newBalance,
        gameId: options.gameId,
        description: options.description,
        idempotencyKey,
      },
    });
  }

  /// Idempotent: safe to call more than once for the same userId (e.g. a
  /// retried registration request) — the unique idempotencyKey means only
  /// the first call actually creates a transaction/wallet.
  creditWelcomeReward(tx: Prisma.TransactionClient, userId: string): Promise<void> {
    const amount = Number(this.config.get('ECONOMY_WELCOME_BONUS_COINS') ?? 1000);
    return this.applyDelta(tx, userId, CoinTransactionType.WELCOME_REWARD, amount, `welcome:${userId}`, {
      description: 'Welcome reward',
    });
  }

  /// Debited when a match actually starts (not at room-join time — see
  /// docs/ECONOMY.md's entry-reservation notes). Throws HttpStatus.PAYMENT_REQUIRED
  /// if the player's balance has since dropped below the entry amount.
  deductGameEntry(
    tx: Prisma.TransactionClient,
    userId: string,
    gameId: string,
    amount: number,
  ): Promise<void> {
    return this.applyDelta(tx, userId, CoinTransactionType.GAME_ENTRY, -amount, `entry:${gameId}:${userId}`, {
      gameId,
      description: 'Room entry',
    });
  }

  /// Credited to the match winner — entry-pool redistribution and/or the
  /// flat completion bonus both use this (see GameEngineService).
  creditGameReward(
    tx: Prisma.TransactionClient,
    userId: string,
    gameId: string,
    amount: number,
    description: string,
  ): Promise<void> {
    return this.applyDelta(tx, userId, CoinTransactionType.GAME_REWARD, amount, `reward:${gameId}:${userId}`, {
      gameId,
      description,
    });
  }

  /// Returns a player's entry if a match is aborted before completion.
  refundGameEntry(
    tx: Prisma.TransactionClient,
    userId: string,
    gameId: string,
    amount: number,
  ): Promise<void> {
    return this.applyDelta(tx, userId, CoinTransactionType.REFUND, amount, `refund:${gameId}:${userId}`, {
      gameId,
      description: 'Entry refund',
    });
  }

  async getWallet(userId: string) {
    return this.prisma.wallet.findUnique({ where: { userId } });
  }

  async getTransactions(userId: string) {
    return this.prisma.coinTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
