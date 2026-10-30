import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';

abstract interface class AuthorizedUsersRepository {
  Future<List<AuthorizedUser>> getUsers();

  Future<void> create(AuthorizedUser user);

  Future<void> save(AuthorizedUser user);
}
