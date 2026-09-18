import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { CurrentUser, type JwtUserPayload } from '../auth/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { GameEngineService } from './game-engine.service.js';

/// Plain-HTTP fallback for GameGateway's `game:subscribe` — same
/// personalized snapshot, usable without a socket handshake (initial page
/// load, debugging).
@Controller('games')
@UseGuards(new JwtAuthGuard())
export class GamesController {
  constructor(private readonly gameEngine: GameEngineService) {}

  @Get(':id')
  getById(@Param('id') id: string, @CurrentUser() user: JwtUserPayload) {
    return this.gameEngine.getStateForUser(id, user.id);
  }
}
