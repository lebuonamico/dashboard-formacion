import 'dart:async';

import 'package:app_finnegans/core/data/data_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _postgrest(String? code) =>
    PostgrestException(message: 'detalle técnico', code: code);

void main() {
  test('un FormatException son datos inválidos', () {
    expect(
      classifyDataError(const FormatException('Fecha inválida.')),
      DataErrorKind.invalidData,
    );
  });

  for (final code in ['42703', '42P01', 'PGRST204', 'PGRST205']) {
    test('$code: la base no coincide con la app', () {
      expect(classifyDataError(_postgrest(code)), DataErrorKind.schemaMismatch);
    });
  }

  for (final code in ['42501', 'PGRST301']) {
    test('$code: sin permisos', () {
      expect(classifyDataError(_postgrest(code)), DataErrorKind.forbidden);
    });
  }

  test('otro código de PostgREST, o ninguno, es desconocido', () {
    expect(classifyDataError(_postgrest('23505')), DataErrorKind.unknown);
    expect(classifyDataError(_postgrest(null)), DataErrorKind.unknown);
  });

  test('un AuthException es una sesión vencida', () {
    expect(
      classifyDataError(const AuthException('expired')),
      DataErrorKind.sessionExpired,
    );
  });

  test('los errores de red se reconocen por su texto', () {
    expect(
      classifyDataError(http.ClientException('Failed to fetch')),
      DataErrorKind.network,
    );
    expect(classifyDataError(TimeoutException('lento')), DataErrorKind.network);
    expect(
      classifyDataError(Exception('SocketException: refused')),
      DataErrorKind.network,
    );
    expect(
      classifyDataError(Exception('XMLHttpRequest: Failed to fetch')),
      DataErrorKind.network,
    );
  });

  test('cualquier otro error es desconocido', () {
    expect(classifyDataError(StateError('boom')), DataErrorKind.unknown);
  });
}
