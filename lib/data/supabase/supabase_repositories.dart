import 'package:app_finnegans/data/supabase/supabase_codes.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado_historial.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_historial_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';

class _Table {
  final SupabaseClient client;
  final SupabaseTableMapping mapping;
  _Table(this.client, this.mapping);

  Future<List<Map<String, dynamic>>> read({
    Map<String, Object> equals = const {},
    DateTime? fromDate,
    DateTime? until,
  }) async {
    PostgrestTransformBuilder<PostgrestList> page(int from, int to) {
      var query = client
          .from(mapping.table)
          .select(mapping.columns.values.join(','));
      for (final entry in equals.entries) {
        query = query.eq(mapping.column(entry.key), entry.value);
      }
      if (fromDate != null) {
        query = query.gte(mapping.column('fecha'), fromDate.toIso8601String());
      }
      if (until != null) {
        query = query.lt(mapping.column('fecha'), until.toIso8601String());
      }
      var ordered = query.order(mapping.column(mapping.conflictFields.first));
      for (final field in mapping.conflictFields.skip(1)) {
        ordered = ordered.order(mapping.column(field));
      }
      return ordered.range(from, to);
    }

    // Supabase limits responses; paginate instead of silently truncating data.
    // The first page also brings the total, so the rest is requested at once
    // instead of one page after another.
    const pageSize = 1000;
    final first = await page(0, pageSize - 1).count(CountOption.exact);
    final rows = [...first.data];
    // The server may cap a page below pageSize: step by what it returned.
    final step = rows.length;
    if (step > 0 && step < first.count) {
      final rest = await Future.wait([
        for (var offset = step; offset < first.count; offset += step)
          page(offset, offset + step - 1),
      ]);
      for (final pageRows in rest) {
        rows.addAll(pageRows);
      }
    }
    return rows.map(mapping.decode).toList();
  }

  String _key(Map<String, dynamic> row) => jsonEncode([
    for (final field in mapping.conflictFields)
      row[mapping.column(field)]?.toString(),
  ]);

  Future<Set<String>> _existingKeys(List<Map<String, dynamic>> rows) async {
    final columns = mapping.conflictFields.map(mapping.column).toList();
    final selectedKeys = rows.map(_key).toSet();
    final existingKeys = <String>{};
    const batchSize = 150;
    const pageSize = 100;
    for (var start = 0; start < rows.length; start += batchSize) {
      final end = start + batchSize < rows.length
          ? start + batchSize
          : rows.length;
      final batch = rows.sublist(start, end);
      for (var offset = 0; ; offset += pageSize) {
        var query = client.from(mapping.table).select(columns.join(','));
        if (columns.length == 1) {
          query = query.inFilter(columns.single, [
            for (final row in batch) row[columns.single],
          ]);
        } else {
          // Quote strings as PostgREST literals, including embedded quotes,
          // backslashes and punctuation; each AND identifies one exact pair.
          query = query.or(
            batch
                .map(
                  (row) =>
                      'and(${columns.map((column) => '$column.eq.${jsonEncode(row[column])}').join(',')})',
                )
                .join(','),
          );
        }
        var ordered = query.order(columns.first);
        for (final column in columns.skip(1)) {
          ordered = ordered.order(column);
        }
        final existing = await ordered.range(offset, offset + pageSize - 1);
        for (final row in existing) {
          final key = _key(row);
          if (selectedKeys.contains(key)) existingKeys.add(key);
        }
        if (existing.length < pageSize) break;
      }
    }
    return existingKeys;
  }

  Future<UpsertResult> upsert(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return UpsertResult.empty;
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final row = mapping.encode(record);
      for (final field in mapping.conflictFields) {
        if (row[mapping.column(field)] == null) {
          throw FormatException('Falta una clave de UPSERT: $field.');
        }
      }
      // PostgreSQL cannot UPSERT the same conflict key twice in one statement.
      uniqueRows[_key(row)] = row;
    }
    final rows = uniqueRows.values.toList();
    final existingKeys = await _existingKeys(rows);
    await client
        .from(mapping.table)
        .upsert(rows, onConflict: mapping.onConflict);
    return UpsertResult(
      processedRecords: records.length,
      inserted: rows.length - existingKeys.length,
      updated: existingKeys.length,
    );
  }
}

