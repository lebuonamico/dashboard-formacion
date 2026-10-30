import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:flutter_test/flutter_test.dart';

final _creation = DateTime.utc(2026, 1, 15, 10);
final _now = DateTime.utc(2026, 10, 3, 14, 30);

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
  group('RolUsuario.fromString', () {
    test('Reconoce name y label, con acentos, espacios y mayúsculas', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('  ADMIN '), UserRole.admin);
      expect(UserRole.fromString('Administrador'), UserRole.admin);
      expect(UserRole.fromString('academy'), UserRole.academy);
      expect(UserRole.fromString('Academia'), UserRole.academy);
      expect(UserRole.fromString('Área'), UserRole.areaLead);
      expect(UserRole.fromString('areaLead'), UserRole.areaLead);
      expect(UserRole.fromString('teamLead'), UserRole.teamLead);
      expect(UserRole.fromString('Líder de equipo'), UserRole.teamLead);
    });

    test('Solo Administrador y Academia son gestores', () {
      expect(UserRole.admin.canManage, isTrue);
      expect(UserRole.academy.canManage, isTrue);
      expect(UserRole.areaLead.canManage, isFalse);
      expect(UserRole.teamLead.canManage, isFalse);
    });

    test('Devuelve null ante lo irreconocible, sin caer en un rol', () {
      for (final raw in ['', '   ', 'usuario', 'superadmin', 'xyz']) {
        expect(UserRole.fromString(raw), isNull, reason: raw);
      }
      expect(UserRole.fromString(null), isNull);
    });
  });

  group('UsuarioAutorizado', () {
    test('Normaliza el email en el constructor', () {
      expect(
        _user(email: '  Juan.Perez@Finnegans.COM  ').email,
        'juan.perez@finnegans.com',
      );
    });

    test('rolConocido traduce lo válido y deja null lo legacy', () {
      expect(_user(role: 'admin').knownRole, UserRole.admin);
      expect(_user(role: 'admin').isAdmin, isTrue);
      expect(_user(role: 'usuario').knownRole, isNull);
      expect(_user(role: 'usuario').isAdmin, isFalse);
    });

    test('esMismoUsuario compara normalizado en los dos lados', () {
      final user = _user(email: 'ana@finnegans.com');
      expect(user.isSameUser('ANA@finnegans.com'), isTrue);
      expect(user.isSameUser(' ana@finnegans.com '), isTrue);
      expect(user.isSameUser('otro@finnegans.com'), isFalse);
      expect(user.isSameUser(null), isFalse);
    });
  });

  group('Estado y regla de activo', () {
    test('Sin sellos está activo', () {
      final user = _user();
      expect(user.status, UserStatus.active);
    });

    test('Eliminado tiene precedencia sobre bloqueado', () {
      final both = _user(blockedAt: _now, deletedAt: _now);
      expect(both.status, UserStatus.deleted);
      expect(_user(blockedAt: _now).status, UserStatus.blocked);
      expect(_user(deletedAt: _now).status, UserStatus.deleted);
    });

    test('eliminar sella la fecha y desactiva', () {
      final deleted = _user().deleted(_now);
      expect(deleted.deletedAt, _now);
      expect(deleted.isActive, isFalse);
      expect(deleted.status, UserStatus.deleted);
    });

    test('desbloquear limpia el sello y reactiva', () {
      final user = _user(blockedAt: _now).unblocked();
      expect(user.blockedAt, isNull);
      expect(user.isActive, isTrue);
      expect(user.status, UserStatus.active);
    });

    test('restaurar limpia el sello y reactiva', () {
      final user = _user(deletedAt: _now).restored();
      expect(user.deletedAt, isNull);
      expect(user.isActive, isTrue);
    });

    test('Desbloquear a alguien también eliminado no lo reactiva', () {
      final user = _user(blockedAt: _now, deletedAt: _now).unblocked();
      expect(user.blockedAt, isNull);
      expect(user.deletedAt, _now);
      expect(user.isActive, isFalse);
      expect(user.status, UserStatus.deleted);
    });

    test('Restaurar a alguien también bloqueado no lo reactiva', () {
      final user = _user(blockedAt: _now, deletedAt: _now).restored();
      expect(user.deletedAt, isNull);
      expect(user.blockedAt, _now);
      expect(user.isActive, isFalse);
      expect(user.status, UserStatus.blocked);
    });

    test('Cambiar el rol conserva sellos y estado', () {
      final blocked = _user(blockedAt: _now);
      final withRole = blocked.withRole(UserRole.academy);
      expect(withRole.role, 'academy');
      expect(withRole.blockedAt, _now);
      expect(withRole.createdAt, _creation);
      expect(withRole.isActive, isFalse);
    });

    test('Toda transición preserva email y ffAlta', () {
      final base = _user(email: 'Ana@Finnegans.com');
      for (final result in [
        base.blocked(_now),
        base.deleted(_now),
        base.unblocked(),
        base.restored(),
        base.withRole(UserRole.admin),
      ]) {
        expect(result.email, 'ana@finnegans.com');
        expect(result.createdAt, _creation);
      }
    });
  });

  group('UsuarioAutorizado.nuevo', () {
    test('Nace activo, con ffAlta y sin sellos', () {
      final user = AuthorizedUser.create(
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
      expect(user.status, UserStatus.active);
    });
  });
}
