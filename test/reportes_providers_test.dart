import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _seccionEquipo = (area: 'Desarrollo', equipo: 'Core');

EquipoGlobalViewModel _equipo({
  String nombre = 'Core',
  String lider = 'María López',
  double porcentaje = 50,
  EstadoEquipo estado = EstadoEquipo.critico,
}) => EquipoGlobalViewModel(
  id: 'desarrollo-$nombre',
  nombre: nombre,
  area: 'Desarrollo',
  lider: lider,
  cantidadIntegrantes: 2,
  integrantesEnObjetivo: 1,
  horasRealizadas: 8,
  horasObjetivo: 16,
  desvioHoras: -8,
  horasNegocio: 4,
  horasBlandas: 4,
  horasLibres: 0,
  horasDictado: 0,
  promedioPorColaborador: 4,
  porcentajeCumplimiento: porcentaje,
  estado: estado,
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
  DetalleEquipoGeneral? equipo,
  DetalleAreaViewModel? area,
  bool fallaProyeccion = false,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      hayDatosEquiposPeriodoProvider.overrideWith((ref) async => hayDatos),
      detalleEquipoGeneralProvider(
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
      equipo: DetalleEquipoGeneral(resumen: _equipo(), miembros: const []),
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
      equipo: DetalleEquipoGeneral(resumen: _equipo(), miembros: const []),
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
            estado: EstadoEquipo.enObjetivo,
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
      equipo: DetalleEquipoGeneral(resumen: _equipo(), miembros: const []),
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
      equipo: DetalleEquipoGeneral(resumen: _equipo(), miembros: const []),
    );
    container.read(alcancePeriodoProvider.notifier).state =
        AlcancePeriodo.anual;

    final reporte = await container.read(
      reporteEquipoProvider(_seccionEquipo).future,
    );

    expect(reporte!.periodo, 'Año 2026 · meses con datos');
  });
}
