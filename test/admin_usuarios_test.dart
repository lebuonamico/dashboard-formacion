import 'dart:convert';

import 'package:app_finnegans/data/supabase/supabase_usuarios_autorizados_repository.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _ahora = DateTime.utc(2026, 10, 3, 14, 30);

({
  SupabaseUsuariosAutorizadosRepository repositorio,
  List<http.Request> requests,
})
_fixture(Future<http.Response> Function(http.Request) responder) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      return responder(request);
    }),
  );
  addTearDown(client.dispose);
  return (
    repositorio: SupabaseUsuariosAutorizadosRepository(client),
    requests: requests,
  );
}

http.Response _json(http.Request request, Object cuerpo, [int status = 200]) =>
    http.Response(
      jsonEncode(cuerpo),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(http.Request request, String code, String message) =>
    _json(request, {
      'code': code,
      'message': message,
      'details': null,
      'hint': null,
    }, code == '23505' ? 409 : 403);

UsuarioAutorizado _usuario({
  String email = 'ana@finnegans.com',
  String rol = 'lider',
  DateTime? ffBloqueo,
  DateTime? ffEliminar,
}) => UsuarioAutorizado(
  email: email,
  rol: rol,
  activo: ffBloqueo == null && ffEliminar == null,
  ffAlta: DateTime.utc(2026, 1, 15, 10),
  ffBloqueo: ffBloqueo,
  ffEliminar: ffEliminar,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lectura de la allowlist', () {
    test('Pide las columnas explícitas ordenadas por email', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {
            'email': 'ana@finnegans.com',
            'rol': 'admin',
            'activo': true,
            'ff_alta': '2026-01-15T10:00:00+00:00',
            'ff_bloqueo': null,
            'ff_eliminar': null,
          },
          {
            'email': 'beto@finnegans.com',
            'rol': 'usuario',
            'activo': false,
            'ff_alta': '2026-02-01T09:00:00+00:00',
            'ff_bloqueo': '2026-03-02T12:00:00+00:00',
            'ff_eliminar': null,
          },
        ]),
      );

      final usuarios = await fixture.repositorio.getUsuarios();

      final request = fixture.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/usuarios_autorizados');
      expect(request.headers['accept-profile'], 'public');
      expect(
        request.url.queryParameters['select'],
        'email,rol,activo,ff_alta,ff_bloqueo,ff_eliminar',
      );
      expect(request.url.queryParameters['order'], 'email.asc.nullslast');

      expect(usuarios, hasLength(2));
      expect(usuarios.first.rolConocido, RolUsuario.admin);
      expect(usuarios.first.estado, EstadoUsuario.activo);
      expect(usuarios.last.rol, 'usuario');
      expect(usuarios.last.rolConocido, isNull);
      expect(usuarios.last.estado, EstadoUsuario.bloqueado);
      expect(usuarios.last.ffBloqueo, DateTime.utc(2026, 3, 2, 12).toLocal());
    });

    test('Tolera filas incompletas sin romper', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'sin.datos@finnegans.com'},
        ]),
      );

      final usuario = (await fixture.repositorio.getUsuarios()).single;

      expect(usuario.rol, '');
      expect(usuario.activo, isFalse);
      expect(usuario.ffAlta, isNull);
      expect(usuario.estado, EstadoUsuario.activo);
    });
  });

  group('Alta', () {
    test('Inserta el payload exacto con ff_alta en UTC', () async {
      final fixture = _fixture((request) async => _json(request, []));

      await fixture.repositorio.crear(
        UsuarioAutorizado.nuevo(
          email: 'Nuevo@Finnegans.com',
          rol: RolUsuario.academia,
          ahora: _ahora,
        ),
      );

      final request = fixture.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/usuarios_autorizados');
      expect(request.headers['content-profile'], 'public');
      expect(request.url.queryParameters.containsKey('on_conflict'), isFalse);
      expect(jsonDecode(request.body), {
        'email': 'nuevo@finnegans.com',
        'rol': 'academia',
        'activo': true,
        'ff_alta': '2026-10-03T14:30:00.000Z',
        'ff_bloqueo': null,
        'ff_eliminar': null,
      });
    });

    test('Traduce el duplicado mencionando la restauración', () async {
      final fixture = _fixture(
        (request) async => _error(
          request,
          '23505',
          'duplicate key value violates unique constraint',
        ),
      );

      await expectLater(
        fixture.repositorio.crear(
          UsuarioAutorizado.nuevo(
            email: 'ana@finnegans.com',
            rol: RolUsuario.lider,
            ahora: _ahora,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('Ya existe'), contains('restauralo')),
          ),
        ),
      );
    });

    test('Traduce el rechazo de RLS a un mensaje de permisos', () async {
      final fixture = _fixture(
        (request) async => _error(
          request,
          '42501',
          'new row violates row-level security policy',
        ),
      );

      await expectLater(
        fixture.repositorio.crear(
          UsuarioAutorizado.nuevo(
            email: 'ana@finnegans.com',
            rol: RolUsuario.lider,
            ahora: _ahora,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('No tenés permiso'),
          ),
        ),
      );
    });
  });

  group('Guardado de rol y sellos', () {
    test('Bloquear manda PATCH con ff_bloqueo y activo false', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'ana@finnegans.com'},
        ]),
      );

      await fixture.repositorio.guardar(_usuario().bloqueado(_ahora));

      final request = fixture.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/usuarios_autorizados');
      expect(request.headers['content-profile'], 'public');
      expect(request.url.queryParameters['email'], 'eq.ana@finnegans.com');
      expect(jsonDecode(request.body), {
        'rol': 'lider',
        'activo': false,
        'ff_bloqueo': '2026-10-03T14:30:00.000Z',
        'ff_eliminar': null,
      });
    });

    test('Eliminar manda ff_eliminar y activo false', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'ana@finnegans.com'},
        ]),
      );

      await fixture.repositorio.guardar(_usuario().eliminado(_ahora));

      expect(jsonDecode(fixture.requests.single.body), {
        'rol': 'lider',
        'activo': false,
        'ff_bloqueo': null,
        'ff_eliminar': '2026-10-03T14:30:00.000Z',
      });
    });

    test('Desbloquear limpia el sello y reactiva', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'ana@finnegans.com'},
        ]),
      );

      await fixture.repositorio.guardar(
        _usuario(ffBloqueo: _ahora).desbloqueado(),
      );

      expect(jsonDecode(fixture.requests.single.body), {
        'rol': 'lider',
        'activo': true,
        'ff_bloqueo': null,
        'ff_eliminar': null,
      });
    });

    test('Desbloquear a alguien también eliminado lo deja inactivo', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'ana@finnegans.com'},
        ]),
      );

      await fixture.repositorio.guardar(
        _usuario(ffBloqueo: _ahora, ffEliminar: _ahora).desbloqueado(),
      );

      expect(jsonDecode(fixture.requests.single.body), {
        'rol': 'lider',
        'activo': false,
        'ff_bloqueo': null,
        'ff_eliminar': '2026-10-03T14:30:00.000Z',
      });
    });

    test('Cambiar rol conserva los sellos', () async {
      final fixture = _fixture(
        (request) async => _json(request, [
          {'email': 'ana@finnegans.com'},
        ]),
      );

      await fixture.repositorio.guardar(
        _usuario(ffBloqueo: _ahora).conRol(RolUsuario.admin),
      );

      expect(jsonDecode(fixture.requests.single.body), {
        'rol': 'admin',
        'activo': false,
        'ff_bloqueo': '2026-10-03T14:30:00.000Z',
        'ff_eliminar': null,
      });
    });

    test('Un PATCH que no matchea ninguna fila falla explícitamente', () async {
      final fixture = _fixture((request) async => _json(request, []));

      await expectLater(
        fixture.repositorio.guardar(_usuario().bloqueado(_ahora)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('ya no existe'), contains('permiso')),
          ),
        ),
      );
      expect(fixture.requests.single.url.queryParameters['select'], 'email');
    });

    test('Traduce el rechazo de RLS en el guardado', () async {
      final fixture = _fixture(
        (request) async => _error(request, '42501', 'permission denied'),
      );

      await expectLater(
        fixture.repositorio.guardar(_usuario().bloqueado(_ahora)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('No tenés permiso'),
          ),
        ),
      );
    });
  });
}
