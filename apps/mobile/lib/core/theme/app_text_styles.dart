import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralized text styles. Never hardcode a font/weight/size in a widget —
/// add or extend a style here instead.
///
/// Two families: Rajdhani (condensed, athletic — headlines/display/card
/// names, anywhere the app should feel like a game HUD) and Manrope (body
/// copy, captions — stays readable at small sizes).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _display => GoogleFonts.rajdhani(color: AppColors.textPrimary);
  static TextStyle get _base => GoogleFonts.manrope(color: AppColors.textPrimary);

  /// Splash/victory-scale hero text.
  static TextStyle get hero => _display.copyWith(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        height: 1,
      );

  static TextStyle get displayLarge => _display.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  static TextStyle get headline => _display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  static TextStyle get title => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get body => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      );

  static TextStyle get overline => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AppColors.textMuted,
      );

  static TextStyle get button => _display.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );

  /// For player names on cards / banners — bold, all-caps by convention.
  static TextStyle get cardName => _display.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.navyDark,
        letterSpacing: 0.3,
      );

  /// For stat values on cards.
  static TextStyle get cardStatValue => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.skyBlue,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get cardStatLabel => _base.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
}
