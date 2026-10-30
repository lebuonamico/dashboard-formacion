import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
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
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Nómina tal como la devuelve la base para la sesión (con RLS), leída una
/// sola vez. La comparten [empleadosProvider] y [empleadoDeSesionProvider].
final nominaProvider = FutureProvider<List<Empleado>>((ref) {
  // Con RLS cada usuario recibe filas distintas: otra sesión vuelve a leer.
  ref.watch(sesionDatosProvider);
  return ref.watch(empleadosRepositoryProvider).getEmpleados();
});

/// Nómina que ve el usuario de la sesión, según su rol y las áreas o equipos
/// que lidera.
final empleadosProvider = FutureProvider<List<Empleado>>((ref) async {
  // La nómina va primero: si falla, ese es el error que tiene que verse.
  final empleados = await ref.watch(nominaProvider.future);
  final alcance = await ref.watch(alcanceUsuarioProvider.future);
  return empleados.where(alcance.incluyeEmpleado).toList();
});

/// Legajos que ve el usuario, o `null` si ve toda la empresa. Filtra las
/// horas y las finalizaciones con el mismo criterio que la nómina.
final legajosVisiblesProvider = FutureProvider<Set<String>?>((ref) async {
  final alcance = await ref.watch(alcanceUsuarioProvider.future);
  if (alcance.esTotal) return null;
  final empleados = await ref.watch(empleadosProvider.future);
  return {for (final empleado in empleados) empleado.legajo};
});

final empleadoHistorialProvider = FutureProvider<List<EmpleadoHistorial>?>((
  ref,
) async {
  final repo = ref.watch(empleadosRepositoryProvider);
  if (repo is! EmpleadosHistorialRepository) return null;
  // Con RLS cada usuario recibe vigencias distintas: se vuelve a consultar
  // cuando entra otro en la misma pestaña.
  ref.watch(sesionDatosProvider);
  // Leandro: llama a getHistorialEmpleados para consultar las vigencias sin escribir un historial paralelo.
  return (repo as EmpleadosHistorialRepository).getHistorialEmpleados();
});

final busquedaEmpleadoProvider = StateProvider<String>((ref) => '');
final filtroSeniorityProvider = StateProvider<Seniority?>((ref) => null);

final empleadosFiltradosProvider = Provider<AsyncValue<List<Empleado>>>((ref) {
  final empleadosAsync = ref.watch(empleadosProvider);
  final query = ref.watch(busquedaEmpleadoProvider).toLowerCase();
  final seniorityFiltro = ref.watch(filtroSeniorityProvider);
  final selection = ref.watch(dataFilterSelectionProvider('personas'));

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

      return matchesQuery &&
          matchesSeniority &&
          matchesDataFilters(selection, empleadoFilterRow(emp));
    }).toList();
  });
});

/// Curso que el empleado cargó en el CRM como dictado, con las horas del período.
class CursoDictadoViewModel {
  final String codigo;
  final String nombre;
  final String area;
  final double horas;

  const CursoDictadoViewModel({
    required this.codigo,
    required this.nombre,
    required this.area,
    required this.horas,
  });
}

class DetalleEmpleadoViewModel {
  final Empleado empleado;
  final CumplimientoEmpleado cumplimiento;
  final List<CargaDeHorasCRMViewModel> cargasCrm;
  final List<CertificacionMoodle> certificacionesMoodle;
  final Map<String, Curso> cursosPorNombre;
  final List<CursoDictadoViewModel> cursosDictados;
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
      final cumplimientoService = await ref.watch(
        cumplimientoServiceProvider.future,
      );
      final equiposService = ref.read(teamsServiceProvider);
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

      final cargasPeriodo = equiposService.periods.filterTimeEntriesByPeriod(
        timeEntries: cargasEmpleado,
        year: anio,
        month: mes,
        isAnnual: esAnual,
      );
      // Solo las finalizadas del período suman cumplimiento.
      final certificacionesValidasPeriodo = equiposService.periods
          .filterCertificationsByPeriod(
            certifications: certificacionesEmpleado,
            year: anio,
            month: mes,
            isAnnual: esAnual,
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
            anio: anio,
            mes: mes,
          )
          .first;
      if (esAnual) {
        // Objetivo del año: los 12 meses, cada uno con su versión del plan.
        cumplimiento = CumplimientoEmpleado(
          empleado: cumplimiento.empleado,
          horasValidas: cumplimiento.horasValidas,
          horasDeclaradas: cumplimiento.horasDeclaradas,
          horasRequeridas: cumplimientoService.planes.requeridasDelAnio(
            empleado.seniority,
            anio,
          ),
        );
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

      // Los dictados salen del CRM (Clasificación "Dictado de capacitaciones").
      final dictadosPorCurso = <String, List<CargaDeHorasCRMViewModel>>{};
      for (final item in cargasCrm.where((item) => item.carga.esDictada)) {
        final cursoId = item.curso?.id.trim() ?? item.carga.cursoId?.trim();
        final clave = cursoId != null && cursoId.isNotEmpty
            ? 'id:$cursoId'
            : 'nombre:${CumplimientoService.normalizarNombreCurso(item.carga.cursoNombre)}';
        dictadosPorCurso.putIfAbsent(clave, () => []).add(item);
      }
      final dictados =
          dictadosPorCurso.values.map((items) {
            final primero = items.first;
            final curso = primero.curso;
            return CursoDictadoViewModel(
              codigo: curso?.id ?? primero.carga.cursoId ?? '',
              nombre: curso?.nombre ?? primero.carga.cursoNombre,
              area: curso?.areaCurso ?? primero.carga.descripcionCurso ?? '',
              horas: items.fold<double>(
                0,
                (total, item) => total + item.carga.horasTotales,
              ),
            );
          }).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
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
