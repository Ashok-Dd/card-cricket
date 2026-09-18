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
            // Generous enough to survive a Render free-tier cold start (the
            // backend's container can take 30-50s to spin back up after
            // being idle) — see SplashScreen for the "waking up" UI shown
            // to the user while the very first request is in flight.
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
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
