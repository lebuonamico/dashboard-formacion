import 'dart:convert';

import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/formacion_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFormacionRepository implements FormacionRepository {
  @override
  Future<List<Empleado>> getEmpleados() async {
    // Simula delay de red o lectura de BD
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Empleado(
        legajo: 'EMP-001',
        nombre: 'Sofía',
        apellido: 'Martínez',
        seniority: Seniority.trainee,
        area: 'Desarrollo',
        equipo: 'Core ERP Backend',
        gerente: 'Lucas Gómez',
        mail: 'sofia.martinez@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-002',
        nombre: 'Lucas',
        apellido: 'Gómez',
        seniority: Seniority.junior3,
        area: 'Desarrollo',
        equipo: 'Core ERP Backend',
        gerente: 'Lucas Gómez',
        mail: 'lucas.gomez@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-003',
        nombre: 'Valeria',
        apellido: 'Ríos',
        seniority: Seniority.semisenior2,
        area: 'Arquitectura',
        equipo: 'Frontend Arquitectura & UI',
        gerente: 'Valeria Ríos',
        mail: 'valeria.rios@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-004',
        nombre: 'Martín',
        apellido: 'Castro',
        seniority: Seniority.senior2,
        area: 'Desarrollo',
        equipo: 'Core ERP Backend',
        gerente: 'Lucas Gómez',
        mail: 'martin.castro@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-005',
        nombre: 'Carolina',
        apellido: 'Herrera',
        seniority: Seniority.manager,
        area: 'Management',
        equipo: 'Formación y Liderazgo',
        gerente: 'Carolina Herrera',
        mail: 'carolina.herrera@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-006',
        nombre: 'Diego',
        apellido: 'Fernández',
        seniority: Seniority.senior1,
        area: 'Infraestructura',
        equipo: 'Cloud Infrastructure',
        gerente: 'Diego Fernández',
        mail: 'diego.fernandez@empresa.com',
      ),
      Empleado(
        legajo: 'EMP-007',
        nombre: 'Sebastian',
        apellido: 'Gonzalez',
        seniority: Seniority.senior2,
        area: 'Calidad',
        equipo: 'QA Automation',
        gerente: 'Sebastian Gonzalez',
        mail: 'sebastian.gonzalez@empresa.com',
      ),
      // Agrega más empleados según sea necesario
      
    ];
  }

  @override
  Future<List<Curso>> getCursos() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Curso(
        id: 'CUR-01',
        nombre: 'Estrategia y Modelos de Negocio',
        tipo: TipoCurso.habilidadesDeNegocio,
        areaCurso: 'Negocio',
        instructorLegajo: 'EMP-004', // Martín Castro
        cargaHorariaHs: 4.0,
      ),
      Curso(
        id: 'CUR-02',
        nombre: 'Finanzas Básicas para Tech',
        tipo: TipoCurso.habilidadesDeNegocio,
        areaCurso: 'Finanzas',
        instructorLegajo: 'EMP-005', // Carolina Herrera
        cargaHorariaHs: 2.0,
      ),
      Curso(
        id: 'CUR-03',
        nombre: 'Comunicación Asertiva y Feedback',
        tipo: TipoCurso.habilidadesBlandas,
        areaCurso: 'RRHH',
        instructorLegajo: 'EMP-004', // Martín Castro
        cargaHorariaHs: 4.0,
      ),
      Curso(
        id: 'CUR-04',
        nombre: 'Gestión del Tiempo y Priorización',
        tipo: TipoCurso.habilidadesBlandas,
        areaCurso: 'Productividad',
        instructorLegajo: 'EMP-003', // Valeria Ríos
        cargaHorariaHs: 2.0,
      ),
      Curso(
        id: 'CUR-05',
        nombre: 'Exploración de Arquitecturas Serverless',
        tipo: TipoCurso.libresExploracion,
        areaCurso: 'Innovación',
        instructorLegajo: 'EMP-003', // Valeria Ríos
        cargaHorariaHs: 1.0,
      ),
      Curso(
        id: 'CUR-06',
        nombre: 'Machine Learning aplicado a Negocios',
        tipo: TipoCurso.libresExploracion,
        areaCurso: 'Data',
        instructorLegajo: 'EMP-004', // Martín Castro
        cargaHorariaHs: 8.0,
      ),
    ];
  }

  @override
  Future<List<Cursada>> getCursadas() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      // EMP-001 (Trainee): Necesita 4h Negocio + 4h Blandas (Cumple 100%)
      Cursada(id: 'CSD-01', cursoId: 'CUR-01', empleadoLegajo: 'EMP-001', fecha: DateTime(2026, 7, 10)),
      Cursada(id: 'CSD-02', cursoId: 'CUR-03', empleadoLegajo: 'EMP-001', fecha: DateTime(2026, 7, 18)),

      // EMP-002 (Junior 3): Necesita 3h Negocio + 4h Blandas + 1h Libres (Tiene 2h Negocio + 4h Blandas)
      Cursada(id: 'CSD-03', cursoId: 'CUR-02', empleadoLegajo: 'EMP-002', fecha: DateTime(2026, 7, 12)),
      Cursada(id: 'CSD-04', cursoId: 'CUR-03', empleadoLegajo: 'EMP-002', fecha: DateTime(2026, 7, 25)),

      // EMP-003 (Semisenior 2): Necesita 2h Negocio + 4h Blandas + 1h Libres + 1h Dictado
      // Dicta CUR-04 (2h) y CUR-05 (1h) -> 3h Dictadas
      Cursada(id: 'CSD-05', cursoId: 'CUR-02', empleadoLegajo: 'EMP-003', fecha: DateTime(2026, 8, 5)),
      Cursada(id: 'CSD-06', cursoId: 'CUR-03', empleadoLegajo: 'EMP-003', fecha: DateTime(2026, 8, 12)),
      Cursada(id: 'CSD-07', cursoId: 'CUR-05', empleadoLegajo: 'EMP-003', fecha: DateTime(2026, 8, 20)),

      // EMP-004 (Senior 2): Necesita 2h Blandas + 2h Libres + 4h Dictado
      // Dicta CUR-01 (4h), CUR-03 (4h), CUR-06 (8h) -> 16h Dictadas
      Cursada(id: 'CSD-08', cursoId: 'CUR-04', empleadoLegajo: 'EMP-004', fecha: DateTime(2026, 8, 15)),
      Cursada(id: 'CSD-09', cursoId: 'CUR-05', empleadoLegajo: 'EMP-004', fecha: DateTime(2026, 8, 22)),

      // EMP-005 (Manager): Necesita 8h Libres (Cumple 100%)
      Cursada(id: 'CSD-10', cursoId: 'CUR-06', empleadoLegajo: 'EMP-005', fecha: DateTime(2026, 8, 28)),
    ];
  }

  @override
  Future<void> replaceData({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<Cursada> cursadas,
  }) async {}

  @override
  Future<void> resetToMock() async {}
}

