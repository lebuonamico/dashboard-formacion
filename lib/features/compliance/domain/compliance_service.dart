import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';
import 'package:collection/collection.dart';

/// The triangular rule: the CRM brings the hours, the LMS confirms the
/// completion and the catalog sets the ceiling. Exploration and Teaching are
/// credited by the CRM alone.
class ComplianceService {
  /// Without versions the default plan applies.
  final TrainingPlanHistory plans;
  final TrainingPlanService planService;
  final CourseClassificationService classification;
  final EmployeeComplianceService summary;

  /// Called for every entry and certification over a few distinct names:
  /// each name is normalized once.
  final _courseKeys = <String, String>{};

  ComplianceService({
    this.plans = const TrainingPlanHistory.empty(),
    this.planService = const TrainingPlanService(),
    this.summary = const EmployeeComplianceService(),
    CourseClassificationService? classification,
  }) : classification = classification ?? CourseClassificationService();

  /// [year] and [month] pick the plan version that sets the target. Without
  /// a period the version in effect today applies.
  List<EmployeeCompliance> calculateComplianceGlobal({
    required List<Employee> employees,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> lmsCertifications,
    int? year,
    int? month,
  }) {
    assert((year == null) == (month == null), 'anio y mes van juntos');
    final plan = year != null && month != null
        ? planService.currentIn(plans, year, month)
        : planService.current(plans);
    final catalog = {
      for (final course in courses) _courseKey(course.name): course,
    };
    final entriesByEmployee = groupBy(
      timeEntries,
      (CrmTimeEntry entry) => entry.employeeId,
    );
    final certificationsByEmployee = groupBy(
      lmsCertifications,
      (LmsCertification certification) => certification.employeeId,
    );

    return employees.map((employee) {
      final entries =
          entriesByEmployee[employee.employeeId] ?? const <CrmTimeEntry>[];
      final completedCourses =
          (certificationsByEmployee[employee.employeeId] ??
                  const <LmsCertification>[])
              .where((certification) => certification.isCompleted)
              .map((certification) => _courseKey(certification.courseName))
              .toSet()
              .map((key) => catalog[key])
              .whereType<Course>()
              .where((course) => classification.lmsCategory(course) != null);

      return summary.summarize(
        employee: employee,
        creditedHours: _hoursByCategory([
          for (final entry in entries)
            (classification.crmOnlyCategory(entry), entry.hours),
          for (final course in completedCourses)
            (
              course.category,
              course.workloadHours < 0 ? 0.0 : course.workloadHours,
            ),
        ]),
        declaredHours: _hoursByCategory([
          for (final entry in entries)
            (
              classification.crmOnlyCategory(entry) ??
                  catalog[_courseKey(entry.courseName)]?.category,
              entry.hours,
            ),
        ]),
        requiredHours: Map.of(plan.hours[employee.seniority]!),
      );
    }).toList();
  }

  /// The year target: the 12 months, each with its plan version.
  Map<CourseCategory, double> requiredForYear(Seniority seniority, int year) =>
      planService.requiredForYear(plans, seniority, year);

  String _courseKey(String name) => _courseKeys[name] ??= normalizeKey(name);

  static Map<CourseCategory, double> _hoursByCategory(
    Iterable<(CourseCategory?, double)> items,
  ) => items.fold(
    {for (final category in CourseCategory.values) category: 0.0},
    (totals, item) => switch (item) {
      (final CourseCategory category, final hours) =>
        totals..[category] = totals[category]! + hours,
      _ => totals,
    },
  );
}
