import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_members_table.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_status_style.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Leandro: Coordina el detalle; las reglas llegan resueltas desde el provider.
class EquipoScreen extends ConsumerWidget {
  final String area;
  final String equipo;

  const EquipoScreen({super.key, required this.area, required this.equipo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(
      detalleEquipoGeneralProvider((area: area, equipo: equipo)),
    );
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final soloRegistros = ref.watch(soloRegistrosCargadosPeriodoProvider);
    final periodo = _periodoLabel(alcance, mes, anio, soloRegistros);

    return Scaffold(
      backgroundColor: equiposBackground,
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  title: 'Detalle de equipo',
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: detalleAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: equiposBrand),
                    ),
                    error: (error, _) => _ErrorState(message: '$error'),
                    data: (detalle) =>
                        _EquipoContent(detalle: detalle, periodo: periodo),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _periodoLabel(
    AlcancePeriodo alcance,
    int mes,
    int anio,
    bool soloRegistros,
  ) {
    if (alcance == AlcancePeriodo.mensual) {
      return '${nombreMes(mes)} $anio';
    }
    return soloRegistros ? 'Año $anio · sólo meses con registros' : 'Año $anio';
  }
}

class _EquipoContent extends StatelessWidget {
  final DetalleEquipoGeneral detalle;
  final String periodo;

  const _EquipoContent({required this.detalle, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final equipo = detalle.resumen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        EquipoDetalleHeader(equipo: equipo, periodo: periodo),
        const SizedBox(height: 22),
        KpiGrid(
          cardHeight: 112,
          items: [
            KpiData(
              title: 'Integrantes',
              value: '${equipo.cantidadIntegrantes}',
              detail: 'nómina del equipo',
              help:
                  'Personas de la nómina que pertenecen al equipo evaluado en el período.',
              icon: Icons.people_outline,
              color: equiposBrand,
            ),
            KpiData(
              title: 'Horas realizadas',
              value: _horas(equipo.horasRealizadas),
              detail: 'aplicadas al objetivo del período',
              help:
                  'Horas validadas que corresponden al objetivo de cada integrante según su seniority.',
              icon: Icons.schedule_outlined,
              color: const Color(0xFF0E7490),
            ),
            KpiData(
              title: 'Objetivo del período',
              value: _horas(equipo.horasObjetivo),
              detail: 'según seniority y período',
              help:
                  'Suma de las horas requeridas a los integrantes según seniority y alcance seleccionado.',
              icon: Icons.flag_outlined,
              color: const Color(0xFF6941C6),
            ),
            KpiData(
              title: 'Cumplimiento',
              value: '${equipo.porcentajeCumplimiento.toStringAsFixed(1)}%',
              detail:
                  '${equipo.integrantesEnObjetivo} de ${equipo.cantidadIntegrantes} en objetivo',
              help:
                  'Horas realizadas sobre horas objetivo; el estado final también considera cuántos integrantes cumplieron.',
              icon: Icons.trending_up,
              color: equipo.estado.colorTexto,
            ),
          ],
        ),
        const SizedBox(height: 16),
        EquipoDetalleResumen(equipo: equipo),
        const SizedBox(height: 24),
        EquipoMiembrosTable(miembros: detalle.miembros),
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
          'No pudimos cargar el equipo.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
