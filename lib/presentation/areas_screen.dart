import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_category_distribution.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_results.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_status_summary.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_bar.dart';

class AreasScreen extends ConsumerWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenAreasPeriodoProvider);
    final areasFiltradasAsync = ref.watch(areasFiltradasProvider);
    final requestedOrigin = GoRouterState.of(
      context,
    ).uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin
        : null;

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          const AppTopBar(title: 'Áreas y equipos generales'),
          Expanded(
            child: resumenAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar las áreas',
                error: error,
              ),
              data: (resumen) => FadeIn(
                child: _AreasContent(
                  resumen: resumen,
                  areasFiltradasAsync: areasFiltradasAsync,
                  origin: origin,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreasContent extends ConsumerWidget {
  final ResumenAreasPeriodo resumen;
  final AsyncValue<List<AreaGlobalViewModel>> areasFiltradasAsync;
  final String? origin;

  const _AreasContent({
    required this.resumen,
    required this.areasFiltradasAsync,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = resumen.areas;
    final busqueda = ref.watch(busquedaAreaProvider);
    final estadoSeleccionado = ref.watch(filtroEstadoAreaProvider);
    final alcanceSeleccionado = ref.watch(alcancePeriodoProvider);
    final mesSeleccionado = ref.watch(filtroMesPeriodoProvider);
    final anioSeleccionado = ref.watch(filtroAnioPeriodoProvider);
    final esAnual = alcanceSeleccionado == AlcancePeriodo.anual;
    final hayFiltrosActivos =
        busqueda.trim().isNotEmpty || estadoSeleccionado != null;

    return ListView(
      padding: paddingPantalla,
      children: [
        Text(
          'Vista general',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          resumen.tieneDatos
              ? 'Seguimiento del avance de ${areas.length} áreas de formación.'
              : 'Seleccioná un período con datos cargados.',
          style: TextStyle(
            fontSize: 14,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        const PeriodoFilterPanel(incluidos: 'todas las áreas'),
        const SizedBox(height: 22),
        if (!resumen.tieneDatos)
          EmptyDataState.periodoSinDatos(
            icon: Icons.apartment_outlined,
            periodo: etiquetaPeriodo(
              alcanceSeleccionado,
              mesSeleccionado,
              anioSeleccionado,
            ),
          )
        else if (areas.isEmpty)
          const EmptyDataState(
            icon: Icons.apartment_outlined,
            title: 'No hay áreas con colaboradores elegibles en este período.',
            message:
                'Verificá la nómina elegible para el período seleccionado.',
          )
        else ...[
          AreasKpiSection(
            totalAreas: resumen.totalAreas,
            totalColaboradores: resumen.colaboradores,
            horasRealizadas: resumen.horasRealizadas,
            horasObjetivo: resumen.horasObjetivo,
            desvioHoras: resumen.desvioHoras,
            cumplimientoGlobal: resumen.cumplimientoGlobal,
            esAnual: esAnual,
            anio: anioSeleccionado,
            mes: mesSeleccionado,
            variacion: ref
                .watch(
                  variacionCumplimientoProvider((area: null, equipo: null)),
                )
                .value,
            proyeccion: ref
                .watch(proyeccionAnualProvider((area: null, equipo: null)))
                .value,
          ),
          const SizedBox(height: 16),
          _ChartsRow(
            statusChart: AreasStatusSummary(
              total: resumen.totalAreas,
              enObjetivo: resumen.enObjetivo,
              enRiesgo: resumen.enRiesgo,
              criticos: resumen.criticos,
            ),
            categoryChart: AreasCategoryDistribution(
              horasNegocio: resumen.horasNegocio,
              horasBlandas: resumen.horasBlandas,
              horasLibres: resumen.horasLibres,
              horasDictado: resumen.horasDictado,
              esAnual: esAnual,
            ),
          ),
          // Moodle vs CRM de todas las áreas, con los mismos colaboradores
          // del resumen.
          if (ref.watch(teamComplianceProvider).value case final items?
              when items.isNotEmpty) ...[
            const SizedBox(height: 16),
            ComparacionMoodleCrmCards(cumplimientos: items),
          ],
          const SizedBox(height: 24),
          FilterBar(
            scope: 'areas',
            hasActiveFilters: hayFiltrosActivos,

            onClear: () {
              ref.read(busquedaAreaProvider.notifier).state = '';
              ref.read(filtroEstadoAreaProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 24),
          areasFiltradasAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: context.colorScheme.primary,
              ),
            ),
            error: (error, _) => ErrorDataState(
              title: 'No pudimos cargar las áreas',
              error: error,
            ),
            data: (areasFiltradas) => AreasResults(
              key: ValueKey(
                '$alcanceSeleccionado-$anioSeleccionado-$mesSeleccionado-'
                '$busqueda-$estadoSeleccionado',
              ),
              areas: areasFiltradas,
              totalAreas: resumen.totalAreas,
              esAnual: esAnual,
              origen: origin,
            ),
          ),
        ],
      ],
    );
  }
}

/// Estado y categorías lado a lado; en pantallas angostas, uno debajo del otro.
class _ChartsRow extends StatelessWidget {
  final Widget statusChart;
  final Widget categoryChart;

  const _ChartsRow({required this.statusChart, required this.categoryChart});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1180) {
          return Column(
            children: [statusChart, const SizedBox(height: 16), categoryChart],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statusChart),
              const SizedBox(width: 16),
              Expanded(child: categoryChart),
            ],
          ),
        );
      },
    );
  }
}
