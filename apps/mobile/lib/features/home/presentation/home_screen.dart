import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../auth/domain/auth_controller.dart';
import '../../wallet/data/wallet_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.navySurface,
                          child: Text(
                            user != null && user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                            style: AppTextStyles.title.copyWith(color: AppColors.gold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          user != null ? user.username : '',
                          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.go('/wallet'),
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        borderRadius: 24,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, size: 18, color: AppColors.gold),
                            const SizedBox(width: 6),
                            Text(
                              walletAsync.value?.balance.toString() ?? '…',
                              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 34, spreadRadius: 3),
                    ],
                  ),
                  child: const Icon(Icons.sports_cricket, size: 48, color: AppColors.navyDark),
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
                  child: Text(
                    'CARD CRICKET',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.hero.copyWith(fontSize: 34, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time cricket card battles',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
                const Spacer(flex: 3),
                PremiumButton(
                  label: 'Create Room',
                  icon: Icons.add_circle_outline,
                  onPressed: () => context.go('/create-room'),
                ),
                const SizedBox(height: 14),
                PremiumButton(
                  label: 'Join Room',
                  icon: Icons.meeting_room_outlined,
                  variant: PremiumButtonVariant.secondary,
                  onPressed: () => context.go('/join-room'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.go('/how-to-play'),
                        icon: const Icon(Icons.menu_book_outlined, size: 18, color: AppColors.textSecondary),
                        label: Text('HOW TO PLAY', style: AppTextStyles.caption),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.go('/profile'),
                        icon: const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                        label: Text('PROFILE', style: AppTextStyles.caption),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
