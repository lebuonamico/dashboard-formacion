import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final cursadasProvider = FutureProvider<List<Cursada>>((ref) async {
  final repo = ref.watch(formacionRepositoryProvider);
  return repo.getCursadas();
});

class CursadaViewModel {
  final Cursada cursada;
  final Empleado? empleado;
  final Curso? curso;

  CursadaViewModel({
    required this.cursada,
    required this.empleado,
    required this.curso,
  });
}

final busquedaCursadaProvider = StateProvider<String>((ref) => '');
final filtroCursoIdProvider = StateProvider<String?>((ref) => null);

final cursadasCompletasProvider =
    Provider<AsyncValue<List<CursadaViewModel>>>((ref) {
  final cursadasAsync = ref.watch(cursadasProvider);
  final empleadosAsync = ref.watch(empleadosProvider);
  final cursosAsync = ref.watch(cursosProvider);
  final query = ref.watch(busquedaCursadaProvider).toLowerCase();
  final cursoFiltro = ref.watch(filtroCursoIdProvider);

  if (cursadasAsync.isLoading ||
      empleadosAsync.isLoading ||
      cursosAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (cursadasAsync.hasError) {
    return AsyncValue.error(cursadasAsync.error!, cursadasAsync.stackTrace!);
  }

  final cursadas = cursadasAsync.value ?? [];
  final empMap = {for (var e in (empleadosAsync.value ?? [])) e.legajo: e};
  final cursoMap = {for (var c in (cursosAsync.value ?? [])) c.id: c};

  final viewModels = cursadas.map((cursada) {
    return CursadaViewModel(
      cursada: cursada,
      empleado: empMap[cursada.empleadoLegajo],
      curso: cursoMap[cursada.cursoId],
    );
  }).where((vm) {
    final empNombre = vm.empleado != null
        ? '${vm.empleado!.nombre} ${vm.empleado!.apellido}'
        : '';
    final cursoNombre = vm.curso?.nombre ?? '';
    final legajo = vm.cursada.empleadoLegajo;

    final matchesQuery = empNombre.toLowerCase().contains(query) ||
        cursoNombre.toLowerCase().contains(query) ||
        legajo.toLowerCase().contains(query);

    final matchesCurso =
        cursoFiltro == null || vm.cursada.cursoId == cursoFiltro;

    return matchesQuery && matchesCurso;
  }).toList();

  return AsyncValue.data(viewModels);
});