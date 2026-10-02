import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CumplimientoService {
  List<CumplimientoEmpleado> calcularCumplimientoGlobal({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<CargaDeHorasCRM> cargasDeHoras,
    required List<CertificacionMoodle> certificacionesMoodle,
  }) {
    final cursosMap = {
      for (final curso in cursos) normalizarNombreCurso(curso.nombre): curso,
    };

    return empleados.map((empleado) {
      final horasValidas = <TipoCurso, double>{
        TipoCurso.habilidadesDeNegocio: 0.0,
        TipoCurso.habilidadesBlandas: 0.0,
        TipoCurso.libresExploracion: 0.0,
        TipoCurso.dictadoCapacitaciones: 0.0,
      };
      final horasDeclaradas = <TipoCurso, double>{
        TipoCurso.habilidadesDeNegocio: 0.0,
        TipoCurso.habilidadesBlandas: 0.0,
        TipoCurso.libresExploracion: 0.0,
        TipoCurso.dictadoCapacitaciones: 0.0,
      };

      final cargasTomadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && !carga.esDictada,
      );
      final horasCrmPorCurso = <String, double>{};
      for (final carga in cargasTomadas) {
        final cursoNormalizado = normalizarNombreCurso(carga.cursoNombre);
        final curso = cursosMap[cursoNormalizado];
        if (curso != null) {
          horasDeclaradas[curso.tipo] =
              (horasDeclaradas[curso.tipo] ?? 0) + carga.horasTotales;
          horasCrmPorCurso.update(
            cursoNormalizado,
            (horas) => horas + carga.horasTotales,
            ifAbsent: () => carga.horasTotales,
          );
        }
      }

      // LMS confirma la finalización; CRM aporta las horas y Cursos fija el máximo.
      final cursosValidados = <String>{};
      for (final certificacion in certificacionesMoodle) {
        final cursoNormalizado = normalizarNombreCurso(
          certificacion.cursoNombre,
        );
        if (certificacion.legajo != empleado.legajo ||
            !certificacion.finalizoCurso ||
            !cursosValidados.add(cursoNormalizado)) {
          continue;
        }

        final curso = cursosMap[cursoNormalizado];
        if (curso == null) continue;

        final horasRegistradas = horasCrmPorCurso[cursoNormalizado] ?? 0;
        final cargaMaxima = curso.cargaHorariaHs < 0
            ? 0.0
            : curso.cargaHorariaHs;
        final horasAcreditadas = horasRegistradas
            .clamp(0.0, cargaMaxima)
            .toDouble();
        horasValidas[curso.tipo] =
            (horasValidas[curso.tipo] ?? 0) + horasAcreditadas;
      }

      // Las horas dictadas se obtienen directamente del CRM.
      final cargasDictadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && carga.esDictada,
      );
      for (final carga in cargasDictadas) {
        horasDeclaradas[TipoCurso.dictadoCapacitaciones] =
            (horasDeclaradas[TipoCurso.dictadoCapacitaciones] ?? 0) +
            carga.horasTotales;
      }

      // Requerimientos mensuales según el seniority del empleado.
      final horasRequeridas = empleado.seniority.planFormacion;

      return CumplimientoEmpleado(
        empleado: empleado,
        horasValidas: horasValidas,
        horasDeclaradas: horasDeclaradas,
        horasRequeridas: horasRequeridas,
      );
    }).toList();
  }

  static String normalizarNombreCurso(String nombre) => nombre
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
