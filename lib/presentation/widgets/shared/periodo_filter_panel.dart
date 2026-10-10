import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_period_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selector de período conectado a los providers globales.
/// Cualquier pantalla que lo use comparte el mismo período.
class PeriodoFilterPanel extends ConsumerWidget {
  const PeriodoFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final aniosDisponibles = ref
        .watch(aniosEquipoDisponiblesProvider)
        .maybeWhen(data: (anios) => anios, orElse: () => [anio]);

    return EquiposPeriodControls(
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
  }
}
