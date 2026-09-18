import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Wraps secure on-device storage for sensitive values (auth token only, for
/// now). Non-sensitive local prefs (e.g. sound on/off) belong in
/// shared_preferences, not here.
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveAuthToken(String token) =>
      _storage.write(key: AppConstants.secureStorageAuthTokenKey, value: token);

  Future<String?> readAuthToken() =>
      _storage.read(key: AppConstants.secureStorageAuthTokenKey);

  Future<void> clearAuthToken() =>
      _storage.delete(key: AppConstants.secureStorageAuthTokenKey);
}
