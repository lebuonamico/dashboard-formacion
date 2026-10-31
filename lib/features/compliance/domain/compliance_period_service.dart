import 'package:collection/collection.dart';
import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/teams/domain/team_identity.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';

class CompliancePeriodService {
  final EmployeeHistoryService historyService;
  final EmployeeComplianceService summary;

  const CompliancePeriodService({
    this.historyService = const EmployeeHistoryService(),
    this.summary = const EmployeeComplianceService(),
  });

  bool hasDataInPeriod({
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    bool isInPeriod(DateTime date) =>
        date.year == year && (isAnnual || date.month == month);

    return timeEntries.any((entry) => isInPeriod(entry.date)) ||
        certifications.any((certification) {
          final date = certification.completedAt;
          return date != null && isInPeriod(date);
        });
  }

  List<CrmTimeEntry> filterTimeEntriesByPeriod({
    required List<CrmTimeEntry> timeEntries,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    return timeEntries.where((entry) {
      final matchesYear = entry.date.year == year;
      if (isAnnual) return matchesYear;

      return matchesYear && entry.date.month == month;
    }).toList();
  }

  List<LmsCertification> filterCertificationsByPeriod({
    required List<LmsCertification> certifications,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    return certifications.where((certification) {
      final date = certification.completedAt;
      if (!certification.isCompleted || date == null || date.year != year) {
        return false;
      }
      return isAnnual || date.month == month;
    }).toList();
  }

  List<Employee> filterEmployeesByPeriod({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required int year,
    required int month,
    required bool isAnnual,
    bool Function(Employee)? includeEmployee,
  }) {
    final nextPeriodStart = DateTime(year, isAnnual ? 13 : month + 1);
    final lastDay = DateTime(year, isAnnual ? 13 : month + 1, 0);
    final historyByEmployeeId = groupBy(
      history ?? const <EmployeeHistoryEntry>[],
      (entry) => entry.employeeId,
    );
    bool included(Employee employee) => includeEmployee?.call(employee) ?? true;

    Employee? eligible(Employee employee) {
      final employmentStart = employee.hireDate;
      if (employmentStart == null) return null;
      final employmentStartDate = DateTime(
        employmentStart.year,
        employmentStart.month,
        employmentStart.day,
      );
      if (employmentStartDate.isAfter(lastDay)) return null;
      if (history == null) {
        return employee.isActive && included(employee) ? employee : null;
      }

      final effectiveEntry =
          historyService.effectiveAt(
            historyByEmployeeId[employee.employeeId] ?? const [],
            nextPeriodStart,
          ) ??
          (throw StateError(
            'El historial del colaborador ${employee.employeeId} no tiene una '
            'vigencia única al cierre de $month/$year.',
          ));
      if (!effectiveEntry.isActive) return null;
      final historicalEmployee = historyService.rebuild(
        effectiveEntry,
        employee,
      );
      return included(historicalEmployee) ? historicalEmployee : null;
    }

    return employees.map(eligible).nonNulls.toList();
  }

  int? lastMonthWithData({
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required int year,
  }) {
    return List.generate(12, (index) => 12 - index).firstWhereOrNull(
      (month) => hasDataInPeriod(
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        month: month,
        isAnnual: false,
      ),
    );
  }

  List<EmployeeCompliance> calculateMonthlyCompliance({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required int year,
    required int month,
    required ComplianceService complianceService,
    bool Function(Employee)? includeEmployee,
  }) {
    return complianceService.calculateComplianceGlobal(
      employees: filterEmployeesByPeriod(
        employees: employees,
        history: history,
        year: year,
        month: month,
        isAnnual: false,
        includeEmployee: includeEmployee,
      ),
      courses: courses,
      timeEntries: filterTimeEntriesByPeriod(
        timeEntries: timeEntries,
        year: year,
        month: month,
        isAnnual: false,
      ),
      lmsCertifications: filterCertificationsByPeriod(
        certifications: certifications,
        year: year,
        month: month,
        isAnnual: false,
      ),
      // The target uses the training plan in effect for the evaluated month.
      year: year,
      month: month,
    );
  }

  List<EmployeeCompliance> calculateAnnualCompliance({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required int year,
    required ComplianceService complianceService,
    bool Function(Employee)? includeEmployee,
  }) {
    return accumulateMonths(
      calculateComplianceByMonth(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        complianceService: complianceService,
        includeEmployee: includeEmployee,
      ).values,
    );
  }

  /// The compliance shown by Teams, Areas and the Dashboard: monthly, or the
  /// sum of the months with data of the year.
  List<EmployeeCompliance> calculateForPeriod({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
    required ComplianceService complianceService,
    bool Function(Employee)? includeEmployee,
  }) => period.scope == PeriodScope.annual
      ? calculateAnnualCompliance(
          employees: employees,
          history: history,
          courses: courses,
          timeEntries: timeEntries,
          certifications: certifications,
          year: period.year,
          complianceService: complianceService,
          includeEmployee: includeEmployee,
        )
      : calculateMonthlyCompliance(
          employees: employees,
          history: history,
          courses: courses,
          timeEntries: timeEntries,
          certifications: certifications,
          year: period.year,
          month: period.month,
          complianceService: complianceService,
          includeEmployee: includeEmployee,
        );

  /// The profile of one employee, with their current payroll attributes and
  /// no eligibility check. The annual target adds the 12 months, each with its
  /// plan version.
  EmployeeCompliance employeeCompliance({
    required Employee employee,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
    required ComplianceService complianceService,
  }) {
    final isAnnual = period.scope == PeriodScope.annual;
    final compliance = complianceService
        .calculateComplianceGlobal(
          employees: [employee],
          courses: courses,
          timeEntries: filterTimeEntriesByPeriod(
            timeEntries: timeEntries
                .where((entry) => entry.employeeId == employee.employeeId)
                .toList(),
            year: period.year,
            month: period.month,
            isAnnual: isAnnual,
          ),
          lmsCertifications: filterCertificationsByPeriod(
            certifications: certifications
                .where((item) => item.employeeId == employee.employeeId)
                .toList(),
            year: period.year,
            month: period.month,
            isAnnual: isAnnual,
          ),
          year: period.year,
          month: period.month,
        )
        .first;
    if (!isAnnual) return compliance;
    return complianceService.summary.summarize(
      employee: compliance.employee,
      creditedHours: compliance.creditedHours,
      declaredHours: compliance.declaredHours,
      requiredHours: complianceService.requiredForYear(
        employee.seniority,
        period.year,
      ),
    );
  }

  Map<int, List<EmployeeCompliance>> calculateComplianceByMonth({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required int year,
    int throughMonth = 12,
    required ComplianceService complianceService,
    bool Function(Employee)? includeEmployee,
  }) {
    final timeEntriesByMonth = groupBy(
      timeEntries.where((entry) => entry.date.year == year),
      (entry) => entry.date.month,
    );
    final certificationsByMonth = groupBy(
      certifications.where(
        (certification) => certification.completedAt?.year == year,
      ),
      (certification) => certification.completedAt!.month,
    );
    return {
      for (var month = 1; month <= throughMonth; month++)
        // Only months with CRM or LMS records contribute to annual compliance.
        if (timeEntriesByMonth.containsKey(month) ||
            certificationsByMonth.containsKey(month))
          month: calculateMonthlyCompliance(
            employees: employees,
            history: history,
            courses: courses,
            timeEntries: timeEntriesByMonth[month] ?? const [],
            certifications: certificationsByMonth[month] ?? const [],
            year: year,
            month: month,
            complianceService: complianceService,
            includeEmployee: includeEmployee,
          ),
    };
  }

  List<EmployeeCompliance> accumulateMonths(
    Iterable<List<EmployeeCompliance>> months,
  ) {
    final accumulated = months.expand((month) => month).fold(
      <String, EmployeeCompliance>{},
      (accumulated, monthly) {
        final employee = monthly.employee;
        final key =
            '${employee.employeeId}::${employee.area}::'
            '${normalizeTeamName(employee.team)}';
        final previous = accumulated[key];
        accumulated[key] = summary.summarize(
          employee: monthly.employee,
          creditedHours: {
            for (final category in CourseCategory.values)
              // Annual hours compensate across months within the same category.
              // Only required months contribute; the accumulated target sets the cap.
              category:
                  (previous?.creditedHours[category] ?? 0) +
                  ((monthly.requiredHours[category] ?? 0) > 0
                      ? monthly.creditedHours[category] ?? 0
                      : 0),
          },
          declaredHours: {
            for (final category in CourseCategory.values)
              category:
                  (previous?.declaredHours[category] ?? 0) +
                  (monthly.declaredHours[category] ?? 0),
          },
          requiredHours: {
            for (final category in CourseCategory.values)
              category:
                  (previous?.requiredHours[category] ?? 0) +
                  (monthly.requiredHours[category] ?? 0),
          },
        );
        return accumulated;
      },
    );

    return accumulated.values.toList();
  }

  bool belongsToTeam(Employee employee, {String? area, String? team}) {
    if (area != null && normalizeLoose(employee.area) != normalizeLoose(area)) {
      return false;
    }
    return team == null ||
        normalizeLoose(normalizeTeamName(employee.team)) ==
            normalizeLoose(normalizeTeamName(team));
  }
}
