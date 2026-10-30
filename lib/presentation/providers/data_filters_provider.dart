import 'dart:collection';

import 'package:app_finnegans/presentation/utils/period_filter.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/providers/admin_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';

typedef FilterRow = Map<String, String>;
typedef FilterLabels = Map<String, Map<String, String>>;

const personFilterDimension = 'Persona / Legajo';
const courseFilterDimension = 'Curso / ID';

// La cascada compara claves estables; los nombres son solo presentación.
class _LabeledFilterRow extends MapView<String, String> {
  final Map<String, String> labels;
  _LabeledFilterRow(super.values, this.labels);
}

String _personLabel(String name, String employeeId) =>
    '${name.trim().isEmpty ? 'Persona sin nombre' : name.trim()} — '
    '${employeeId.trim().isEmpty ? 'Sin legajo' : 'Legajo ${employeeId.trim()}'}';
String _courseLabel(String name, String id) =>
    '${name.trim().isEmpty ? 'Curso sin nombre' : name.trim()} — '
    '${id.trim().isEmpty ? 'Sin ID' : 'ID ${id.trim()}'}';

// No se resuelven homónimos ambiguos ni se usan IDs de transacciones.
final courseFilterIdentifiersProvider = Provider<Map<String, String>>((ref) {
  final ids = <String, String>{};
  for (final course in ref.watch(coursesProvider).value ?? <Course>[]) {
    final name = ComplianceService.normalizeCourseName(course.name);
    final id = course.id.trim();
    if (name.isEmpty || id.isEmpty) continue;
    if (ids.containsKey(name) && ids[name] != id) {
      ids[name] = '';
    } else {
      ids.putIfAbsent(name, () => id);
    }
  }
  return Map.unmodifiable(ids);
});

String _courseId(String? id, String name, Map<String, String> idsByName) =>
    (id?.trim().isNotEmpty ?? false)
    ? id!.trim()
    : idsByName[ComplianceService.normalizeCourseName(name)] ?? '';

FilterRow employeeFilterRow(Employee e) => _LabeledFilterRow(
  {
    personFilterDimension: e.employeeId.trim(),
    'Área': e.area,
    'Equipo': e.team,
    'Líder': e.manager,
    'Email': e.email,
    'Seniority': e.seniority.label,
  },
  {personFilterDimension: _personLabel(e.fullName, e.employeeId)},
);
FilterRow courseFilterRow(Course c, String instructor) => _LabeledFilterRow(
  {
    courseFilterDimension: c.id.trim(),
    'Área': c.courseArea,
    'Instructor': instructor,
    'Tipo': c.classificationLms?.label ?? '',
  },
  {courseFilterDimension: _courseLabel(c.name, c.id)},
);
FilterRow teamFilterRow(TeamOverview e) => {
  'Equipo': e.name,
  'Área': e.area,
  'Líder': e.leader,
  'Estado': e.status.label,
};
FilterRow crmFilterRow(
  CrmTimeEntryViewModel vm, {
  Map<String, String> courseIdsByName = const {},
}) {
  final id = _courseId(
    vm.timeEntry.courseId,
    vm.timeEntry.courseName,
    courseIdsByName,
  );
  return _LabeledFilterRow(
    {
      personFilterDimension: vm.timeEntry.employeeId.trim(),
      courseFilterDimension: id,
      'Área': vm.employee?.area ?? '',
    },
    {
      personFilterDimension: _personLabel(
        vm.employee?.fullName ?? '',
        vm.timeEntry.employeeId,
      ),
      courseFilterDimension: _courseLabel(vm.timeEntry.courseName, id),
    },
  );
}

FilterRow certificationFilterRow(
  CertificationViewModel vm, {
  Map<String, String> courseIdsByName = const {},
}) {
  final id = _courseId(
    vm.certification.courseId,
    vm.certification.courseName,
    courseIdsByName,
  );
  return _LabeledFilterRow(
    {
      personFilterDimension: vm.certification.employeeId.trim(),
      courseFilterDimension: id,
      'Área': vm.employee?.area ?? '',
      'Equipo': vm.employee?.team ?? '',
      'Tipo': vm.course?.classificationLms?.label ?? '',
      'Estado': vm.certification.isCompleted ? 'Finalizado' : 'Pendiente',
    },
    {
      personFilterDimension: _personLabel(
        vm.employee?.fullName ?? '',
        vm.certification.employeeId,
      ),
      courseFilterDimension: _courseLabel(vm.certification.courseName, id),
    },
  );
}

