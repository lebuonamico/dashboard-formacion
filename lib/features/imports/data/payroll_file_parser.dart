import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority_parser.dart';
import 'package:app_finnegans/features/imports/data/sheet_headers.dart';
import 'package:app_finnegans/features/imports/data/sheet_rules.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/imports/domain/payroll_import.dart';
import 'package:collection/collection.dart';

typedef _PayrollColumns = ({
  List<String> headers,
  int employeeId,
  int firstName,
  int lastName,
  int email,
  int area,
  int team,
  int manager,
  int hireDate,
  int seniority,
});

typedef _PayrollRow = ({Employee employee, String location});

class PayrollFileParser implements ImportFileParser<PayrollImport> {
  final SpreadsheetReader reader;
  final SeniorityParser seniorityParser;

  const PayrollFileParser({
    this.reader = const SpreadsheetReader(),
    this.seniorityParser = const SeniorityParser(),
  });

  static const employeeIdAliases = ['legajo', 'nlegajo', 'idempleado'];
  static const firstNameAliases = ['nombre', 'nombreyapellido'];
  static const lastNameAliases = ['apellido'];
  static const emailAliases = ['mail', 'email', 'correo', 'correoelectronico'];
  static const areaAliases = [
    'area',
    'sector',
    'gerencia',
    'departamento',
    'unidad',
  ];
  static const teamAliases = [
    'equipo',
    'team',
    'equipogeneral',
    'equipofuncional',
    'equipoprincipal',
  ];
  static const managerAliases = [
    'gerente',
    'manager',
    'jefe',
    'supervisor',
    'reportaa',
  ];
  static const hireDateAliases = ['fechadeingreso', 'fechaingreso'];
  static const specificSeniorityHeaders = [
    'seniority',
    'senority',
    'nivelseniority',
    'niveldeseniority',
    'senioridad',
    'niveljerarquico',
  ];
  static const _laxSeniorityHeaders = {
    ...specificSeniorityHeaders,
    'nivel',
    'categoria',
    'grado',
  };
  static final _seniorityValue = RegExp(
    r'^(?:senior|senor|sr|ssr|ss|junior|jr|j[123]|trainee|manager|gerente)',
  );

  /// Only the first rows are scanned to guess an unlabelled seniority column.
  static const _seniorityScanRows = 50;

  @override
  PayrollImport parse(ImportFile file) {
    final (byId, rowCount) = reader
        .read(file)
        .entries
        .where((sheet) => sheet.value.any(rowHasData))
        .expand(_sheetRows)
        .fold((<String, Employee>{}, 0), (read, row) {
          final (byId, rowCount) = read;
          final id = row.employee.employeeId;
          requireConsistentRecord(
            previous: byId[id]?.toJson(),
            current: row.employee.toJson(),
            key: id,
            field: 'legajo',
            location: row.location,
          );
          return (byId..[id] = row.employee, rowCount + 1);
        });
    if (rowCount == 0) {
      throw const FormatException('El archivo no tiene registros.');
    }
    return PayrollImport(employees: byId.values.toList(), rowCount: rowCount);
  }

  static bool _isPayrollHeader(List<String> headers) =>
      hasColumn(headers, employeeIdAliases) &&
      hasColumn(headers, firstNameAliases);

  Iterable<_PayrollRow> _sheetRows(MapEntry<String, SheetRows> sheet) {
    final MapEntry(key: name, value: rows) = sheet;
    final headerIndex = findHeaderRow(rows, _isPayrollHeader);
    if (headerIndex == -1) {
      throw FormatException(
        'No se reconocen los encabezados de nómina en la hoja "$name". No se sincronizó la nómina.',
      );
    }
    final headers = normalizedHeaders(rows[headerIndex]);
    requireUniqueHeaders(headers, name);
    final columns = (
      headers: headers,
      employeeId: columnFor(headers, employeeIdAliases),
      firstName: columnFor(headers, firstNameAliases),
      lastName: columnFor(headers, lastNameAliases),
      email: columnFor(headers, emailAliases),
      area: columnFor(headers, areaAliases),
      team: columnFor(headers, teamAliases),
      manager: columnFor(headers, managerAliases),
      hireDate: columnFor(headers, hireDateAliases),
      seniority: _seniorityColumn(headers, rows.skip(headerIndex + 1)),
    );
    if (columns.seniority == -1 || columns.hireDate == -1) {
      throw FormatException(
        'Faltan las columnas Seniority o Fecha de ingreso en la hoja "$name".',
      );
    }
    return rows.indexed
        .skip(headerIndex + 1)
        .where((row) => rowHasData(row.$2))
        .map((row) {
          final location = sheetLocation(name, row.$1);
          return (
            employee: _employee(row.$2, columns, location),
            location: location,
          );
        });
  }

  /// A specific header first, then a loose one, and finally the column whose
  /// values look most like seniority levels.
  static int _seniorityColumn(
    List<String> headers,
    Iterable<List<String>> data,
  ) {
    final specific = headers.indexWhere(specificSeniorityHeaders.contains);
    if (specific != -1) return specific;
    final lax = headers.indexWhere(
      (header) =>
          _laxSeniorityHeaders.contains(header) || header.contains('seniority'),
    );
    if (lax != -1) return lax;
    final sample = data.take(_seniorityScanRows).toList();
    final matches = List.generate(
      headers.length,
      (column) => sample
          .where(
            (row) =>
                column < row.length &&
                _seniorityValue.hasMatch(normalizeKey(row[column])),
          )
          .length,
    );
    final best = matches.maxOrNull ?? 0;
    return best == 0 ? -1 : matches.indexOf(best);
  }

  Employee _employee(
    List<String> row,
    _PayrollColumns columns,
    String location,
  ) {
    requireHeaderForEveryCell(row, columns.headers, location);
    String at(int column) => cellAt(row, column);
    final employeeId = at(columns.employeeId);
    if (employeeId.isEmpty) {
      throw FormatException('Falta el legajo en $location.');
    }
    final firstName = at(columns.firstName);
    if (firstName.isEmpty) {
      throw FormatException('Falta el nombre en $location.');
    }
    final seniorityText = at(columns.seniority);
    final seniority =
        seniorityParser.tryParse(seniorityText) ??
        (throw FormatException(
          'Seniority inválido en $location: "$seniorityText".',
        ));
    final hireDateText = at(columns.hireDate);
    final hireDate =
        importDate(hireDateText) ??
        (throw FormatException(
          'Fecha de ingreso inválida en $location: "$hireDateText".',
        ));
    return Employee(
      employeeId: employeeId,
      firstName: firstName,
      lastName: at(columns.lastName),
      seniority: seniority,
      area: at(columns.area),
      email: at(columns.email),
      team: at(columns.team),
      manager: at(columns.manager),
      hireDate: hireDate,
    );
  }
}
