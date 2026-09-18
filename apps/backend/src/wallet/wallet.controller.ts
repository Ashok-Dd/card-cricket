import { Controller, Get, NotFoundException, UseGuards } from '@nestjs/common';
import { CurrentUser, type JwtUserPayload } from '../auth/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { WalletService } from './wallet.service.js';

@Controller('wallet')
@UseGuards(new JwtAuthGuard())
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  async getWallet(@CurrentUser() user: JwtUserPayload) {
    const wallet = await this.walletService.getWallet(user.id);
    if (!wallet) {
      throw new NotFoundException('Wallet not found');
    }
    return wallet;
  }

  @Get('transactions')
  getTransactions(@CurrentUser() user: JwtUserPayload) {
    return this.walletService.getTransactions(user.id);
  }
}
