import 'package:app_finnegans/features/admin/data/authorized_users_seed.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';

class InMemoryAuthorizedUsersRepository implements AuthorizedUsersRepository {
  final Map<String, AuthorizedUser> _users;

  InMemoryAuthorizedUsersRepository([List<AuthorizedUser>? users])
    : _users = {
        for (final user in users ?? authorizedUsersSeed) user.email: user,
      };

  @override
  Future<List<AuthorizedUser>> getUsers() async =>
      _users.values.toList()..sort((a, b) => a.email.compareTo(b.email));

  @override
  Future<void> create(AuthorizedUser user) async {
    if (_users.containsKey(user.email)) {
      throw const FormatException(
        'Ya existe un usuario con ese email. '
        'Si fue eliminado, restauralo desde la lista.',
      );
    }
    _users[user.email] = user;
  }

  @override
  Future<void> save(AuthorizedUser user) async {
    if (!_users.containsKey(user.email)) {
      throw const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    }
    _users[user.email] = user;
  }
}
