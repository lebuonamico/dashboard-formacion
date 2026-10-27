import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/consulta_asistente.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado_historial.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_historial_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/repositorios/estructura_repository.dart';
import 'package:app_finnegans/domain/repositorios/plan_formacion_repository.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/asistente_datos_provider.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _anio = 2026;

class _EmpleadosFake implements EmpleadosRepository {
  final List<Empleado> empleados;
  _EmpleadosFake(this.empleados);

  @override
  Future<List<Empleado>> getEmpleados({
    String? legajo,
    String? equipo,
    String? sector,
  }) async => empleados;

  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) async {}

  @override
  Future<void> resetToMock() async {}
}

class _EmpleadosConHistorialFake extends _EmpleadosFake
    implements EmpleadosHistorialRepository {
  final List<EmpleadoHistorial> historial;
  _EmpleadosConHistorialFake(super.empleados, this.historial);

  @override
  Future<List<EmpleadoHistorial>> getHistorialEmpleados() async => historial;
}

class _CursosFake implements CursosRepository {
  @override
  Future<List<Curso>> getCursos({String? id, String? nombre}) async => [_curso];

  @override
  Future<void> replaceCursos(List<Curso> cursos) async {}

  @override
  Future<void> resetToMock() async {}
}

class _CargasFake implements CargaDeHorasCRMRepository {
  final List<CargaDeHorasCRM> cargas;
  _CargasFake(this.cargas);

  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras({
    String? empleadoLegajo,
    String? cursoId,
    DateTime? desde,
    DateTime? hasta,
  }) async => cargas
      .where(
        (carga) =>
            (desde == null || !carga.fecha.isBefore(desde)) &&
            (hasta == null || carga.fecha.isBefore(hasta)),
      )
      .toList();

  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) async {}

  @override
  Future<void> resetToMock() async {}
}

class _CertificacionesFake implements CertificacionesMoodleRepository {
  final List<CertificacionMoodle> certificaciones;
  _CertificacionesFake(this.certificaciones);

  @override
  Future<List<CertificacionMoodle>> getCertificaciones({
    String? legajo,
    String? cursoId,
  }) async => certificaciones;

  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) async {}
}

class _EstructuraFake implements EstructuraRepository {
  final EstructuraOrganizacional estructura;
  _EstructuraFake(this.estructura);

  @override
  Future<EstructuraOrganizacional> getEstructura() async => estructura;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _curso = Curso(
  id: '1',
  nombre: 'Negociación',
  clasificacion: TipoCurso.habilidadesDeNegocio,
  areaCurso: '',
  instructorLegajo: '',
  cargaHorariaHs: 4,
);

Empleado _empleado(String legajo, String sector, String equipo) => Empleado(
  legajo: legajo,
  nombre: 'Persona',
  apellido: legajo,
  seniority: Seniority.junior1,
  area: sector,
  mail: 'persona$legajo@finnegans.com',
  equipo: equipo,
  gerente: 'Gerente $equipo',
  fechaIngreso: DateTime(2020, 1, 1),
);

/// 1 y 2 en PLATAFORMA CORE y BACKEND, de PRODUCTOS TECNOLÓGICOS; 3 en SOPORTE
/// y 4 sin equipo, de SERVICIOS.
final _empleados = [
  Empleado(
    legajo: '1',
    nombre: 'Lía',
    apellido: 'Líder',
    seniority: Seniority.junior1,
    area: 'PRODUCTOS TECNOLÓGICOS',
    mail: 'Lider@finnegans.com',
    equipo: 'PLATAFORMA CORE',
    gerente: 'Gerente Core',
    fechaIngreso: DateTime(2020, 1, 1),
  ),
  _empleado('2', 'PRODUCTOS TECNOLÓGICOS', 'BACKEND'),
  _empleado('3', 'SERVICIOS', 'SOPORTE'),
  _empleado('4', 'SERVICIOS', ''),
];

EstructuraOrganizacional _estructura({
  Set<String> lideresCore = const {'lider@finnegans.com'},
}) => EstructuraOrganizacional(
  areas: [
    Area(id: '1', nombre: 'PRODUCTOS TECNOLÓGICOS'),
    Area(id: '2', nombre: 'SERVICIOS', lideres: {'area@finnegans.com'}),
  ],
  equipos: [
    Equipo(
      id: '10',
      areaId: '1',
      nombre: 'PLATAFORMA CORE',
      lideres: lideresCore,
    ),
    Equipo(id: '11', areaId: '1', nombre: 'BACKEND'),
    Equipo(id: '20', areaId: '2', nombre: 'SOPORTE'),
  ],
);

List<CargaDeHorasCRM> _cargas(Iterable<String> legajos, int mes) => [
  for (final legajo in legajos)
    CargaDeHorasCRM(
      id: 'tx-$legajo-$mes',
      cursoNombre: _curso.nombre,
      empleadoLegajo: legajo,
      fecha: DateTime(_anio, mes, 10),
      horasTotales: 4,
      tipo: TipoCargaDeHoras.tomada,
    ),
];

List<CertificacionMoodle> _finalizaciones(Iterable<String> legajos, int mes) =>
    [
      for (final legajo in legajos)
        CertificacionMoodle(
          legajo: legajo,
          cursoNombre: _curso.nombre,
          finalizoCurso: true,
          fechaFinalizacion: DateTime(_anio, mes, 20),
        ),
    ];

/// Sin versiones: rige el plan por defecto, como antes de poder editarlo.
class _PlanFake implements PlanFormacionRepository {
  @override
  Future<PlanesFormacion> getPlanes() async =>
      const PlanesFormacion.sinVersiones();

