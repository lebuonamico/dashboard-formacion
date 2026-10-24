import 'dart:collection';

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

const personaFilterDimension = 'Persona / Legajo';
const cursoFilterDimension = 'Curso / ID';

// La cascada compara claves estables; los nombres son solo presentación.
class _LabeledFilterRow extends MapView<String, String> {
  final Map<String, String> labels;
  _LabeledFilterRow(super.values, this.labels);
}

String _personaLabel(String nombre, String legajo) =>
    '${nombre.trim().isEmpty ? 'Persona sin nombre' : nombre.trim()} — '
    '${legajo.trim().isEmpty ? 'Sin legajo' : 'Legajo ${legajo.trim()}'}';
String _cursoLabel(String nombre, String id) =>
    '${nombre.trim().isEmpty ? 'Curso sin nombre' : nombre.trim()} — '
    '${id.trim().isEmpty ? 'Sin ID' : 'ID ${id.trim()}'}';

// No se resuelven homónimos ambiguos ni se usan IDs de transacciones.
final courseFilterIdentifiersProvider = Provider<Map<String, String>>((ref) {
  final ids = <String, String>{};
  for (final curso in ref.watch(cursosProvider).value ?? <Curso>[]) {
    final nombre = CumplimientoService.normalizarNombreCurso(curso.nombre);
    final id = curso.id.trim();
    if (nombre.isEmpty || id.isEmpty) continue;
    if (ids.containsKey(nombre) && ids[nombre] != id) {
      ids[nombre] = '';
    } else {
      ids.putIfAbsent(nombre, () => id);
    }
  }
  return Map.unmodifiable(ids);
});

String _courseId(String? id, String nombre, Map<String, String> idsPorNombre) =>
    (id?.trim().isNotEmpty ?? false)
    ? id!.trim()
    : idsPorNombre[CumplimientoService.normalizarNombreCurso(nombre)] ?? '';

FilterRow empleadoFilterRow(Empleado e) => _LabeledFilterRow(
  {
    personaFilterDimension: e.legajo.trim(),
    'Área': e.area,
    'Equipo': e.equipo,
    'Líder': e.gerente,
    'Email': e.mail,
    'Seniority': e.seniority.label,
  },
  {personaFilterDimension: _personaLabel(e.nombreCompleto, e.legajo)},
);
FilterRow cursoFilterRow(Curso c, String instructor) => _LabeledFilterRow(
  {
    cursoFilterDimension: c.id.trim(),
    'Área': c.areaCurso,
    'Instructor': instructor,
    'Tipo': c.tipoLms?.label ?? '',
  },
  {cursoFilterDimension: _cursoLabel(c.nombre, c.id)},
);
FilterRow equipoFilterRow(EquipoGlobalViewModel e) => {
  'Equipo': e.nombre,
  'Área': e.area,
  'Líder': e.lider,
  'Estado': e.estado.label,
};
FilterRow crmFilterRow(
  CargaDeHorasCRMViewModel vm, {
  Map<String, String> cursoIdsPorNombre = const {},
}) {
  final id = _courseId(
    vm.carga.cursoId,
    vm.carga.cursoNombre,
    cursoIdsPorNombre,
  );
  return _LabeledFilterRow(
    {
      personaFilterDimension: vm.carga.empleadoLegajo.trim(),
      cursoFilterDimension: id,
      'Área': vm.empleado?.area ?? '',
    },
    {
      personaFilterDimension: _personaLabel(
        vm.empleado?.nombreCompleto ?? '',
        vm.carga.empleadoLegajo,
      ),
      cursoFilterDimension: _cursoLabel(vm.carga.cursoNombre, id),
    },
  );
}

FilterRow certificacionFilterRow(
  CertificacionViewModel vm, {
  Map<String, String> cursoIdsPorNombre = const {},
}) {
  final id = _courseId(
    vm.certificacion.cursoId,
    vm.certificacion.cursoNombre,
    cursoIdsPorNombre,
  );
  return _LabeledFilterRow(
    {
      personaFilterDimension: vm.certificacion.legajo.trim(),
      cursoFilterDimension: id,
      'Área': vm.empleado?.area ?? '',
      'Equipo': vm.empleado?.equipo ?? '',
      'Tipo': vm.curso?.tipoLms?.label ?? '',
      'Estado': vm.certificacion.finalizoCurso ? 'Finalizado' : 'Pendiente',
    },
    {
      personaFilterDimension: _personaLabel(
        vm.empleado?.nombreCompleto ?? '',
        vm.certificacion.legajo,
      ),
      cursoFilterDimension: _cursoLabel(vm.certificacion.cursoNombre, id),
    },
  );
}

