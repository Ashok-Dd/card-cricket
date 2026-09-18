import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/socket_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';

/// Null means logged out. Loading on first build means "checking a stored
/// token"; the router treats that as "stay put" (see app_router.dart), not
/// as logged-out, so a returning user doesn't flash the login screen.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final token = await ref.read(secureStorageServiceProvider).readAuthToken();
    if (token == null) return null;

    try {
      final user = await ref.read(authRepositoryProvider).me();
      ref.read(socketServiceProvider).connect(token);
      return user;
    } on DioException catch (error) {
      // Only a genuine "this token is invalid/expired" response should log
      // the user out. Everything else (server unreachable, timeout, a
      // flaky connection) is a transient problem, not a bad credential —
      // wiping the token here used to mean any network hiccup on launch
      // permanently signed the user out, defeating "stay logged in until
      // you uninstall". Keep the token; just report logged-out for now,
      // and the next successful launch/retry picks it back up.
      if (error.response?.statusCode == 401) {
        await ref.read(secureStorageServiceProvider).clearAuthToken();
      }
      return null;
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(authRepositoryProvider)
          .register(email: email, username: username, password: password);
      await _onAuthenticated(result);
      return result.user;
    });
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(authRepositoryProvider).login(email: email, password: password);
      await _onAuthenticated(result);
      return result.user;
    });
  }

  Future<void> _onAuthenticated(AuthResult result) async {
    await ref.read(secureStorageServiceProvider).saveAuthToken(result.accessToken);
    ref.read(socketServiceProvider).connect(result.accessToken);
  }

  Future<void> logout() async {
    await ref.read(secureStorageServiceProvider).clearAuthToken();
    ref.read(socketServiceProvider).disconnect();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
