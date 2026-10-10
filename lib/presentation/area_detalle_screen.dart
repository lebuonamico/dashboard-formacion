import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_members_table.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_team_card.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';

class AreaDetalleScreen extends ConsumerWidget {
  final String nombreArea;

  const AreaDetalleScreen({super.key, required this.nombreArea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleAreaProvider(nombreArea));
    final hayDatosAsync = ref.watch(hayDatosEquiposPeriodoProvider);
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anio]);
    final periodControls = AreasPeriodControls(
      alcance: alcance,
      selectedMonth: mes,
      selectedYear: anio,
      availableYears: aniosDisponibles,
      onScopeChanged: (value) {
        ref.read(alcancePeriodoProvider.notifier).state = value;
      },
      onMonthChanged: (value) {
        if (value == null) return;
        ref.read(filtroMesPeriodoProvider.notifier).state = value;
      },
      onYearChanged: (value) {
        if (value == null) return;
        ref.read(filtroAnioPeriodoProvider.notifier).state = value;
      },
    );
    final requestedOrigin = GoRouterState.of(
      context,
    ).uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin!
        : 'areas';

    return Scaffold(
      backgroundColor: areasBackground,
      body: Column(
        children: [
          AppTopBar(title: 'Detalle de área', onBack: () => context.pop()),
          Expanded(
            child: detalleAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: areasBrand),
              ),
              error: (error, _) => _ErrorState(message: '$error'),
              data: (detalle) => FadeIn(
                child: (() {
                  final periodo = etiquetaPeriodo(alcance, mes, anio);
                  final hayDatos = hayDatosAsync.value ?? true;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    children: [
                      periodControls,
                      const SizedBox(height: 22),
                      if (!hayDatos)
                        EmptyDataState.periodoSinDatos(
                          icon: Icons.apartment_outlined,
                          periodo: periodo,
                        )
                      else if (detalle == null)
                        EmptyDataState(
                          icon: Icons.apartment_outlined,
                          title:
                              'El área $nombreArea no tiene colaboradores elegibles en $periodo.',
                          message:
                              'Probá otro período o verificá la nómina del área.',
                        )
                      else
                        _AreaContent(
                          detalle: detalle,
                          periodo: _periodoLabel(alcance, mes, anio),
                          esAnual: alcance == AlcancePeriodo.anual,
                          origin: origin,
                        ),
                    ],
                  );
                })(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _periodoLabel(AlcancePeriodo alcance, int mes, int anio) {
    if (alcance == AlcancePeriodo.mensual) {
      return '${nombreMes(mes)} $anio';
    }
    return 'Año $anio · meses con datos';
  }
}

class _AreaContent extends ConsumerWidget {
  final DetalleAreaViewModel detalle;
  final String periodo;
  final bool esAnual;
  final String origin;

  const _AreaContent({
    required this.detalle,
    required this.periodo,
    required this.esAnual,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = detalle.area;
    final filtro = ref.watch(filtroEstadoMiembroAreaProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AreaDetalleHeader(area: area, periodo: periodo),
        const SizedBox(height: 22),
        KpiGrid(
          cardHeight: 112,
          items: [
            KpiData(
              title: 'Integrantes',
              value: '${area.cantidadIntegrantes}',
              detail: 'nómina del área',
              help: esAnual
                  ? 'Colaboradores que tuvieron objetivo en esta área durante al menos uno de los meses con datos del año.'
                  : 'Personas de la nómina que pertenecen al área evaluada en el período.',
              icon: Icons.people_outline,
              color: areasBrand,
            ),
            KpiData(
              title: 'Horas realizadas',
              value: _horas(area.horasRealizadas),
              detail: 'aplicadas al objetivo del período',
              help: esAnual
                  ? 'Suma de las horas válidas de los meses con datos del año.'
                  : 'Horas validadas que corresponden al objetivo de cada integrante según su seniority.',
              icon: Icons.schedule_outlined,
              color: const Color(0xFF0E7490),
            ),
            KpiData(
              title: 'Objetivo del período',
              value: _horas(area.horasObjetivo),
              detail: 'según seniority y período',
              help: esAnual
                  ? 'Suma de los objetivos mensuales de los integrantes elegibles en los meses con datos del año.'
                  : 'Suma de las horas requeridas a los integrantes según seniority y alcance seleccionado.',
              icon: Icons.flag_outlined,
              color: const Color(0xFF6941C6),
            ),
            KpiData(
              title: 'Cumplimiento',
              value: '${area.porcentajeCumplimiento.toStringAsFixed(1)}%',
              detail:
                  '${area.integrantesEnObjetivo} de ${area.cantidadIntegrantes} en objetivo',
              help: esAnual
                  ? 'Porcentaje de horas válidas acumuladas sobre la suma de los objetivos mensuales de los períodos con datos.'
                  : 'Horas realizadas sobre horas objetivo. El estado del área sólo mira este porcentaje.',
              icon: Icons.trending_up,
              color: area.semaforo.colorTexto,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AreaDetalleResumen(area: area, esAnual: esAnual),
        const SizedBox(height: 24),
        AreaEquiposGrid(
          equipos: detalle.equipos,
          esAnual: esAnual,
          origen: origin,
        ),
        const SizedBox(height: 24),
        AreaMiembrosTable(
          miembros: detalle.miembros,
          filtro: filtro,
          onFiltro: (value) =>
              ref.read(filtroEstadoMiembroAreaProvider.notifier).state = value,
        ),
      ],
    );
  }

  String _horas(double value) => '${value.toStringAsFixed(1)} h';
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No pudimos cargar el área.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
