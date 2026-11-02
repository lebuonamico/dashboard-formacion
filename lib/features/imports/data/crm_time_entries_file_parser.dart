import 'package:app_finnegans/features/imports/data/sheet_headers.dart';
import 'package:app_finnegans/features/imports/data/sheet_rules.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

typedef _CrmColumns = ({
  List<String> headers,
  int id,
  int employeeId,
  int date,
  int course,
  int hours,
});

/// The CRM report headers vary between exports, so the required columns are
/// matched by the words they contain. Every entry is a taken course, named
/// as in the file: the course is resolved against the catalog afterwards.
class CrmTimeEntriesFileParser implements ImportFileParser<List<CrmTimeEntry>> {
  final SpreadsheetReader reader;

  const CrmTimeEntriesFileParser({this.reader = const SpreadsheetReader()});

  static bool isIdHeader(String header) =>
      header.contains('transaccion') && header.contains('id');
  static bool isEmployeeIdHeader(String header) => header.contains('legajo');
  static bool isDateHeader(String header) => header.contains('fecha');
  static bool isHoursHeader(String header) =>
      header.contains('hora') && header.contains('total');
  static const courseHeader = 'curso';

  /// Optional traceability columns, matched by their exact header.
  static const caseHeader = 'caso';
  static const courseDescriptionHeader = 'descripcioncurso';
  static const classificationHeader = 'clasificacion';
  static const projectHeader = 'proyecto';
  static const projectItemHeader = 'proyectoitem';
  static const descriptionHeader = 'descripcion';

  @override
  List<CrmTimeEntry> parse(ImportFile file) {
    final sheets = reader
        .read(file)
        .values
        .where((rows) => rows.length >= 2)
        .map(
          (rows) =>
              (rows: rows, headerIndex: findHeaderRow(rows, _isCrmHeader)),
        )
        .where((sheet) => sheet.headerIndex != -1)
        .toList();
    final entries = sheets
        .expand((sheet) => _sheetEntries(sheet.rows, sheet.headerIndex))
        .toList();
    if (entries.isNotEmpty) return entries;
    throw FormatException(
      sheets.isEmpty
          ? 'No se reconocieron los encabezados. El Excel debe incluir ID de transacción, legajo, fecha, curso y horas total.'
          : 'El archivo no tiene registros CRM válidos.',
    );
  }

  static bool _isCrmHeader(List<String> headers) =>
      headers.any(isIdHeader) &&
      headers.any(isEmployeeIdHeader) &&
      headers.contains(courseHeader) &&
      headers.any(isDateHeader) &&
      headers.any(isHoursHeader);

  Iterable<CrmTimeEntry> _sheetEntries(SheetRows rows, int headerIndex) {
    final headers = normalizedHeaders(rows[headerIndex]);
    final columns = (
      headers: headers,
      id: headers.indexWhere(isIdHeader),
      employeeId: headers.indexWhere(isEmployeeIdHeader),
      date: headers.indexWhere(isDateHeader),
      course: headers.indexOf(courseHeader),
      hours: headers.indexWhere(isHoursHeader),
    );
    return rows
        .skip(headerIndex + 1)
        .where(rowHasData)
        .map((row) => _entry(row, columns))
        .nonNulls;
  }

  /// Null for the rows the report may carry without hours or without an ID.
  CrmTimeEntry? _entry(List<String> row, _CrmColumns columns) {
    final required = [
      columns.id,
      columns.employeeId,
      columns.date,
      columns.course,
      columns.hours,
    ];
    if (required.any((column) => column >= row.length)) {
      throw const FormatException(
        'Fila CRM incompleta: faltan columnas obligatorias.',
      );
    }
    final date = requiredDate(row[columns.date]);
    final hours = double.tryParse(row[columns.hours].replaceAll(',', '.')) ?? 0;
    final id = cellAt(row, columns.id);
    final employeeId = cellAt(row, columns.employeeId);
    if (hours <= 0 || id.isEmpty || employeeId.isEmpty) return null;
    String? optional(String header) {
      final column = columns.headers.indexOf(header);
      return column < 0 || column >= row.length ? null : cellAt(row, column);
    }

    return CrmTimeEntry(
      id: id,
      courseName: cellAt(row, columns.course),
      caseRef: optional(caseHeader),
      courseDescription: optional(courseDescriptionHeader),
      classification: optional(classificationHeader),
      project: optional(projectHeader),
      projectItem: optional(projectItemHeader),
      description: optional(descriptionHeader),
      employeeId: employeeId,
      date: date,
      hours: hours,
      kind: TimeEntryKind.taken,
    );
  }
}
