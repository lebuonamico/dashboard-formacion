import 'package:app_finnegans/features/imports/data/crm_time_entries_file_parser.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

const _parser = CrmTimeEntriesFileParser();
const _header = 'ID Transacción,N° Legajo,Fecha,Curso,Horas Total';

Matcher _rejects(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  test('lee la carga como tomada, con el curso tal como viene', () {
    final entry = _parser
        .parse(csvFile('$_header\r\ntxn-1, 10 ,15/07/2026, Excel ,"1,5"\r\n'))
        .single;

    expect(entry.id, 'txn-1');
    expect(entry.employeeId, '10');
    expect(entry.date, DateTime(2026, 7, 15));
    expect(entry.courseName, 'Excel');
    expect(entry.courseId, isNull);
    expect(entry.hours, 1.5);
    expect(entry.kind, TimeEntryKind.taken);
    expect(entry.caseRef, isNull);
  });

  test('reconoce los encabezados por las palabras que contienen', () {
    final entry = _parser
        .parse(
          csvFile(
            'Transaccion ID,Legajo empleado,Fecha de carga,Curso,Total horas\n'
            'txn-1,10,2026-07-15,Excel,2\n',
          ),
        )
        .single;

    expect(entry.id, 'txn-1');
    expect(entry.employeeId, '10');
    expect(entry.hours, 2);
  });

  test('la columna del curso tiene que llamarse exactamente "Curso"', () {
    expect(
      () => _parser.parse(
        csvFile(
          'ID Transacción,Legajo,Fecha,Nombre curso,Horas Total\n'
          'txn-1,10,15/07/2026,Excel,2\n',
        ),
      ),
      _rejects('No se reconocieron los encabezados.'),
    );
  });

  test('copia las columnas de trazabilidad que estén', () {
    final entry = _parser
        .parse(
          csvFile(
            '$_header,Caso,Descripción curso,Clasificación,Proyecto,'
            'Proyecto item,Descripción\n'
            'txn-1,10,15/07/2026,Excel,2,Choras - 46,Excel I,Negocio,'
            '01 - Capacitación,Item,Detalle\n',
          ),
        )
        .single;

    expect(entry.caseRef, 'Choras - 46');
    expect(entry.courseDescription, 'Excel I');
    expect(entry.classification, 'Negocio');
    expect(entry.project, '01 - Capacitación');
    expect(entry.projectItem, 'Item');
    expect(entry.description, 'Detalle');
  });

  group('Fila de encabezado y hojas', () {
    String withTitles(int titles) =>
        '${List.filled(titles, 'Reporte CRM,,,,').join('\n')}\n'
        '$_header\ntxn-1,10,15/07/2026,Excel,2\n';

    test('la encuentra dentro de las 15 primeras filas', () {
      expect(_parser.parse(csvFile(withTitles(14))), hasLength(1));
    });

    test('más abajo no la reconoce', () {
      expect(
        () => _parser.parse(csvFile(withTitles(15))),
        _rejects(
          'No se reconocieron los encabezados. El Excel debe incluir ID de transacción, legajo, fecha, curso y horas total.',
        ),
      );
    });

    test('suma las hojas con encabezados y saltea las demás', () {
      final entries = _parser.parse(
        xlsxFile({
          'Julio': [
            ['ID Transacción', 'Legajo', 'Fecha', 'Curso', 'Horas Total'],
            ['txn-1', 10, '15/07/2026', 'Excel', 2],
          ],
          'Resumen': [
            ['Total', 'Horas'],
            ['Julio', 2],
          ],
          'Vacía': [
            ['ID Transacción', 'Legajo', 'Fecha', 'Curso', 'Horas Total'],
          ],
          'Agosto': [
            ['ID Transacción', 'Legajo', 'Fecha', 'Curso', 'Horas Total'],
            ['txn-2', 11, 46235, 'Oratoria', 1.5],
          ],
        }),
      );

      expect(entries.map((entry) => entry.id), ['txn-1', 'txn-2']);
      expect(entries.last.date, DateTime(2026, 8, 1));
      expect(entries.last.employeeId, '11');
    });
  });

  test('descarta las filas sin horas, sin ID o sin legajo', () {
    final entries = _parser.parse(
      csvFile(
        '$_header\n'
        'txn-1,10,15/07/2026,Excel,2\n'
        'txn-2,10,15/07/2026,Excel,0\n'
        'txn-3,10,15/07/2026,Excel,-1\n'
        'txn-4,10,15/07/2026,Excel,sin dato\n'
        ',10,15/07/2026,Excel,2\n'
        'txn-6,,15/07/2026,Excel,2\n'
        ',,,,\n',
      ),
    );

    expect(entries.map((entry) => entry.id), ['txn-1']);
  });

  group('Fechas', () {
    for (final (format, text, expected) in [
      ('dd/mm/yyyy', '15/07/2026', DateTime(2026, 7, 15)),
      ('dd-mm-yyyy', '15-07-2026', DateTime(2026, 7, 15)),
      ('ISO con hora', '2026-07-15 10:30', DateTime(2026, 7, 15, 10, 30)),
      ('serial de Excel', '46204', DateTime(2026, 7, 1)),
    ]) {
      test('acepta $format', () {
        final entry = _parser
            .parse(csvFile('$_header\ntxn-1,10,$text,Excel,2\n'))
            .single;

        expect(entry.date, expected);
      });
    }
  });

  group('Rechazos que cortan la importación', () {
    test('una fila sin todas las columnas obligatorias', () {
      expect(
        () => _parser.parse(csvFile('$_header\ntxn-1,10,15/07/2026,Excel\n')),
        _rejects('Fila CRM incompleta: faltan columnas obligatorias.'),
      );
    });

    test('una fecha inválida, aunque la fila no tenga horas', () {
      expect(
        () => _parser.parse(csvFile('$_header\ntxn-1,10,31/02/2026,Excel,0\n')),
        _rejects('Fecha inválida: "31/02/2026".'),
      );
    });

    test('encabezados reconocidos pero ninguna fila válida', () {
      expect(
        () => _parser.parse(csvFile('$_header\ntxn-1,10,15/07/2026,Excel,0\n')),
        _rejects('El archivo no tiene registros CRM válidos.'),
      );
    });
  });
}
