import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/premium_button.dart';

class StatButton extends StatelessWidget {
  const StatButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumButton(
      label: label,
      onPressed: onTap,
      variant: PremiumButtonVariant.secondary,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      textStyle: AppTextStyles.button.copyWith(fontSize: 13),
    );
  }
}
