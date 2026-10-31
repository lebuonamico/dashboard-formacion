import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeKey', () {
    test('quita tildes, mayúsculas, espacios y símbolos', () {
      expect(
        normalizeKey('  Habilidades de Negocio  '),
        'habilidadesdenegocio',
      );
      expect(
        normalizeKey('Exploración / Profundización'),
        'exploracionprofundizacion',
      );
      expect(normalizeKey('N° Legajo'), 'nlegajo');
      expect(normalizeKey('Año Pingüino'), 'anopinguino');
    });

    test('con separador deja una palabra por tramo', () {
      expect(
        normalizeKey('  Semi-Senior   Segundo ', separator: ' '),
        'semi senior segundo',
      );
      expect(
        normalizeKey('¿Cuántos equipos?', separator: ' '),
        'cuantos equipos',
      );
    });

    test('vacío o solo símbolos da texto vacío', () {
      expect(normalizeKey(''), '');
      expect(normalizeKey(' -/- ', separator: ' '), '');
    });
  });

  group('normalizeLoose', () {
    test('solo recorta y pasa a minúsculas', () {
      expect(normalizeLoose('  RRHH '), 'rrhh');
      expect(normalizeLoose(' Curso: Ágil '), 'curso: ágil');
    });
  });
}
