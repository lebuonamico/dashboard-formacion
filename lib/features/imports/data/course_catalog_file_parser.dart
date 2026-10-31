import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_category_parser.dart';
import 'package:app_finnegans/features/imports/data/sheet_headers.dart';
import 'package:app_finnegans/features/imports/data/sheet_rules.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/domain/import_file_parser.dart';

typedef _CourseColumns = ({
  List<String> headers,
  int id,
  int name,
  int category,
  int workloadHours,
});

typedef _CourseRow = ({Course course, String location});

/// One course per row, repeated rows included: the catalog is the complete
/// current snapshot and its row count is what gets reported.
class CourseCatalogFileParser implements ImportFileParser<List<Course>> {
  final SpreadsheetReader reader;
  final CourseCategoryParser categoryParser;

  CourseCatalogFileParser({
    this.reader = const SpreadsheetReader(),
    CourseCategoryParser? categoryParser,
  }) : categoryParser = categoryParser ?? CourseCategoryParser();

  static const idAliases = [
    'id',
    'cursoid',
    'courseid',
    'iddelcurso',
    'idcurso',
    'shortname',
    'courseshortname',
    'codigo',
  ];
  static const nameAliases = [
    'nombre',
    'nombrecurso',
    'course',
    'coursename',
    'fullname',
    'coursefullname',
    'nombrecompleto',
    'titulo',
  ];
  static const categoryAliases = [
    'clasificacion',
    'tipo',
    'tipocurso',
    'category',
    'categoria',
  ];
  static const workloadHoursAliases = [
    'cargahorariahs',
    'cargahoraria',
    'horas',
    'hours',
  ];

  @override
  List<Course> parse(ImportFile file) {
    final (_, courses) = reader
        .read(file)
        .entries
        .where((sheet) => sheet.value.any(rowHasData))
        .expand(_sheetRows)
        .fold((<String, Course>{}, <Course>[]), (read, row) {
          final (byId, courses) = read;
          final id = row.course.id;
          requireConsistentRecord(
            previous: byId[id]?.toJson(),
            current: row.course.toJson(),
            key: id,
            field: 'ID de curso',
            location: row.location,
          );
          return (byId..[id] = row.course, courses..add(row.course));
        });
    if (courses.isEmpty) {
      throw const FormatException(
        'No se encontraron cursos. Verificá las columnas de ID y nombre.',
      );
    }
    return courses;
  }

  static bool _isCatalogHeader(List<String> headers) =>
      hasColumn(headers, idAliases) && hasColumn(headers, nameAliases);

  Iterable<_CourseRow> _sheetRows(MapEntry<String, SheetRows> sheet) {
    final MapEntry(key: name, value: rows) = sheet;
    final headerIndex = findHeaderRow(rows, _isCatalogHeader);
    if (headerIndex == -1) {
      throw FormatException(
        'No se encontraron cursos con encabezados válidos en la hoja "$name". No se sincronizó el catálogo.',
      );
    }
    final headers = normalizedHeaders(rows[headerIndex]);
    requireUniqueHeaders(headers, name);
    final columns = (
      headers: headers,
      id: columnFor(headers, idAliases),
      name: columnFor(headers, nameAliases),
      category: columnFor(headers, categoryAliases),
      workloadHours: columnFor(headers, workloadHoursAliases),
    );
    if ([
      columns.id,
      columns.name,
      columns.category,
      columns.workloadHours,
    ].contains(-1)) {
      throw FormatException(
        'Faltan columnas obligatorias de ID, nombre, clasificación o carga horaria en la hoja "$name".',
      );
    }
    return rows.indexed
        .skip(headerIndex + 1)
        .where((row) => rowHasData(row.$2))
        .map((row) {
          final location = sheetLocation(name, row.$1);
          return (
            course: _course(row.$2, columns, location),
            location: location,
          );
        });
  }

  Course _course(List<String> row, _CourseColumns columns, String location) {
    requireHeaderForEveryCell(row, columns.headers, location);
    final required = [
      columns.id,
      columns.name,
      columns.category,
      columns.workloadHours,
    ];
    if (required.any((column) => column >= row.length)) {
      throw FormatException(
        'Faltan datos obligatorios del curso en $location.',
      );
    }
    final id = cellAt(row, columns.id);
    final name = cellAt(row, columns.name);
    if (id.isEmpty || name.isEmpty) {
      throw FormatException('Falta el ID o nombre del curso en $location.');
    }
    final hoursText = cellAt(row, columns.workloadHours);
    final hours = double.tryParse(hoursText.replaceAll(',', '.'));
    if (hours == null || !hours.isFinite || hours < 0) {
      throw FormatException(
        'Carga horaria inválida en $location: "$hoursText".',
      );
    }
    return Course(
      id: id,
      name: name,
      category: _category(row[columns.category], location),
      courseArea: '',
      instructorEmployeeId: '',
      workloadHours: hours,
    );
  }

  CourseCategory _category(String text, String location) =>
      categoryParser.tryParse(text) ??
      (throw FormatException('Clasificación inválida en $location: "$text".'));
}
