import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('una columna inexistente se explica sin mostrar el error técnico', () {
    final message = timeEntryErrorMessage(
      const PostgrestException(
        message: 'column cursos.tipo does not exist',
        code: '42703',
      ),
    );

    expect(message, contains('no coincide con esta versión'));
    expect(message, isNot(contains('cursos.tipo')));
  });

  test('sin permisos lo dice', () {
    expect(
      timeEntryErrorMessage(
        const PostgrestException(message: 'denied', code: '42501'),
      ),
      contains('permisos'),
    );
  });

  test('un FormatException conserva su mensaje', () {
    expect(
      timeEntryErrorMessage(const FormatException('Fecha inválida.')),
      'Fecha inválida.',
    );
  });

  test('un error desconocido da un mensaje genérico', () {
    final message = timeEntryErrorMessage(StateError('boom'));
    expect(message, contains('error inesperado'));
    expect(message, isNot(contains('boom')));
  });
}
