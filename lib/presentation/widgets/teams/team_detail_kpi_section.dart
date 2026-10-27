import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/team_overview.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamDetailKpiSection extends ConsumerWidget {
  final TeamOverview team;
  final bool isAnnual;

  const TeamDetailKpiSection({
    super.key,
    required this.team,
    required this.isAnnual,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(filtroAnioPeriodoProvider);
    final month = ref.watch(filtroMesPeriodoProvider);
    final projection = ref
        .watch(proyeccionAnualProvider((area: team.area, equipo: team.name)))
        .value;

    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'INTEGRANTES',
          value: '${team.memberCount}',
          suffix: 'nómina del equipo',
          progress: team.memberCount == 0
              ? 0
              : team.membersOnTarget / team.memberCount,
          progressLabel:
              '${team.membersOnTarget} de ${team.memberCount} en objetivo',
          footer: '',
          icon: Icons.people_outline,
          color: context.colorScheme.primary,
          ayuda: ayudaIntegrantes('del equipo'),
        ),
        horasValidasKpiCard(
          context,
          esAnual: isAnnual,
          anio: year,
          mes: month,
          horas: team.completedHours,
          objetivo: team.targetHours,
        ),
        DashboardKpiCard(
          title: 'OBJETIVO DEL PERÍODO',
          value: _formatHours(team.targetHours),
          suffix: 'según seniority',
          progress: 1,
          progressLabel: isAnnual
              ? 'Suma de los objetivos del año'
              : 'Objetivo del mes',
          footer: '',
          icon: Icons.flag_outlined,
          color: context.colores.acentoVioleta,
          ayuda: ayudaObjetivo('el equipo'),
        ),

        cumplimientoKpiCard(
          context,
          esAnual: isAnnual,
          anio: year,
          mes: month,
          porcentaje: team.completionPercentage,
          variacion: ref
              .watch(
                variacionCumplimientoProvider((
                  area: team.area,
                  equipo: team.name,
                )),
              )
              .value,
          color: team.status.colores(context).texto,
        ),
        if (projection != null) proyeccionKpiCard(context, projection),
      ],
    );
  }

  String _formatHours(double value) => '${value.toStringAsFixed(1)} h';
}
