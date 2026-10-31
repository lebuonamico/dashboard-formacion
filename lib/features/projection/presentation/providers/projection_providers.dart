import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

export 'package:app_finnegans/features/projection/domain/projection.dart';
export 'package:app_finnegans/features/projection/domain/projection_service.dart';

final projectionServiceProvider = Provider<ProjectionService>(
  (ref) => ProjectionService(periods: ref.watch(teamsServiceProvider).periods),
);

/// Mes en el que se corta la proyección: el elegido en el mensual; en el
/// anual, el último mes del año con datos. `null` si el año no tiene datos.
final annualProjectionCutoffMonthProvider = FutureProvider<int?>((ref) async {
  final year = ref.watch(periodFilterProvider).year;
  if (ref.watch(periodFilterProvider).scope == PeriodScope.monthly) {
    return ref.watch(periodFilterProvider).month;
  }
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return ref
      .watch(teamsServiceProvider)
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

      final year = ref.watch(periodFilterProvider).year;
      final employees = await ref.watch(employeesProvider.future);
      final history = await ref.watch(employeeHistoryProvider.future);
      final courses = await ref.watch(coursesProvider.future);
      final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
      final certifications = await ref.watch(lmsCertificationsProvider.future);
      final complianceService = await ref.watch(
        complianceServiceProvider.future,
      );
      final userScope = await ref.watch(userScopeProvider.future);
      final include = ref
          .watch(userScopeServiceProvider)
          .employeeFilter(userScope);
      final teamsService = ref.watch(teamsServiceProvider);

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
        return ref
            .watch(projectionServiceProvider)
            .variation(
              byMonth: await ref.watch(complianceByMonthProvider.future),
              cutoffMonth: cutoffMonth,
              area: section.area,
              team: section.team,
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
      return ref
          .watch(projectionServiceProvider)
          .projectEmployee(
            own: byMonth.map(
              (month, items) => MapEntry(
                month,
                items
                    .where((item) => item.employee.employeeId == employeeId)
                    .toList(),
              ),
            ),
            cutoffMonth: cutoffMonth,
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
      return ref
          .watch(projectionServiceProvider)
          .calculateForSection(
            byMonth: await ref.watch(complianceByMonthProvider.future),
            cutoffMonth: cutoffMonth,
            area: section.area,
            team: section.team,
          );
    });
