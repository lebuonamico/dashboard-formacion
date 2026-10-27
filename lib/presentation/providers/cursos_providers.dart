import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:app_finnegans/presentation/utils/period_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final cursosProvider = FutureProvider<List<Curso>>((ref) async {
  final repo = ref.watch(cursosRepositoryProvider);
  return repo.getCursos();
});

class CursoViewModel {
  final Curso curso;
  final String nombreInstructor;

  /// Colaboradores distintos que cargaron horas del curso en el CRM (en un
  /// curso de dictado, quienes lo dictaron).
  final int personas;

  /// Horas cargadas en el CRM para el curso.
  final double horasCrm;

  /// Colaboradores distintos con la finalización del curso en el LMS.
  final int finalizaron;

  CursoViewModel({
    required this.curso,
    required this.nombreInstructor,
    this.personas = 0,
    this.horasCrm = 0,
    this.finalizaron = 0,
  });

  /// `null` si nadie cargó horas del curso.
  double? get promedioHorasPorPersona =>
      personas == 0 ? null : horasCrm / personas;
}

final busquedaCursoProvider = StateProvider<String>((ref) => '');
final filtroTipoCursoProvider = StateProvider<TipoCurso?>((ref) => null);

// Período de las métricas del catálogo (null = todos). No es el período
// global: filtrar acá no cambia lo que muestran Dashboard o Equipos.
final filtroAnioCursosProvider = StateProvider<int?>((ref) => null);
final filtroMesCursosProvider = StateProvider<int?>((ref) => null);

/// Años con cargas CRM o finalizaciones LMS, del más reciente al más viejo.
final aniosCursosDisponiblesProvider = Provider<AsyncValue<List<int>>>((ref) {
  final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
  final certificacionesAsync = ref.watch(certificacionesMoodleProvider);
  return cargasAsync.whenData((cargas) {
    final anios = <int>{
      for (final carga in cargas) carga.fecha.year,
      for (final certificacion
          in certificacionesAsync.value ?? const <CertificacionMoodle>[])
        ?certificacion.fechaFinalizacion?.year,
    };
    return anios.toList()..sort((a, b) => b.compareTo(a));
  });
});

final cursosConInstructorProvider = Provider<AsyncValue<List<CursoViewModel>>>((
  ref,
) {
  final cursosAsync = ref.watch(cursosProvider);
  final empleadosAsync = ref.watch(empleadosProvider);
  final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
  final certificacionesAsync = ref.watch(certificacionesMoodleProvider);
  final query = ref.watch(busquedaCursoProvider).toLowerCase();
  final tipoFiltro = ref.watch(filtroTipoCursoProvider);
  final anioFiltro = ref.watch(filtroAnioCursosProvider);
  final mesFiltro = ref.watch(filtroMesCursosProvider);
  final selection = ref.watch(dataFilterSelectionProvider('cursos'));

  final asyncValues = [
    cursosAsync,
    empleadosAsync,
    cargasAsync,
    certificacionesAsync,
  ];
  if (asyncValues.any((value) => value.isLoading)) {
    return const AsyncValue.loading();
  }
  final error = asyncValues.where((value) => value.hasError).firstOrNull;
  if (error != null) return AsyncValue.error(error.error!, error.stackTrace!);

  final cursos = cursosAsync.value ?? [];
  final empleados = empleadosAsync.value ?? [];
  final empMap = {
    for (var e in empleados) e.legajo: '${e.nombre} ${e.apellido}',
  };

  bool enPeriodo(DateTime fecha) =>
      coincidePeriodo(fecha, anio: anioFiltro, mes: mesFiltro);

  // Mismo cruce por nombre normalizado que el cálculo de cumplimiento.
  final legajosCrm = <String, Set<String>>{};
  final horasCrm = <String, double>{};
  // Todas las cargas cuentan, también las de dictado: en un curso de tipo
  // Dictado, quienes cargan horas son quienes lo dictan.
  for (final carga in cargasAsync.value ?? const <CargaDeHorasCRM>[]) {
    if (!enPeriodo(carga.fecha)) continue;
    final clave = CumplimientoService.normalizarNombreCurso(carga.cursoNombre);
    legajosCrm.putIfAbsent(clave, () => {}).add(carga.empleadoLegajo);
    horasCrm[clave] = (horasCrm[clave] ?? 0) + carga.horasTotales;
  }
  final legajosFinalizados = <String, Set<String>>{};
  for (final certificacion
      in certificacionesAsync.value ?? const <CertificacionMoodle>[]) {
    final fecha = certificacion.fechaFinalizacion;
    if (!certificacion.finalizoCurso || fecha == null || !enPeriodo(fecha)) {
      continue;
    }
    legajosFinalizados
        .putIfAbsent(
          CumplimientoService.normalizarNombreCurso(certificacion.cursoNombre),
          () => {},
        )
        .add(certificacion.legajo);
  }

  final viewModels = cursos
      .map((c) {
        final clave = CumplimientoService.normalizarNombreCurso(c.nombre);
        return CursoViewModel(
          curso: c,
          nombreInstructor: empMap[c.instructorLegajo] ?? c.instructorLegajo,
          personas: legajosCrm[clave]?.length ?? 0,
          horasCrm: horasCrm[clave] ?? 0,
          finalizaron: legajosFinalizados[clave]?.length ?? 0,
        );
      })
      .where((vm) {
        final matchesQuery =
            vm.curso.nombre.toLowerCase().contains(query) ||
            vm.curso.areaCurso.toLowerCase().contains(query) ||
            vm.nombreInstructor.toLowerCase().contains(query);

        final matchesTipo = tipoFiltro == null || vm.curso.clasificacion == tipoFiltro;

        return matchesQuery &&
            matchesTipo &&
            matchesDataFilters(
              selection,
              cursoFilterRow(vm.curso, vm.nombreInstructor),
            );
      })
      .toList();

  return AsyncValue.data(viewModels);
});
