import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/features/assistant/data/offline_assistant_repository.dart';
import 'package:app_finnegans/features/assistant/data/supabase_assistant_repository.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _sessionJson({bool expired = false}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': 'test-user', 'aud': 'authenticated', 'iat': now, 'exp': now + (expired ? -3600 : 3600)})}.'
      'test-signature';
  return {
    'access_token': token,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': expired ? -3600 : 3600,
    'expires_at': now + (expired ? -3600 : 3600),
    'user': {
      'id': 'test-user',
      'aud': 'authenticated',
      'email': 'test@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

class _Fixture {
  final requests = <http.Request>[];
  late final SupabaseClient client;
  late final SupabaseAssistantRepository repository;

  _Fixture(
    Future<http.Response> Function(http.Request request) respond, {
    Duration timeout = const Duration(seconds: 40),
  }) {
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
      httpClient: MockClient((request) {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = SupabaseAssistantRepository(client, timeout: timeout);
    addTearDown(client.dispose);
  }

  static Future<_Fixture> signedIn(
    Future<http.Response> Function(http.Request request) respond, {
    Duration timeout = const Duration(seconds: 40),
    bool expired = false,
  }) async {
    final fixture = _Fixture(respond, timeout: timeout);
    await fixture.client.auth.setInitialSession(
      jsonEncode(_sessionJson(expired: expired)),
    );
    return fixture;
  }
}

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

Matcher _error(AssistantErrorType type, {int? status, String? code}) =>
    isA<AssistantException>()
        .having((e) => e.type, 'type', type)
        .having((e) => e.status, 'status', status)
        .having((e) => e.code, 'code', code);

void main() {
  group('SupabaseAssistantRepository', () {
    test('sin sesión no consulta y pide iniciar sesión', () async {
      final fixture = _Fixture((request) async => _json({}, 200, request));

      await expectLater(
        fixture.repository.ask('Hola'),
        throwsA(_error(AssistantErrorType.session, status: 401)),
      );
      expect(fixture.requests, isEmpty);
    });

    test('una sesión vencida tampoco consulta', () async {
      final fixture = await _Fixture.signedIn(
        (request) async => _json({}, 200, request),
        expired: true,
      );

      await expectLater(
        fixture.repository.ask('Hola'),
        throwsA(_error(AssistantErrorType.session, status: 401)),
      );
      expect(
        fixture.requests.where((r) => r.url.path.startsWith('/functions')),
        isEmpty,
      );
    });

    test('envía el mensaje a asistente-ia y devuelve la respuesta', () async {
      final fixture = await _Fixture.signedIn(
        (request) async => _json({'respuesta': '  Todo bien.  '}, 200, request),
      );

      expect(await fixture.repository.ask('¿Cómo va?'), 'Todo bien.');
      final request = fixture.requests.single;
      expect(request.url.path, '/functions/v1/asistente-ia');
      expect(jsonDecode(request.body), {'mensaje': '¿Cómo va?'});
    });

    test('un mensaje vacío o demasiado largo no se envía', () async {
      final fixture = await _Fixture.signedIn(
        (request) async => _json({'respuesta': 'x'}, 200, request),
      );

      for (final message in ['   ', 'a' * 6001]) {
        await expectLater(
          fixture.repository.ask(message),
          throwsA(_error(AssistantErrorType.unknown)),
        );
      }
      expect(fixture.requests, isEmpty);
    });

    test('una respuesta vacía, sin texto o enorme es desconocida', () async {
      for (final body in [
        {'respuesta': '  '},
        {'respuesta': 3},
        {'otra': 'x'},
        {'respuesta': 'a' * 16001},
      ]) {
        final fixture = await _Fixture.signedIn(
          (request) async => _json(body, 200, request),
        );
        await expectLater(
          fixture.repository.ask('Hola'),
          throwsA(_error(AssistantErrorType.unknown)),
          reason: '$body',
        );
      }
    });

    test('los estados HTTP se traducen sin guardar el cuerpo', () async {
      final cases = <(int, Object, AssistantErrorType, String?)>[
        (401, {}, AssistantErrorType.session, null),
        (403, {}, AssistantErrorType.permission, null),
        (429, {}, AssistantErrorType.limit, null),
        (408, {}, AssistantErrorType.connection, null),
        (504, {}, AssistantErrorType.connection, null),
        (
          502,
          {
            'error': {'status': 'UNAVAILABLE'},
          },
          AssistantErrorType.temporary,
          'UNAVAILABLE',
        ),
        (503, {}, AssistantErrorType.unknown, null),
        (
          500,
          {
            'error': {'code': 'RESOURCE_EXHAUSTED', 'message': 'secreto'},
          },
          AssistantErrorType.limit,
          'RESOURCE_EXHAUSTED',
        ),
        (
          500,
          {'code': 'DEADLINE_EXCEEDED'},
          AssistantErrorType.connection,
          'DEADLINE_EXCEEDED',
        ),
        (500, {'status': 'OTRO_CODIGO'}, AssistantErrorType.unknown, null),
      ];
      for (final (status, body, type, code) in cases) {
        final fixture = await _Fixture.signedIn(
          (request) async => _json(body, status, request),
        );
        await expectLater(
          fixture.repository.ask('Hola'),
          throwsA(_error(type, status: status, code: code)),
          reason: '$status $body',
        );
      }
    });

    test('un cuerpo de texto se interpreta solo si es JSON', () async {
      for (final (body, code) in [
        ('{"status":"UNAVAILABLE"}', 'UNAVAILABLE'),
        ('Bad gateway', null),
      ]) {
        final fixture = await _Fixture.signedIn(
          (request) async => http.Response(
            body,
            502,
            request: request,
            headers: {'content-type': 'text/plain'},
          ),
        );
        await expectLater(
          fixture.repository.ask('Hola'),
          throwsA(
            _error(
              code == null
                  ? AssistantErrorType.unknown
                  : AssistantErrorType.temporary,
              status: 502,
              code: code,
            ),
          ),
          reason: body,
        );
      }
    });

    test('vencido el tiempo de espera es un error de conexión', () async {
      final fixture = await _Fixture.signedIn(
        (request) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        fixture.repository.ask('Hola'),
        throwsA(_error(AssistantErrorType.connection)),
      );
    });
  });

  test('en modo local el asistente pide iniciar sesión', () async {
    await expectLater(
      const OfflineAssistantRepository().ask('Hola'),
      throwsA(_error(AssistantErrorType.session, status: 401)),
    );
  });

  test('solo los errores de sesión y permiso no se reintentan', () {
    for (final type in AssistantErrorType.values) {
      expect(
        AssistantException(type).allowsRetry,
        type != AssistantErrorType.session &&
            type != AssistantErrorType.permission,
        reason: type.name,
      );
    }
    expect(
      const AssistantException(
        AssistantErrorType.unknown,
        status: 401,
      ).allowsRetry,
      isFalse,
    );
    expect(
      const AssistantException(
        AssistantErrorType.unknown,
        status: 403,
      ).allowsRetry,
      isFalse,
    );
  });
}