FilterRow adminFilterRow(AuthorizedUser user) => {
  'Email': user.email,
  'Rol': user.knownRole?.label ?? user.role,
  'Estado': user.status.label,
};

typedef DataFilterValues = Map<String, Set<String>>;

// OR entre los valores de una dimensión, AND entre las dimensiones activas.
bool matchesDataFilters(DataFilterValues selection, FilterRow row) =>
    selection.entries.every(
      (entry) => entry.value.isEmpty || entry.value.contains(row[entry.key]),
    );

/// Opciones compatibles con los demás filtros, más las selecciones conservadas.
class DataFilterOptions {
  final List<String> values;
  final Set<String> incompatibleValues;
  final Map<String, String> labels;

  DataFilterOptions(
    Iterable<String> available,
    Set<String> selected, {
    Map<String, String> labels = const {},
  }) : labels = Map.unmodifiable(labels),
       values = List.unmodifiable(
         ({...available, ...selected}.toList()..sort((a, b) {
           final compare = (labels[a] ?? a).compareTo(labels[b] ?? b);
           return compare == 0 ? a.compareTo(b) : compare;
         })),
       ),
       incompatibleValues = Set.unmodifiable(
         selected.difference(available.toSet()),
       );

  String labelFor(String value) => labels[value] ?? value;
}

Map<String, DataFilterOptions> cascadeFilterOptions(
  List<FilterRow> rows,
  DataFilterValues selection, {
  FilterLabels selectedLabels = const {},
}) {
  final labels = <String, Map<String, String>>{};
  final available = <String, Set<String>>{};
  final active = selection.entries
      .where((entry) => entry.value.isNotEmpty)
      .toList();
  for (final row in rows) {
    if (row is _LabeledFilterRow) {
      for (final entry in row.labels.entries) {
        final value = row[entry.key];
        if (value != null && value.isNotEmpty) {
          labels
              .putIfAbsent(entry.key, () => {})
              .putIfAbsent(value, () => entry.value);
        }
      }
    }
    for (final entry in row.entries) {
      if (entry.value.trim().isNotEmpty) {
        available.putIfAbsent(entry.key, () => {});
      }
    }
    // Una fila con cero fallos sirve a todas las dimensiones; con un fallo
    // sirve solo a esa dimensión, porque su propio filtro debe excluirse.
    String? failedDimension;
    var failures = 0;
    for (final entry in active) {
      if (!entry.value.contains(row[entry.key])) {
        failedDimension = entry.key;
        if (++failures > 1) break;
      }
    }
    if (failures > 1) continue;
    for (final entry in row.entries) {
      if (entry.value.trim().isNotEmpty &&
          (failures == 0 || entry.key == failedDimension)) {
        available[entry.key]!.add(entry.value);
      }
    }
  }
  for (final dimension in selection.keys) {
    available.putIfAbsent(dimension, () => {});
  }
  return Map.unmodifiable({
    for (final entry in available.entries)
      entry.key: DataFilterOptions(
        entry.value,
        selection[entry.key] ?? const {},
        labels: {...?selectedLabels[entry.key], ...?labels[entry.key]},
      ),
  });
}

DataFilterValues withDataFilterValues(
  DataFilterValues current,
  String dimension,
  Set<String> values,
) {
  final next = {...current}..remove(dimension);
  if (values.isNotEmpty) next[dimension] = Set.unmodifiable(values);
  return Map.unmodifiable(next);
}

// Solo datos obtenidos por los providers existentes, bajo los mismos permisos.
// Esta base conserva el alcance del listado y no depende de sus selecciones.

