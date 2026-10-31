enum UserStatus { active, blocked, deleted }

class AuthorizedUser {
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? blockedAt;
  final DateTime? deletedAt;

  const AuthorizedUser({
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.blockedAt,
    this.deletedAt,
  });

  AuthorizedUser copyWith({
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? blockedAt,
    DateTime? deletedAt,
  }) => AuthorizedUser(
    email: email ?? this.email,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    blockedAt: blockedAt ?? this.blockedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
