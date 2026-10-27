import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';
import 'package:flutter/material.dart';

/// Indicadores de todos los equipos, con las mismas cards que el inicio.
class EquiposKpiSection extends StatelessWidget {
  final int totalEquipos;
  final int totalColaboradores;
  final double horasRealizadas;
  final double horasObjetivo;
  final double desvioHoras;
  final double cumplimientoGlobal;
  final bool esAnual;
  final int anio;
  final int mes;

  /// Variación del cumplimiento contra el mes anterior.
  final VariacionCumplimiento? variacion;

  /// Proyección a fin de año de todos los equipos; sin ella no se muestra la
  /// card.
  final ProyeccionAnual? proyeccion;

  const EquiposKpiSection({
    super.key,
    required this.totalEquipos,
    required this.totalColaboradores,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.desvioHoras,
    required this.cumplimientoGlobal,
    required this.anio,
    required this.mes,
    this.esAnual = false,
    this.variacion,
    this.proyeccion,
  });

  @override
  Widget build(BuildContext context) {
    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'EQUIPOS ACTIVOS',
          value: '$totalEquipos',
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
          value: '$totalColaboradores',
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
          esAnual: esAnual,
          anio: anio,
          mes: mes,
          horas: horasRealizadas,
          objetivo: horasObjetivo,
        ),
        cumplimientoKpiCard(
          context,
          esAnual: esAnual,
          anio: anio,
          mes: mes,
          porcentaje: cumplimientoGlobal,
          variacion: variacion,
        ),
        if (proyeccion case final proyeccion?)
          proyeccionKpiCard(context, proyeccion),
      ],
    );
  }
}
