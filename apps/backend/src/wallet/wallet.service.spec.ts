import { HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletService } from './wallet.service.js';

function makeTx(walletBalance: number | null) {
  const wallets = new Map<string, { userId: string; balance: number }>();
  if (walletBalance !== null) {
    wallets.set('user-1', { userId: 'user-1', balance: walletBalance });
  }
  const transactions = new Set<string>();

  return {
    coinTransaction: {
      findUnique: vi.fn(({ where }: { where: { idempotencyKey: string } }) =>
        transactions.has(where.idempotencyKey) ? { id: 'existing' } : null,
      ),
      create: vi.fn(({ data }: { data: { idempotencyKey: string } }) => {
        transactions.add(data.idempotencyKey);
        return data;
      }),
    },
    wallet: {
      findUnique: vi.fn(({ where }: { where: { userId: string } }) => wallets.get(where.userId) ?? null),
      update: vi.fn(({ where, data }: { where: { userId: string }; data: { balance: number } }) => {
        const wallet = wallets.get(where.userId)!;
        wallet.balance = data.balance;
        return wallet;
      }),
      create: vi.fn(({ data }: { data: { userId: string; balance: number } }) => {
        wallets.set(data.userId, data);
        return data;
      }),
    },
    _wallets: wallets,
  };
}

describe('WalletService', () => {
  let walletService: WalletService;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        WalletService,
        { provide: PrismaService, useValue: {} },
        { provide: ConfigService, useValue: { get: () => undefined } },
      ],
    }).compile();

    walletService = moduleRef.get(WalletService);
  });

  it('deductGameEntry lowers the balance and is idempotent on retry', async () => {
    const tx = makeTx(1000);

    await walletService.deductGameEntry(tx as any, 'user-1', 'game-1', 300);
    expect(tx._wallets.get('user-1')?.balance).toBe(700);

    // Same idempotency key (same gameId+userId) — must not deduct twice.
    await walletService.deductGameEntry(tx as any, 'user-1', 'game-1', 300);
    expect(tx._wallets.get('user-1')?.balance).toBe(700);
  });

  it('deductGameEntry rejects when the balance is no longer sufficient', async () => {
    const tx = makeTx(100);

    await expect(walletService.deductGameEntry(tx as any, 'user-1', 'game-1', 300)).rejects.toThrow(
      HttpException,
    );
    expect(tx._wallets.get('user-1')?.balance).toBe(100);
  });

  it('creditGameReward raises the balance', async () => {
    const tx = makeTx(0);

    await walletService.creditGameReward(tx as any, 'user-1', 'game-1', 600, 'Match reward');
    expect(tx._wallets.get('user-1')?.balance).toBe(600);
  });

  it('refundGameEntry restores a previously deducted amount', async () => {
    const tx = makeTx(700);

    await walletService.refundGameEntry(tx as any, 'user-1', 'game-1', 300);
    expect(tx._wallets.get('user-1')?.balance).toBe(1000);
  });
});
