import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';
import 'package:app_finnegans/features/time_entries/domain/time_entry_records_service.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/courses/presentation/providers/course_services_providers.dart';
import 'package:app_finnegans/features/courses/domain/course_catalog_service.dart';

final crmTimeEntriesProvider = FutureProvider<List<CrmTimeEntry>>((ref) async {
  final repo = ref.watch(crmTimeEntriesRepositoryProvider);
  // Solo las horas de los colaboradores que ve el usuario de la sesión.
  final employeeIds = await ref.watch(visibleEmployeeIdsProvider.future);
  final timeEntries = await repo.getTimeEntries();
  if (employeeIds == null) return timeEntries;
  return timeEntries
      .where((timeEntry) => employeeIds.contains(timeEntry.employeeId))
      .toList();
});

final timeEntryRecordsServiceProvider = Provider<TimeEntryRecordsService>(
  (ref) => TimeEntryRecordsService(
    classification: ref.watch(courseClassificationServiceProvider),
  ),
);

final timeEntriesPeriodProvider = OptionalPeriodProvider(
  OptionalPeriodNotifier.new,
);

final availableTimeEntryYearsProvider = FutureProvider<List<int>>((ref) async {
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  return timeEntries.map((timeEntry) => timeEntry.date.year).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
});

FilterRow crmFilterRow(
  CrmTimeEntryRecord item,
  Map<String, String> courseIdsByName,
) {
  final courseId = const CourseCatalogService().courseIdFor(
    item.timeEntry.courseId,
    item.timeEntry.courseName,
    courseIdsByName,
  );
  return FilterRow(
    {
      personFilterDimension: item.timeEntry.employeeId.trim(),
      courseFilterDimension: courseId,
      'Área': item.employee?.area ?? '',
    },
    labels: {
      personFilterDimension: personFilterLabel(
        item.employee?.fullName ?? '',
        item.timeEntry.employeeId,
      ),
      courseFilterDimension: courseFilterLabel(
        item.timeEntry.courseName,
        courseId,
      ),
    },
  );
}

final _periodTimeEntriesProvider = FutureProvider<List<CrmTimeEntryRecord>>((
  ref,
) async {
  final period = ref.watch(timeEntriesPeriodProvider);
  final periodService = ref.watch(periodServiceProvider);
  final service = ref.watch(timeEntryRecordsServiceProvider);
  final timeEntries = await ref.watch(crmTimeEntriesProvider.future);
  final employees = await ref.watch(employeesProvider.future);
  final courses = await ref.watch(coursesProvider.future);

  return service.join(
    timeEntries: timeEntries,
    employees: employees,
    courses: courses,
    inPeriod: (date) =>
        periodService.contains(date, year: period.year, month: period.month),
  );
});

final timeEntryFilterRowsProvider = FutureProvider<List<FilterRow>>((
  ref,
) async {
  final courseIds = await ref.watch(courseIdsByNameProvider.future);
  final items = await ref.watch(_periodTimeEntriesProvider.future);
  return items.map((item) => crmFilterRow(item, courseIds)).toList();
});

final joinedTimeEntriesProvider = FutureProvider<List<CrmTimeEntryRecord>>((
  ref,
) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.timeEntries))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final courseIds = await ref.watch(courseIdsByNameProvider.future);
  final items = await ref.watch(_periodTimeEntriesProvider.future);
  return items
      .where(
        (item) => filters.matches(selection, crmFilterRow(item, courseIds)),
      )
      .toList();
});
