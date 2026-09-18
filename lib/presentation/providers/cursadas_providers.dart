import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final cargasDeHorasCRMProvider = FutureProvider<List<CargaDeHorasCRM>>((
  ref,
) async {
  final repo = ref.watch(cargaDeHorasCRMRepositoryProvider);
  return repo.getCargasDeHoras();
});

class CargaDeHorasCRMViewModel {
  final CargaDeHorasCRM carga;
  final Empleado? empleado;
  final Curso? curso;

  CargaDeHorasCRMViewModel({
    required this.carga,
    required this.empleado,
    required this.curso,
  });

  CargaDeHorasCRM get cursada => carga;
}

typedef CursadaViewModel = CargaDeHorasCRMViewModel;

final busquedaCargaDeHorasProvider = StateProvider<String>((ref) => '');
final busquedaCursadaProvider = busquedaCargaDeHorasProvider;
final filtroCursoIdProvider = StateProvider<String?>((ref) => null);

final cargasDeHorasCompletasProvider =
    Provider<AsyncValue<List<CargaDeHorasCRMViewModel>>>((ref) {
      final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
      final empleadosAsync = ref.watch(empleadosProvider);
      final cursosAsync = ref.watch(cursosProvider);
      final query = ref.watch(busquedaCargaDeHorasProvider).toLowerCase();
      final cursoFiltro = ref.watch(filtroCursoIdProvider);

      if (cargasAsync.isLoading ||
          empleadosAsync.isLoading ||
          cursosAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (cargasAsync.hasError) {
        return AsyncValue.error(cargasAsync.error!, cargasAsync.stackTrace!);
      }

      final cargas = cargasAsync.value ?? [];
      final empMap = {for (var e in (empleadosAsync.value ?? [])) e.legajo: e};
      final cursoMap = {for (var c in (cursosAsync.value ?? [])) c.id: c};

      final viewModels = cargas
          .map((carga) {
            return CargaDeHorasCRMViewModel(
              carga: carga,
              empleado: empMap[carga.empleadoLegajo],
              curso: cursoMap[carga.cursoId],
            );
          })
          .where((vm) {
            final empNombre = vm.empleado != null
                ? '${vm.empleado!.nombre} ${vm.empleado!.apellido}'
                : '';
            final cursoNombre = vm.curso?.nombre ?? '';
            final legajo = vm.carga.empleadoLegajo;

            final matchesQuery =
                empNombre.toLowerCase().contains(query) ||
                cursoNombre.toLowerCase().contains(query) ||
                legajo.toLowerCase().contains(query);

            final matchesCurso =
                cursoFiltro == null || vm.carga.cursoId == cursoFiltro;

            return matchesQuery && matchesCurso;
          })
          .toList();

      return AsyncValue.data(viewModels);
    });

final cursadasProvider = cargasDeHorasCRMProvider;
final cursadasCompletasProvider = cargasDeHorasCompletasProvider;
