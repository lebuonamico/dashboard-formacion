import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/core/widgets/kpi_card.dart';

class DashboardKpiGrid extends StatelessWidget {
  final AsyncValue<List<EmployeeCompliance>> complianceListAsync;
  final AsyncValue<List<CrmTimeEntry>> timeEntriesAsync;
  final AsyncValue<List<AreaComplianceViewModel>> areasAsync;
  final AsyncValue<List<TeamOverview>> teamsAsync;
  final PeriodScope scope;
  final int selectedMonth;
  final int selectedYear;

  /// Meses evaluados en el período: 1 en el mensual, los meses con datos en
  /// el anual. Sirve para pasar las horas del período a un ritmo mensual.
  final int evaluatedMonths;

  /// Proyección a fin de año de toda la nómina visible.
  final AsyncValue<AnnualProjection?> projectionAsync;

  /// Variación del cumplimiento de toda la nómina contra el mes anterior.
  final AsyncValue<ComplianceVariation?> variationAsync;

  const DashboardKpiGrid({
    super.key,
    required this.complianceListAsync,
    required this.timeEntriesAsync,
    required this.areasAsync,
    required this.teamsAsync,
    required this.scope,
    required this.selectedMonth,
    required this.selectedYear,
    this.evaluatedMonths = 1,
    this.projectionAsync = const AsyncData(null),
    this.variationAsync = const AsyncData(null),
  });

  @override
  Widget build(BuildContext context) {
    if (complianceListAsync.isLoading ||
        timeEntriesAsync.isLoading ||
        areasAsync.isLoading ||
        teamsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final asyncValues = [
      complianceListAsync,
      timeEntriesAsync,
      areasAsync,
      teamsAsync,
    ];
    final error = asyncValues.where((value) => value.hasError).firstOrNull;
    if (error != null) {
      return ErrorDataState(
        title: 'No pudimos cargar esta sección',
        error: error.error!,
        compact: true,
      );
    }

    final complianceList = complianceListAsync.value ?? [];
    final timeEntries = timeEntriesAsync.value ?? [];
    final areas = areasAsync.value ?? [];
    final teams = teamsAsync.value ?? [];
    if (complianceList.isEmpty) return const SizedBox.shrink();

    final kpis = DashboardKpisService().calculate(
      complianceList: complianceList,
      timeEntries: timeEntries,
      evaluatedMonths: evaluatedMonths,
    );
    final totalEmployees = kpis.employees;
    final completedHours = kpis.creditedHours;
    final employeesWhoTookCourse = kpis.training;
    final periodGoal = kpis.targetHours;
    // Mientras carga, o si el año no tiene datos, no se muestra su card.
    final projection = projectionAsync.value;
    final isAnnual = scope == PeriodScope.annual;
    final periodLabel = isAnnual
        ? 'AÑO $selectedYear'
        : '${monthName(selectedMonth).toUpperCase()} $selectedYear';

    return KpiCardRow(
      cards: [
        DashboardKpiCard(
          title: 'COLABORADORES',
          value: '$totalEmployees',
          suffix: ' nómina activa',
          progress: 1,
          progressLabel: '${areas.length} áreas',
          footer: '${teams.length} equipos',
          icon: Icons.groups_outlined,
          color: context.colorScheme.primary,
          help: '$eligiblePayrollHelp Abajo, cuántas áreas y equipos abarcan.',
        ),
        DashboardKpiCard(
          title: 'COLABORADORES CAPACITÁNDOSE',
          value: '$employeesWhoTookCourse',
          suffix: ' de $totalEmployees',
          progress: (employeesWhoTookCourse / totalEmployees).clamp(0.0, 1.0),
          progressLabel:
              '${(employeesWhoTookCourse / totalEmployees * 100).toStringAsFixed(0)}% de la nómina',
          footer:
              '${totalEmployees - employeesWhoTookCourse} sin cursos tomados',
          icon: Icons.school_outlined,
          color: context.colors.success.text,
          help:
              'Colaboradores elegibles con al menos una carga de horas en el '
              'CRM en el período, sin contar las horas que dictaron. No indica '
              'si cumplieron el objetivo.',
        ),
        // Solo las horas que suman al objetivo de cumplimiento del período.
        DashboardKpiCard(
          title: 'HORAS VÁLIDAS · $periodLabel',
          value: '${completedHours.toStringAsFixed(1)} h',
          suffix: 'para el objetivo',
          progress: periodGoal == 0
              ? 0
              : (completedHours / periodGoal).clamp(0.0, 1.0),
          progressLabel: 'Meta: ${periodGoal.toStringAsFixed(0)} h',
          footer:
              '${(periodGoal - completedHours).clamp(0, double.infinity).toStringAsFixed(1)} h para la meta',
          icon: Icons.schedule_outlined,
          color: context.colorScheme.primary,
          help: isAnnual ? annualCreditedHoursHelp : monthCreditedHoursHelp,
        ),
        complianceKpiCard(
          context,
          isAnnual: isAnnual,
          year: selectedYear,
          month: selectedMonth,
          percentage: kpis.compliance,
          variation: variationAsync.value,
        ),
        if (projection != null) projectionKpiCard(context, projection),
      ],
    );
  }
}
