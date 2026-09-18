/// Mirrors the backend's AuthenticatedUser shape (GET /auth/me, register/login).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.avatarUrl,
    required this.level,
    required this.xp,
  });

  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final int level;
  final int xp;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        level: json['level'] as int,
        xp: json['xp'] as int,
      );
}
