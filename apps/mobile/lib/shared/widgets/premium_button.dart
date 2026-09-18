import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum PremiumButtonVariant { primary, secondary, danger }

/// The one button used for every primary/secondary action in the app — a
/// consistent tap-scale + glow so it feels like a game UI rather than a
/// stock Material button. Wraps the existing themed button styles rather
/// than replacing them outright.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PremiumButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.textStyle,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PremiumButtonVariant variant;
  final bool isLoading;
  final bool expand;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_enabled) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: widget.variant == PremiumButtonVariant.primary
                  ? AppColors.navyDark
                  : AppColors.textPrimary,
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: _foreground),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label.toUpperCase(),
            style: (widget.textStyle ?? AppTextStyles.button).copyWith(color: _foreground),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: _enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: widget.padding,
            decoration: _decoration,
            child: content,
          ),
        ),
      ),
    );
  }

  Color get _foreground {
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return AppColors.navyDark;
      case PremiumButtonVariant.secondary:
        return AppColors.textPrimary;
      case PremiumButtonVariant.danger:
        return AppColors.danger;
    }
  }

  BoxDecoration get _decoration {
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        );
      case PremiumButtonVariant.secondary:
        return BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
        );
      case PremiumButtonVariant.danger:
        return BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5),
        );
    }
  }
}
