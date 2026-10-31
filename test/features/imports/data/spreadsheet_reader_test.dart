import 'package:app_finnegans/features/imports/data/sheet_headers.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

void main() {
  const reader = SpreadsheetReader();
  const expected = [
    ['legajo', 'nombre'],
    ['10', 'Ana'],
    ['11', 'Beto'],
  ];

  group('CSV', () {
    for (final (label, eol) in [('CRLF', '\r\n'), ('LF', '\n'), ('CR', '\r')]) {
      test('separa las filas con $label', () {
        final rows = reader.read(
          csvFile('legajo,nombre${eol}10,Ana${eol}11,Beto$eol'),
        )['CSV']!;

        expect(rows.where(rowHasData), expected);
      });
    }

    test('quita el BOM inicial y no convierte números', () {
      final sheets = reader.read(csvFile('\ufefflegajo,nombre\n007,Ana\n'));

      expect(sheets.keys, ['CSV']);
      expect(sheets['CSV']!.first, ['legajo', 'nombre']);
      expect(sheets['CSV']![1], ['007', 'Ana']);
    });

    test('respeta las comas dentro de comillas', () {
      final rows = reader.read(csvFile('curso,horas\n"Excel, nivel 1",4\n'));

      expect(rows['CSV']![1], ['Excel, nivel 1', '4']);
    });
  });

  group('xlsx', () {
    test('lee todas las hojas y cada tipo de celda como texto', () {
      final sheets = reader.read(
        xlsxFile({
          'Empleados': [
            ['legajo', 'activo', 'horas', 'nombre'],
            [
              10,
              true,
              2.5,
              TextCellValue.span(
                const TextSpan(
                  text: 'Ana ',
                  children: [TextSpan(text: 'María')],
                ),
              ),
            ],
          ],
          'Cursos': [
            ['id', 'nombre'],
            ['107', null],
          ],
        }),
      );

      expect(sheets.keys, containsAll(['Empleados', 'Cursos']));
      expect(sheets['Empleados']![1], ['10', 'true', '2.5', 'Ana María']);
      expect(sheets['Cursos']![1], ['107', '']);
    });

    test('decide el formato por la extensión del nombre', () {
      final file = xlsxFile({
        'Hoja': [
          ['id'],
        ],
      }, name: 'CURSOS.XLSX');

      expect(reader.read(file).keys, ['Hoja']);
    });
  });

  group('Encabezados', () {
    List<String> blank() => ['', ''];

    test('normaliza tildes, mayúsculas y símbolos', () {
      expect(normalizedHeaders(['N° Legajo', 'Fecha de Ingreso']), [
        'nlegajo',
        'fechadeingreso',
      ]);
    });

    test('busca la fila de encabezado en las primeras 15 filas', () {
      bool matches(List<String> headers) => headers.contains('legajo');
      SheetRows withTitles(int titles) => [
        for (var i = 0; i < titles; i++) blank(),
        ['Legajo', 'Nombre'],
      ];

      expect(findHeaderRow(withTitles(0), matches), 0);
      expect(findHeaderRow(withTitles(14), matches), 14);
      expect(findHeaderRow(withTitles(15), matches), -1);
    });

    test('toma la columna del primer alias presente', () {
      final headers = ['nombreyapellido', 'legajo', 'nombre'];

      expect(columnFor(headers, ['nombre', 'nombreyapellido']), 2);
      expect(columnFor(headers, ['mail', 'correo']), -1);
      expect(hasColumn(headers, ['nlegajo', 'legajo']), isTrue);
    });

    test('una fila con solo espacios no tiene datos', () {
      expect(rowHasData([' ', '']), isFalse);
      expect(rowHasData(['', 'x']), isTrue);
    });
  });
}
