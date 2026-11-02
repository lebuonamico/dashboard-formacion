import 'package:collection/collection.dart';
import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';
import 'package:app_finnegans/features/time_entries/domain/time_entry_records_service.dart';

/// Builds an employee's profile for a period. Lives in compliance and not in
/// employees because compliance already depends on employees.
class EmployeeDetailService {
  final TimeEntryRecordsService records;
  final CompliancePeriodService periods;

  const EmployeeDetailService({
    required this.records,
    this.periods = const CompliancePeriodService(),
  });

  /// `null` when [employeeId] is not in [employees].
  EmployeeDetail? build({
    required String employeeId,
    required List<Employee> employees,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> certifications,
    required PeriodFilter period,
    required ComplianceService complianceService,
    required bool hasPeriodData,
  }) {
    final employee = employees
        .where((item) => item.employeeId == employeeId)
        .firstOrNull;
    if (employee == null) return null;

    final isAnnual = period.scope == PeriodScope.annual;
    final employeeTimeEntries = timeEntries
        .where((timeEntry) => timeEntry.employeeId == employeeId)
        .toList();
    final employeeCertifications = certifications
        .where((item) => item.employeeId == employeeId)
        .toList();
    final coursesByName = {
      for (final course in courses) normalizeKey(course.name): course,
    };

    final periodRecords = periods
        .filterTimeEntriesByPeriod(
          timeEntries: employeeTimeEntries,
          year: period.year,
          month: period.month,
          isAnnual: isAnnual,
        )
        .map(
          (timeEntry) => records.record(
            timeEntry,
            employee: employee,
            course: coursesByName[normalizeKey(timeEntry.courseName)],
          ),
        )
        .toList();

    // Every certification dated in the period is shown, completed or not.
    final periodCertifications = employeeCertifications.where((item) {
      final date = item.completedAt;
      if (date == null || date.year != period.year) return false;
      return isAnnual || date.month == period.month;
    }).toList()..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final certificationDetails = periodCertifications
        .map(
          (item) => CertificationDetail(
            certification: item,
            course: coursesByName[normalizeKey(item.courseName)],
          ),
        )
        .toList();

    // Completed in any period, so an entry from another month still shows it.
    final completedCourses = employeeCertifications
        .where((item) => item.isCompleted)
        .map((item) => normalizeKey(item.courseName))
        .toSet();

    return EmployeeDetail(
      employee: employee,
      compliance: periods.employeeCompliance(
        employee: employee,
        courses: courses,
        timeEntries: employeeTimeEntries,
        certifications: employeeCertifications,
        period: period,
        complianceService: complianceService,
      ),
      hasPeriodData: hasPeriodData,
      timeEntryGroups: _timeEntryGroups(periodRecords, completedCourses),
      certifications: certificationDetails,
      taughtCourses: _taughtCourses(periodRecords),
      crmHours: _hours(periodRecords),
      creditedLmsHours: certificationDetails
          .where((item) => item.certification.isCompleted)
          .fold(0, (total, item) => total + (item.course?.workloadHours ?? 0)),
    );
  }

  /// Grouped by catalog id, or by trimmed lowercase name without a catalog
  /// course.
  List<CourseTimeEntries> _timeEntryGroups(
    List<CrmTimeEntryRecord> periodRecords,
    Set<String> completedCourses,
  ) {
    final groups =
        groupBy(periodRecords, (CrmTimeEntryRecord record) {
          final courseId = record.course?.id.trim() ?? '';
          return courseId.isNotEmpty
              ? 'id:$courseId'
              : 'nombre:${_courseName(record).trim().toLowerCase()}';
        }).entries.toList()..sort(
          (a, b) =>
              _courseName(a.value.first).compareTo(_courseName(b.value.first)),
        );

    return groups.map((group) {
      final sorted = [...group.value]
        ..sort((a, b) => b.timeEntry.date.compareTo(a.timeEntry.date));
      final courseName = _courseName(sorted.first);
      return CourseTimeEntries(
        key: group.key,
        courseName: courseName,
        records: sorted,
        hours: _hours(sorted),
        isCompleted: completedCourses.contains(normalizeKey(courseName)),
      );
    }).toList();
  }

  /// Taught entries come from the CRM classification "Dictado de
  /// capacitaciones". Grouped by catalog or CRM id, or by normalized name
  /// without either.
  List<TaughtCourse> _taughtCourses(List<CrmTimeEntryRecord> periodRecords) {
    final taughtByCourse = groupBy(
      periodRecords.where((item) => item.isTaught),
      (item) {
        final courseId =
            item.course?.id.trim() ?? item.timeEntry.courseId?.trim();
        return courseId != null && courseId.isNotEmpty
            ? 'id:$courseId'
            : 'nombre:${normalizeKey(item.timeEntry.courseName)}';
      },
    );
    return taughtByCourse.values.map((items) {
      final first = items.first;
      final course = first.course;
      return TaughtCourse(
        code: course?.id ?? first.timeEntry.courseId ?? '',
        name: course?.name ?? first.timeEntry.courseName,
        area: course?.courseArea ?? first.timeEntry.courseDescription ?? '',
        hours: _hours(items),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  static String _courseName(CrmTimeEntryRecord record) =>
      record.course?.name ?? record.timeEntry.courseName;

  static double _hours(List<CrmTimeEntryRecord> items) =>
      items.fold(0, (total, item) => total + item.timeEntry.hours);
}