  @override
  Future<void> guardarVersion(VersionPlanFormacion version) async {}
}

ProviderContainer _container({
  required bool habilitada,
  String? email,
  String? rol,
  EstructuraOrganizacional? estructura,
  List<Empleado>? empleados,
  List<EmpleadoHistorial>? historial,
  List<CargaDeHorasCRM>? cargas,
  List<CertificacionMoodle>? certificaciones,
  int mes = 6,
}) {
  final nomina = empleados ?? _empleados;
  final legajos = nomina.map((empleado) => empleado.legajo);
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      sesionDatosProvider.overrideWithValue((
        habilitada: habilitada,
        email: email,
        rol: rol,
      )),
      estructuraRepositoryProvider.overrideWithValue(
        estructura == null ? null : _EstructuraFake(estructura),
      ),
      empleadosRepositoryProvider.overrideWithValue(
        historial == null
            ? _EmpleadosFake(nomina)
            : _EmpleadosConHistorialFake(nomina, historial),
      ),
      cursosRepositoryProvider.overrideWithValue(_CursosFake()),
      planFormacionRepositoryProvider.overrideWithValue(_PlanFake()),
      cargaDeHorasCRMRepositoryProvider.overrideWithValue(
        _CargasFake(cargas ?? _cargas(legajos, 6)),
      ),
      certificacionesMoodleRepositoryProvider.overrideWithValue(
        _CertificacionesFake(certificaciones ?? _finalizaciones(legajos, 6)),
      ),
      alcancePeriodoProvider.overrideWith((ref) => AlcancePeriodo.mensual),
      filtroMesPeriodoProvider.overrideWith((ref) => mes),
      filtroAnioPeriodoProvider.overrideWith((ref) => _anio),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Un líder ve solo su equipo', () async {
    final container = _container(
      habilitada: true,
      email: 'lider@finnegans.com',
      rol: 'lider',
      estructura: _estructura(),
    );

    final empleados = await container.read(empleadosProvider.future);
    expect(empleados.map((e) => e.legajo), ['1']);

    final cargas = await container.read(cargasDeHorasCRMProvider.future);
    expect(cargas.map((c) => c.empleadoLegajo), ['1']);
    final dashboard = await container.read(cargasDashboardProvider.future);
    expect(dashboard.map((c) => c.empleadoLegajo), ['1']);
    final certificaciones = await container.read(
      certificacionesMoodleProvider.future,
    );
    expect(certificaciones.map((c) => c.legajo), ['1']);

    final resumen = await container.read(resumenEquiposPeriodoProvider.future);
    expect(resumen.equipos, hasLength(1));
    expect(resumen.equipos.single.nombre, 'PLATAFORMA CORE');
    expect(resumen.equipos.single.area, 'PRODUCTOS TECNOLÓGICOS');
    // El email del líder coincide con el de la nómina: se ve su nombre.
    expect(resumen.equipos.single.lider, 'Lía Líder');
  });

  test('Un usuario de área ve toda su área, sin equipo incluidos', () async {
    final container = _container(
      habilitada: true,
      email: 'Area@Finnegans.com',
      rol: 'area',
      estructura: _estructura(),
    );

    final empleados = await container.read(empleadosProvider.future);
    expect(empleados.map((e) => e.legajo), ['3', '4']);

    final areas = await container.read(resumenAreasPeriodoProvider.future);
    expect(areas.areas.map((area) => area.nombre), ['SERVICIOS']);
    // No hay empleado con ese email: se muestra el email.
    expect(areas.areas.single.lideres, 'area@finnegans.com');

    final equipos = await container.read(resumenEquiposPeriodoProvider.future);
    expect(equipos.equipos.map((equipo) => equipo.nombre).toSet(), {
      'SOPORTE',
      'Sin equipo asignado',
    });
  });

  test(
    'Academia ve toda la empresa y los equipos sin líder caen al Gerente',
    () async {
      final container = _container(
        habilitada: true,
        email: 'academia@finnegans.com',
        rol: 'academia',
        estructura: _estructura(),
      );

      expect(await container.read(legajosVisiblesProvider.future), isNull);
      final empleados = await container.read(empleadosProvider.future);
      expect(empleados.map((e) => e.legajo), ['1', '2', '3', '4']);

      final resumen = await container.read(
        resumenEquiposPeriodoProvider.future,
      );
      final backend = resumen.equipos.firstWhere((e) => e.nombre == 'BACKEND');
      expect(backend.lider, 'Gerente BACKEND');
      final core = resumen.equipos.firstWhere(
        (e) => e.nombre == 'PLATAFORMA CORE',
      );
      expect(core.lider, 'Lía Líder');
    },
  );

  test(
    'El contexto del asistente IA conserva el alcance de la sesión',
    () async {
      final container = _container(
        habilitada: true,
        email: 'lider@finnegans.com',
        rol: 'lider',
        estructura: _estructura(),
      );

      final contexto = await container.read(prepararContextoIaProvider)(
        const DestinoAsistente(ModuloAsistente.dashboard),
        '¿Cómo viene el cumplimiento general?',
      );

      final resultado =
          (contexto.datos['resultados'] as List).single as Map<String, Object?>;
      expect(resultado['tiene_datos'], isTrue);
      expect((resultado['global'] as Map)['colaboradores'], 1);
      expect((resultado['dashboard'] as Map)['colaboradores'], 1);
    },
  );

  test('Un líder sin equipos asignados no ve datos', () async {
    final container = _container(
      habilitada: true,
      email: 'nuevo@finnegans.com',
      rol: 'lider',
      estructura: _estructura(),
    );

    expect(await container.read(empleadosProvider.future), isEmpty);
    expect(await container.read(cargasDeHorasCRMProvider.future), isEmpty);
    expect(await container.read(certificacionesMoodleProvider.future), isEmpty);
  });

  test(
    'Pertenece a sale de la nómina aunque no esté en lo que lidera',
    () async {
      // Lidera PLATAFORMA CORE, pero en la nómina figura en SOPORTE.
      final container = _container(
        habilitada: true,
        email: 'PERSONA3@finnegans.com',
        rol: 'lider',
        estructura: _estructura(lideresCore: {'persona3@finnegans.com'}),
      );

      final empleados = await container.read(empleadosProvider.future);
      expect(empleados.map((e) => e.legajo), ['1']);
      final propio = await container.read(empleadoDeSesionProvider.future);
      expect(propio!.legajo, '3');
      expect(propio.equipo, 'SOPORTE');
      expect(propio.area, 'SERVICIOS');
    },
  );

  test('Sin fila en la nómina, Pertenece a queda vacío', () async {
    final container = _container(
      habilitada: true,
      email: 'externo@gmail.com',
      rol: 'lider',
      estructura: _estructura(),
    );
    expect(await container.read(empleadoDeSesionProvider.future), isNull);
  });

  test('En modo local se ve todo y no hay sesión que buscar', () async {
    final container = _container(habilitada: false);

    expect(await container.read(estructuraProvider.future), isNull);
    expect(await container.read(legajosVisiblesProvider.future), isNull);
    expect(await container.read(empleadoDeSesionProvider.future), isNull);
    final empleados = await container.read(empleadosProvider.future);
    expect(empleados.map((e) => e.legajo), ['1', '2', '3', '4']);

    final resumen = await container.read(resumenEquiposPeriodoProvider.future);
    expect(
      resumen.equipos.firstWhere((e) => e.nombre == 'PLATAFORMA CORE').lider,
      'Gerente Core',
    );
  });

  group('Con historial', () {
    // La persona 2 hoy está en PLATAFORMA CORE, pero hasta junio estuvo en
    // BACKEND.
    final historial = [
      EmpleadoHistorial(
        legajo: '1',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        equipo: 'PLATAFORMA CORE',
        gerente: 'Gerente Core',
        activo: true,
        vigenteDesde: DateTime(2020, 1, 1),
      ),
      EmpleadoHistorial(
        legajo: '2',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        equipo: 'BACKEND',
        gerente: 'Gerente BACKEND',
        activo: true,
        vigenteDesde: DateTime(2020, 1, 1),
        vigenteHasta: DateTime(_anio, 7, 1),
      ),
      EmpleadoHistorial(
        legajo: '2',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        equipo: 'PLATAFORMA CORE',
        gerente: 'Gerente Core',
        activo: true,
        vigenteDesde: DateTime(_anio, 7, 1),
      ),
    ];

    ProviderContainer contenedor(int mes) => _container(
      habilitada: true,
      email: 'lider@finnegans.com',
      rol: 'lider',
      estructura: _estructura(),
      // La nómina actual pone a la persona 2 en PLATAFORMA CORE.
      empleados: [
        _empleados[0],
        _empleado('2', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
      ],
      historial: historial,
      cargas: [
        ..._cargas(['1', '2'], 6),
        ..._cargas(['1', '2'], 7),
      ],
      certificaciones: [
        ..._finalizaciones(['1', '2'], 6),
        ..._finalizaciones(['1', '2'], 7),
      ],
      mes: mes,
    );

    test(
      'El líder ve a alguien solo en los meses en que estuvo en su equipo',
      () async {
        final junio = contenedor(6);
        final cumplimientosJunio = await junio.read(
          cumplimientoEquiposProvider.future,
        );
        expect(cumplimientosJunio.map((c) => c.empleado.legajo), ['1']);

        final julio = contenedor(7);
        final cumplimientosJulio = await julio.read(
          cumplimientoEquiposProvider.future,
        );
        expect(cumplimientosJulio.map((c) => c.empleado.legajo).toSet(), {
          '1',
          '2',
        });
        expect(cumplimientosJulio.map((c) => c.empleado.equipo).toSet(), {
          'PLATAFORMA CORE',
        });
      },
    );

    test(
      'El asistente IA reconstruye el período con el alcance del líder',
      () async {
        // Su contenedor no tiene padre: si armara su propia sesión, en junio
        // contaría también a la persona 2, que estaba en Backend.
        final contexto = await contenedor(6).read(prepararContextoIaProvider)(
          const DestinoAsistente(ModuloAsistente.dashboard),
          '¿Cómo viene el cumplimiento general?',
        );

        final resultado =
            (contexto.datos['resultados'] as List).single
                as Map<String, Object?>;
        expect((resultado['global'] as Map)['colaboradores'], 1);
      },
    );
  });
}
