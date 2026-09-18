import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureStorageServiceProvider));
});

/// Thin wrapper around Dio. Feature repositories depend on this, never on
/// Dio directly, so auth headers/interceptors/error mapping stay in one place.
class ApiClient {
  ApiClient(this._storage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            // Generous enough to survive a Render free-tier cold start.
            // 60s wasn't quite enough in practice — a real cold start hit
            // the old receiveTimeout and surfaced as a raw Dio exception
            // mid-login, not just at app launch (which has its own
            // "waking up" splash-screen animation covering the /auth/me
            // check specifically). 100s leaves real margin; api_error.dart
            // also gives this a friendly message instead of the raw
            // exception text if it's ever hit anyway.
            connectTimeout: const Duration(seconds: 100),
            receiveTimeout: const Duration(seconds: 100),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final SecureStorageService _storage;
}
