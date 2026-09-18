import { createParamDecorator, type ExecutionContext } from '@nestjs/common';

export interface JwtUserPayload {
  id: string;
  email: string;
  username: string;
}

/// Reads the user attached by JwtStrategy.validate() — use on any route
/// behind JwtAuthGuard.
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtUserPayload => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
