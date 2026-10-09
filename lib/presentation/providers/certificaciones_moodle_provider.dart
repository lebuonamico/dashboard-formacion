import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final certificacionesMoodleProvider = FutureProvider<List<CertificacionMoodle>>(
  (ref) {
    return ref
        .watch(certificacionesMoodleRepositoryProvider)
        .getCertificaciones();
  },
);

final busquedaCertificacionMoodleProvider = StateProvider<String>((ref) => '');

/// `null` muestra todas, `true` solo las finalizadas y `false` las pendientes.
final filtroEstadoCertificacionProvider = StateProvider<bool?>((ref) => null);

/// Certificación del LMS cruzada con la nómina y el catálogo.
class CertificacionViewModel {
  final CertificacionMoodle certificacion;
  final Empleado? empleado;
  final Curso? curso;

  const CertificacionViewModel({
    required this.certificacion,
    required this.empleado,
    required this.curso,
  });

  /// Sin curso en el catálogo la finalización no acredita horas (regla
  /// triangular de CumplimientoService).
  bool get cursoFueraDeCatalogo => curso == null;

  bool get legajoFueraDeNomina => empleado == null;

  bool get fueraDelCalculo => cursoFueraDeCatalogo || legajoFueraDeNomina;
}

/// Todas las certificaciones importadas, sin filtrar y ordenadas: las más
/// recientes primero y las que no tienen fecha (pendientes) al final.
final certificacionesCompletasProvider =
    Provider<AsyncValue<List<CertificacionViewModel>>>((ref) {
      final certificacionesAsync = ref.watch(certificacionesMoodleProvider);
      final empleadosAsync = ref.watch(empleadosProvider);
      final cursosAsync = ref.watch(cursosProvider);

      if (certificacionesAsync.isLoading ||
          empleadosAsync.isLoading ||
          cursosAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (certificacionesAsync.hasError) {
        return AsyncValue.error(
          certificacionesAsync.error!,
          certificacionesAsync.stackTrace!,
        );
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

      final empMap = {for (final e in empleadosAsync.value ?? []) e.legajo: e};
      // Mismo normalizador que el cálculo de cumplimiento: así el aviso de
      // "fuera de catálogo" coincide con lo que realmente no acredita.
      final cursoMap = {
        for (final curso in cursosAsync.value ?? <Curso>[])
          CumplimientoService.normalizarNombreCurso(curso.nombre): curso,
      };

      final viewModels = [
        for (final certificacion in certificacionesAsync.value ?? [])
          CertificacionViewModel(
            certificacion: certificacion,
            empleado: empMap[certificacion.legajo],
            curso:
                cursoMap[CumplimientoService.normalizarNombreCurso(
                  certificacion.cursoNombre,
                )],
          ),
      ];

      viewModels.sort((a, b) {
        final fechaA = a.certificacion.fechaFinalizacion;
        final fechaB = b.certificacion.fechaFinalizacion;
        if (fechaA != null && fechaB != null) {
          final porFecha = fechaB.compareTo(fechaA);
          if (porFecha != 0) return porFecha;
        } else if (fechaA != null) {
          return -1;
        } else if (fechaB != null) {
          return 1;
        }
        return a.certificacion.cursoNombre.toLowerCase().compareTo(
          b.certificacion.cursoNombre.toLowerCase(),
        );
      });

      return AsyncValue.data(viewModels);
    });

final certificacionesFiltradasProvider =
    Provider<AsyncValue<List<CertificacionViewModel>>>((ref) {
      final completasAsync = ref.watch(certificacionesCompletasProvider);
      final query = ref
          .watch(busquedaCertificacionMoodleProvider)
          .trim()
          .toLowerCase();
      final estadoFiltro = ref.watch(filtroEstadoCertificacionProvider);

      return completasAsync.whenData((items) {
        return items.where((vm) {
          final emp = vm.empleado;
          final matchesQuery =
              query.isEmpty ||
              vm.certificacion.legajo.toLowerCase().contains(query) ||
              vm.certificacion.cursoNombre.toLowerCase().contains(query) ||
              (emp != null &&
                  ('${emp.nombre} ${emp.apellido}'.toLowerCase().contains(
                        query,
                      ) ||
                      emp.area.toLowerCase().contains(query) ||
                      emp.equipo.toLowerCase().contains(query)));

          final matchesEstado =
              estadoFiltro == null ||
              vm.certificacion.finalizoCurso == estadoFiltro;

          return matchesQuery && matchesEstado;
        }).toList();
      });
    });
