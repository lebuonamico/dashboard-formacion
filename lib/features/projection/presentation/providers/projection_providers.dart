import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/projection/domain/projection_service.dart';

/// Mes en el que se corta la proyección: el elegido en el mensual; en el
/// anual, el último mes del año con datos. `null` si el año no tiene datos.
final annualProjectionCutoffMonthProvider = FutureProvider<int?>((ref) async {
  final year = ref.watch(periodYearFilterProvider);
  if (ref.watch(periodScopeProvider) == PeriodScope.monthly) {
    return ref.watch(periodMonthFilterProvider);
  }
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return ref
      .read(teamsServiceProvider)
      .periods
      .lastMonthWithData(
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
      );
});

/// Cumplimiento de cada mes con datos de enero al mes de corte, con la misma
/// nómina elegible y alcance del usuario que Equipos y Áreas. Lo comparten
/// todas las secciones; cada una filtra sus colaboradores.
final complianceByMonthProvider =
    FutureProvider<Map<int, List<EmployeeCompliance>>>((ref) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return {};

      final year = ref.watch(periodYearFilterProvider);
      final employees = await ref.watch(employeesProvider.future);
      final history = await ref.watch(employeeHistoryProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final userScope = await ref.watch(userScopeProvider.future);
      final include = userScope.isTotal ? null : userScope.includesEmployee;
      final teamsService = ref.read(teamsServiceProvider);

      return teamsService.periods.calculateComplianceByMonth(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        throughMonth: cutoffMonth,
        complianceService: complianceService,
        includeEmployee: include,
      );
    });

/// Cuánto cambió el cumplimiento de una sección contra el mes anterior.
class ComplianceVariation {
  /// Anual: puntos que subió o bajó el acumulado del año contra el acumulado
  /// hasta el mes con datos anterior. `null` si no hay mes anterior.
  final double? points;

  /// Mensual: horas por persona del mes de corte, con el tope mensual.
  final double hoursPerPerson;

  /// Horas por persona del mes anterior; `null` si ese mes no tiene datos.
  final double? previousHoursPerPerson;

  const ComplianceVariation({
    required this.points,
    required this.hoursPerPerson,
    required this.previousHoursPerPerson,
  });

  double? get hours => previousHoursPerPerson == null
      ? null
      : hoursPerPerson - previousHoursPerPerson!;
}

/// Variación del cumplimiento de una sección: `(area: null, team: null)` es
/// toda la nómina visible. Cada mes se filtra con dónde estaba cada
/// colaborador ese mes, igual que el cumplimiento de Áreas y Equipos, y se
/// acumula con el mismo cálculo que el anual.
final complianceVariationProvider =
    FutureProvider.family<ComplianceVariation?, ({String? area, String? team})>(
      (ref, section) async {
        final cutoffMonth = await ref.watch(
          annualProjectionCutoffMonthProvider.future,
        );
        if (cutoffMonth == null) return null;
        final byMonth = await ref.watch(complianceByMonthProvider.future);
        final teamsService = ref.read(teamsServiceProvider);

        final all = section.area == null && section.team == null;
        final filtered = {
          for (final entry in byMonth.entries)
            entry.key: all
                ? entry.value
                : entry.value
                      .where(
                        (item) => teamsService.periods.belongsToTeam(
                          item.employee,
                          area: section.area,
                          team: section.team,
                        ),
                      )
                      .toList(),
        };

        double percentage(int until) {
          final accumulated = teamsService.periods.accumulateMonths([
            for (final entry in filtered.entries)
              if (entry.key <= until) entry.value,
          ]);
          final hours = accumulated.fold<double>(
            0,
            (t, c) => t + c.totalCreditedHours,
          );
          final target = accumulated.fold<double>(
            0,
            (t, c) => t + c.totalRequiredHours,
          );
          return target == 0 ? 0 : hours / target * 100;
        }

        double? hoursPerPerson(int month) {
          final items = filtered[month];
          if (items == null || items.isEmpty) return null;
          return items.fold<double>(0, (t, c) => t + c.totalCreditedHours) /
              items.length;
        }

        final current = hoursPerPerson(cutoffMonth);
        if (current == null) return null;
        final previous =
            filtered.entries
                .where((e) => e.key < cutoffMonth && e.value.isNotEmpty)
                .map((e) => e.key)
                .toList()
              ..sort();
        return ComplianceVariation(
          points: previous.isEmpty
              ? null
              : percentage(cutoffMonth) - percentage(previous.last),
          hoursPerPerson: current,
          previousHoursPerPerson: hoursPerPerson(cutoffMonth - 1),
        );
      },
    );

/// Proyección de un colaborador por categoría, para su pantalla de detalle.
/// `null` si no está en la nómina elegible del mes de corte.
final employeeProjectionProvider =
    FutureProvider.family<EmployeeProjection?, String>((ref, employeeId) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return null;
      final byMonth = await ref.watch(complianceByMonthProvider.future);
      final own = {
        for (final entry in byMonth.entries)
          entry.key: entry.value
              .where((item) => item.employee.employeeId == employeeId)
              .toList(),
      };
      const service = ProjectionService();
      final current = service
          .projectEmployees(byMonth: own, cutoffMonth: cutoffMonth)
          .firstOrNull;
      if (current == null) return null;

      // La misma proyección cortada en el mes anterior en el que estuvo.
      final previous =
          own.entries
              .where((e) => e.key < cutoffMonth && e.value.isNotEmpty)
              .map((e) => e.key)
              .toList()
            ..sort();
      if (previous.isEmpty) return current;
      final preview = service
          .projectEmployees(byMonth: own, cutoffMonth: previous.last)
          .firstOrNull;
      return EmployeeProjection(
        employeeId: current.employeeId,
        cutoffMonth: current.cutoffMonth,
        categories: current.categories,
        previousPercentage: preview?.percentage,
      );
    });

/// Proyección de una sección: `(area: null, team: null)` es toda la nómina
/// visible; con área, solo esa área; con área y equipo, solo ese equipo.
final annualProjectionProvider =
    FutureProvider.family<AnnualProjection?, ({String? area, String? team})>((
      ref,
      section,
    ) async {
      final cutoffMonth = await ref.watch(
        annualProjectionCutoffMonthProvider.future,
      );
      if (cutoffMonth == null) return null;
      final byMonth = await ref.watch(complianceByMonthProvider.future);
      final teamsService = ref.read(teamsServiceProvider);

      // La sección se define por dónde está cada colaborador en el mes de
      // corte; de ellos se toma todo el historial del año, aunque antes
      // estuvieran en otro equipo.
      Map<int, List<EmployeeCompliance>> filtered = byMonth;
      if (section.area != null || section.team != null) {
        final employeeIds = {
          for (final item
              in byMonth[cutoffMonth] ?? const <EmployeeCompliance>[])
            if (teamsService.periods.belongsToTeam(
              item.employee,
              area: section.area,
              team: section.team,
            ))
              item.employee.employeeId,
        };
        filtered = {
          for (final entry in byMonth.entries)
            entry.key: entry.value
                .where((item) => employeeIds.contains(item.employee.employeeId))
                .toList(),
        };
      }
      return const ProjectionService().calculate(
        byMonth: filtered,
        cutoffMonth: cutoffMonth,
      );
    });
