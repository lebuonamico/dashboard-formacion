import 'dart:convert';
import 'dart:typed_data';

import 'package:app_finnegans/features/imports/domain/import_file.dart';

import 'spreadsheet_fixtures.dart';

/// A synthetic dataset that goes through the four real importers. In July,
/// August and September 2026:
/// - Web (Producto) is on target: both members complete their 4 h of
///   business and 4 h of soft skills.
/// - Mobile (Producto) is at risk: Carla completes everything and Diego only
///   business skills (12 of 16 h, 75 %).
/// - Soporte (Operaciones) is critical: Elena declares hours without a
///   completion and Fede only completes a 4 h course (4 of 16 h, 25 %).
const demoMonths = [7, 8, 9];

const _months = {7: 'I', 8: 'II', 9: 'III'};

final _bom = String.fromCharCode(0xFEFF);

/// LF line endings, a BOM and header aliases, with the seniority under
/// "Nivel".
String demoPayrollCsv({String eol = '\n'}) =>
    _bom +
    [
      'N° Legajo,Nombre,Apellido,Nivel,Sector,Equipo,Correo,Gerente,Fecha de ingreso',
      '10,Ana,Pérez,Trainee,Producto,Web,ana@finnegans-demo.com,Laura Paz,01/03/2025',
      '11,Bruno,Gil,Jr 1,Producto,Web,bruno@finnegans-demo.com,Laura Paz,2025-04-01',
      '12,Carla,Ruiz,Junior II,Producto,Mobile,carla@finnegans-demo.com,Laura Paz,15-05-2025',
      '13,Diego,Sosa,Trainee,Producto,Mobile,diego@finnegans-demo.com,Laura Paz,01/06/2025',
      '14,Elena,Vera,Jr 1,Operaciones,Soporte,elena@finnegans-demo.com,Mario Luna,01/02/2024',
      '15,Fede,Ríos,Junior 2,Operaciones,Soporte,fede@finnegans-demo.com,Mario Luna,10/01/2026',
      '',
    ].join(eol);

/// Titles above the header, and the category under "Tipo".
Uint8List demoCoursesXlsx() => xlsxBytes({
  'Catálogo': [
    ['Catálogo de cursos 2026'],
    [],
    ['ID', 'Nombre', 'Tipo', 'Carga horaria'],
    for (final MapEntry(key: month, value: level) in _months.entries) ...[
      ['EXC-$month', 'Excel $level', 'Habilidades de negocio', 4],
      ['COM-$month', 'Comunicación $level', 'Habilidades blandas', 4],
    ],
    ['EXP-1', 'Exploración IA', 'Libres / exploración', 2],
    ['DIC-1', 'Dictado interno', 'Dictado de capacitaciones', 2],
  ],
});

/// CRLF line endings, traceability columns and one row without hours.
String demoTimeEntriesCsv() {
  final rows = [
    'ID Transacción,Legajo,Fecha,Curso,Horas Total,Caso,Proyecto',
    for (final MapEntry(key: month, value: level) in _months.entries) ...[
      for (final id in ['10', '11', '12']) ...[
        'txn-$id-$month-1,$id,10/0$month/2026,Excel $level,4,Choras - $id,01 - Capacitación',
        'txn-$id-$month-2,$id,12/0$month/2026,Comunicación $level,4,Choras - $id,01 - Capacitación',
      ],
      'txn-13-$month-1,13,10/0$month/2026,Excel $level,4,Choras - 13,01 - Capacitación',
      'txn-14-$month-1,14,10/0$month/2026,Excel $level,4,Choras - 14,01 - Capacitación',
      'txn-15-$month-1,15,10/0$month/2026,Excel $level,2,Choras - 15,01 - Capacitación',
      'txn-15-$month-2,15,11/0$month/2026,Comunicación $level,0,Choras - 15,01 - Capacitación',
    ],
  ];
  return '${rows.join('\r\n')}\r\n';
}

/// Moodle's report: Elena never completes, so her hours are only declared.
Uint8List demoCertificationsXlsx() => xlsxBytes({
  'Finalizaciones': [
    [
      'ID empleado / legajo',
      'Nombre del curso',
      'Finalizó el curso',
      'Fecha de finalización',
    ],
    for (final MapEntry(key: month, value: level) in _months.entries) ...[
      for (final id in ['10', '11', '12']) ...[
        [id, 'Excel $level', 'Sí', '20/0$month/2026'],
        [id, 'Comunicación $level', 'Sí', '21/0$month/2026'],
      ],
      ['13', 'Excel $level', 'Sí', '20/0$month/2026'],
      ['14', 'Excel $level', 'No', ''],
      ['15', 'Excel $level', 'Sí', '20/0$month/2026'],
    ],
  ],
});

ImportFile demoPayroll({String eol = '\n'}) => ImportFile(
  name: 'nomina_demo.csv',
  bytes: Uint8List.fromList(utf8.encode(demoPayrollCsv(eol: eol))),
);

ImportFile demoCourses() =>
    ImportFile(name: 'cursos_demo.xlsx', bytes: demoCoursesXlsx());

ImportFile demoTimeEntries() => ImportFile(
  name: 'horas_crm_demo.csv',
  bytes: Uint8List.fromList(utf8.encode(demoTimeEntriesCsv())),
);

ImportFile demoCertifications() => ImportFile(
  name: 'finalizaciones_lms_demo.xlsx',
  bytes: demoCertificationsXlsx(),
);
