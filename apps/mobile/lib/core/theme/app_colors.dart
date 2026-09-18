import 'package:flutter/material.dart';

/// Palette for the "modern sports esports + collectible card game" visual
/// direction. See docs/CARD_DESIGN.md at the repo root before adding colors.
class AppColors {
  AppColors._();

  // Base surfaces
  static const Color black = Color(0xFF05070A);
  static const Color navyDark = Color(0xFF0A1220);
  static const Color navy = Color(0xFF101A2E);
  static const Color navySurface = Color(0xFF16223A);
  static const Color navyElevated = Color(0xFF1C2A45);

  // Accents
  static const Color gold = Color(0xFFE8B84B);
  static const Color goldBright = Color(0xFFFFD873);
  static const Color goldDeep = Color(0xFFB9862E);
  static const Color electricGreen = Color(0xFF3DFFAE);
  static const Color neonBlue = Color(0xFF4FC3FF);
  static const Color skyBlue = Color(0xFF7FD8FF);
  static const Color violet = Color(0xFFB388FF);

  // Semantic
  static const Color success = electricGreen;
  static const Color danger = Color(0xFFFF5C5C);
  static const Color warning = gold;

  static const Color textPrimary = Color(0xFFF4F7FB);
  static const Color textSecondary = Color(0xFFA9B4C8);
  static const Color textMuted = Color(0xFF6B7789);

  /// Deeper, three-stop backdrop — more depth than a flat two-tone fade.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1830), navyDark, black],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldBright, gold, goldDeep],
    stops: [0.0, 0.55, 1.0],
  );

  /// Frosted-glass panel fill/border — the base for `GlassPanel`.
  static Color glassFill = Colors.white.withValues(alpha: 0.045);
  static Color glassBorder = Colors.white.withValues(alpha: 0.09);

  /// One accent per rarity tier, used for CricketCard borders/glows and
  /// anywhere else rarity needs a visual identity. Keys match the
  /// `CardRarity` enum values the backend sends verbatim.
  static const Map<String, Color> rarity = {
    'COMMON': Color(0xFF8FA3C7),
    'RARE': Color(0xFF4FC3FF),
    'EPIC': Color(0xFFB388FF),
    'LEGENDARY': Color(0xFFFF9E4F),
    'ICONIC': gold,
  };

  static Color rarityColor(String value) => rarity[value] ?? gold;

  /// A stable, deterministic accent per country name — not a real flag,
  /// just enough visual variety that cards don't all look identical.
  static Color countryAccent(String country) {
    const accents = [electricGreen, skyBlue, violet, Color(0xFFFF8A65), goldBright];
    return accents[country.hashCode.abs() % accents.length];
  }
}
