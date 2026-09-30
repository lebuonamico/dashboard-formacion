import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

// --- ENUMS Y VIEWMODELS ---

enum EstadoSemaforo {
  verde(Color(0xFF16A34A), Color(0xFFDCFCE7), 'En objetivo'),
  amarillo(Color(0xFFD97706), Color(0xFFFEF3C7), 'En riesgo'),
  rojo(Color(0xFFDC2626), Color(0xFFFEE2E2), 'Crítico');

  final Color colorTexto;
  final Color colorFondo;
  final String label;

  const EstadoSemaforo(this.colorTexto, this.colorFondo, this.label);

  static EstadoSemaforo desdePorcentaje(double porcentaje) {
    if (porcentaje >= 100.0) return EstadoSemaforo.verde;
    if (porcentaje >= 70.0) return EstadoSemaforo.amarillo;
    return EstadoSemaforo.rojo;
  }
}

class KpisGeneralesViewModel {
  final double porcentajeFinnencersAlcanzados;
  final int totalFinnencersAlcanzados;
  final int totalNomina;
  final double proyectadoAnualPromedio;
  final double horasRequeridasAnuales;
  final double totalHorasDictadas;

  KpisGeneralesViewModel({
    required this.porcentajeFinnencersAlcanzados,
    required this.totalFinnencersAlcanzados,
    required this.totalNomina,
    required this.proyectadoAnualPromedio,
    required this.horasRequeridasAnuales,
    required this.totalHorasDictadas,
  });
}

class DesvioCategoriaViewModel {
  final TipoCurso tipo;
  final double horasRequeridas;
  final double horasRealizadas;
  final double desvio; // Realizadas - Requeridas

  DesvioCategoriaViewModel({
    required this.tipo,
    required this.horasRequeridas,
    required this.horasRealizadas,
    required this.desvio,
  });
}

class SeniorityMetricaViewModel {
  final Seniority seniority;
  final int cantidadEmpleados;
  final double totalHorasRequeridas;
  final double totalHorasRealizadas;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;
  final List<DesvioCategoriaViewModel> desviosPorCategoria;

  SeniorityMetricaViewModel({
    required this.seniority,
    required this.cantidadEmpleados,
    required this.totalHorasRequeridas,
    required this.totalHorasRealizadas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
    required this.desviosPorCategoria,
  });
}

class SemaforoAreaViewModel {
  final String area;
  final int cantidadColaboradores;
  final double horasCompletadas;
  final double horasRequeridas;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;

  SemaforoAreaViewModel({
    required this.area,
    required this.cantidadColaboradores,
    required this.horasCompletadas,
    required this.horasRequeridas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
  });
}

class InstructorMetricaViewModel {
  final String legajo;
  final String nombreCompleto;
  final String area;
  final Seniority seniority;
  final int variedadCursosDistintos;
  final double totalHorasDictadas;
  final List<Curso> cursosDictados;

  InstructorMetricaViewModel({
    required this.legajo,
    required this.nombreCompleto,
    required this.area,
    required this.seniority,
    required this.variedadCursosDistintos,
    required this.totalHorasDictadas,
    required this.cursosDictados,
  });
}

// --- FILTROS DE TIEMPO ---

final filtroMesMetricasProvider = StateProvider<int?>((ref) => null);
final mesCorteProyeccionProvider = Provider<int>((ref) => 9);

// --- PROVIDERS DE MÉTRICAS CALCULADAS ---

// 1. KPIs Generales
final kpisGeneralesMetricasProvider = FutureProvider<KpisGeneralesViewModel>((
  ref,
) async {
  final empleados = await ref.watch(empleadosProvider.future);
  final cargasDeHoras = await ref.watch(cargasDeHorasCRMProvider.future);
  final cursos = await ref.watch(cursosProvider.future);
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final mesCorte = ref.watch(mesCorteProyeccionProvider);

  final totalNomina = empleados.length;
  if (totalNomina == 0) {
    return KpisGeneralesViewModel(
      porcentajeFinnencersAlcanzados: 0,
      totalFinnencersAlcanzados: 0,
      totalNomina: 0,
      proyectadoAnualPromedio: 0,
      horasRequeridasAnuales: 96.0,
      totalHorasDictadas: 0,
    );
  }

  final legajosConAsistencia = cargasDeHoras
      .map((carga) => carga.empleadoLegajo)
      .toSet();
  final totalAlcanzados = legajosConAsistencia.length;
  final porcentajeAlcanzados = (totalAlcanzados / totalNomina) * 100;

  final sumaHorasRealizadas = cumplimientos.fold<double>(
    0.0,
    (acc, c) => acc + c.totalHorasCompletadas,
  );
  final promedioActualPorPersona = sumaHorasRealizadas / totalNomina;

  final mesesTranscurridos = mesCorte.clamp(1, 12);
  final proyectadoAnual = (promedioActualPorPersona / mesesTranscurridos) * 12;

  final horasDictadas = cursos.fold<double>(
    0.0,
    (acc, cur) => acc + cur.cargaHorariaHs,
  );

  return KpisGeneralesViewModel(
    porcentajeFinnencersAlcanzados: porcentajeAlcanzados,
    totalFinnencersAlcanzados: totalAlcanzados,
    totalNomina: totalNomina,
    proyectadoAnualPromedio: proyectadoAnual,
    horasRequeridasAnuales: 96.0,
    totalHorasDictadas: horasDictadas,
  );
});

