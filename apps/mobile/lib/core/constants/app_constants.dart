/// App-wide constants that are truly static (not game config).
///
/// Anything that can change without a client rebuild — reward amounts, entry
/// tiers, card-set metadata, rarity tiers — must come from the backend, not
/// live here. See docs/ARCHITECTURE.md and docs/ECONOMY.md at the repo root.
class AppConstants {
  AppConstants._();

  static const String appName = 'Card Cricket';

  static const int minPlayers = 2;
  static const int maxPlayers = 6;

  /// Overridden per-environment via --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String secureStorageAuthTokenKey = 'auth_token';
}
