import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/periodo_providers.dart';

final cargasDashboardProvider = FutureProvider<List<CargaDeHorasCRM>>((
  ref,
) async {
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);
  final soloRegistrosCargados = ref.watch(
    soloRegistrosCargadosPeriodoProvider,
  );

  if (soloRegistrosCargados) return cargas;

  return cargas.where((carga) {
    if (carga.fecha.year != anio) return false;
    return alcance == AlcancePeriodo.anual || carga.fecha.month == mes;
  }).toList();
});

final cumplimientoDashboardProvider =
    FutureProvider<List<CumplimientoEmpleado>>((ref) async {
      final empleados = await ref.watch(empleadosProvider.future);
      final cursos = await ref.watch(cursosProvider.future);
      final cargas = await ref.watch(cargasDashboardProvider.future);
      final service = ref.read(cumplimientoServiceProvider);
      final cumplimientos = service.calcularCumplimientoGlobal(
        empleados: empleados,
        cursos: cursos,
        cargasDeHoras: cargas,
      );

      return cumplimientos;
    });

final cumplimientoGlobalProvider = FutureProvider<List<CumplimientoEmpleado>>((
  ref,
) async {
  final empleados = await ref.watch(empleadosProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final service = ref.read(cumplimientoServiceProvider);

  return service.calcularCumplimientoGlobal(
    empleados: empleados,
    cursos: cursos,
    cargasDeHoras: cargasDeHoras,
  );
});