final dataFilterRowsProvider =
    Provider.family<AsyncValue<List<FilterRow>>, String>((ref, scope) {
      switch (scope) {
        case 'personas':
          return ref
              .watch(employeesProvider)
              .whenData((items) => items.map(employeeFilterRow).toList());
        case 'equipos':
          return ref
              .watch(teamsPeriodSummaryProvider)
              .whenData((data) => data.teams.map(teamFilterRow).toList());
        case 'areas':
          return ref
              .watch(areasPeriodSummaryProvider)
              .whenData(
                (data) => [
                  for (final a in data.areas)
                    for (final team
                        in a.generalTeams.isEmpty ? [''] : a.generalTeams)
                      {'Área': a.name, 'Equipo': team, 'Estado': a.level.label},
                ],
              );
        case 'cursos':
          final employeesAsync = ref.watch(employeesProvider);
          if (employeesAsync.isLoading) return const AsyncValue.loading();
          if (employeesAsync.hasError) {
            return AsyncValue.error(
              employeesAsync.error!,
              employeesAsync.stackTrace!,
            );
          }
          final employees = employeesAsync.value ?? <Employee>[];
          final names = {for (final e in employees) e.employeeId: e.fullName};
          return ref
              .watch(coursesProvider)
              .whenData(
                (items) => items
                    .map(
                      (c) => courseFilterRow(
                        c,
                        names[c.instructorEmployeeId] ?? c.instructorEmployeeId,
                      ),
                    )
                    .toList(),
              );
        case 'crm':
          final courseIds = ref.watch(courseFilterIdentifiersProvider);
          final coursesAsync = ref.watch(coursesProvider);
          if (coursesAsync.isLoading) return const AsyncValue.loading();
          if (coursesAsync.hasError) {
            return AsyncValue.error(
              coursesAsync.error!,
              coursesAsync.stackTrace!,
            );
          }
          final year = ref.watch(timeEntryYearFilterProvider);
          final month = ref.watch(timeEntryMonthFilterProvider);
          final employeesAsync = ref.watch(employeesProvider);
          if (employeesAsync.isLoading) return const AsyncValue.loading();
          if (employeesAsync.hasError) {
            return AsyncValue.error(
              employeesAsync.error!,
              employeesAsync.stackTrace!,
            );
          }
          final employees = employeesAsync.value ?? <Employee>[];
          final names = {for (final e in employees) e.employeeId: e};
          return ref
              .watch(crmTimeEntriesProvider)
              .whenData(
                (items) => items
                    .where(
                      (timeEntry) => matchesPeriod(
                        timeEntry.date,
                        year: year,
                        month: month,
                      ),
                    )
                    .map(
                      (c) => crmFilterRow(
                        CrmTimeEntryViewModel(
                          timeEntry: c,
                          employee: names[c.employeeId],
                          course: null,
                        ),
                        courseIdsByName: courseIds,
                      ),
                    )
                    .toList(),
              );
        case 'admin':
          if (ref.watch(accessAdminProvider) != AccessAdmin.allowed) {
            return const AsyncValue.data([]);
          }
          return ref
              .watch(authorizedUsersProvider)
              .whenData((items) => items.map(adminFilterRow).toList());
        case 'lms':
          final courseIds = ref.watch(courseFilterIdentifiersProvider);
          return ref
              .watch(joinedCertificationsProvider)
              .whenData(
                (items) => items
                    .map(
                      (vm) => certificationFilterRow(
                        vm,
                        courseIdsByName: courseIds,
                      ),
                    )
                    .toList(),
              );
        default:
          return const AsyncValue.data([]);
      }
    });

class DataFilterSelection extends StateNotifier<DataFilterValues> {
  DataFilterSelection() : super({});
  FilterLabels _selectedLabels = {};
  FilterLabels get selectedLabels => _selectedLabels;

  void select(
    String dimension,
    Set<String> values, {
    Map<String, String> labels = const {},
  }) {
    final nextLabels = {..._selectedLabels}..remove(dimension);
    if (values.isNotEmpty) {
      nextLabels[dimension] = Map.unmodifiable({
        for (final value in values)
          value: labels[value] ?? _selectedLabels[dimension]?[value] ?? value,
      });
    }
    _selectedLabels = Map.unmodifiable(nextLabels);
    state = withDataFilterValues(state, dimension, values);
  }

  void clear() {
    _selectedLabels = {};
    state = {};
  }
}

final dataFilterSelectionProvider =
    StateNotifierProvider.family<DataFilterSelection, DataFilterValues, String>(
      (ref, scope) {
        // Las selecciones sobreviven a cambios de datos/período; al cambiar de
        // usuario se reinician, sin trasladar etiquetas entre sesiones.
        ref.watch(authControllerProvider.select((auth) => auth.email));
        return DataFilterSelection();
      },
    );

final dataFilterOptionsProvider =
    Provider.family<AsyncValue<Map<String, DataFilterOptions>>, String>((
      ref,
      scope,
    ) {
      final rows = ref.watch(dataFilterRowsProvider(scope));
      final selection = ref.watch(dataFilterSelectionProvider(scope));
      final selectedLabels = ref
          .read(dataFilterSelectionProvider(scope).notifier)
          .selectedLabels;
      return rows.whenData(
        (items) => cascadeFilterOptions(
          items,
          selection,
          selectedLabels: selectedLabels,
        ),
      );
    });
