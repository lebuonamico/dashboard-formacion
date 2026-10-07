import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:flutter_test/flutter_test.dart';

final _alta = DateTime.utc(2026, 1, 15, 10);
final _ahora = DateTime.utc(2026, 10, 3, 14, 30);

UsuarioAutorizado _usuario({
  String email = 'alguien@finnegans.com',
  String rol = 'lider',
  DateTime? ffBloqueo,
  DateTime? ffEliminar,
}) => UsuarioAutorizado(
  email: email,
  rol: rol,
  activo: ffBloqueo == null && ffEliminar == null,
  ffAlta: _alta,
  ffBloqueo: ffBloqueo,
  ffEliminar: ffEliminar,
);

void main() {
  group('RolUsuario.fromString', () {
    test('Reconoce name y label, con acentos, espacios y mayúsculas', () {
      expect(RolUsuario.fromString('admin'), RolUsuario.admin);
      expect(RolUsuario.fromString('  ADMIN '), RolUsuario.admin);
      expect(RolUsuario.fromString('Administrador'), RolUsuario.admin);
      expect(RolUsuario.fromString('academia'), RolUsuario.academia);
      expect(RolUsuario.fromString('Área'), RolUsuario.area);
      expect(RolUsuario.fromString('area'), RolUsuario.area);
      expect(RolUsuario.fromString('lider'), RolUsuario.lider);
      expect(RolUsuario.fromString('Líder de equipo'), RolUsuario.lider);
    });

    test('Devuelve null ante lo irreconocible, sin caer en un rol', () {
      for (final crudo in ['', '   ', 'usuario', 'superadmin', 'xyz']) {
        expect(RolUsuario.fromString(crudo), isNull, reason: crudo);
      }
      expect(RolUsuario.fromString(null), isNull);
    });
  });

  group('UsuarioAutorizado', () {
    test('Normaliza el email en el constructor', () {
      expect(
        _usuario(email: '  Juan.Perez@Finnegans.COM  ').email,
        'juan.perez@finnegans.com',
      );
    });

    test('rolConocido traduce lo válido y deja null lo legacy', () {
      expect(_usuario(rol: 'admin').rolConocido, RolUsuario.admin);
      expect(_usuario(rol: 'admin').esAdmin, isTrue);
      expect(_usuario(rol: 'usuario').rolConocido, isNull);
      expect(_usuario(rol: 'usuario').esAdmin, isFalse);
    });

    test('esMismoUsuario compara normalizado en los dos lados', () {
      final usuario = _usuario(email: 'ana@finnegans.com');
      expect(usuario.esMismoUsuario('ANA@finnegans.com'), isTrue);
      expect(usuario.esMismoUsuario(' ana@finnegans.com '), isTrue);
      expect(usuario.esMismoUsuario('otro@finnegans.com'), isFalse);
      expect(usuario.esMismoUsuario(null), isFalse);
    });
  });

  group('Estado y regla de activo', () {
    test('Sin sellos está activo', () {
      final usuario = _usuario();
      expect(usuario.estado, EstadoUsuario.activo);
      expect(usuario.activoCalculado, isTrue);
    });

    test('Eliminado tiene precedencia sobre bloqueado', () {
      final ambos = _usuario(ffBloqueo: _ahora, ffEliminar: _ahora);
      expect(ambos.estado, EstadoUsuario.eliminado);
      expect(_usuario(ffBloqueo: _ahora).estado, EstadoUsuario.bloqueado);
      expect(_usuario(ffEliminar: _ahora).estado, EstadoUsuario.eliminado);
    });

    test('activoCalculado exige los dos sellos en null', () {
      expect(_usuario(ffBloqueo: _ahora).activoCalculado, isFalse);
      expect(_usuario(ffEliminar: _ahora).activoCalculado, isFalse);
      expect(
        _usuario(ffBloqueo: _ahora, ffEliminar: _ahora).activoCalculado,
        isFalse,
      );
    });
  });

  group('Transiciones', () {
    test('bloquear sella la fecha y desactiva', () {
      final bloqueado = _usuario().bloqueado(_ahora);
      expect(bloqueado.ffBloqueo, _ahora);
      expect(bloqueado.ffEliminar, isNull);
      expect(bloqueado.activo, isFalse);
      expect(bloqueado.estado, EstadoUsuario.bloqueado);
    });

    test('eliminar sella la fecha y desactiva', () {
      final eliminado = _usuario().eliminado(_ahora);
      expect(eliminado.ffEliminar, _ahora);
      expect(eliminado.activo, isFalse);
      expect(eliminado.estado, EstadoUsuario.eliminado);
    });

    test('desbloquear limpia el sello y reactiva', () {
      final usuario = _usuario(ffBloqueo: _ahora).desbloqueado();
      expect(usuario.ffBloqueo, isNull);
      expect(usuario.activo, isTrue);
      expect(usuario.estado, EstadoUsuario.activo);
    });

    test('restaurar limpia el sello y reactiva', () {
      final usuario = _usuario(ffEliminar: _ahora).restaurado();
      expect(usuario.ffEliminar, isNull);
      expect(usuario.activo, isTrue);
    });

    test('Desbloquear a alguien también eliminado no lo reactiva', () {
      final usuario = _usuario(
        ffBloqueo: _ahora,
        ffEliminar: _ahora,
      ).desbloqueado();
      expect(usuario.ffBloqueo, isNull);
      expect(usuario.ffEliminar, _ahora);
      expect(usuario.activo, isFalse);
      expect(usuario.estado, EstadoUsuario.eliminado);
    });

    test('Restaurar a alguien también bloqueado no lo reactiva', () {
      final usuario = _usuario(
        ffBloqueo: _ahora,
        ffEliminar: _ahora,
      ).restaurado();
      expect(usuario.ffEliminar, isNull);
      expect(usuario.ffBloqueo, _ahora);
      expect(usuario.activo, isFalse);
      expect(usuario.estado, EstadoUsuario.bloqueado);
    });

    test('Cambiar el rol conserva sellos y estado', () {
      final bloqueado = _usuario(ffBloqueo: _ahora);
      final conRol = bloqueado.conRol(RolUsuario.academia);
      expect(conRol.rol, 'academia');
      expect(conRol.ffBloqueo, _ahora);
      expect(conRol.ffAlta, _alta);
      expect(conRol.activo, isFalse);
    });

    test('Toda transición preserva email y ffAlta', () {
      final base = _usuario(email: 'Ana@Finnegans.com');
      for (final resultado in [
        base.bloqueado(_ahora),
        base.eliminado(_ahora),
        base.desbloqueado(),
        base.restaurado(),
        base.conRol(RolUsuario.admin),
      ]) {
        expect(resultado.email, 'ana@finnegans.com');
        expect(resultado.ffAlta, _alta);
      }
    });
  });

  group('UsuarioAutorizado.nuevo', () {
    test('Nace activo, con ffAlta y sin sellos', () {
      final usuario = UsuarioAutorizado.nuevo(
        email: 'Nuevo@Finnegans.com',
        rol: RolUsuario.academia,
        ahora: _ahora,
      );
      expect(usuario.email, 'nuevo@finnegans.com');
      expect(usuario.rol, 'academia');
      expect(usuario.activo, isTrue);
      expect(usuario.ffAlta, _ahora);
      expect(usuario.ffBloqueo, isNull);
      expect(usuario.ffEliminar, isNull);
      expect(usuario.estado, EstadoUsuario.activo);
    });
  });
}
