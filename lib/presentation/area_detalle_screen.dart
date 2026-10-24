import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/reportes/reportes_pantallas.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_members_table.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_team_card.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';

class AreaDetalleScreen extends ConsumerWidget {
  final String nombreArea;

  const AreaDetalleScreen({super.key, required this.nombreArea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleAreaProvider(nombreArea));
    // Mantener la selección durante cargas o períodos sin integrantes.
    final filtroMiembros = ref.watch(filtroEstadoMiembroAreaProvider);
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
      construirReporte: () {
        final detalle = detalleAsync.value;
        if (detalle == null || hayDatosAsync.value == false) return null;
        return reporteArea(
          periodo: _periodoLabel(alcance, mes, anio),
          detalle: detalle,
          proyeccion: ref
              .read(
                proyeccionAnualProvider((
                  area: detalle.area.nombre,
                  equipo: null,
                )),
              )
              .value,
        );
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
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          AppTopBar(title: 'Detalle de área', onBack: () => context.pop()),
          Expanded(
            child: detalleAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => _ErrorState(message: '$error'),
              data: (detalle) => FadeIn(
                child: (() {
                  final periodo = etiquetaPeriodo(alcance, mes, anio);
                  final hayDatos = hayDatosAsync.value ?? true;

                  return ListView(
                    padding: paddingPantalla,
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
                          filtro: filtroMiembros,
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
  final Set<String> filtro;
  final String periodo;
  final bool esAnual;
  final String origin;

  const _AreaContent({
    required this.detalle,
    required this.filtro,
    required this.periodo,
    required this.esAnual,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = detalle.area;
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AreaDetalleHeader(area: area, periodo: periodo),
        const SizedBox(height: 22),
        KpiCardRow(
          cards: [
            DashboardKpiCard(
              title: 'INTEGRANTES',
              value: '${area.cantidadIntegrantes}',
              suffix: 'nómina del área',
              progress: area.cantidadIntegrantes == 0
                  ? 0
                  : area.integrantesEnObjetivo / area.cantidadIntegrantes,
              progressLabel:
                  '${area.integrantesEnObjetivo} de ${area.cantidadIntegrantes} en objetivo',
              footer: '',
              icon: Icons.people_outline,
              color: context.colorScheme.primary,
            ),
            horasValidasKpiCard(
              context,
              esAnual: esAnual,
              anio: anio,
              mes: mes,
              horas: area.horasRealizadas,
              objetivo: area.horasObjetivo,
            ),
            DashboardKpiCard(
              title: 'OBJETIVO DEL PERÍODO',
              value: _horas(area.horasObjetivo),
              suffix: 'según seniority',
              progress: 1,
              progressLabel: esAnual
                  ? 'Suma de los objetivos del año'
                  : 'Objetivo del mes',
              footer: '',
              icon: Icons.flag_outlined,
              color: context.colores.acentoVioleta,
            ),
            cumplimientoKpiCard(
              context,
              esAnual: esAnual,
              anio: anio,
              mes: mes,
              porcentaje: area.porcentajeCumplimiento,
              variacion: ref
                  .watch(
                    variacionCumplimientoProvider((
                      area: area.nombre,
                      equipo: null,
                    )),
                  )
                  .value,
              color: area.semaforo.colores(context).texto,
            ),
            if (ref
                    .watch(
                      proyeccionAnualProvider((
                        area: area.nombre,
                        equipo: null,
                      )),
                    )
                    .value
                case final proyeccion?)
              proyeccionKpiCard(context, proyeccion),
          ],
        ),
        const SizedBox(height: 16),
        AreaDetalleResumen(area: area, esAnual: esAnual),
        if (detalle.miembros.isNotEmpty) ...[
          const SizedBox(height: 16),
          ComparacionMoodleCrmCards(cumplimientos: detalle.miembros),
        ],
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
          style: TextStyle(color: context.colorScheme.error),
        ),
      ),
    );
  }
}
