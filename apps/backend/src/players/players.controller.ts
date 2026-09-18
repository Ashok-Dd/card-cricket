import { Controller, Get, NotFoundException, Param, Query } from '@nestjs/common';
import { ListPlayersQueryDto } from './dto/list-players-query.dto.js';
import { PlayersService } from './players.service.js';

@Controller('players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get()
  findMany(@Query() query: ListPlayersQueryDto) {
    return this.playersService.findMany(query);
  }

  @Get(':id')
  async findById(@Param('id') id: string) {
    const player = await this.playersService.findById(id);
    if (!player) {
      throw new NotFoundException('Player not found');
    }
    return player;
  }
}
