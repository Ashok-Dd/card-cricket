import { AuthGuard } from '@nestjs/passport';

/// Apply via `@UseGuards(new JwtAuthGuard())` (an instance, not the bare
/// class) to any route that requires a logged-in user. Passing an instance
/// sidesteps Nest's per-module DI resolution for the guard's optional
/// AuthModuleOptions constructor param, which otherwise forces every
/// consuming module (Wallet, and later Rooms/Lobby/Game) to import
/// PassportModule itself just to satisfy the guard's own dependency.
export class JwtAuthGuard extends AuthGuard('jwt') {}
