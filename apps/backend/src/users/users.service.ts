import { Injectable } from '@nestjs/common';
import type { User } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

export type AuthenticatedUser = Omit<User, 'passwordHash'>;
export type PublicProfile = Omit<User, 'passwordHash' | 'email'>;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  /// For the owning user only (e.g. GET /auth/me) — strips passwordHash but
  /// keeps email.
  sanitize(user: User): AuthenticatedUser {
    const { passwordHash: _passwordHash, ...authenticatedUser } = user;
    return authenticatedUser;
  }

  /// For any other viewer (e.g. GET /users/:id, opponent info in a game) —
  /// strips passwordHash and email too.
  toPublicProfile(user: User): PublicProfile {
    const { passwordHash: _passwordHash, email: _email, ...publicProfile } = user;
    return publicProfile;
  }
}
