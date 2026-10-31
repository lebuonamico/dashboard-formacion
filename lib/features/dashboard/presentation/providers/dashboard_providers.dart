import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';

final dashboardTimeEntriesProvider = FutureProvider<List<CrmTimeEntry>>((
  ref,
) async {
  final scope = ref.watch(periodFilterProvider).scope;
  final month = ref.watch(periodFilterProvider).month;
  final year = ref.watch(periodFilterProvider).year;

  final from = DateTime(year, scope == PeriodScope.annual ? 1 : month);
  final until = scope == PeriodScope.annual
      ? DateTime(year + 1)
      : DateTime(year, month + 1);
  // Las horas ya están en memoria (con el alcance del usuario): cambiar el
  // período filtra, no vuelve a consultar la base.
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  return timeEntries
      .where(
        (timeEntry) =>
            !timeEntry.date.isBefore(from) && timeEntry.date.isBefore(until),
      )
      .toList();
});

/// Misma base que Equipos y Áreas: nómina elegible del período,
/// certificaciones finalizadas en el período y, en el anual, la suma de los
/// meses con datos contra sus objetivos mensuales. Así los KPIs del Dashboard
/// coinciden con los de las otras pantallas.
final dashboardComplianceProvider = FutureProvider<List<EmployeeCompliance>>((
  ref,
) {
  return ref.watch(teamComplianceProvider.future);
});

/// Meses que se evaluaron en el período: 1 en el mensual; en el anual, los
/// meses con registros CRM o LMS, igual que el acumulado de Equipos.
final dashboardEvaluatedMonthsProvider = FutureProvider<int>((ref) async {
  if (ref.watch(periodFilterProvider).scope == PeriodScope.monthly) return 1;

  final year = ref.watch(periodFilterProvider).year;
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final teamsService = ref.read(teamsServiceProvider);
  var months = 0;
  for (var month = 1; month <= 12; month++) {
    if (teamsService.periods.hasDataInPeriod(
      timeEntries: timeEntries,
      certifications: certifications,
      year: year,
      month: month,
      isAnnual: false,
    )) {
      months++;
    }
  }
  // Nunca 0, para poder dividir el ritmo mensual.
  return months == 0 ? 1 : months;
});

/// Horas válidas promedio por colaborador elegible en los 4 meses que terminan
/// en el período elegido (en el anual, el último mes del año con datos).
final dashboardMonthlyEvolutionProvider =
    FutureProvider<List<({DateTime month, double hours})>>((ref) async {
      final scope = ref.watch(periodFilterProvider).scope;
      final chosenMonth = ref.watch(periodFilterProvider).month;
      final year = ref.watch(periodFilterProvider).year;
      final employees = await ref.watch(employeesProvider.future);
      final history = await ref.watch(employeeHistoryProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final userScope = await ref.watch(userScopeProvider.future);
      final include = ref
          .watch(userScopeServiceProvider)
          .employeeFilter(userScope);
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final teamsService = ref.read(teamsServiceProvider);

      bool hasData(DateTime date) => teamsService.periods.hasDataInPeriod(
        timeEntries: timeEntries,
        certifications: certifications,
        year: date.year,
        month: date.month,
        isAnnual: false,
      );

      var finalMonth = DateTime(year, chosenMonth);
      if (scope == PeriodScope.annual) {
        finalMonth = DateTime(year, 12);
        while (finalMonth.month > 1 && !hasData(finalMonth)) {
          finalMonth = DateTime(year, finalMonth.month - 1);
        }
        if (!hasData(finalMonth)) finalMonth = DateTime(year, 12);
      }

      return [
        for (var offset = 3; offset >= 0; offset--)
          (() {
            final date = DateTime(finalMonth.year, finalMonth.month - offset);
            if (!hasData(date)) return (month: date, hours: 0.0);
            final complianceList = teamsService.periods
                .calculateMonthlyCompliance(
                  employees: employees,
                  history: history,
                  courses: courses,
                  timeEntries: timeEntries,
                  certifications: certifications,
                  year: date.year,
                  month: date.month,
                  complianceService: complianceService,
                  includeEmployee: include,
                );
            if (complianceList.isEmpty) return (month: date, hours: 0.0);
            final total = complianceList.fold<double>(
              0,
              (t, item) => t + item.totalCreditedHours,
            );
            return (month: date, hours: total / complianceList.length);
          })(),
      ];
    });

final globalComplianceProvider = FutureProvider<List<EmployeeCompliance>>((
  ref,
) async {
  final employees = await ref.watch(employeesProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  final service = await ref.watch(complianceServiceProvider.future);

  return service.calculateComplianceGlobal(
    employees: employees,
    courses: courses,
    timeEntries: timeEntries,
    lmsCertifications: certifications,
  );
});
