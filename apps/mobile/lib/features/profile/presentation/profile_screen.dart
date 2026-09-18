import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../auth/domain/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('Profile', style: AppTextStyles.title)),
      body: AppBackground(
        child: user == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        boxShadow: [
                          BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.navyElevated,
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          style: AppTextStyles.hero.copyWith(fontSize: 32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: Text(user.username, style: AppTextStyles.headline)),
                  const SizedBox(height: 2),
                  Center(child: Text(user.email, style: AppTextStyles.body)),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _StatTile(icon: Icons.military_tech, label: 'Level', value: '${user.level}')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatTile(icon: Icons.bolt, label: 'XP', value: '${user.xp}')),
                    ],
                  ),
                  const SizedBox(height: 32),
                  PremiumButton(
                    label: 'Log Out',
                    icon: Icons.logout,
                    variant: PremiumButtonVariant.danger,
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 16,
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headline.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTextStyles.overline),
        ],
      ),
    );
  }
}
