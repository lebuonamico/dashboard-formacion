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
      for (final curso in cursos) _normalizarNombreCurso(curso.nombre): curso,
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

      // Moodle validates course hours only after the course is completed.
      for (final certificacion in certificacionesMoodle) {
        if (certificacion.legajo != empleado.legajo ||
            !certificacion.finalizoCurso) {
          continue;
        }
        final curso =
            cursosMap[_normalizarNombreCurso(certificacion.cursoNombre)];
        if (curso != null) {
          horasValidas[curso.tipo] =
              (horasValidas[curso.tipo] ?? 0) + certificacion.cargaEstimada;
        }
      }

      // CRM hours remain declared hours and do not contribute to compliance.
      final cargasTomadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && !carga.esDictada,
      );
      for (final carga in cargasTomadas) {
        final curso = cursosMap[_normalizarNombreCurso(carga.cursoNombre)];
        if (curso != null) {
          horasDeclaradas[curso.tipo] =
              (horasDeclaradas[curso.tipo] ?? 0) + carga.horasTotales;
        }
      }

      // 2. Horas como instructor (Dictado de capacitaciones)
      final cargasDictadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && carga.esDictada,
      );
      for (final carga in cargasDictadas) {
        horasDeclaradas[TipoCurso.dictadoCapacitaciones] =
            (horasDeclaradas[TipoCurso.dictadoCapacitaciones] ?? 0) +
            carga.horasTotales;
      }

      // 3. Requerimientos por Seniority
      final horasRequeridas = empleado.seniority.planFormacion;

      return CumplimientoEmpleado(
        empleado: empleado,
        horasValidas: horasValidas,
        horasDeclaradas: horasDeclaradas,
        horasRequeridas: horasRequeridas,
      );
    }).toList();
  }

  String _normalizarNombreCurso(String nombre) => nombre
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
