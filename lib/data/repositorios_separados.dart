import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'dart:convert';

import 'package:app_finnegans/data/formacion_repository.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEmpleadosRepository implements EmpleadosRepository {
  final MockFormacionRepository _source = MockFormacionRepository();

  @override
  Future<List<Empleado>> getEmpleados({
    String? legajo,
    String? equipo,
    String? sector,
  }) async {
    return (await _leerEmpleados())
        .where(
          (item) =>
              (legajo == null || item.legajo == legajo) &&
              (equipo == null || item.equipo == equipo) &&
              (sector == null || item.area == sector),
        )
        .toList();
  }

  Future<List<Empleado>> _leerEmpleados() => _source.getEmpleados();

  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCursosRepository implements CursosRepository {
  final MockFormacionRepository _source = MockFormacionRepository();

  @override
  Future<List<Curso>> getCursos({String? id, String? nombre}) async {
    return (await _leerCursos())
        .where(
          (item) =>
              (id == null || item.id == id) &&
              (nombre == null ||
                  item.nombre.trim().toLowerCase() ==
                      nombre.trim().toLowerCase()),
        )
        .toList();
  }

  Future<List<Curso>> _leerCursos() => _source.getCursos();

  @override
  Future<void> replaceCursos(List<Curso> cursos) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCargaDeHorasCRMRepository implements CargaDeHorasCRMRepository {
  final MockFormacionRepository _source = MockFormacionRepository();

  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras({
    String? empleadoLegajo,
    String? cursoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    return (await _leerCargaDeHorasCRM())
        .where(
          (item) =>
              (empleadoLegajo == null ||
                  item.empleadoLegajo == empleadoLegajo) &&
              (cursoId == null || item.cursoId == cursoId) &&
              (desde == null || !item.fecha.isBefore(desde)) &&
              (hasta == null || item.fecha.isBefore(hasta)),
        )
        .toList();
  }

  Future<List<CargaDeHorasCRM>> _leerCargaDeHorasCRM() async {
    final cursos = await _source.getCursos();
    final cursadas = await _source.getCursadas();
    final cursosMap = {for (final curso in cursos) curso.id: curso};
    return cursadas
        .map(
          (cursada) => CargaDeHorasCRM(
            id: cursada.id,
            cursoId: cursada.cursoId,
            cursoNombre: cursosMap[cursada.cursoId]?.nombre ?? '',
            empleadoLegajo: cursada.empleadoLegajo,
            fecha: cursada.fecha,
            horasTotales: cursosMap[cursada.cursoId]?.cargaHorariaHs ?? 0,
            tipo: TipoCargaDeHoras.tomada,
          ),
        )
        .toList();
  }

  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) async {}

  @override
  Future<void> resetToMock() async {}
}

class LocalEmpleadosRepository extends MockEmpleadosRepository
    implements UpsertRepository<Empleado> {
  static const _key = 'formacion_empleados';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<Empleado> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <Empleado>[]
        : _decodeList(raw, Empleado.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.legajo: item,
    };
    await replaceEmpleados(merged.values.toList());
  }

  @override
  Future<List<Empleado>> _leerEmpleados() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super._leerEmpleados()
        : _decodeList(raw, Empleado.fromJson);
  }

  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) async {
    await (await _storage).setString(
      _key,
      jsonEncode(empleados.map((empleado) => empleado.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class LocalCursosRepository extends MockCursosRepository
    implements UpsertRepository<Curso> {
  static const _key = 'formacion_cursos';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<Curso> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null ? <Curso>[] : _decodeList(raw, Curso.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.id: item,
    };
    await replaceCursos(merged.values.toList());
  }

  @override
  Future<List<Curso>> _leerCursos() async {
    final raw = (await _storage).getString(_key);
    return raw == null ? super._leerCursos() : _decodeList(raw, Curso.fromJson);
  }

  @override
  Future<void> replaceCursos(List<Curso> cursos) async {
    await (await _storage).setString(
      _key,
      jsonEncode(cursos.map((curso) => curso.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class LocalCargaDeHorasCRMRepository extends MockCargaDeHorasCRMRepository
    implements UpsertRepository<CargaDeHorasCRM> {
  static const _key = 'formacion_carga_de_horas_crm';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<CargaDeHorasCRM> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <CargaDeHorasCRM>[]
        : _decodeList(raw, CargaDeHorasCRM.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.id: item,
    };
    await replaceCargasDeHoras(merged.values.toList());
  }

  @override
  Future<List<CargaDeHorasCRM>> _leerCargaDeHorasCRM() async {
    final raw = (await _storage).getString(_key);
    if (raw == null) return super._leerCargaDeHorasCRM();

    final cargas = _decodeList(raw, CargaDeHorasCRM.fromJson);
    if (cargas.isEmpty ||
        cargas.every((carga) => carga.cursoNombre.isNotEmpty)) {
      return cargas;
    }

    try {
      final registros = jsonDecode(raw) as List<dynamic>;
      final cursos = await LocalCursosRepository().getCursos();
      final cursosPorId = {for (final curso in cursos) curso.id: curso};
      final cargasMigradas = registros.map((registro) {
        final data = Map<String, dynamic>.from(registro as Map);
        if ((data['cursoNombre']?.toString().trim() ?? '').isEmpty) {
          final cursoId = data['cursoId']?.toString();
          data['cursoNombre'] = cursosPorId[cursoId]?.nombre ?? '';
        }
        return CargaDeHorasCRM.fromJson(data);
      }).toList();
      await replaceCargasDeHoras(cargasMigradas);
      return cargasMigradas;
    } on FormatException {
      return cargas;
    } on TypeError {
      return cargas;
    }
  }

  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) async {
    await (await _storage).setString(
      _key,
      jsonEncode(cargas.map((carga) => carga.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class MockCertificacionesMoodleRepository
    implements CertificacionesMoodleRepository {
  @override
  Future<List<CertificacionMoodle>> getCertificaciones({
    String? legajo,
    String? cursoId,
  }) async {
    return (await _leerCertificacionesMoodle())
        .where(
          (item) =>
              (legajo == null || item.legajo == legajo) &&
              (cursoId == null || item.cursoId == cursoId),
        )
        .toList();
  }

  Future<List<CertificacionMoodle>> _leerCertificacionesMoodle() async => [];

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) async {}
}

class LocalCertificacionesMoodleRepository
    extends MockCertificacionesMoodleRepository
    implements UpsertRepository<CertificacionMoodle> {
  static const _key = 'formacion_certificaciones_moodle';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<CertificacionMoodle> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <CertificacionMoodle>[]
        : _decodeList(raw, CertificacionMoodle.fromJson);
    // Preserve imported rows; the future SQL design determines historical identity.
    final rows = {
      for (final item in [...existing, ...items])
        jsonEncode(item.toJson()): item,
    };
    await replaceCertificaciones(rows.values.toList());
  }

  @override
  Future<List<CertificacionMoodle>> _leerCertificacionesMoodle() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super._leerCertificacionesMoodle()
        : _decodeList(raw, CertificacionMoodle.fromJson);
  }

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) async {
    await (await _storage).setString(
      _key,
      jsonEncode(certificaciones.map((item) => item.toJson()).toList()),
    );
  }
}

List<T> _decodeList<T>(String raw, T Function(Map<String, dynamic>) fromJson) {
  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  } on TypeError {
    throw const FormatException('Datos locales con estructura inválida.');
  }
}