class LocalFormacionRepository extends MockFormacionRepository {
  static const _empleadosKey = 'formacion_empleados';
  static const _cursosKey = 'formacion_cursos';
  static const _cursadasKey = 'formacion_cursadas';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<List<Empleado>> getEmpleados() async {
    final preferences = await _storage;
    final raw = preferences.getString(_empleadosKey);
    if (raw == null) return super.getEmpleados();

    return _decodeList(raw, Empleado.fromJson);
  }

  @override
  Future<List<Curso>> getCursos() async {
    final preferences = await _storage;
    final raw = preferences.getString(_cursosKey);
    if (raw == null) return super.getCursos();

    return _decodeList(raw, Curso.fromJson);
  }

  @override
  Future<List<Cursada>> getCursadas() async {
    final preferences = await _storage;
    final raw = preferences.getString(_cursadasKey);
    if (raw == null) return super.getCursadas();

    return _decodeList(raw, Cursada.fromJson);
  }

  @override
  Future<void> replaceData({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<Cursada> cursadas,
  }) async {
    final preferences = await _storage;
    await preferences.setString(
      _empleadosKey,
      jsonEncode(empleados.map((empleado) => empleado.toJson()).toList()),
    );
    await preferences.setString(
      _cursosKey,
      jsonEncode(cursos.map((curso) => curso.toJson()).toList()),
    );
    await preferences.setString(
      _cursadasKey,
      jsonEncode(cursadas.map((cursada) => cursada.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    final preferences = await _storage;
    await preferences.remove(_empleadosKey);
    await preferences.remove(_cursosKey);
    await preferences.remove(_cursadasKey);
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
}