FilterRow adminFilterRow(UsuarioAutorizado usuario) => {
  'Email': usuario.email,
  'Rol': usuario.rolConocido?.label ?? usuario.rol,
  'Estado': usuario.estado.label,
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
              .watch(empleadosProvider)
              .whenData((items) => items.map(empleadoFilterRow).toList());
        case 'equipos':
          return ref
              .watch(resumenEquiposPeriodoProvider)
              .whenData((data) => data.equipos.map(equipoFilterRow).toList());
        case 'areas':
          return ref
              .watch(resumenAreasPeriodoProvider)
              .whenData(
                (data) => [
                  for (final a in data.areas)
                    for (final equipo
                        in a.equiposGenerales.isEmpty
                            ? ['']
                            : a.equiposGenerales)
                      {
                        'Área': a.nombre,
                        'Equipo': equipo,
                        'Estado': a.semaforo.label,
                      },
                ],
              );
        case 'cursos':
          final empleadosAsync = ref.watch(empleadosProvider);
          if (empleadosAsync.isLoading) return const AsyncValue.loading();
          if (empleadosAsync.hasError) {
            return AsyncValue.error(
              empleadosAsync.error!,
              empleadosAsync.stackTrace!,
            );
          }
          final empleados = empleadosAsync.value ?? <Empleado>[];
          final nombres = {
            for (final e in empleados) e.legajo: e.nombreCompleto,
          };
          return ref
              .watch(cursosProvider)
              .whenData(
                (items) => items
                    .map(
                      (c) => cursoFilterRow(
                        c,
                        nombres[c.instructorLegajo] ?? c.instructorLegajo,
                      ),
                    )
                    .toList(),
              );
        case 'crm':
          final cursoIds = ref.watch(courseFilterIdentifiersProvider);
          final cursosAsync = ref.watch(cursosProvider);
          if (cursosAsync.isLoading) return const AsyncValue.loading();
          if (cursosAsync.hasError) {
            return AsyncValue.error(
              cursosAsync.error!,
              cursosAsync.stackTrace!,
            );
          }
          final anio = ref.watch(filtroAnioCargaProvider);
          final mes = ref.watch(filtroMesCargaProvider);
          final empleadosAsync = ref.watch(empleadosProvider);
          if (empleadosAsync.isLoading) return const AsyncValue.loading();
          if (empleadosAsync.hasError) {
            return AsyncValue.error(
              empleadosAsync.error!,
              empleadosAsync.stackTrace!,
            );
          }
          final empleados = empleadosAsync.value ?? <Empleado>[];
          final nombres = {for (final e in empleados) e.legajo: e};
          return ref
              .watch(cargasDeHorasCRMProvider)
              .whenData(
                (items) => items
                    .where(
                      (carga) =>
                          anio == null ||
                          (carga.fecha.year == anio &&
                              (mes == null || carga.fecha.month == mes)),
                    )
                    .map(
                      (c) => crmFilterRow(
                        CargaDeHorasCRMViewModel(
                          carga: c,
                          empleado: nombres[c.empleadoLegajo],
                          curso: null,
                        ),
                        cursoIdsPorNombre: cursoIds,
                      ),
                    )
                    .toList(),
              );
        case 'admin':
          if (ref.watch(accesoAdminProvider) != AccesoAdmin.permitido) {
            return const AsyncValue.data([]);
          }
          return ref
              .watch(usuariosAutorizadosProvider)
              .whenData((items) => items.map(adminFilterRow).toList());
        case 'lms':
          final cursoIds = ref.watch(courseFilterIdentifiersProvider);
          return ref
              .watch(certificacionesCompletasProvider)
              .whenData(
                (items) => items
                    .map(
                      (vm) => certificacionFilterRow(
                        vm,
                        cursoIdsPorNombre: cursoIds,
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
