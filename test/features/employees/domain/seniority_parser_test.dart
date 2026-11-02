import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/employees/domain/seniority_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SeniorityParser();

  test('reconoce el nombre del enum y la etiqueta', () {
    for (final seniority in Seniority.values) {
      expect(parser.parse(seniority.name), seniority);
    }
    expect(parser.parse('Semisenior 2'), Seniority.semisenior2);
    expect(parser.parse('  junior 1 '), Seniority.junior1);
  });

  test('acepta las variantes de las planillas', () {
    final cases = {
      'SSr2': Seniority.semisenior2,
      'Jr 3': Seniority.junior3,
      'Senior II': Seniority.senior2,
      'semisenior segundo': Seniority.semisenior2,
      'Semi-Senior Tercero': Seniority.semisenior3,
      'S1': Seniority.senior1,
      'Sr. 3': Seniority.senior3,
      'J2': Seniority.junior2,
      'Junior III': Seniority.junior3,
      'M': Seniority.manager,
      'Gerente': Seniority.manager,
      'Trainee': Seniority.trainee,
      'T': Seniority.trainee,
      'Señor 2': Seniority.senior2,
    };
    cases.forEach((text, expected) {
      expect(parser.parse(text), expected, reason: text);
    });
  });

  test('sin nivel toma el primero de la banda', () {
    expect(parser.parse('Senior'), Seniority.senior1);
    expect(parser.parse('Sr'), Seniority.senior1);
    expect(parser.parse('Junior'), Seniority.junior1);
    expect(parser.parse('Jr'), Seniority.junior1);
  });

  test('un nivel escrito pegado no cae en Junior 1', () {
    expect(parser.parse('JuniorDos'), Seniority.junior2);
    expect(parser.parse('SSTres'), Seniority.semisenior3);
  });

  test('un texto irreconocible es un error, no Junior 1', () {
    for (final text in ['', '   ', 'Analista', 'Pasante', 'Lead 2', 'xyz']) {
      expect(parser.tryParse(text), isNull, reason: text);
      expect(() => parser.parse(text), throwsFormatException, reason: text);
    }
  });
}
