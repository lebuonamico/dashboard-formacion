import 'dart:async';

import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/features/admin/presentation/providers/authorized_users_repository_provider.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 3, 14, 30);

class _FakeUsers implements AuthorizedUsersRepository {
  List<AuthorizedUser> users;
  final saved = <AuthorizedUser>[];
  final created = <AuthorizedUser>[];
  Object? error;
  Completer<void>? gate;

  _FakeUsers(this.users);

  @override
  Future<List<AuthorizedUser>> getUsers() async => users;

  @override
  Future<void> create(AuthorizedUser user) async {
    await gate?.future;
    created.add(user);
    users = [...users, user];
  }

  @override
  Future<void> save(AuthorizedUser user) async {
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    saved.add(user);
    users = [
      for (final current in users)
        if (current.email == user.email) user else current,
    ];
  }
}

class _CountingAuth extends AuthNotifier {
  int validations = 0;

  _CountingAuth(String email)
    : super(
        AuthState(
          user: AuthUser(id: 'test-user', email: email),
          isAuthorized: true,
          role: UserRole.admin.name,
        ),
      );

  @override
  Future<void> validateAuthorization() async => validations++;
}

AuthorizedUser _user(String email) => AuthorizedUser(
  email: email,
  role: UserRole.teamLead.name,
  isActive: true,
  createdAt: DateTime.utc(2026, 1, 15),
);

Future<(ProviderContainer, _FakeUsers, _CountingAuth)> _setUp({
  String sessionEmail = 'admin@finnegans.com',
}) async {
  final repository = _FakeUsers([_user('ana@finnegans.com')]);
  final auth = _CountingAuth(sessionEmail);
  final container = ProviderContainer(
    overrides: [
      authorizedUsersRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => _now),
      authProvider.overrideWith(() => auth),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(adminUsersProvider, (_, _) {});
  await container.read(adminUsersProvider.future);
  return (container, repository, auth);
}

AdminUsersState _state(ProviderContainer container) =>
    container.read(adminUsersProvider).requireValue;

void main() {
  test('Bloquear sella la hora del reloj y recarga la lista', () async {
    final (container, repository, auth) = await _setUp();
    final ana = _state(container).users.single;

    await container.read(adminUsersProvider.notifier).block(ana);

    expect(repository.saved.single.blockedAt, _now);
    expect(
      const AuthorizedUserService().status(_state(container).users.single),
      UserStatus.blocked,
    );
    expect(_state(container).pendingAction, isNull);
    expect(auth.validations, 0);
  });

  test('El alta normaliza el email y sella la creación', () async {
    final (container, repository, _) = await _setUp();

    await container
        .read(adminUsersProvider.notifier)
        .create(email: '  Nuevo@Finnegans.com ', role: UserRole.academy);

    final created = repository.created.single;
    expect(created.email, 'nuevo@finnegans.com');
    expect(created.role, UserRole.academy.name);
    expect(created.createdAt, _now);
    expect(
      _state(container).users.map((user) => user.email),
      contains('nuevo@finnegans.com'),
    );
  });

  test('Un error se relanza y deja la lista como estaba', () async {
    final (container, repository, _) = await _setUp();
    repository.error = const FormatException('Sin permiso.');
    final ana = _state(container).users.single;

    await expectLater(
      container.read(adminUsersProvider.notifier).delete(ana),
      throwsA(isA<FormatException>()),
    );

    expect(_state(container).users.single, same(ana));
    expect(_state(container).pendingAction, isNull);
    expect(container.read(adminUsersProvider).hasError, isFalse);
  });

  test('Mientras guarda marca la acción e ignora otra', () async {
    final (container, repository, _) = await _setUp();
    final gate = repository.gate = Completer<void>();
    final notifier = container.read(adminUsersProvider.notifier);
    final ana = _state(container).users.single;

    final blocking = notifier.block(ana);
    expect(_state(container).pendingAction, AdminUserAction.block);

    await notifier.delete(ana);
    expect(_state(container).pendingAction, AdminUserAction.block);

    gate.complete();
    await blocking;
    expect(repository.saved.map((user) => user.deletedAt), [isNull]);
    expect(_state(container).pendingAction, isNull);
  });

  test('Una acción sobre el propio usuario revalida la sesión', () async {
    final (container, _, auth) = await _setUp(
      sessionEmail: 'ANA@finnegans.com',
    );
    final ana = _state(container).users.single;

    await container
        .read(adminUsersProvider.notifier)
        .changeRole(ana, UserRole.areaLead);

    expect(auth.validations, 1);
    expect(_state(container).users.single.role, UserRole.areaLead.name);
  });

  test('La selección se elige y se limpia', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(selectedAdminEmailProvider, (_, _) {});
    final selection = container.read(selectedAdminEmailProvider.notifier);

    selection.select('ana@finnegans.com');
    expect(container.read(selectedAdminEmailProvider), 'ana@finnegans.com');

    selection.clear();
    expect(container.read(selectedAdminEmailProvider), isNull);
  });
}
