import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import * as bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PrismaService } from '../prisma/prisma.service.js';
import { UsersService } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { AuthService } from './auth.service.js';

describe('AuthService', () => {
  let authService: AuthService;
  let prisma: { $transaction: ReturnType<typeof vi.fn> };
  let usersService: { findByEmail: ReturnType<typeof vi.fn>; sanitize: ReturnType<typeof vi.fn> };
  let walletService: { creditWelcomeReward: ReturnType<typeof vi.fn> };
  let jwtService: { sign: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    prisma = { $transaction: vi.fn() };
    usersService = {
      findByEmail: vi.fn(),
      sanitize: vi.fn((user) => {
        const { passwordHash: _passwordHash, ...rest } = user;
        return rest;
      }),
    };
    walletService = { creditWelcomeReward: vi.fn() };
    jwtService = { sign: vi.fn(() => 'signed.jwt.token') };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: UsersService, useValue: usersService },
        { provide: WalletService, useValue: walletService },
        { provide: JwtService, useValue: jwtService },
      ],
    }).compile();

    authService = moduleRef.get(AuthService);
  });

  it('register() hashes the password, credits the welcome reward, and never returns passwordHash', async () => {
    const createdUser = {
      id: 'user-1',
      email: 'player@example.com',
      username: 'player1',
      passwordHash: 'hashed',
    };

    prisma.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) => {
      const tx = {
        user: { create: vi.fn().mockResolvedValue(createdUser) },
      };
      return callback(tx);
    });

    const result = await authService.register({
      email: 'player@example.com',
      username: 'player1',
      password: 'super-secret-1',
    });

    expect(walletService.creditWelcomeReward).toHaveBeenCalledWith(expect.anything(), 'user-1');
    expect(result.accessToken).toBe('signed.jwt.token');
    expect(result.user).not.toHaveProperty('passwordHash');
    expect(result.user.email).toBe('player@example.com');
  });

  it('login() rejects a bad password', async () => {
    const passwordHash = await bcrypt.hash('correct-password', 10);
    usersService.findByEmail.mockResolvedValue({
      id: 'user-1',
      email: 'player@example.com',
      username: 'player1',
      passwordHash,
    });

    await expect(
      authService.login({ email: 'player@example.com', password: 'wrong-password' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('login() rejects an unknown email', async () => {
    usersService.findByEmail.mockResolvedValue(null);

    await expect(
      authService.login({ email: 'ghost@example.com', password: 'whatever' }),
    ).rejects.toThrow(UnauthorizedException);
  });
});
