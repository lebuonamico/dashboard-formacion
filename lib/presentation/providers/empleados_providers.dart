import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado_historial.dart';
import 'package:app_finnegans/domain/repositorios/empleados_historial_repository.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final empleadosProvider = FutureProvider<List<Empleado>>((ref) async {
  final repo = ref.watch(empleadosRepositoryProvider);
  return repo.getEmpleados();
});

final empleadoHistorialProvider = FutureProvider<List<EmpleadoHistorial>?>((
  ref,
) async {
  final repo = ref.watch(empleadosRepositoryProvider);
  if (repo is! EmpleadosHistorialRepository) return null;
  // Leandro: llama a getHistorialEmpleados para consultar las vigencias sin escribir un historial paralelo.
  return (repo as EmpleadosHistorialRepository).getHistorialEmpleados();
});

final busquedaEmpleadoProvider = StateProvider<String>((ref) => '');
final filtroSeniorityProvider = StateProvider<Seniority?>((ref) => null);

final empleadosFiltradosProvider = Provider<AsyncValue<List<Empleado>>>((ref) {
  final empleadosAsync = ref.watch(empleadosProvider);
  final query = ref.watch(busquedaEmpleadoProvider).toLowerCase();
  final seniorityFiltro = ref.watch(filtroSeniorityProvider);

  return empleadosAsync.whenData((empleados) {
    return empleados.where((emp) {
      final matchesQuery =
          emp.nombre.toLowerCase().contains(query) ||
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
  final List<CargaDeHorasCRMViewModel> cargasCrm;
  final List<CertificacionMoodle> certificacionesMoodle;
  final Map<String, Curso> cursosPorNombre;
  final List<Curso> cursosDictados;
  final Set<String> cursosFinalizados;

  DetalleEmpleadoViewModel({
    required this.empleado,
    required this.cumplimiento,
    required this.cargasCrm,
    required this.certificacionesMoodle,
    required this.cursosPorNombre,
    required this.cursosDictados,
    required this.cursosFinalizados,
  });

  /// Busca el curso del catálogo por nombre normalizado.
  Curso? cursoPorNombre(String nombre) =>
      cursosPorNombre[CumplimientoService.normalizarNombreCurso(nombre)];
}

/// Detalle del empleado recalculado para el período global seleccionado.
final detalleEmpleadoProvider =
    FutureProvider.family<DetalleEmpleadoViewModel?, String>((
      ref,
      legajo,
    ) async {
      final empleados = await ref.watch(empleadosProvider.future);
      final cursos = await ref.watch(cursosProvider.future);
      final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
      final certificaciones = await ref.watch(
        certificacionesMoodleProvider.future,
      );
      final alcance = ref.watch(alcancePeriodoProvider);
      final mes = ref.watch(filtroMesPeriodoProvider);
      final anio = ref.watch(filtroAnioPeriodoProvider);
      final soloRegistrosCargados = ref.watch(
        soloRegistrosCargadosPeriodoProvider,
      );
      final cumplimientoService = ref.read(cumplimientoServiceProvider);
      final equiposService = ref.read(equiposServiceProvider);
      final esAnual = alcance == AlcancePeriodo.anual;

      final empleado = empleados
          .where((emp) => emp.legajo == legajo)
          .firstOrNull;
      if (empleado == null) return null;

      final cargasEmpleado = cargas
          .where((carga) => carga.empleadoLegajo == legajo)
          .toList();
      final certificacionesEmpleado = certificaciones
          .where((item) => item.legajo == legajo)
          .toList();

      final cargasPeriodo = equiposService.filtrarCargasPorPeriodo(
        cargas: cargasEmpleado,
        anio: anio,
        mes: mes,
        esAnual: esAnual,
      );
      // Solo las finalizadas del período suman cumplimiento.
      final certificacionesValidasPeriodo = equiposService
          .filtrarCertificacionesPorPeriodo(
            certificaciones: certificacionesEmpleado,
            anio: anio,
            mes: mes,
            esAnual: esAnual,
          );
      // Para mostrar se incluyen todas las que tienen fecha en el período.
      final certificacionesPeriodo =
          certificacionesEmpleado.where((item) {
            final fecha = item.fechaFinalizacion;
            if (fecha == null || fecha.year != anio) return false;
            return esAnual || fecha.month == mes;
          }).toList()..sort(
            (a, b) => b.fechaFinalizacion!.compareTo(a.fechaFinalizacion!),
          );

      var cumplimiento = cumplimientoService
          .calcularCumplimientoGlobal(
            empleados: [empleado],
            cursos: cursos,
            cargasDeHoras: cargasPeriodo,
            certificacionesMoodle: certificacionesValidasPeriodo,
          )
          .first;
      if (esAnual) {
        final mesesObjetivo = soloRegistrosCargados
            ? equiposService.contarMesesConRegistros(
                cargas: cargasPeriodo,
                certificaciones: certificacionesValidasPeriodo,
                anio: anio,
              )
            : 12;
        cumplimiento = equiposService.convertirObjetivoMensualAAnual([
          cumplimiento,
        ], mesesConRegistros: mesesObjetivo).first;
      }

      final cursosPorNombre = {
        for (final curso in cursos)
          CumplimientoService.normalizarNombreCurso(curso.nombre): curso,
      };
      final cargasCrm = cargasPeriodo
          .map(
            (carga) => CargaDeHorasCRMViewModel(
              carga: carga,
              empleado: empleado,
              curso:
                  cursosPorNombre[CumplimientoService.normalizarNombreCurso(
                    carga.cursoNombre,
                  )],
            ),
          )
          .toList();

      final dictados = cursos
          .where((cur) => cur.instructorLegajo == legajo)
          .toList();
      final cursosFinalizados = certificacionesEmpleado
          .where((item) => item.finalizoCurso)
          .map(
            (item) =>
                CumplimientoService.normalizarNombreCurso(item.cursoNombre),
          )
          .toSet();

      return DetalleEmpleadoViewModel(
        empleado: empleado,
        cumplimiento: cumplimiento,
        cargasCrm: cargasCrm,
        certificacionesMoodle: certificacionesPeriodo,
        cursosPorNombre: cursosPorNombre,
        cursosDictados: dictados,
        cursosFinalizados: cursosFinalizados,
      );
    });
