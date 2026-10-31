import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:collection/collection.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourses();
});

class CourseViewModel {
  final Course course;
  final String instructorName;

  /// Colaboradores distintos que cargaron horas del curso en el CRM (en un
  /// curso de dictado, quienes lo dictaron).
  final int people;

  /// Horas cargadas en el CRM para el curso.
  final double crmHours;

  /// Colaboradores distintos con la finalización del curso en el LMS.
  final int completed;

  CourseViewModel({
    required this.course,
    required this.instructorName,
    this.people = 0,
    this.crmHours = 0,
    this.completed = 0,
  });

  /// `null` si nadie cargó horas del curso.
  double? get averageHoursPerPerson => people == 0 ? null : crmHours / people;
}

final courseStatsPeriodProvider = OptionalPeriodProvider(
  OptionalPeriodNotifier.new,
);

final availableCourseYearsProvider = FutureProvider<List<int>>((ref) async {
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);
  return {
    ...timeEntries.map((timeEntry) => timeEntry.date.year),
    ...certifications
        .map((certification) => certification.completedAt?.year)
        .whereType<int>(),
  }.toList()..sort((a, b) => b.compareTo(a));
});

/// Course id for each normalized course name. Ambiguous names map to an
/// empty id, so a filter never picks one of two homonyms at random.
final courseIdsByNameProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final courses = await ref.watch(coursesProvider.future);
  final idsByName = <String, Set<String>>{};
  for (final course in courses) {
    final name = ComplianceService.normalizeCourseName(course.name);
    final id = course.id.trim();
    if (name.isNotEmpty && id.isNotEmpty) {
      idsByName.putIfAbsent(name, () => {}).add(id);
    }
  }
  return Map.unmodifiable({
    for (final MapEntry(key: name, value: ids) in idsByName.entries)
      name: ids.length == 1 ? ids.single : '',
  });
});

String courseIdFor(String? id, String name, Map<String, String> idsByName) =>
    (id?.trim().isNotEmpty ?? false)
    ? id!.trim()
    : idsByName[ComplianceService.normalizeCourseName(name)] ?? '';

FilterRow courseFilterRow(Course course, String instructor) => FilterRow(
  {
    courseFilterDimension: course.id.trim(),
    'Área': course.courseArea,
    'Instructor': instructor,
    'Tipo': course.classificationLms?.label ?? '',
  },
  labels: {courseFilterDimension: courseFilterLabel(course.name, course.id)},
);

final courseFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final stats = await ref.watch(_allCourseStatsProvider.future);
  return stats
      .map((item) => courseFilterRow(item.course, item.instructorName))
      .toList();
});

final _allCourseStatsProvider = FutureProvider<List<CourseViewModel>>((
  ref,
) async {
  final period = ref.watch(courseStatsPeriodProvider);
  final periodService = ref.watch(periodServiceProvider);
  final courses = await ref.watch(coursesProvider.future);
  final employees = await ref.watch(employeesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);

  bool inPeriod(DateTime date) =>
      periodService.contains(date, year: period.year, month: period.month);
  String key(String courseName) =>
      ComplianceService.normalizeCourseName(courseName);

  final employeeNames = {
    for (final employee in employees) employee.employeeId: employee.fullName,
  };
  // Every time entry counts, also teaching ones: in a teaching course the
  // people who load hours are the ones who teach it.
  final periodEntries = timeEntries.where((entry) => inPeriod(entry.date));
  final entriesByCourse = groupBy(
    periodEntries,
    (CrmTimeEntry entry) => key(entry.courseName),
  );
  final completionsByCourse = groupBy(
    certifications.where(
      (certification) =>
          certification.isCompleted &&
          certification.completedAt != null &&
          inPeriod(certification.completedAt!),
    ),
    (LmsCertification certification) => key(certification.courseName),
  );

  return courses.map((course) {
    final entries = entriesByCourse[key(course.name)] ?? const [];
    final completions = completionsByCourse[key(course.name)] ?? const [];
    return CourseViewModel(
      course: course,
      instructorName:
          employeeNames[course.instructorEmployeeId] ??
          course.instructorEmployeeId,
      people: entries.map((entry) => entry.employeeId).toSet().length,
      crmHours: entries.fold(0.0, (total, entry) => total + entry.hours),
      completed: completions
          .map((certification) => certification.employeeId)
          .toSet()
          .length,
    );
  }).toList();
});

final courseStatsProvider = FutureProvider<List<CourseViewModel>>((ref) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.courses))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final stats = await ref.watch(_allCourseStatsProvider.future);
  return stats
      .where(
        (item) => filters.matches(
          selection,
          courseFilterRow(item.course, item.instructorName),
        ),
      )
      .toList();
});
