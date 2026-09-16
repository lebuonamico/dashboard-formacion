import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final empleadosProvider = FutureProvider<List<Empleado>>((ref) async {
  final repo = ref.watch(formacionRepositoryProvider);
  return repo.getEmpleados();
});

final busquedaEmpleadoProvider = StateProvider<String>((ref) => '');
final filtroSeniorityProvider = StateProvider<Seniority?>((ref) => null);

final empleadosFiltradosProvider = Provider<AsyncValue<List<Empleado>>>((ref) {
  final empleadosAsync = ref.watch(empleadosProvider);
  final query = ref.watch(busquedaEmpleadoProvider).toLowerCase();
  final seniorityFiltro = ref.watch(filtroSeniorityProvider);

  return empleadosAsync.whenData((empleados) {
    return empleados.where((emp) {
      final matchesQuery = emp.nombre.toLowerCase().contains(query) ||
          emp.apellido.toLowerCase().contains(query) ||
          emp.legajo.toLowerCase().contains(query) ||
          emp.area.toLowerCase().contains(query) ||
          emp.equipo.toLowerCase().contains(query) ||
          emp.gerente.toLowerCase().contains(query) ||
          emp.mail.toLowerCase().contains(query);

      final matchesSeniority =
          seniorityFiltro == null || emp.seniority == seniorityFiltro;

      return matchesQuery && matchesSeniority;
    }).toList();
  });
});

class DetalleEmpleadoViewModel {
  final Empleado empleado;
  final CumplimientoEmpleado cumplimiento;
  final List<CursadaViewModel> historialCursadas;
  final List<Curso> cursosDictados;

  DetalleEmpleadoViewModel({
    required this.empleado,
    required this.cumplimiento,
    required this.historialCursadas,
    required this.cursosDictados,
  });
}

final detalleEmpleadoProvider =
    FutureProvider.family<DetalleEmpleadoViewModel?, String>((ref, legajo) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final cursadasCompletasAsync = ref.watch(cursadasCompletasProvider);
  final cursosAsync = await ref.watch(cursosProvider.future);

  final itemCumplimiento = cumplimientos.firstWhere(
    (c) => c.empleado.legajo == legajo,
    orElse: () => throw Exception('Empleado no encontrado'),
  );

  final todasLasCursadas = cursadasCompletasAsync.value ?? [];
  final cursadasDelEmpleado =
      todasLasCursadas.where((c) => c.cursada.empleadoLegajo == legajo).toList();

  final dictados =
      cursosAsync.where((cur) => cur.instructorLegajo == legajo).toList();

  return DetalleEmpleadoViewModel(
    empleado: itemCumplimiento.empleado,
    cumplimiento: itemCumplimiento,
    historialCursadas: cursadasDelEmpleado,
    cursosDictados: dictados,
  );
});