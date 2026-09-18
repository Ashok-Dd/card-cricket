import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser, type JwtUserPayload } from '../auth/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { CreateRoomDto } from './dto/create-room.dto.js';
import { SetReadyDto } from './dto/set-ready.dto.js';
import { RoomsService } from './rooms.service.js';

@Controller('rooms')
@UseGuards(new JwtAuthGuard())
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Post()
  create(@CurrentUser() user: JwtUserPayload, @Body() dto: CreateRoomDto) {
    return this.roomsService.create(user.id, dto);
  }

  @Get(':code')
  getByCode(@Param('code') code: string) {
    return this.roomsService.getByCode(code);
  }

  @Post(':code/join')
  join(@Param('code') code: string, @CurrentUser() user: JwtUserPayload) {
    return this.roomsService.join(code, user.id);
  }

  @Post(':code/ready')
  setReady(
    @Param('code') code: string,
    @CurrentUser() user: JwtUserPayload,
    @Body() dto: SetReadyDto,
  ) {
    return this.roomsService.setReady(code, user.id, dto.ready);
  }

  @Post(':code/leave')
  leave(@Param('code') code: string, @CurrentUser() user: JwtUserPayload) {
    return this.roomsService.leave(code, user.id);
  }

  @Post(':code/start')
  start(@Param('code') code: string, @CurrentUser() user: JwtUserPayload) {
    return this.roomsService.start(code, user.id);
  }
}
