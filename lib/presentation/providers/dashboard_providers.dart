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

  final repo = ref.watch(cargaDeHorasCRMRepositoryProvider);
  final desde = DateTime(anio, alcance == AlcancePeriodo.anual ? 1 : mes);
  final hasta = alcance == AlcancePeriodo.anual
      ? DateTime(anio + 1)
      : DateTime(anio, mes + 1);
  return repo.getCargasDeHoras(desde: desde, hasta: hasta);
});

/// Misma base que Equipos y Áreas: nómina elegible del período,
/// certificaciones finalizadas en el período y, en el anual, la suma de los
/// meses con datos contra sus objetivos mensuales. Así los KPIs del Dashboard
/// coinciden con los de las otras pantallas.
final cumplimientoDashboardProvider =
    FutureProvider<List<CumplimientoEmpleado>>((ref) {
      return ref.watch(cumplimientoEquiposProvider.future);
    });

/// Meses que se evaluaron en el período: 1 en el mensual; en el anual, los
/// meses con registros CRM o LMS, igual que el acumulado de Equipos.
final mesesEvaluadosDashboardProvider = FutureProvider<int>((ref) async {
  if (ref.watch(alcancePeriodoProvider) == AlcancePeriodo.mensual) return 1;

  final anio = ref.watch(filtroAnioPeriodoProvider);
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final equiposService = ref.read(equiposServiceProvider);
  var meses = 0;
  for (var mes = 1; mes <= 12; mes++) {
    if (equiposService.tieneDatosEnPeriodo(
      cargas: cargas,
      certificaciones: certificaciones,
      anio: anio,
      mes: mes,
      esAnual: false,
    )) {
      meses++;
    }
  }
  // Nunca 0, para poder dividir el ritmo mensual.
  return meses == 0 ? 1 : meses;
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
