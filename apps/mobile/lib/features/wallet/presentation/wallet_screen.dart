import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/wallet.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../data/wallet_repository.dart';

const _typeIcons = {
  'WELCOME_REWARD': Icons.card_giftcard,
  'DAILY_REWARD': Icons.today,
  'GAME_ENTRY': Icons.logout,
  'GAME_REWARD': Icons.emoji_events,
  'ACHIEVEMENT_REWARD': Icons.military_tech,
  'TOURNAMENT_REWARD': Icons.workspace_premium,
  'REFUND': Icons.replay,
  'ADMIN_ADJUSTMENT': Icons.build,
};

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Wallet', style: AppTextStyles.title)),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletProvider);
            ref.invalidate(walletTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              walletAsync.when(
                data: (wallet) => _BalanceCard(balance: wallet.balance),
                loading: () => const _BalanceCard(balance: null),
                error: (error, _) => Text('Could not load balance', style: AppTextStyles.body),
              ),
              const SizedBox(height: 28),
              Text('TRANSACTIONS', style: AppTextStyles.overline),
              const SizedBox(height: 10),
              transactionsAsync.when(
                data: (transactions) => transactions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No transactions yet', style: AppTextStyles.body),
                      )
                    : Column(
                        children: [
                          for (final t in transactions) ...[
                            _TransactionRow(transaction: t),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text('Could not load transactions', style: AppTextStyles.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final int? balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CURRENT BALANCE', style: AppTextStyles.overline.copyWith(color: AppColors.navyDark)),
              const SizedBox(height: 8),
              Text(
                balance == null ? '—' : NumberFormat.decimalPattern().format(balance),
                style: AppTextStyles.hero.copyWith(fontSize: 36, color: AppColors.navyDark),
              ),
            ],
          ),
          Icon(Icons.monetization_on, size: 48, color: AppColors.navyDark.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});
  final CoinTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.amount >= 0;
    final sign = isPositive ? '+' : '';
    final color = isPositive ? AppColors.electricGreen : AppColors.danger;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(_typeIcons[transaction.type] ?? Icons.swap_horiz, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              transaction.description ?? transaction.type,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text(
            '$sign${transaction.amount}',
            style: AppTextStyles.cardStatValue.copyWith(color: color, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
