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
  Future<List<Empleado>> getEmpleados() => _source.getEmpleados();

  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCursosRepository implements CursosRepository {
  final MockFormacionRepository _source = MockFormacionRepository();

  @override
  Future<List<Curso>> getCursos() => _source.getCursos();

  @override
  Future<void> replaceCursos(List<Curso> cursos) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCargaDeHorasCRMRepository implements CargaDeHorasCRMRepository {
  final MockFormacionRepository _source = MockFormacionRepository();

  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras() async {
    final cursos = await _source.getCursos();
    final cursadas = await _source.getCursadas();
    final cursosMap = {for (final curso in cursos) curso.id: curso};
    return cursadas
        .map(
          (cursada) => CargaDeHorasCRM(
            id: cursada.id,
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

class LocalEmpleadosRepository extends MockEmpleadosRepository {
  static const _key = 'formacion_empleados';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<List<Empleado>> getEmpleados() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super.getEmpleados()
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

class LocalCursosRepository extends MockCursosRepository {
  static const _key = 'formacion_cursos';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<List<Curso>> getCursos() async {
    final raw = (await _storage).getString(_key);
    return raw == null ? super.getCursos() : _decodeList(raw, Curso.fromJson);
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

class LocalCargaDeHorasCRMRepository extends MockCargaDeHorasCRMRepository {
  static const _key = 'formacion_carga_de_horas_crm';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras() async {
    final raw = (await _storage).getString(_key);
    if (raw == null) return super.getCargasDeHoras();

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
  Future<List<CertificacionMoodle>> getCertificaciones() async => [];

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) async {}
}

class LocalCertificacionesMoodleRepository
    extends MockCertificacionesMoodleRepository {
  static const _key = 'formacion_certificaciones_moodle';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<List<CertificacionMoodle>> getCertificaciones() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super.getCertificaciones()
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
  } on FormatException {
    return [];
  } on TypeError {
    return [];
  }
}
