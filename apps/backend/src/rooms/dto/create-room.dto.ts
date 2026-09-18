import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class CreateRoomDto {
  @IsUUID()
  cardSetId!: string;

  @IsInt()
  @Min(0)
  entryAmount: number = 0;

  @IsInt()
  @Min(2)
  @Max(6)
  maxPlayers!: number;

  /// How many cards to actually deal from the chosen set's pool (e.g. a
  /// 500-card IPL pool might be played as a 50/100/200-card match).
  /// Omitted/undefined means "use every eligible card" — validated against
  /// the set's real count in RoomsService.create.
  @IsOptional()
  @IsInt()
  @Min(10)
  deckSize?: number;
}
