import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';

class TeamsKpiSection extends StatelessWidget {
  final int teamCount;
  final int employeeCount;
  final double completedHours;
  final double targetHours;
  final double overallCompletion;
  final bool isAnnual;
  final int year;
  final int month;

  final VariacionCumplimiento? variation;

  final ProyeccionAnual? projection;

  const TeamsKpiSection({
    super.key,
    required this.teamCount,
    required this.employeeCount,
    required this.completedHours,
    required this.targetHours,
    required this.overallCompletion,
    required this.year,
    required this.month,
    this.isAnnual = false,
    this.variation,
    this.projection,
  });

  @override
  Widget build(BuildContext context) {
    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'EQUIPOS ACTIVOS',
          value: '$teamCount',
          suffix: 'en seguimiento',
          progress: 1,
          progressLabel: 'Con colaboradores elegibles',
          footer: '',
          icon: Icons.groups_outlined,
          color: context.colorScheme.primary,
          ayuda:
              'Equipos con al menos un colaborador elegible en el período '
              'elegido.',
        ),
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$employeeCount',
          suffix: 'en todos los equipos',
          progress: 1,
          progressLabel: 'Nómina elegible',
          footer: '',
          icon: Icons.people_outline,
          color: context.colores.acentoCian,
          ayuda: ayudaNominaElegible,
        ),
        horasValidasKpiCard(
          context,
          esAnual: isAnnual,
          anio: year,
          mes: month,
          horas: completedHours,
          objetivo: targetHours,
        ),
        cumplimientoKpiCard(
          context,
          esAnual: isAnnual,
          anio: year,
          mes: month,
          porcentaje: overallCompletion,
          variacion: variation,
        ),
        if (projection case final projection?)
          proyeccionKpiCard(context, projection),
      ],
    );
  }
}
