import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/admin/data/authorized_users_seed.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';

class InMemoryAuthorizedUsersRepository implements AuthorizedUsersRepository {
  final Map<String, AuthorizedUser> _users;

  InMemoryAuthorizedUsersRepository([List<AuthorizedUser>? users])
    : _users = {
        for (final user in users ?? authorizedUsersSeed)
          normalizeLoose(user.email): _normalized(user),
      };

  @override
  Future<List<AuthorizedUser>> getUsers() async =>
      _users.values.toList()..sort((a, b) => a.email.compareTo(b.email));

  @override
  Future<void> create(AuthorizedUser user) async {
    final normalized = _normalized(user);
    if (_users.containsKey(normalized.email)) {
      throw const FormatException(
        'Ya existe un usuario con ese email. '
        'Si fue eliminado, restauralo desde la lista.',
      );
    }
    _users[normalized.email] = normalized;
  }

  @override
  Future<void> save(AuthorizedUser user) async {
    final normalized = _normalized(user);
    if (!_users.containsKey(normalized.email)) {
      throw const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    }
    _users[normalized.email] = normalized;
  }

  static AuthorizedUser _normalized(AuthorizedUser user) =>
      user.copyWith(email: normalizeLoose(user.email));
}
