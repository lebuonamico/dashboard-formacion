import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/reportes/reportes_pantallas.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_period_controls.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_members_table.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EquipoScreen extends ConsumerWidget {
  final String area;
  final String equipo;

  const EquipoScreen({super.key, required this.area, required this.equipo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leandro: llama a detalleEquipoGeneralProvider para obtener el resumen y los integrantes del equipo elegido.
    final detalleAsync = ref.watch(
      detalleEquipoGeneralProvider((area: area, equipo: equipo)),
    );
    final hayDatosAsync = ref.watch(hayDatosEquiposPeriodoProvider);
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    // Leandro: llama a _periodoLabel para armar el nombre del período que aparece en el encabezado.
    final periodo = _periodoLabel(alcance, mes, anio);
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anio]);
    // Mismo panel que el detalle de área: el período es global a la app.
    final periodControls = EquiposPeriodControls(
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
        return reporteEquipo(
          periodo: periodo,
          detalle: detalle,
          proyeccion: ref
              .read(
                proyeccionAnualProvider((
                  area: detalle.resumen.area,
                  equipo: detalle.resumen.nombre,
                )),
              )
              .value,
        );
      },
    );

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          // Leandro: llama al widget AppTopBar para mostrar el título del detalle y permitir volver a la pantalla anterior.
          AppTopBar(title: 'Detalle de equipo', onBack: () => context.pop()),
          Expanded(
            // Leandro: llama a AsyncValue.when para mostrar la carga, el error o los datos del equipo.
            child: detalleAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => _ErrorState(message: '$error'),
              data: (detalle) => FadeIn(
                child: (() {
                  final etiqueta = etiquetaPeriodo(alcance, mes, anio);
                  if (!(hayDatosAsync.value ?? true)) {
                    return _EmptyContent(
                      periodControls: periodControls,
                      child: EmptyDataState.periodoSinDatos(
                        icon: Icons.groups_outlined,
                        periodo: etiqueta,
                      ),
                    );
                  }
                  if (detalle == null) {
                    return _EmptyContent(
                      periodControls: periodControls,
                      child: EmptyDataState(
                        icon: Icons.groups_outlined,
                        title:
                            'El equipo $equipo no tiene colaboradores elegibles en $etiqueta.',
                        message:
                            'Probá otro período o verificá la nómina del equipo.',
                      ),
                    );
                  }
                  // Leandro: llama al widget _EquipoContent para presentar el detalle del equipo y su período.
                  return _EquipoContent(
                    detalle: detalle,
                    periodo: periodo,
                    esAnual: alcance == AlcancePeriodo.anual,
                    periodControls: periodControls,
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

class _EquipoContent extends ConsumerWidget {
  final DetalleEquipoGeneral detalle;
  final String periodo;
  final bool esAnual;
  final Widget periodControls;

  const _EquipoContent({
    required this.detalle,
    required this.periodo,
    required this.esAnual,
    required this.periodControls,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipo = detalle.resumen;
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final proyeccion = ref
        .watch(
          proyeccionAnualProvider((area: equipo.area, equipo: equipo.nombre)),
        )
        .value;

    return ListView(
      padding: paddingPantalla,
      children: [
        periodControls,
        const SizedBox(height: 22),
        // Leandro: llama al widget EquipoDetalleHeader para mostrar el nombre, el período y el estado del equipo.
        EquipoDetalleHeader(equipo: equipo, periodo: periodo),
        const SizedBox(height: 22),
        // Mismas cards que el inicio, con los datos del equipo.
        KpiCardRow(
          cards: [
            DashboardKpiCard(
              title: 'INTEGRANTES',
              value: '${equipo.cantidadIntegrantes}',
              suffix: 'nómina del equipo',
              progress: equipo.cantidadIntegrantes == 0
                  ? 0
                  : equipo.integrantesEnObjetivo / equipo.cantidadIntegrantes,
              progressLabel:
                  '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes} en objetivo',
              footer: '',
              icon: Icons.people_outline,
              color: context.colorScheme.primary,
            ),
            horasValidasKpiCard(
              context,
              esAnual: esAnual,
              anio: anio,
              mes: mes,
              horas: equipo.horasRealizadas,
              objetivo: equipo.horasObjetivo,
            ),
            DashboardKpiCard(
              title: 'OBJETIVO DEL PERÍODO',
              value: _horas(equipo.horasObjetivo),
              suffix: 'según seniority',
              progress: 1,
              progressLabel: esAnual
                  ? 'Suma de los objetivos del año'
                  : 'Objetivo del mes',
              footer: '',
              icon: Icons.flag_outlined,
              color: context.colores.acentoVioleta,
            ),
            // El color sigue el estado del equipo, que también mira cuántos
            // integrantes cumplieron.
            cumplimientoKpiCard(
              context,
              esAnual: esAnual,
              anio: anio,
              mes: mes,
              porcentaje: equipo.porcentajeCumplimiento,
              variacion: ref
                  .watch(
                    variacionCumplimientoProvider((
                      area: equipo.area,
                      equipo: equipo.nombre,
                    )),
                  )
                  .value,
              color: equipo.estado.colores(context).texto,
            ),
            if (proyeccion != null) proyeccionKpiCard(context, proyeccion),
          ],
        ),
        const SizedBox(height: 16),
        // Leandro: llama al widget EquipoDetalleResumen para mostrar la distribución y el avance de las horas.
        EquipoDetalleResumen(equipo: equipo, esAnual: esAnual),
        if (detalle.miembros.isNotEmpty) ...[
          const SizedBox(height: 16),
          ComparacionMoodleCrmCards(cumplimientos: detalle.miembros),
        ],
        const SizedBox(height: 24),
        // Leandro: llama al widget EquipoMiembrosTable para listar el cumplimiento de cada integrante.
        EquipoMiembrosTable(miembros: detalle.miembros),
      ],
    );
  }

  String _horas(double value) => '${value.toStringAsFixed(1)} h';
}

class _EmptyContent extends StatelessWidget {
  final Widget periodControls;
  final Widget child;

  const _EmptyContent({required this.periodControls, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: paddingPantalla,
      children: [periodControls, const SizedBox(height: 22), child],
    );
  }
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
          'No pudimos cargar el equipo.\n$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colorScheme.error),
        ),
      ),
    );
  }
}
