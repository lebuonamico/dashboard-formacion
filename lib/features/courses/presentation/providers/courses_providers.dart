import 'package:app_finnegans/core/data_filters/data_filters_provider.dart';
import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

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

final courseSearchProvider = StateProvider<String>((ref) => '');
final courseCategoryFilterProvider = StateProvider<CourseCategory?>(
  (ref) => null,
);

// Período de las métricas del catálogo (null = todos). No es el período
// global: filtrar acá no cambia lo que muestran Dashboard o Equipos.
final courseYearFilterProvider = StateProvider<int?>((ref) => null);
final courseMonthFilterProvider = StateProvider<int?>((ref) => null);

/// Años con cargas CRM o finalizaciones LMS, del más reciente al más viejo.
final availableCourseYearsProvider = Provider<AsyncValue<List<int>>>((ref) {
  final timeEntriesAsync = ref.watch(crmTimeEntriesProvider);
  final certificationsAsync = ref.watch(lmsCertificationsProvider);
  return timeEntriesAsync.whenData((timeEntries) {
    final years = <int>{
      for (final timeEntry in timeEntries) timeEntry.date.year,
      for (final certification
          in certificationsAsync.value ?? const <LmsCertification>[])
        ?certification.completedAt?.year,
    };
    return years.toList()..sort((a, b) => b.compareTo(a));
  });
});

final courseStatsProvider = Provider<AsyncValue<List<CourseViewModel>>>((ref) {
  final coursesAsync = ref.watch(coursesProvider);
  final employeesAsync = ref.watch(employeesProvider);
  final timeEntriesAsync = ref.watch(crmTimeEntriesProvider);
  final certificationsAsync = ref.watch(lmsCertificationsProvider);
  final query = ref.watch(courseSearchProvider).toLowerCase();
  final typeFilter = ref.watch(courseCategoryFilterProvider);
  final yearFilter = ref.watch(courseYearFilterProvider);
  final filterMonth = ref.watch(courseMonthFilterProvider);
  final selection = ref.watch(dataFilterSelectionProvider('cursos'));

  final asyncValues = [
    coursesAsync,
    employeesAsync,
    timeEntriesAsync,
    certificationsAsync,
  ];
  if (asyncValues.any((value) => value.isLoading)) {
    return const AsyncValue.loading();
  }
  final error = asyncValues.where((value) => value.hasError).firstOrNull;
  if (error != null) return AsyncValue.error(error.error!, error.stackTrace!);

  final courses = coursesAsync.value ?? [];
  final employees = employeesAsync.value ?? [];
  final employeeMap = {
    for (var e in employees) e.employeeId: '${e.firstName} ${e.lastName}',
  };

  bool inPeriod(DateTime date) => ref
      .watch(periodServiceProvider)
      .contains(date, year: yearFilter, month: filterMonth);

  // Mismo cruce por nombre normalizado que el cálculo de cumplimiento.
  final crmEmployeeIds = <String, Set<String>>{};
  final crmHours = <String, double>{};
  // Todas las cargas cuentan, también las de dictado: en un curso de tipo
  // Dictado, quienes cargan horas son quienes lo dictan.
  for (final timeEntry in timeEntriesAsync.value ?? const <CrmTimeEntry>[]) {
    if (!inPeriod(timeEntry.date)) continue;
    final key = ComplianceService.normalizeCourseName(timeEntry.courseName);
    crmEmployeeIds.putIfAbsent(key, () => {}).add(timeEntry.employeeId);
    crmHours[key] = (crmHours[key] ?? 0) + timeEntry.hours;
  }
  final completedEmployeeIds = <String, Set<String>>{};
  for (final certification
      in certificationsAsync.value ?? const <LmsCertification>[]) {
    final date = certification.completedAt;
    if (!certification.isCompleted || date == null || !inPeriod(date)) {
      continue;
    }
    completedEmployeeIds
        .putIfAbsent(
          ComplianceService.normalizeCourseName(certification.courseName),
          () => {},
        )
        .add(certification.employeeId);
  }

  final viewModels = courses
      .map((c) {
        final key = ComplianceService.normalizeCourseName(c.name);
        return CourseViewModel(
          course: c,
          instructorName:
              employeeMap[c.instructorEmployeeId] ?? c.instructorEmployeeId,
          people: crmEmployeeIds[key]?.length ?? 0,
          crmHours: crmHours[key] ?? 0,
          completed: completedEmployeeIds[key]?.length ?? 0,
        );
      })
      .where((vm) {
        final matchesQuery =
            vm.course.name.toLowerCase().contains(query) ||
            vm.course.courseArea.toLowerCase().contains(query) ||
            vm.instructorName.toLowerCase().contains(query);

        final matchesType =
            typeFilter == null || vm.course.category == typeFilter;

        return matchesQuery &&
            matchesType &&
            matchesDataFilters(
              selection,
              courseFilterRow(vm.course, vm.instructorName),
            );
      })
      .toList();

  return AsyncValue.data(viewModels);
});
