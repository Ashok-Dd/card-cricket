import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/user.dart';

class AuthResult {
  const AuthResult({required this.accessToken, required this.user});
  final String accessToken;
  final AuthUser user;
}

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'email': email, 'username': username, 'password': password},
    );
    return AuthResult(
      accessToken: response.data['accessToken'] as String,
      user: AuthUser.fromJson(response.data['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return AuthResult(
      accessToken: response.data['accessToken'] as String,
      user: AuthUser.fromJson(response.data['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthUser> me() async {
    final response = await _dio.get('/auth/me');
    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// A lightweight, unauthenticated call whose only purpose is to make sure
  /// *some* request has reached the backend as early as possible — see
  /// AuthController.build(): a brand-new user with no stored token skips
  /// straight past `me()` and would otherwise send nothing at all until
  /// they actually submit the login form, turning that tap into the first
  /// real request and eating a cold-start delay at the worst possible
  /// moment instead of during the splash screen's passive wait.
  Future<void> ping() async {
    await _dio.get('/');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider).dio);
});
