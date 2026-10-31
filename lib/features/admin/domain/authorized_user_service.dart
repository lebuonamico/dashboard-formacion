import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/domain/user_role_parser.dart';

/// Reglas de la allowlist: un usuario está activo si no tiene sello de
/// eliminación ni de bloqueo, y la eliminación manda sobre el bloqueo.
class AuthorizedUserService {
  final UserRoleParser roles;

  const AuthorizedUserService({this.roles = const UserRoleParser()});

  AuthorizedUser create({
    required String email,
    required UserRole role,
    required DateTime now,
  }) => AuthorizedUser(
    email: normalizeLoose(email),
    role: role.name,
    isActive: true,
    createdAt: now,
  );

  /// `null` para un rol que la app no conoce (por ejemplo, uno legacy).
  UserRole? knownRole(AuthorizedUser user) => roles.tryParse(user.role);

  bool isAdmin(AuthorizedUser user) => knownRole(user) == UserRole.admin;

  UserStatus status(AuthorizedUser user) {
    if (user.deletedAt != null) return UserStatus.deleted;
    if (user.blockedAt != null) return UserStatus.blocked;
    return UserStatus.active;
  }

  bool isSameUser(AuthorizedUser user, String? sessionEmail) =>
      sessionEmail != null &&
      normalizeLoose(sessionEmail) == normalizeLoose(user.email);

  AuthorizedUser withRole(AuthorizedUser user, UserRole role) =>
      user.copyWith(role: role.name);

  AuthorizedUser block(AuthorizedUser user, DateTime now) =>
      _stamped(user, blockedAt: now, deletedAt: user.deletedAt);

  AuthorizedUser unblock(AuthorizedUser user) =>
      _stamped(user, blockedAt: null, deletedAt: user.deletedAt);

  AuthorizedUser delete(AuthorizedUser user, DateTime now) =>
      _stamped(user, blockedAt: user.blockedAt, deletedAt: now);

  AuthorizedUser restore(AuthorizedUser user) =>
      _stamped(user, blockedAt: user.blockedAt, deletedAt: null);

  AuthorizedUser _stamped(
    AuthorizedUser user, {
    required DateTime? blockedAt,
    required DateTime? deletedAt,
  }) => AuthorizedUser(
    email: user.email,
    role: user.role,
    isActive: blockedAt == null && deletedAt == null,
    createdAt: user.createdAt,
    blockedAt: blockedAt,
    deletedAt: deletedAt,
  );
}
