import 'package:app_finnegans/features/imports/data/lms_certifications_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

const _parser = LmsCertificationsFileParser();
const _header = [
  'ID empleado / legajo',
  'Nombre del curso',
  'Finalizó el curso',
  'Fecha de finalización',
];

ImportFile _sheet(List<List<Object?>> rows) => xlsxFile({
  'Moodle': [_header, ...rows],
});

Matcher _rejects(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  test('lee legajo, curso, finalización y fecha', () {
    final certification = _parser
        .parse(
          _sheet([
            [' 10 ', ' Excel ', 'Sí', '15/07/2026'],
          ]),
        )
        .single;

    expect(certification.employeeId, '10');
    expect(certification.courseName, 'Excel');
    expect(certification.courseId, isNull);
    expect(certification.isCompleted, isTrue);
    expect(certification.completedAt, DateTime(2026, 7, 15));
  });

  group('Alias de encabezado', () {
    final columns = [
      LmsCertificationsFileParser.employeeIdAliases,
      LmsCertificationsFileParser.courseAliases,
      LmsCertificationsFileParser.completedAliases,
      LmsCertificationsFileParser.completedAtAliases,
    ];

    for (final (position, aliases) in columns.indexed) {
      for (final alias in aliases) {
        test('"$alias"', () {
          final headers = [
            for (final (other, otherAliases) in columns.indexed)
              other == position ? alias : otherAliases.first,
          ];
          final certification = _parser
              .parse(
                xlsxFile({
                  'Moodle': [
                    headers,
                    ['10', 'Excel', 'true', '2026-07-15'],
                  ],
                }),
              )
              .single;

          expect(certification.employeeId, '10');
          expect(certification.completedAt, DateTime(2026, 7, 15));
        });
      }
    }
  });

  test('encuentra el encabezado debajo de los títulos y suma las hojas', () {
    final certifications = _parser.parse(
      xlsxFile({
        'Julio': [
          ['Reporte de finalización'],
          [],
          _header,
          ['10', 'Excel', 'Sí', 46204.5],
        ],
        'Notas': [
          ['Generado', 'por Moodle'],
          ['hoy', ''],
        ],
        'Agosto': [
          _header,
          [11, 'Oratoria', 1, '01-08-2026'],
        ],
      }),
    );

    expect(certifications.map((c) => c.employeeId), ['10', '11']);
    expect(certifications.first.completedAt, DateTime(2026, 7, 1, 12));
    expect(certifications.last.completedAt, DateTime(2026, 8, 1));
  });

  test('más abajo de la fila 15 no reconoce el encabezado', () {
    expect(
      () => _parser.parse(
        xlsxFile({
          'Moodle': [
            for (var i = 0; i < 15; i++) ['Título'],
            _header,
            ['10', 'Excel', 'Sí', '15/07/2026'],
          ],
        }),
      ),
      _rejects('No se encontraron filas LMS válidas en el Excel.'),
    );
  });

  group('Finalización', () {
    for (final text in ['true', 'Verdadero', 'SI', 's', '1', 'yes', 'Y']) {
      test('"$text" es finalizado', () {
        final certification = _parser
            .parse(
              _sheet([
                ['10', 'Excel', text, '15/07/2026'],
              ]),
            )
            .single;

        expect(certification.isCompleted, isTrue);
      });
    }

    for (final text in [
      'false',
      'Falso',
      'NO',
      'n',
      '0',
      'Incompleto',
      'pendiente',
    ]) {
      test('"$text" no es finalizado y puede no tener fecha', () {
        final certification = _parser
            .parse(
              _sheet([
                ['10', 'Excel', text, ''],
              ]),
            )
            .single;

        expect(certification.isCompleted, isFalse);
        expect(certification.completedAt, isNull);
      });
    }

    test('un no finalizado conserva la fecha que trae', () {
      final certification = _parser
          .parse(
            _sheet([
              ['10', 'Excel', 'No', '15/07/2026'],
            ]),
          )
          .single;

      expect(certification.completedAt, DateTime(2026, 7, 15));
    });
  });

  test('saltea las filas sin legajo, sin curso o con un valor de '
      'finalización irreconocible', () {
    final certifications = _parser.parse(
      _sheet([
        ['10', 'Excel', 'Sí', '15/07/2026'],
        ['', 'Excel', 'Sí', '15/07/2026'],
        ['12', '', 'Sí', '15/07/2026'],
        ['13', 'Excel', 'quizás', '15/07/2026'],
      ]),
    );

    expect(certifications.map((c) => c.employeeId), ['10']);
  });

  group('Rechazos que cortan la importación', () {
    test('falta la columna de fecha', () {
      expect(
        () => _parser.parse(
          xlsxFile({
            'Moodle': [
              _header.take(3).toList(),
              ['10', 'Excel', 'Sí'],
            ],
          }),
        ),
        _rejects(
          'Falta la columna Fecha de finalización en el Excel de Moodle.',
        ),
      );
    });

    test('finalizado sin fecha', () {
      expect(
        () => _parser.parse(
          _sheet([
            ['10', 'Excel', 'Sí', ''],
          ]),
        ),
        _rejects(
          'Falta una fecha de finalización válida para el legajo 10 y el curso Excel.',
        ),
      );
    });

    test('una fecha inválida, aunque la fila se saltee', () {
      expect(
        () => _parser.parse(
          _sheet([
            ['10', 'Excel', 'quizás', '31/02/2026'],
          ]),
        ),
        _rejects(
          'Fecha de finalización inválida para el legajo 10: 31/02/2026.',
        ),
      );
    });

    test('ninguna fila válida', () {
      expect(
        () => _parser.parse(
          _sheet([
            ['10', 'Excel', 'quizás', ''],
          ]),
        ),
        _rejects('No se encontraron filas LMS válidas en el Excel.'),
      );
    });
  });
}