class SupabaseEmployeesRepository
    implements
        EmployeesRepository,
        CountedUpsertRepository<Employee>,
        SnapshotRepository<Employee>,
        EmployeeHistoryRepository {
  final _Table _table;
  SupabaseEmployeesRepository(
    SupabaseClient client,
    SupabaseTableMapping mapping,
  ) : _table = _Table(client, mapping) {
    mapping.requireFields([
      'legajo',
      'mail',
      'nombre',
      'apellido',
      'seniority',
      'area',
      'equipo',
      'gerente',
      'fechaIngreso',
    ]);
  }
  @override
  Future<List<Employee>> getEmployees({
    String? employeeId,
    String? team,
    String? sector,
  }) async => (await _table.read(
    equals: {'legajo': ?employeeId, 'equipo': ?team, 'area': ?sector},
  )).map(Employee.fromJson).toList();
  @override
  Future<void> upsert(List<Employee> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<UpsertResult> upsertWithResult(List<Employee> items) =>
      _table.upsert(items.map((e) => e.toJson()).toList());
  @override
  Future<UpsertResult> syncSnapshotWithResult(List<Employee> items) async {
    _table.mapping.requireFields(['activo']);
    if (items.isEmpty || items.any((item) => item.employeeId.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Nómina está vacía o tiene claves inválidas.',
      );
    }
    final present = items.map((item) => item.employeeId).toSet();
    final previous = await getEmployees();
    final changes = [
      for (final item in items) item.copyWith(active: true),
      for (final item in previous)
        if (item.isActive && !present.contains(item.employeeId))
          item.copyWith(active: false),
    ];
    // Leandro: llama a upsertConResultado para guardar presentes y bajas en una escritura con el trigger de historial existente.
    final result = await upsertWithResult(changes);
    return UpsertResult(
      processedRecords: items.length,
      inserted: result.inserted,
      updated: result.updated,
    );
  }

  @override
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory() async {
    final history = <EmployeeHistoryEntry>[];
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await _table.client
          .from('empleado_historial')
          .select(
            'id,legajo,seniority,sector,equipo_general,gerente,activo,vigente_desde,vigente_hasta',
          )
          .order('legajo')
          .order('vigente_desde')
          .order('id')
          .range(offset, offset + pageSize - 1);
      history.addAll(rows.map(EmployeeHistoryEntry.fromJson));
      if (rows.length < pageSize) break;
    }
    return history;
  }

  @override
  Future<void> replaceEmployees(List<Employee> employees) => upsert(employees);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

class SupabaseCoursesRepository
    implements
        CoursesRepository,
        CountedUpsertRepository<Course>,
        SnapshotRepository<Course> {
  final _Table _table;
  SupabaseCoursesRepository(SupabaseClient client, SupabaseTableMapping mapping)
    : _table = _Table(client, mapping) {
    mapping.requireFields(['id', 'nombre', 'clasificacion', 'cargaHorariaHs']);
  }

  /// El catálogo es chico y lo leen la pantalla de cursos, las horas, las
  /// finalizaciones y las importaciones: se pide una vez y se reutiliza hasta
  /// que esta app lo modifique.
  Future<List<Course>>? _catalog;

  Future<List<Course>> _readCatalog() {
    final read = _catalog ??= _table.read().then(
      (rows) => rows
          .map(
            (row) => Course.fromJson({
              ...row,
              'clasificacion':
                  courseCategoryFromDb(row['clasificacion']) ??
                  row['clasificacion'],
            }),
          )
          .toList(),
    );
    // Un fallo no queda guardado: el próximo pedido vuelve a intentar.
    read.catchError((Object _) {
      if (identical(_catalog, read)) _catalog = null;
      return const <Course>[];
    });
    return read;
  }

  @override
  Future<List<Course>> getCourses({String? id, String? name}) async {
    final searched = name?.trim().toLowerCase();
    return [
      for (final course in await _readCatalog())
        if ((id == null || course.id == id) &&
            (searched == null || course.name.trim().toLowerCase() == searched))
          course,
    ];
  }

  @override
  Future<void> upsert(List<Course> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<UpsertResult> upsertWithResult(List<Course> items) async {
    try {
      return await _table.upsert(
        items
            .map(
              (c) => {
                'id': c.id,
                'nombre': c.name.trim(),
                'clasificacion': courseCategoryToDb(c.category),
                'cargaHorariaHs': c.workloadHours,
                'activo': c.isActive,
              },
            )
            .toList(),
      );
    } finally {
      _catalog = null;
    }
  }

  @override
  Future<UpsertResult> syncSnapshotWithResult(List<Course> items) async {
    _table.mapping.requireFields(['activo']);
    if (items.isEmpty || items.any((item) => item.id.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Cursos está vacía o tiene claves inválidas.',
      );
    }
    // Se compara contra la base actual, no contra lo leído antes.
    _catalog = null;
    final previous = await getCourses();
    // Un curso que ya existe con el mismo nombre se actualiza con su ID
    // actual: el nombre es único en la base y horas y finalizaciones
    // apuntan a ese ID. Los que no existen se insertan con el ID del archivo.
    final idByName = {
      for (final course in previous)
        normalizeCourseName(course.name): course.id,
    };
    final current = [
      for (final item in items)
        item.copyWith(
          id: idByName[normalizeCourseName(item.name)],
          active: true,
        ),
    ];
    final present = current.map((item) => item.id).toSet();
    final changes = [
      ...current,
      for (final item in previous)
        if (item.isActive && !present.contains(item.id))
          item.copyWith(active: false),
    ];
    final result = await upsertWithResult(changes);
    return UpsertResult(
      processedRecords: items.length,
      inserted: result.inserted,
      updated: result.updated,
    );
  }

  @override
  Future<void> replaceCourses(List<Course> courses) => upsert(courses);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

Future<void> _hydrateCourses(
  List<Map<String, dynamic>> rows,
  CoursesRepository courses,
) async {
  if (rows.isEmpty) return;
  // Una sola lectura del catálogo en vez de una consulta por curso.
  final names = {
    for (final course in await courses.getCourses()) course.id: course.name,
  };
  for (final row in rows) {
    final id = row['cursoId']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Falta la FK del curso.');
    }
    final name = names[id];
    if (name == null) {
      throw FormatException('Curso inexistente o inaccesible: $id.');
    }
    row['cursoNombre'] = name;
  }
}

class SupabaseCrmTimeEntriesRepository
    implements CrmTimeEntriesRepository, CountedUpsertRepository<CrmTimeEntry> {
  final _Table _table;
  final CoursesRepository courses;
  SupabaseCrmTimeEntriesRepository(
    SupabaseClient client,
    SupabaseTableMapping mapping,
    this.courses,
  ) : _table = _Table(client, mapping) {
    mapping.requireFields([
      'id',
      'empleadoLegajo',
      'cursoId',
      'fecha',
      'horasTotales',
      'caso',
      'descripcionCurso',
      'clasificacion',
      'proyecto',
      'proyectoItem',
      'descripcion',
    ]);
  }
  @override
  Future<List<CrmTimeEntry>> getTimeEntries({
    String? employeeId,
    String? courseId,
    DateTime? from,
    DateTime? until,
  }) async {
    final rows = await _table.read(
      equals: {'empleadoLegajo': ?employeeId, 'cursoId': ?courseId},
      fromDate: from,
      until: until,
    );
    await _hydrateCourses(rows, courses);
    return rows.map(CrmTimeEntry.fromJson).toList();
  }

  @override
  Future<void> upsert(List<CrmTimeEntry> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<UpsertResult> upsertWithResult(List<CrmTimeEntry> items) async {
    if (items.isEmpty) return UpsertResult.empty;
    final catalog = <String, Course>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final name = normalizeCourseName(item.courseName);
      final course = catalog[name] ??= courseResolver(
        item.courseName,
        await courses.getCourses(name: item.courseName),
      );
      rows.add({...item.toJson(), 'cursoId': course.id}..remove('tipo'));
    }
    return _table.upsert(rows);
  }

  @override
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries) =>
      upsert(timeEntries);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

class SupabaseLmsCertificationsRepository
    implements
        LmsCertificationsRepository,
        CountedUpsertRepository<LmsCertification> {
  final _Table _table;
  final CoursesRepository courses;
  SupabaseLmsCertificationsRepository(
    SupabaseClient client,
    SupabaseTableMapping mapping,
    this.courses,
  ) : _table = _Table(client, mapping) {
    mapping.requireFields([
      'legajo',
      'cursoId',
      'finalizoCurso',
      'fechaFinalizacion',
    ]);
  }
  @override
  Future<List<LmsCertification>> getCertifications({
    String? employeeId,
    String? courseId,
  }) async {
    final rows = await _table.read(
      equals: {'legajo': ?employeeId, 'cursoId': ?courseId},
    );
    await _hydrateCourses(rows, courses);
    return rows.map(LmsCertification.fromJson).toList();
  }

  @override
  Future<void> upsert(List<LmsCertification> items) async {
    await upsertWithResult(items);
  }

  @override
  Future<UpsertResult> upsertWithResult(List<LmsCertification> items) async {
    if (items.isEmpty) return UpsertResult.empty;
    final catalog = <String, Course>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.isCompleted && item.completedAt == null) {
        throw const FormatException('Falta la fecha de finalización.');
      }
      final name = normalizeCourseName(item.courseName);
      final course = catalog[name] ??= courseResolver(
        item.courseName,
        await courses.getCourses(name: item.courseName),
      );
      rows.add({...item.toJson(), 'cursoId': course.id});
    }
    return _table.upsert(rows);
  }

  @override
  Future<void> replaceCertifications(List<LmsCertification> certifications) =>
      upsert(certifications);
}
