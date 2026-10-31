import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

class DashboardTrendService {
  static const evolutionMonths = 4;

  final CompliancePeriodService periods;

  const DashboardTrendService({this.periods = const CompliancePeriodService()});

  List<CrmTimeEntry> timeEntriesInPeriod(
    List<CrmTimeEntry> timeEntries,
    PeriodFilter period,
  ) => periods.filterTimeEntriesByPeriod(
    timeEntries: timeEntries,
    year: period.year,
    month: period.month,
    isAnnual: period.scope == PeriodScope.annual,
  );

  /// 1 in the monthly view; in the annual one, the months with CRM or LMS
  /// records. Never 0, so it can divide the monthly pace.
  int evaluatedMonths({
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
  }) {
    if (period.scope == PeriodScope.monthly) return 1;
    final months = List.generate(
      12,
      (index) => DateTime(period.year, index + 1),
    ).where((month) => _hasData(timeEntries, certifications, month)).length;
    return months == 0 ? 1 : months;
  }

  /// The chosen month; in the annual view, the last month of the year with
  /// data, or December if none has.
  DateTime evolutionEndMonth({
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
  }) {
    if (period.scope == PeriodScope.monthly) {
      return DateTime(period.year, period.month);
    }
    return List.generate(12, (index) => DateTime(period.year, 12 - index))
            .where((month) => _hasData(timeEntries, certifications, month))
            .firstOrNull ??
        DateTime(period.year, 12);
  }

  /// The months that end in [evolutionEndMonth]. A month without records or
  /// without eligible employees counts 0 hours and 0 target.
  List<MonthlyHours> monthlyEvolution({
    required List<Employee> employees,
    List<EmployeeHistoryEntry>? history,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
    required ComplianceService complianceService,
    bool Function(Employee)? includeEmployee,
  }) {
    final end = evolutionEndMonth(
      timeEntries: timeEntries,
      certifications: certifications,
      period: period,
    );
    return List.generate(evolutionMonths, (index) {
      final month = DateTime(
        end.year,
        end.month - (evolutionMonths - 1 - index),
      );
      if (!_hasData(timeEntries, certifications, month)) {
        return MonthlyHours(month: month, hours: 0, target: 0);
      }
      final compliance = periods.calculateMonthlyCompliance(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        year: month.year,
        month: month.month,
        complianceService: complianceService,
        includeEmployee: includeEmployee,
      );
      if (compliance.isEmpty) {
        return MonthlyHours(month: month, hours: 0, target: 0);
      }
      double average(double Function(EmployeeCompliance item) hours) =>
          compliance.fold(0.0, (total, item) => total + hours(item)) /
          compliance.length;
      return MonthlyHours(
        month: month,
        hours: average((item) => item.totalCreditedHours),
        target: average((item) => item.totalRequiredHours),
      );
    });
  }

  bool _hasData(
    List<CrmTimeEntry> timeEntries,
    List<LmsCertification> certifications,
    DateTime month,
  ) => periods.hasDataInPeriod(
    timeEntries: timeEntries,
    certifications: certifications,
    year: month.year,
    month: month.month,
    isAnnual: false,
  );
}
