import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
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
    DateTime? desde,
    DateTime? hasta,
    String? nombre,
  }) async {
    final result = <Map<String, dynamic>>[];
    // Supabase limits responses; paginate instead of silently truncating data.
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      var query = client
          .from(mapping.table)
          .select(mapping.columns.values.join(','));
      for (final entry in equals.entries) {
        query = query.eq(mapping.column(entry.key), entry.value);
      }
      if (nombre != null) {
        query = query.ilike(
          mapping.column('nombre'),
          nombre
              .trim()
              .replaceAll('\\', '\\\\')
              .replaceAll('%', '\\%')
              .replaceAll('_', '\\_'),
        );
      }
      if (desde != null) {
        query = query.gte(mapping.column('fecha'), desde.toIso8601String());
      }
      if (hasta != null) {
        query = query.lt(mapping.column('fecha'), hasta.toIso8601String());
      }
      var ordered = query.order(mapping.column(mapping.conflictFields.first));
      for (final field in mapping.conflictFields.skip(1)) {
        ordered = ordered.order(mapping.column(field));
      }
      final rows = await ordered.range(offset, offset + pageSize - 1);
      result.addAll(rows.map(mapping.decode));
      if (rows.length < pageSize) break;
    }
    return result;
  }

  Future<void> upsert(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final rows = records.map(mapping.encode).toList();
    for (final row in rows) {
      for (final field in mapping.conflictFields) {
        if (row[mapping.column(field)] == null) {
          throw FormatException('Falta una clave de UPSERT: $field.');
        }
      }
    }
    await client
        .from(mapping.table)
        .upsert(rows, onConflict: mapping.onConflict);
  }
}

class SupabaseEmpleadosRepository
    implements EmpleadosRepository, UpsertRepository<Empleado> {
  final _Table _table;
  SupabaseEmpleadosRepository(
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
  Future<List<Empleado>> getEmpleados({
    String? legajo,
    String? equipo,
    String? sector,
  }) async => (await _table.read(
    equals: {'legajo': ?legajo, 'equipo': ?equipo, 'area': ?sector},
  )).map(Empleado.fromJson).toList();
  @override
  Future<void> upsert(List<Empleado> items) =>
      _table.upsert(items.map((e) => e.toJson()).toList());
  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) => upsert(empleados);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

class SupabaseCursosRepository
    implements CursosRepository, UpsertRepository<Curso> {
  final _Table _table;
  SupabaseCursosRepository(SupabaseClient client, SupabaseTableMapping mapping)
    : _table = _Table(client, mapping) {
    mapping.requireFields(['id', 'nombre', 'tipo', 'cargaHorariaHs']);
  }
  @override
  Future<List<Curso>> getCursos({String? id, String? nombre}) async =>
      (await _table.read(
        equals: {'id': ?id},
        nombre: nombre,
      )).map(Curso.fromJson).toList();
  @override
  Future<void> upsert(List<Curso> items) => _table.upsert(
    items
        .map(
          (c) => {
            'id': c.id,
            'nombre': c.nombre.trim(),
            'tipo': c.tipo.name,
            'cargaHorariaHs': c.cargaHorariaHs,
          },
        )
        .toList(),
  );
  @override
  Future<void> replaceCursos(List<Curso> cursos) => upsert(cursos);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

Future<void> _hydrateCourses(
  List<Map<String, dynamic>> rows,
  CursosRepository cursos,
) async {
  final names = <String, String>{};
  for (final row in rows) {
    final id = row['cursoId']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Falta la FK del curso.');
    }
    if (!names.containsKey(id)) {
      final matches = await cursos.getCursos(id: id);
      if (matches.length != 1) {
        throw FormatException('Curso inexistente o inaccesible: $id.');
      }
      names[id] = matches.single.nombre;
    }
    row['cursoNombre'] = names[id];
  }
}

class SupabaseCargaDeHorasCRMRepository
    implements CargaDeHorasCRMRepository, UpsertRepository<CargaDeHorasCRM> {
  final _Table _table;
  final CursosRepository cursos;
  SupabaseCargaDeHorasCRMRepository(
    SupabaseClient client,
    SupabaseTableMapping mapping,
    this.cursos,
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
  Future<List<CargaDeHorasCRM>> getCargasDeHoras({
    String? empleadoLegajo,
    String? cursoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final rows = await _table.read(
      equals: {'empleadoLegajo': ?empleadoLegajo, 'cursoId': ?cursoId},
      desde: desde,
      hasta: hasta,
    );
    await _hydrateCourses(rows, cursos);
    return rows.map(CargaDeHorasCRM.fromJson).toList();
  }

  @override
  Future<void> upsert(List<CargaDeHorasCRM> items) async {
    if (items.isEmpty) return;
    final catalog = <String, Curso>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final nombre = normalizarNombreCurso(item.cursoNombre);
      final curso = catalog[nombre] ??= resolverCurso(
        item.cursoNombre,
        await cursos.getCursos(nombre: item.cursoNombre),
      );
      rows.add({...item.toJson(), 'cursoId': curso.id}..remove('tipo'));
    }
    await _table.upsert(rows);
  }

  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) =>
      upsert(cargas);
  @override
  Future<void> resetToMock() async => throw UnsupportedError(
    'No se eliminan datos remotos para restaurar mocks.',
  );
}

class SupabaseCertificacionesMoodleRepository
    implements
        CertificacionesMoodleRepository,
        UpsertRepository<CertificacionMoodle> {
  final _Table _table;
  final CursosRepository cursos;
  SupabaseCertificacionesMoodleRepository(
    SupabaseClient client,
    SupabaseTableMapping mapping,
    this.cursos,
  ) : _table = _Table(client, mapping) {
    mapping.requireFields([
      'legajo',
      'cursoId',
      'finalizoCurso',
      'fechaFinalizacion',
    ]);
  }
  @override
  Future<List<CertificacionMoodle>> getCertificaciones({
    String? legajo,
    String? cursoId,
  }) async {
    final rows = await _table.read(
      equals: {'legajo': ?legajo, 'cursoId': ?cursoId},
    );
    await _hydrateCourses(rows, cursos);
    return rows.map(CertificacionMoodle.fromJson).toList();
  }

  @override
  Future<void> upsert(List<CertificacionMoodle> items) async {
    if (items.isEmpty) return;
    final catalog = <String, Curso>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.finalizoCurso && item.fechaFinalizacion == null) {
        throw const FormatException('Falta la fecha de finalización.');
      }
      final nombre = normalizarNombreCurso(item.cursoNombre);
      final curso = catalog[nombre] ??= resolverCurso(
        item.cursoNombre,
        await cursos.getCursos(nombre: item.cursoNombre),
      );
      rows.add({...item.toJson(), 'cursoId': curso.id});
    }
    await _table.upsert(rows);
  }

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) => upsert(certificaciones);
}
