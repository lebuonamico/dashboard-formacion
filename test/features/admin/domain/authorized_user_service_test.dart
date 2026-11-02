import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

final _creation = DateTime.utc(2026, 1, 15, 10);
final _now = DateTime.utc(2026, 10, 3, 14, 30);

const _service = AuthorizedUserService();

AuthorizedUser _user({
  String email = 'alguien@finnegans.com',
  String role = 'teamLead',
  DateTime? blockedAt,
  DateTime? deletedAt,
}) => AuthorizedUser(
  email: email,
  role: role,
  isActive: blockedAt == null && deletedAt == null,
  createdAt: _creation,
  blockedAt: blockedAt,
  deletedAt: deletedAt,
);

void main() {
  group('Usuario autorizado', () {
    test('knownRole traduce lo válido y deja null lo legacy', () {
      expect(_service.knownRole(_user(role: 'admin')), UserRole.admin);
      expect(_service.isAdmin(_user(role: 'admin')), isTrue);
      expect(_service.knownRole(_user(role: 'usuario')), isNull);
      expect(_service.isAdmin(_user(role: 'usuario')), isFalse);
    });

    test('isSameUser compara normalizado en los dos lados', () {
      final user = _user(email: 'ana@finnegans.com');
      expect(_service.isSameUser(user, 'ANA@finnegans.com'), isTrue);
      expect(_service.isSameUser(user, ' ana@finnegans.com '), isTrue);
      expect(_service.isSameUser(user, 'otro@finnegans.com'), isFalse);
      expect(_service.isSameUser(user, null), isFalse);
    });
  });

  group('Estado y regla de activo', () {
    test('Sin sellos está activo', () {
      expect(_service.status(_user()), UserStatus.active);
    });

    test('Eliminado tiene precedencia sobre bloqueado', () {
      final both = _user(blockedAt: _now, deletedAt: _now);
      expect(_service.status(both), UserStatus.deleted);
      expect(_service.status(_user(blockedAt: _now)), UserStatus.blocked);
      expect(_service.status(_user(deletedAt: _now)), UserStatus.deleted);
    });

    test('eliminar sella la fecha y desactiva', () {
      final deleted = _service.delete(_user(), _now);
      expect(deleted.deletedAt, _now);
      expect(deleted.isActive, isFalse);
      expect(_service.status(deleted), UserStatus.deleted);
    });

    test('desbloquear limpia el sello y reactiva', () {
      final user = _service.unblock(_user(blockedAt: _now));
      expect(user.blockedAt, isNull);
      expect(user.isActive, isTrue);
      expect(_service.status(user), UserStatus.active);
    });

    test('restaurar limpia el sello y reactiva', () {
      final user = _service.restore(_user(deletedAt: _now));
      expect(user.deletedAt, isNull);
      expect(user.isActive, isTrue);
    });

    test('Desbloquear a alguien también eliminado no lo reactiva', () {
      final user = _service.unblock(_user(blockedAt: _now, deletedAt: _now));
      expect(user.blockedAt, isNull);
      expect(user.deletedAt, _now);
      expect(user.isActive, isFalse);
      expect(_service.status(user), UserStatus.deleted);
    });

    test('Restaurar a alguien también bloqueado no lo reactiva', () {
      final user = _service.restore(_user(blockedAt: _now, deletedAt: _now));
      expect(user.deletedAt, isNull);
      expect(user.blockedAt, _now);
      expect(user.isActive, isFalse);
      expect(_service.status(user), UserStatus.blocked);
    });

    test('Cambiar el rol conserva sellos y estado', () {
      final blocked = _user(blockedAt: _now);
      final withRole = _service.withRole(blocked, UserRole.academy);
      expect(withRole.role, 'academy');
      expect(withRole.blockedAt, _now);
      expect(withRole.createdAt, _creation);
      expect(withRole.isActive, isFalse);
    });

    test('Toda transición preserva email y ffAlta', () {
      final base = _service.create(
        email: 'Ana@Finnegans.com',
        role: UserRole.teamLead,
        now: _creation,
      );
      for (final result in [
        _service.block(base, _now),
        _service.delete(base, _now),
        _service.unblock(base),
        _service.restore(base),
        _service.withRole(base, UserRole.admin),
      ]) {
        expect(result.email, 'ana@finnegans.com');
        expect(result.createdAt, _creation);
      }
    });
  });

  group('Alta', () {
    test('Nace activo, con ffAlta, sin sellos y con el email normalizado', () {
      final user = _service.create(
        email: 'Nuevo@Finnegans.com',
        role: UserRole.academy,
        now: _now,
      );
      expect(user.email, 'nuevo@finnegans.com');
      expect(user.role, 'academy');
      expect(user.isActive, isTrue);
      expect(user.createdAt, _now);
      expect(user.blockedAt, isNull);
      expect(user.deletedAt, isNull);
      expect(_service.status(user), UserStatus.active);
    });
  });
}
