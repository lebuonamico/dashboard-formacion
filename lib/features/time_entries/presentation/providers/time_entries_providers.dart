import 'package:app_finnegans/core/data_filters/data_filters_provider.dart';
import 'package:app_finnegans/core/period/period_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

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

class CrmTimeEntryViewModel {
  final CrmTimeEntry timeEntry;
  final Employee? employee;
  final Course? course;

  CrmTimeEntryViewModel({
    required this.timeEntry,
    required this.employee,
    required this.course,
  });
}

final timeEntrySearchProvider = StateProvider<String>((ref) => '');

// Filtros propios del listado del CRM (null = todos). No son el período
// global: filtrar acá no cambia lo que muestran Dashboard o Equipos.
final timeEntryYearFilterProvider = StateProvider<int?>((ref) => null);
final timeEntryMonthFilterProvider = StateProvider<int?>((ref) => null);

/// Años con cargas de horas, del más reciente al más viejo.
final availableTimeEntryYearsProvider = Provider<AsyncValue<List<int>>>((ref) {
  return ref.watch(crmTimeEntriesProvider).whenData((timeEntries) {
    return ({for (final timeEntry in timeEntries) timeEntry.date.year}.toList()
      ..sort((a, b) => b.compareTo(a)));
  });
});

final joinedTimeEntriesProvider =
    Provider<AsyncValue<List<CrmTimeEntryViewModel>>>((ref) {
      final timeEntriesAsync = ref.watch(crmTimeEntriesProvider);
      final employeesAsync = ref.watch(employeesProvider);
      final coursesAsync = ref.watch(coursesProvider);
      final query = ref.watch(timeEntrySearchProvider).toLowerCase();
      final yearFilter = ref.watch(timeEntryYearFilterProvider);
      final filterMonth = ref.watch(timeEntryMonthFilterProvider);
      final selection = ref.watch(dataFilterSelectionProvider('crm'));
      final courseIds = ref.watch(courseFilterIdentifiersProvider);

      if (timeEntriesAsync.isLoading ||
          employeesAsync.isLoading ||
          coursesAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (timeEntriesAsync.hasError) {
        return AsyncValue.error(
          timeEntriesAsync.error!,
          timeEntriesAsync.stackTrace!,
        );
      }

      if (employeesAsync.hasError) {
        return AsyncValue.error(
          employeesAsync.error!,
          employeesAsync.stackTrace!,
        );
      }

      if (coursesAsync.hasError) {
        return AsyncValue.error(coursesAsync.error!, coursesAsync.stackTrace!);
      }

      final timeEntries = timeEntriesAsync.value ?? [];
      final employeeMap = {
        for (final e in employeesAsync.value ?? <Employee>[]) e.employeeId: e,
      };
      final courseMap = {
        for (final course in coursesAsync.value ?? <Course>[])
          course.name.trim().toLowerCase(): course,
      };

      final viewModels =
          timeEntries
              .map((timeEntry) {
                return CrmTimeEntryViewModel(
                  timeEntry: timeEntry,
                  employee: employeeMap[timeEntry.employeeId],
                  course: courseMap[timeEntry.courseName.trim().toLowerCase()],
                );
              })
              .where((vm) {
                final employeeName = vm.employee != null
                    ? '${vm.employee!.firstName} ${vm.employee!.lastName}'
                    : '';
                // Si el curso no está en el catálogo se busca por el nombre del CRM.
                final courseName = vm.course?.name ?? vm.timeEntry.courseName;
                final employeeId = vm.timeEntry.employeeId;
                final area = vm.employee?.area ?? '';
                final date = vm.timeEntry.date;

                final matchesQuery =
                    employeeName.toLowerCase().contains(query) ||
                    courseName.toLowerCase().contains(query) ||
                    employeeId.toLowerCase().contains(query) ||
                    area.toLowerCase().contains(query);

                final periodMatch = matchesPeriod(
                  date,
                  year: yearFilter,
                  month: filterMonth,
                );

                return matchesQuery &&
                    periodMatch &&
                    matchesDataFilters(
                      selection,
                      crmFilterRow(vm, courseIdsByName: courseIds),
                    );
              })
              .toList()
            // Lo más reciente primero.
            ..sort((a, b) => b.timeEntry.date.compareTo(a.timeEntry.date));

      return AsyncValue.data(viewModels);
    });
