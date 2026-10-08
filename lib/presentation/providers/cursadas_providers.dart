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

// Filtros propios del listado del CRM (null = todos). No son el período
// global: filtrar acá no cambia lo que muestran Dashboard o Equipos.
final filtroAnioCargaProvider = StateProvider<int?>((ref) => null);
final filtroMesCargaProvider = StateProvider<int?>((ref) => null);
final filtroAreaCargaProvider = StateProvider<String?>((ref) => null);

/// Años con cargas de horas, del más reciente al más viejo.
final aniosCargasDisponiblesProvider = Provider<AsyncValue<List<int>>>((ref) {
  return ref.watch(cargasDeHorasCRMProvider).whenData((cargas) {
    return ({for (final carga in cargas) carga.fecha.year}.toList()
      ..sort((a, b) => b.compareTo(a)));
  });
});

/// Áreas de los colaboradores que tienen cargas de horas, en orden alfabético.
final areasCargasDisponiblesProvider = Provider<AsyncValue<List<String>>>((
  ref,
) {
  final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
  final empleadosAsync = ref.watch(empleadosProvider);

  return cargasAsync.whenData((cargas) {
    final legajos = {for (final carga in cargas) carga.empleadoLegajo};
    final areas = {
      for (final emp in (empleadosAsync.value ?? <Empleado>[]))
        if (legajos.contains(emp.legajo) && emp.area.trim().isNotEmpty)
          emp.area.trim(),
    };
    return areas.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  });
});

final cargasDeHorasCompletasProvider =
    Provider<AsyncValue<List<CargaDeHorasCRMViewModel>>>((ref) {
      final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
      final empleadosAsync = ref.watch(empleadosProvider);
      final cursosAsync = ref.watch(cursosProvider);
      final query = ref.watch(busquedaCargaDeHorasProvider).toLowerCase();
      final anioFiltro = ref.watch(filtroAnioCargaProvider);
      final mesFiltro = ref.watch(filtroMesCargaProvider);
      final areaFiltro = ref.watch(filtroAreaCargaProvider);

      if (cargasAsync.isLoading ||
          empleadosAsync.isLoading ||
          cursosAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (cargasAsync.hasError) {
        return AsyncValue.error(cargasAsync.error!, cargasAsync.stackTrace!);
      }

      if (empleadosAsync.hasError) {
        return AsyncValue.error(
          empleadosAsync.error!,
          empleadosAsync.stackTrace!,
        );
      }

      if (cursosAsync.hasError) {
        return AsyncValue.error(cursosAsync.error!, cursosAsync.stackTrace!);
      }

      final cargas = cargasAsync.value ?? [];
      final empMap = {for (var e in (empleadosAsync.value ?? [])) e.legajo: e};
      final cursoMap = {
        for (final curso in (cursosAsync.value ?? []))
          curso.nombre.trim().toLowerCase(): curso,
      };

      final viewModels = cargas
          .map((carga) {
            return CargaDeHorasCRMViewModel(
              carga: carga,
              empleado: empMap[carga.empleadoLegajo],
              curso: cursoMap[carga.cursoNombre.trim().toLowerCase()],
            );
          })
          .where((vm) {
            final empNombre = vm.empleado != null
                ? '${vm.empleado!.nombre} ${vm.empleado!.apellido}'
                : '';
            // Si el curso no está en el catálogo se busca por el nombre del CRM.
            final cursoNombre = vm.curso?.nombre ?? vm.carga.cursoNombre;
            final legajo = vm.carga.empleadoLegajo;
            final fecha = vm.carga.fecha;

            final matchesQuery =
                empNombre.toLowerCase().contains(query) ||
                cursoNombre.toLowerCase().contains(query) ||
                legajo.toLowerCase().contains(query);

            final matchesAnio = anioFiltro == null || fecha.year == anioFiltro;
            // El mes sólo filtra si hay un año elegido.
            final matchesMes =
                anioFiltro == null ||
                mesFiltro == null ||
                fecha.month == mesFiltro;
            final matchesArea =
                areaFiltro == null || vm.empleado?.area.trim() == areaFiltro;

            return matchesQuery && matchesAnio && matchesMes && matchesArea;
          })
          .toList()
        // Lo más reciente primero.
        ..sort((a, b) => b.carga.fecha.compareTo(a.carga.fecha));

      return AsyncValue.data(viewModels);
    });

final cursadasProvider = cargasDeHorasCRMProvider;
final cursadasCompletasProvider = cargasDeHorasCompletasProvider;
