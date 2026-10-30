import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';

final cargasDashboardProvider = FutureProvider<List<CargaDeHorasCRM>>((
  ref,
) async {
  final alcance = ref.watch(alcancePeriodoProvider);
  final mes = ref.watch(filtroMesPeriodoProvider);
  final anio = ref.watch(filtroAnioPeriodoProvider);

  final desde = DateTime(anio, alcance == AlcancePeriodo.anual ? 1 : mes);
  final hasta = alcance == AlcancePeriodo.anual
      ? DateTime(anio + 1)
      : DateTime(anio, mes + 1);
  // Las horas ya están en memoria (con el alcance del usuario): cambiar el
  // período filtra, no vuelve a consultar la base.
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  return cargas
      .where(
        (carga) => !carga.fecha.isBefore(desde) && carga.fecha.isBefore(hasta),
      )
      .toList();
});

/// Misma base que Equipos y Áreas: nómina elegible del período,
/// certificaciones finalizadas en el período y, en el anual, la suma de los
/// meses con datos contra sus objetivos mensuales. Así los KPIs del Dashboard
/// coinciden con los de las otras pantallas.
final cumplimientoDashboardProvider =
    FutureProvider<List<CumplimientoEmpleado>>((ref) {
      return ref.watch(teamComplianceProvider.future);
    });

/// Meses que se evaluaron en el período: 1 en el mensual; en el anual, los
/// meses con registros CRM o LMS, igual que el acumulado de Equipos.
final mesesEvaluadosDashboardProvider = FutureProvider<int>((ref) async {
  if (ref.watch(alcancePeriodoProvider) == AlcancePeriodo.mensual) return 1;

  final anio = ref.watch(filtroAnioPeriodoProvider);
  final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final equiposService = ref.read(teamsServiceProvider);
  var meses = 0;
  for (var mes = 1; mes <= 12; mes++) {
    if (equiposService.periods.hasDataInPeriod(
      timeEntries: cargas,
      certifications: certificaciones,
      year: anio,
      month: mes,
      isAnnual: false,
    )) {
      meses++;
    }
  }
  // Nunca 0, para poder dividir el ritmo mensual.
  return meses == 0 ? 1 : meses;
});

/// Horas válidas promedio por colaborador elegible en los 4 meses que terminan
/// en el período elegido (en el anual, el último mes del año con datos).
final evolucionMensualDashboardProvider =
    FutureProvider<List<({DateTime mes, double horas})>>((ref) async {
      final alcance = ref.watch(alcancePeriodoProvider);
      final mesElegido = ref.watch(filtroMesPeriodoProvider);
      final anio = ref.watch(filtroAnioPeriodoProvider);
      final empleados = await ref.watch(empleadosProvider.future);
      final historial = await ref.watch(empleadoHistorialProvider.future);
      final cursos = await ref.watch(cursosProvider.future);
      final cargas = await ref.watch(cargasDeHorasCRMProvider.future);
      final certificaciones = await ref.watch(
        certificacionesMoodleProvider.future,
      );
      final alcanceUsuario = await ref.watch(alcanceUsuarioProvider.future);
      final incluir = alcanceUsuario.esTotal
          ? null
          : alcanceUsuario.incluyeEmpleado;
      final cumplimientoService = await ref.watch(
        cumplimientoServiceProvider.future,
      );
      final equiposService = ref.read(teamsServiceProvider);

      bool tieneDatos(DateTime fecha) => equiposService.periods.hasDataInPeriod(
        timeEntries: cargas,
        certifications: certificaciones,
        year: fecha.year,
        month: fecha.month,
        isAnnual: false,
      );

      var mesFinal = DateTime(anio, mesElegido);
      if (alcance == AlcancePeriodo.anual) {
        mesFinal = DateTime(anio, 12);
        while (mesFinal.month > 1 && !tieneDatos(mesFinal)) {
          mesFinal = DateTime(anio, mesFinal.month - 1);
        }
        if (!tieneDatos(mesFinal)) mesFinal = DateTime(anio, 12);
      }

      return [
        for (var offset = 3; offset >= 0; offset--)
          (() {
            final fecha = DateTime(mesFinal.year, mesFinal.month - offset);
            if (!tieneDatos(fecha)) return (mes: fecha, horas: 0.0);
            final cumplimientos = equiposService.periods
                .calculateMonthlyCompliance(
                  employees: empleados,
                  history: historial,
                  courses: cursos,
                  timeEntries: cargas,
                  certifications: certificaciones,
                  year: fecha.year,
                  month: fecha.month,
                  complianceService: cumplimientoService,
                  includeEmployee: incluir,
                );
            if (cumplimientos.isEmpty) return (mes: fecha, horas: 0.0);
            final total = cumplimientos.fold<double>(
              0,
              (t, item) => t + item.totalHorasValidas,
            );
            return (mes: fecha, horas: total / cumplimientos.length);
          })(),
      ];
    });

final cumplimientoGlobalProvider = FutureProvider<List<CumplimientoEmpleado>>((
  ref,
) async {
  final empleados = await ref.watch(empleadosProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final certificaciones = await ref.watch(certificacionesMoodleProvider.future);
  final service = await ref.watch(cumplimientoServiceProvider.future);

  return service.calcularCumplimientoGlobal(
    empleados: empleados,
    cursos: cursos,
    cargasDeHoras: cargasDeHoras,
    certificacionesMoodle: certificaciones,
  );
});
