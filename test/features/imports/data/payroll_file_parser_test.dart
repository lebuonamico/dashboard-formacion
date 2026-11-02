import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/imports/data/payroll_file_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

const _parser = PayrollFileParser();

Matcher _rejects(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  const header = 'legajo,nombre,apellido,seniority,sector,correo,fechaIngreso';

  test('lee cada campo desde sus encabezados', () {
    final payroll = _parser.parse(
      csvFile(
        'N° Legajo,Nombre y Apellido,Apellido,Nivel de Seniority,Gerencia,'
        'Equipo general,Correo electrónico,Reporta a,Fecha de Ingreso\n'
        ' 10 ,Ana,Pérez,SSr 2,Producto,Web,ana@example.com,Laura,01/10/2026\n',
      ),
    );

    final ana = payroll.employees.single;
    expect(ana.employeeId, '10');
    expect(ana.firstName, 'Ana');
    expect(ana.lastName, 'Pérez');
    expect(ana.seniority, Seniority.semisenior2);
    expect(ana.area, 'Producto');
    expect(ana.team, 'Web');
    expect(ana.email, 'ana@example.com');
    expect(ana.manager, 'Laura');
    expect(ana.hireDate, DateTime(2026, 10, 1));
    expect(ana.isActive, isTrue);
    expect(payroll.rowCount, 1);
  });

  group('Alias de encabezado', () {
    final fields = {
      'legajo': (PayrollFileParser.employeeIdAliases, '10'),
      'nombre': (PayrollFileParser.firstNameAliases, 'Ana'),
      'correo': (PayrollFileParser.emailAliases, 'ana@example.com'),
      'área': (PayrollFileParser.areaAliases, 'Producto'),
      'equipo': (PayrollFileParser.teamAliases, 'Web'),
      'gerente': (PayrollFileParser.managerAliases, 'Laura'),
    };
    const base = {
      'legajo': '10',
      'nombre': 'Ana',
      'seniority': 'Senior',
      'fechaingreso': '01/10/2026',
    };

    for (final MapEntry(key: field, value: (aliases, value))
        in fields.entries) {
      for (final alias in aliases) {
        test('$field desde "$alias"', () {
          final columns = {...base}
            ..removeWhere((key, _) => aliases.contains(key))
            ..[alias] = value;
          final employee = _parser
              .parse(
                csvFile(
                  '${columns.keys.join(',')}\n${columns.values.join(',')}\n',
                ),
              )
              .employees
              .single;

          expect(employee.toJson().values, contains(value));
        });
      }
    }

    for (final alias in PayrollFileParser.hireDateAliases) {
      test('fecha de ingreso desde "$alias"', () {
        final employee = _parser
            .parse(
              csvFile(
                'legajo,nombre,seniority,$alias\n10,Ana,Senior,01/10/2026\n',
              ),
            )
            .employees
            .single;

        expect(employee.hireDate, DateTime(2026, 10, 1));
      });
    }
  });

  group('Fila de encabezado', () {
    String withTitles(int titles) =>
        '${List.filled(titles, 'Nómina de octubre,,,,,,').join('\n')}\n'
        '$header\n10,Ana,Pérez,Senior,Producto,ana@example.com,01/10/2026\n';

    test('la encuentra debajo de los títulos dentro de las 15 primeras', () {
      expect(_parser.parse(csvFile(withTitles(9))).employees, hasLength(1));
      expect(_parser.parse(csvFile(withTitles(14))).employees, hasLength(1));
    });

    test('más abajo de la fila 15 no la reconoce', () {
      expect(
        () => _parser.parse(csvFile(withTitles(15))),
        _rejects('No se reconocen los encabezados de nómina en la hoja "CSV"'),
      );
    });
  });

  test('suma las hojas, saltea las vacías y cuenta las filas repetidas', () {
    final payroll = _parser.parse(
      xlsxFile({
        'Producto': [
          ['legajo', 'nombre', 'seniority', 'fecha de ingreso'],
          ['10', 'Ana', 'Senior', '01/10/2026'],
          ['10', 'Ana', 'Senior', '01/10/2026'],
          ['', '', '', ''],
        ],
        'Vacía': [
          ['', ''],
        ],
        'RRHH': [
          ['Nómina RRHH'],
          ['legajo', 'nombre', 'seniority', 'fecha de ingreso'],
          [11, 'Beto', 'Jr 1', 46296],
        ],
      }),
    );

    expect(payroll.employees.map((e) => e.employeeId), ['10', '11']);
    expect(payroll.rowCount, 3);
    expect(payroll.employees.last.hireDate, DateTime(2026, 10, 1));
  });

  test('una hoja con datos y sin encabezados de nómina corta todo', () {
    expect(
      () => _parser.parse(
        xlsxFile({
          'Nómina': [
            ['legajo', 'nombre', 'seniority', 'fecha de ingreso'],
            ['10', 'Ana', 'Senior', '01/10/2026'],
          ],
          'Cursos': [
            ['id', 'nombre'],
            ['107', 'Excel'],
          ],
        }),
      ),
      _rejects('No se reconocen los encabezados de nómina en la hoja "Cursos"'),
    );
  });

  group('Columna de seniority', () {
    Seniority seniorityFrom(String headers, String values) => _parser
        .parse(csvFile('$headers\n$values\n'))
        .employees
        .single
        .seniority;

    test('prefiere un encabezado específico', () {
      expect(
        seniorityFrom(
          'legajo,nombre,nivel,seniority,fechaingreso',
          '10,Ana,Trainee,Senior 2,01/10/2026',
        ),
        Seniority.senior2,
      );
    });

    test('si no, uno laxo', () {
      expect(
        seniorityFrom(
          'legajo,nombre,Categoría,fechaingreso',
          '10,Ana,Junior 3,01/10/2026',
        ),
        Seniority.junior3,
      );
    });

    test('si no, la columna cuyos valores parecen niveles', () {
      expect(
        seniorityFrom(
          'legajo,nombre,Puesto,fechaingreso',
          '10,Ana,SSr 1,01/10/2026',
        ),
        Seniority.semisenior1,
      );
    });
  });

  group('Fecha de ingreso', () {
    for (final (format, text) in [
      ('dd/mm/yyyy', '01/10/2026'),
      ('dd-mm-yyyy', '01-10-2026'),
      ('ISO', '2026-10-01'),
      ('serial de Excel', '46296'),
    ]) {
      test('acepta $format', () {
        final employee = _parser
            .parse(csvFile('$header\n10,Ana,Pérez,Senior,P,a@x.com,$text\n'))
            .employees
            .single;

        expect(employee.hireDate, DateTime(2026, 10, 1));
      });
    }
  });

  group('Rechazos que cortan la importación', () {
    void expectRejected(String csv, String message) =>
        expect(() => _parser.parse(csvFile(csv)), _rejects(message));

    test('encabezado duplicado', () {
      expectRejected(
        'legajo,nombre,seniority,fechaingreso,Nombre\n10,Ana,Senior,01/10/2026,A\n',
        'Encabezado duplicado "nombre" en la hoja "CSV".',
      );
    });

    test('faltan seniority o fecha de ingreso', () {
      expectRejected(
        'legajo,nombre,fechaingreso\n10,Ana,01/10/2026\n',
        'Faltan las columnas Seniority o Fecha de ingreso en la hoja "CSV".',
      );
      expectRejected(
        'legajo,nombre,seniority\n10,Ana,Senior\n',
        'Faltan las columnas Seniority o Fecha de ingreso',
      );
    });

    test('datos en una columna sin encabezado', () {
      expectRejected(
        'legajo,nombre,seniority,fechaingreso\n10,Ana,Senior,01/10/2026,extra\n',
        'Hay datos sin encabezado de columna en hoja "CSV", fila 2.',
      );
    });

    test('falta el legajo o el nombre', () {
      expectRejected(
        '$header\n,Ana,Pérez,Senior,P,a@x.com,01/10/2026\n',
        'Falta el legajo en hoja "CSV", fila 2.',
      );
      expectRejected(
        '$header\n10,,Pérez,Senior,P,a@x.com,01/10/2026\n',
        'Falta el nombre en hoja "CSV", fila 2.',
      );
    });

    test('seniority irreconocible', () {
      expectRejected(
        '$header\n10,Ana,Pérez,Experto,P,a@x.com,01/10/2026\n',
        'Seniority inválido en hoja "CSV", fila 2: "Experto".',
      );
    });

    test('fecha de ingreso inválida o vacía', () {
      expectRejected(
        '$header\n10,Ana,Pérez,Senior,P,a@x.com,31/02/2026\n',
        'Fecha de ingreso inválida en hoja "CSV", fila 2: "31/02/2026".',
      );
      expectRejected(
        '$header\n10,Ana,Pérez,Senior,P,a@x.com,\n',
        'Fecha de ingreso inválida en hoja "CSV", fila 2: "".',
      );
    });

    test('legajo repetido con otros datos, antes que un error posterior', () {
      expectRejected(
        '$header\n'
            '10,Ana,Pérez,Senior,P,a@x.com,01/10/2026\n'
            '10,Ana,Gómez,Senior,P,a@x.com,01/10/2026\n'
            '11,Beto,Gil,Senior,P,b@x.com,31/02/2026\n',
        'El legajo "10" tiene datos contradictorios en hoja "CSV", fila 3.',
      );
    });

    test('un archivo sin filas de datos', () {
      expectRejected('$header\n', 'El archivo no tiene registros.');
    });
  });
}
