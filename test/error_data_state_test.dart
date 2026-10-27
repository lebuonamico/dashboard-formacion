import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('una columna inexistente se explica sin mostrar el error técnico', () {
    final mensaje = mensajeErrorCarga(
      const PostgrestException(
        message: 'column cursos.tipo does not exist',
        code: '42703',
      ),
    );

    expect(mensaje, contains('no coincide con esta versión'));
    expect(mensaje, isNot(contains('cursos.tipo')));
  });

  test('sin permisos lo dice', () {
    expect(
      mensajeErrorCarga(
        const PostgrestException(message: 'denied', code: '42501'),
      ),
      contains('permisos'),
    );
  });

  test('un FormatException conserva su mensaje', () {
    expect(
      mensajeErrorCarga(const FormatException('Fecha inválida.')),
      'Fecha inválida.',
    );
  });

  test('un error desconocido da un mensaje genérico', () {
    final mensaje = mensajeErrorCarga(StateError('boom'));
    expect(mensaje, contains('error inesperado'));
    expect(mensaje, isNot(contains('boom')));
  });
}
