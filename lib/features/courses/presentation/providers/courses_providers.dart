import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_stats.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/courses/presentation/providers/course_services_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.getCourses();
});

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

final courseIdsByNameProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final courses = await ref.watch(coursesProvider.future);
  return ref.watch(courseCatalogServiceProvider).idsByName(courses);
});

FilterRow courseFilterRow(CourseStats stats) => FilterRow(
  {
    courseFilterDimension: stats.course.id.trim(),
    'Área': stats.course.courseArea,
    'Instructor': stats.instructorName,
    'Tipo': stats.lmsCategory?.label ?? '',
  },
  labels: {
    courseFilterDimension: courseFilterLabel(
      stats.course.name,
      stats.course.id,
    ),
  },
);

final courseFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final stats = await ref.watch(_allCourseStatsProvider.future);
  return stats.map(courseFilterRow).toList();
});

final _allCourseStatsProvider = FutureProvider<List<CourseStats>>((ref) async {
  final period = ref.watch(courseStatsPeriodProvider);
  final periodService = ref.watch(periodServiceProvider);
  final service = ref.watch(courseStatsServiceProvider);
  final courses = await ref.watch(coursesProvider.future);
  final employees = await ref.watch(employeesProvider.future);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final certifications = await ref.watch(lmsCertificationsProvider.future);

  return service.calculate(
    courses: courses,
    employees: employees,
    timeEntries: timeEntries,
    certifications: certifications,
    inPeriod: (date) =>
        periodService.contains(date, year: period.year, month: period.month),
  );
});

final courseStatsProvider = FutureProvider<List<CourseStats>>((ref) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.courses))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final stats = await ref.watch(_allCourseStatsProvider.future);
  return stats
      .where((item) => filters.matches(selection, courseFilterRow(item)))
      .toList();
});
