import 'package:app_finnegans/features/admin/domain/authorized_user.dart';

abstract interface class AuthorizedUsersRepository {
  Future<List<AuthorizedUser>> getUsers();

  Future<void> create(AuthorizedUser user);

  Future<void> save(AuthorizedUser user);
}
