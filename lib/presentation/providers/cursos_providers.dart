import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final cursosProvider = FutureProvider<List<Curso>>((ref) async {
  final repo = ref.watch(cursosRepositoryProvider);
  return repo.getCursos();
});

class CursoViewModel {
  final Curso curso;
  final String nombreInstructor;

  CursoViewModel({required this.curso, required this.nombreInstructor});
}

final busquedaCursoProvider = StateProvider<String>((ref) => '');
final filtroTipoCursoProvider = StateProvider<TipoCurso?>((ref) => null);

final cursosConInstructorProvider = Provider<AsyncValue<List<CursoViewModel>>>((
  ref,
) {
  final cursosAsync = ref.watch(cursosProvider);
  final empleadosAsync = ref.watch(empleadosProvider);
  final query = ref.watch(busquedaCursoProvider).toLowerCase();
  final tipoFiltro = ref.watch(filtroTipoCursoProvider);

  if (cursosAsync.isLoading || empleadosAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (cursosAsync.hasError) {
    return AsyncValue.error(cursosAsync.error!, cursosAsync.stackTrace!);
  }

  final cursos = cursosAsync.value ?? [];
  final empleados = empleadosAsync.value ?? [];
  final empMap = {
    for (var e in empleados) e.legajo: '${e.nombre} ${e.apellido}',
  };

  final viewModels = cursos
      .map((c) {
        return CursoViewModel(
          curso: c,
          nombreInstructor: empMap[c.instructorLegajo] ?? c.instructorLegajo,
        );
      })
      .where((vm) {
        final matchesQuery =
            vm.curso.nombre.toLowerCase().contains(query) ||
            vm.curso.areaCurso.toLowerCase().contains(query) ||
            vm.nombreInstructor.toLowerCase().contains(query);

        final matchesTipo = tipoFiltro == null || vm.curso.tipo == tipoFiltro;

        return matchesQuery && matchesTipo;
      })
      .toList();

  return AsyncValue.data(viewModels);
});
