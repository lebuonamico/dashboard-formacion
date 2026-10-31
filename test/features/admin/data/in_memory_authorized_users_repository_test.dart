import 'package:app_finnegans/features/admin/data/in_memory_authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:flutter_test/flutter_test.dart';

AuthorizedUser _user(String email) =>
    AuthorizedUser(email: email, role: 'teamLead', isActive: true);

void main() {
  test('Normaliza el email al guardar y al buscar', () async {
    final repository = InMemoryAuthorizedUsersRepository([
      _user('  Ana@Finnegans.COM '),
    ]);

    await repository.create(_user('Nuevo@Finnegans.com'));
    await repository.save(_user('ANA@finnegans.com').copyWith(role: 'admin'));

    final users = await repository.getUsers();
    expect(users.map((user) => user.email), [
      'ana@finnegans.com',
      'nuevo@finnegans.com',
    ]);
    expect(users.first.role, 'admin');
  });

  test('Un email repetido con otras mayúsculas no se da de alta', () async {
    final repository = InMemoryAuthorizedUsersRepository([
      _user('ana@finnegans.com'),
    ]);

    await expectLater(
      repository.create(_user(' ANA@finnegans.com')),
      throwsA(isA<FormatException>()),
    );
  });
}
