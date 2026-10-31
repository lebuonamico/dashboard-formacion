import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/imports/data/sheet_headers.dart';
import 'package:app_finnegans/features/imports/data/sheet_rules.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';

typedef _LmsColumns = ({
  int employeeId,
  int course,
  int completed,
  int completedAt,
});

/// The Moodle completion report, always an xlsx. The completion date sets
/// the month a completion belongs to, so a completed course needs one.
class LmsCertificationsFileParser
    implements ImportFileParser<List<LmsCertification>> {
  final SpreadsheetReader reader;

  const LmsCertificationsFileParser({this.reader = const SpreadsheetReader()});

  static const employeeIdAliases = [
    'idempleadolegajo',
    'idempleado',
    'nlegajo',
    'legajo',
  ];
  static const courseAliases = [
    'nombredelcurso',
    'nombrecurso',
    'coursename',
    'coursefullname',
    'fullname',
    'curso',
  ];
  static const completedAliases = [
    'finalizoelcurso',
    'finalizocurso',
    'completado',
    'completed',
  ];
  static const completedAtAliases = [
    'fechadefinalizacion',
    'fechafinalizacion',
    'completiondate',
    'datecompleted',
    'timecompleted',
  ];

  @override
  List<LmsCertification> parse(ImportFile file) {
    final certifications = reader
        .readExcel(file.bytes)
        .values
        .where((rows) => rows.length >= 2)
        .expand(_sheetCertifications)
        .toList();
    if (certifications.isEmpty) {
      throw const FormatException(
        'No se encontraron filas LMS válidas en el Excel.',
      );
    }
    return certifications;
  }

  static bool _isLmsHeader(List<String> headers) =>
      hasColumn(headers, employeeIdAliases) &&
      hasColumn(headers, courseAliases) &&
      hasColumn(headers, completedAliases);

  Iterable<LmsCertification> _sheetCertifications(SheetRows rows) {
    final headerIndex = findHeaderRow(rows, _isLmsHeader);
    if (headerIndex == -1) return const [];
    final headers = normalizedHeaders(rows[headerIndex]);
    final columns = (
      employeeId: columnFor(headers, employeeIdAliases),
      course: columnFor(headers, courseAliases),
      completed: columnFor(headers, completedAliases),
      completedAt: columnFor(headers, completedAtAliases),
    );
    if (columns.completedAt == -1) {
      throw const FormatException(
        'Falta la columna Fecha de finalización en el Excel de Moodle.',
      );
    }
    return rows
        .skip(headerIndex + 1)
        .map((row) => _certification(row, columns))
        .nonNulls;
  }

  /// Null for the rows without every column, an employee, a course or a
  /// recognizable completion flag.
  LmsCertification? _certification(List<String> row, _LmsColumns columns) {
    final required = [
      columns.employeeId,
      columns.course,
      columns.completed,
      columns.completedAt,
    ];
    if (required.any((column) => column >= row.length)) return null;
    final employeeId = cellAt(row, columns.employeeId);
    final courseName = cellAt(row, columns.course);
    final completed = _completedFlag(row[columns.completed]);
    final completedAtText = row[columns.completedAt];
    final completedAt = importDate(completedAtText);
    if (completedAtText.trim().isNotEmpty && completedAt == null) {
      throw FormatException(
        'Fecha de finalización inválida para el legajo $employeeId: $completedAtText.',
      );
    }
    if (employeeId.isEmpty || courseName.isEmpty || completed == null) {
      return null;
    }
    if (completed && completedAt == null) {
      throw FormatException(
        'Falta una fecha de finalización válida para el legajo $employeeId y el curso $courseName.',
      );
    }
    return LmsCertification(
      employeeId: employeeId,
      courseName: courseName,
      isCompleted: completed,
      completedAt: completedAt,
    );
  }

  static bool? _completedFlag(String value) => switch (normalizeKey(value)) {
    'true' || 'verdadero' || 'si' || 's' || '1' || 'yes' || 'y' => true,
    'false' ||
    'falso' ||
    'no' ||
    'n' ||
    '0' ||
    'incompleto' ||
    'pendiente' => false,
    _ => null,
  };
}
