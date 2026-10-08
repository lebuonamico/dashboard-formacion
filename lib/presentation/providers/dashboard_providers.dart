import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';

final cargasDashboardProvider = FutureProvider<List<CargaDeHorasCRM>>((
  ref,
) async {
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);
  final soloRegistrosCargados = ref.watch(soloRegistrosCargadosPeriodoProvider);

  final repo = ref.watch(cargaDeHorasCRMRepositoryProvider);
  if (soloRegistrosCargados) return repo.getCargasDeHoras();
  final desde = DateTime(anio, alcance == AlcancePeriodo.anual ? 1 : mes);
  final hasta = alcance == AlcancePeriodo.anual
      ? DateTime(anio + 1)
      : DateTime(anio, mes + 1);
  return repo.getCargasDeHoras(desde: desde, hasta: hasta);
});

final hayDatosPeriodoProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(soloRegistrosCargadosPeriodoProvider)) {
    return ref.watch(hayDatosEquiposPeriodoProvider.future);
  }
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  return cargas.isNotEmpty ||
      certificaciones.any((item) => item.fechaFinalizacion != null);
});

final cumplimientoDashboardProvider =
    FutureProvider<List<CumplimientoEmpleado>>((ref) async {
      final empleados = await ref.watch(empleadosProvider.future);
      final cursos = await ref.watch(cursosProvider.future);
      final cargas = await ref.watch(cargasDashboardProvider.future);
      final certificaciones = await ref.watch(
        certificacionesMoodleProvider.future,
      );
      final service = ref.read(cumplimientoServiceProvider);
      final cumplimientos = service.calcularCumplimientoGlobal(
        empleados: empleados,
        cursos: cursos,
        cargasDeHoras: cargas,
        certificacionesMoodle: certificaciones,
      );

      return cumplimientos;
    });

final cumplimientoGlobalProvider = FutureProvider<List<CumplimientoEmpleado>>((
  ref,
) async {
  final empleados = await ref.watch(empleadosProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final service = ref.read(cumplimientoServiceProvider);

  return service.calcularCumplimientoGlobal(
    empleados: empleados,
    cursos: cursos,
    cargasDeHoras: cargasDeHoras,
    certificacionesMoodle: certificaciones,
  );
});
