import 'package:app_finnegans/domain/modelos/rol_usuario.dart';

enum UserStatus {
  active('Activo'),
  blocked('Bloqueado'),
  deleted('Eliminado');

  final String label;
  const UserStatus(this.label);
}

class AuthorizedUser {
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? blockedAt;
  final DateTime? deletedAt;

  AuthorizedUser({
    required String email,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.blockedAt,
    this.deletedAt,
  }) : email = email.trim().toLowerCase();

  AuthorizedUser.create({
    required String email,
    required UserRole role,
    required DateTime now,
  }) : this(email: email, role: role.name, isActive: true, createdAt: now);

  UserRole? get knownRole => UserRole.fromString(role);

  bool get isAdmin => knownRole == UserRole.admin;

  UserStatus get status {
    if (deletedAt != null) return UserStatus.deleted;
    if (blockedAt != null) return UserStatus.blocked;
    return UserStatus.active;
  }

  bool isSameUser(String? sessionEmail) =>
      sessionEmail != null && sessionEmail.trim().toLowerCase() == email;

  AuthorizedUser withRole(UserRole newRole) => _with(role: newRole.name);

  AuthorizedUser blocked(DateTime now) => _with(blockedAt: now);

  AuthorizedUser unblocked() => _with(clearBlock: true);

  AuthorizedUser deleted(DateTime now) => _with(deletedAt: now);

  AuthorizedUser restored() => _with(clearDeletion: true);

  AuthorizedUser _with({
    String? role,
    DateTime? blockedAt,
    DateTime? deletedAt,
    bool clearBlock = false,
    bool clearDeletion = false,
  }) {
    final block = clearBlock ? null : (blockedAt ?? this.blockedAt);
    final deletion = clearDeletion ? null : (deletedAt ?? this.deletedAt);
    return AuthorizedUser(
      email: email,
      role: role ?? this.role,
      isActive: deletion == null && block == null,
      createdAt: createdAt,
      blockedAt: block,
      deletedAt: deletion,
    );
  }
}
