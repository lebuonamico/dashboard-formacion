import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _seccionEquipo = (area: 'Desarrollo', equipo: 'Core');

TeamOverview _equipo({
  String nombre = 'Core',
  String lider = 'María López',
  double porcentaje = 50,
  TeamStatus estado = TeamStatus.critical,
}) => TeamOverview(
  id: 'desarrollo-$nombre',
  name: nombre,
  area: 'Desarrollo',
  leader: lider,
  memberCount: 2,
  membersOnTarget: 1,
  completedHours: 8,
  targetHours: 16,
  hoursDeviation: -8,
  businessHours: 4,
  softSkillsHours: 4,
  explorationHours: 0,
  teachingHours: 0,
  averageHoursPerMember: 4,
  completionPercentage: porcentaje,
  status: estado,
);

const _area = AreaGlobalViewModel(
  nombre: 'Desarrollo',
  equiposGenerales: ['Core', 'Mobile'],
  cantidadIntegrantes: 4,
  integrantesEnObjetivo: 1,
  horasRealizadas: 20,
  horasObjetivo: 32,
  horasNegocio: 10,
  horasBlandas: 10,
  horasLibres: 0,
  horasDictado: 0,
  porcentajeCumplimiento: 62.5,
  semaforo: EstadoSemaforo.rojo,
  lideres: 'Ana Pérez',
);

ProviderContainer _container({
  bool hayDatos = true,
  TeamDetail? equipo,
  DetalleAreaViewModel? area,
  bool fallaProyeccion = false,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      hasTeamPeriodDataProvider.overrideWith((ref) async => hayDatos),
      teamDetailProvider(
        _seccionEquipo,
      ).overrideWith((ref) async => equipo),
      detalleAreaProvider('Desarrollo').overrideWith((ref) async => area),
      proyeccionAnualProvider.overrideWith(
        (ref, seccion) async =>
            fallaProyeccion ? throw StateError('sin cargas') : null,
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(alcancePeriodoProvider.notifier).state =
      AlcancePeriodo.mensual;
  container.read(filtroMesPeriodoProvider.notifier).state = 10;
  container.read(filtroAnioPeriodoProvider.notifier).state = 2026;
  return container;
}

void main() {
  test('Sin datos en el período no hay reporte en ninguna pantalla', () async {
    final container = _container(
      hayDatos: false,
      equipo: TeamDetail(overview: _equipo(), members: const []),
    );

    expect(await container.read(reporteDashboardProvider.future), isNull);
    expect(
      await container.read(reporteAreaProvider('Desarrollo').future),
      isNull,
    );
    expect(
      await container.read(reporteEquipoProvider(_seccionEquipo).future),
      isNull,
    );
  });

  test('Sin colaboradores elegibles no hay reporte del equipo', () async {
    final container = _container();

    expect(
      await container.read(reporteEquipoProvider(_seccionEquipo).future),
      isNull,
    );
  });

  test('El reporte del equipo usa los números de su detalle', () async {
    final container = _container(
      equipo: TeamDetail(overview: _equipo(), members: const []),
    );

    final reporte = await container.read(
      reporteEquipoProvider(_seccionEquipo).future,
    );

    expect(reporte!.tipo, TipoReporte.equipo);
    expect(reporte.titulo, 'Core');
    expect(reporte.detalles, ['Área: Desarrollo', 'Líder: María López']);
    expect(reporte.periodo, 'Octubre 2026');
    expect(reporte.porcentaje, 50);
    expect(reporte.estado, 'Crítico');
    expect(reporte.nivel, NivelReporte.critico);
    expect(reporte.desglose, isEmpty);
  });

  test('El reporte del área desglosa sus equipos', () async {
    final container = _container(
      area: DetalleAreaViewModel(
        area: _area,
        equipos: [
          _equipo(),
          _equipo(
            nombre: 'Mobile',
            porcentaje: 100,
            estado: TeamStatus.onTarget,
          ),
        ],
        miembros: const [],
      ),
    );

    final reporte = await container.read(
      reporteAreaProvider('Desarrollo').future,
    );

    expect(reporte!.tipo, TipoReporte.area);
    expect(reporte.detalles, ['Líder: Ana Pérez', '2 equipos']);
    expect(reporte.nivel, NivelReporte.critico);
    expect(reporte.desglose.map((f) => (f.nombre, f.nivel)), [
      ('Core', NivelReporte.critico),
      ('Mobile', NivelReporte.ok),
    ]);
  });

  test('Si la proyección falla, el reporte sale sin ella', () async {
    final container = _container(
      equipo: TeamDetail(overview: _equipo(), members: const []),
      fallaProyeccion: true,
    );

    final reporte = await container.read(
      reporteEquipoProvider(_seccionEquipo).future,
    );

    expect(reporte, isNotNull);
    expect(reporte!.proyeccion, isNull);
  });

  test('En el anual el período aclara que suma los meses con datos', () async {
    final container = _container(
      equipo: TeamDetail(overview: _equipo(), members: const []),
    );
    container.read(alcancePeriodoProvider.notifier).state =
        AlcancePeriodo.anual;

    final reporte = await container.read(
      reporteEquipoProvider(_seccionEquipo).future,
    );

    expect(reporte!.periodo, 'Año 2026 · meses con datos');
  });
}
