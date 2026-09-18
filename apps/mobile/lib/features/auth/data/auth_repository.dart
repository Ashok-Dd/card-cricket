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
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider).dio);
});