// 2. Cumplimiento, Desvíos y Semáforo por Seniority
final cumplimientoPorSeniorityProvider =
    FutureProvider<List<SeniorityMetricaViewModel>>((ref) async {
      final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);

      final agrupadoPorSeniority = <Seniority, List<dynamic>>{};
      for (final item in cumplimientos) {
        agrupadoPorSeniority
            .putIfAbsent(item.empleado.seniority, () => [])
            .add(item);
      }

      final resultado = <SeniorityMetricaViewModel>[];

      for (final seniority in Seniority.values) {
        final listaItems = agrupadoPorSeniority[seniority] ?? [];
        if (listaItems.isEmpty) continue;

        double totalRequeridas = 0;
        double totalRealizadas = 0;
        final horasReqPorTipo = <TipoCurso, double>{};
        final horasRealPorTipo = <TipoCurso, double>{};

        for (final item in listaItems) {
          totalRequeridas += item.totalHorasRequeridas;
          totalRealizadas += item.totalHorasCompletadas;

          for (final tipo in TipoCurso.values) {
            horasReqPorTipo[tipo] =
                (horasReqPorTipo[tipo] ?? 0) +
                (item.horasRequeridas[tipo] ?? 0);
            horasRealPorTipo[tipo] =
                (horasRealPorTipo[tipo] ?? 0) +
                (item.horasCompletadas[tipo] ?? 0);
          }
        }

        final desvios = TipoCurso.values.map((tipo) {
          final req = horasReqPorTipo[tipo] ?? 0.0;
          final real = horasRealPorTipo[tipo] ?? 0.0;
          return DesvioCategoriaViewModel(
            tipo: tipo,
            horasRequeridas: req,
            horasRealizadas: real,
            desvio: real - req,
          );
        }).toList();

        final porcentaje = totalRequeridas == 0
            ? 100.0
            : (totalRealizadas / totalRequeridas) * 100;

        resultado.add(
          SeniorityMetricaViewModel(
            seniority: seniority,
            cantidadEmpleados: listaItems.length,
            totalHorasRequeridas: totalRequeridas,
            totalHorasRealizadas: totalRealizadas,
            porcentajeCumplimiento: porcentaje,
            semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
            desviosPorCategoria: desvios,
          ),
        );
      }

      return resultado;
    });

// 3. Semáforos de Cumplimiento por Área
final semaforoPorAreaProvider = FutureProvider<List<SemaforoAreaViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoDashboardProvider.future);

  final agrupadoPorArea = <String, List<dynamic>>{};
  for (final item in cumplimientos) {
    agrupadoPorArea.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final resultado = <SemaforoAreaViewModel>[];

  agrupadoPorArea.forEach((area, listaItems) {
    final horasCompletadas = listaItems.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasCompletadas,
    );
    final horasRequeridas = listaItems.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasRequeridas,
    );

    final porcentaje = horasRequeridas == 0
        ? 100.0
        : (horasCompletadas / horasRequeridas) * 100;

    resultado.add(
      SemaforoAreaViewModel(
        area: area,
        cantidadColaboradores: listaItems.length,
        horasCompletadas: horasCompletadas,
        horasRequeridas: horasRequeridas,
        porcentajeCumplimiento: porcentaje,
        semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
      ),
    );
  });

  resultado.sort(
    (a, b) => b.porcentajeCumplimiento.compareTo(a.porcentajeCumplimiento),
  );
  return resultado;
});

// 4. Métricas de Instructores con Modelos completos de Curso
final metricasInstructoresProvider =
    FutureProvider<List<InstructorMetricaViewModel>>((ref) async {
      final empleados = await ref.watch(empleadosProvider.future);
      final cursos = await ref.watch(cursosProvider.future);

      final empMap = {for (var e in empleados) e.legajo: e};

      final cursosPorInstructor = <String, List<Curso>>{};
      for (final curso in cursos) {
        cursosPorInstructor
            .putIfAbsent(curso.instructorLegajo, () => [])
            .add(curso);
      }

      final resultado = <InstructorMetricaViewModel>[];

      cursosPorInstructor.forEach((legajo, listaCursos) {
        final emp = empMap[legajo];
        if (emp == null) return;

        final idsCursosDistintos = listaCursos.map((c) => c.id).toSet();
        final totalHoras = listaCursos.fold<double>(
          0.0,
          (acc, c) => acc + c.cargaHorariaHs,
        );

        resultado.add(
          InstructorMetricaViewModel(
            legajo: emp.legajo,
            nombreCompleto: '${emp.nombre} ${emp.apellido}',
            area: emp.area,
            seniority: emp.seniority,
            variedadCursosDistintos: idsCursosDistintos.length,
            totalHorasDictadas: totalHoras,
            cursosDictados: List<Curso>.from(listaCursos),
          ),
        );
      });

      resultado.sort(
        (a, b) => b.totalHorasDictadas.compareTo(a.totalHorasDictadas),
      );
      return resultado;
    });
