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
    final cargasPorLegajo = <String, List<CargaDeHorasCRM>>{};
    for (final carga in cargasDeHoras) {
      cargasPorLegajo.putIfAbsent(carga.empleadoLegajo, () => []).add(carga);
    }
    final certificacionesPorLegajo = <String, List<CertificacionMoodle>>{};
    for (final certificacion in certificacionesMoodle) {
      certificacionesPorLegajo
          .putIfAbsent(certificacion.legajo, () => [])
          .add(certificacion);
    }

    return empleados.map((empleado) {
      // Leandro: llama a _horasPorCategoriaEnCero para inicializar las horas del colaborador sin inventar actividad.
      final horasValidas = _horasPorCategoriaEnCero();
      final horasDeclaradas = _horasPorCategoriaEnCero();

      final cargasEmpleado =
          cargasPorLegajo[empleado.legajo] ?? const <CargaDeHorasCRM>[];
      for (final carga in cargasEmpleado) {
        // Libres y Dictado no pasan por el LMS: la Clasificación CRM las acredita.
        final categoriaSoloCrm = carga.categoriaSoloCrm;
        if (categoriaSoloCrm != null) {
          horasDeclaradas[categoriaSoloCrm] =
              (horasDeclaradas[categoriaSoloCrm] ?? 0) + carga.horasTotales;
          horasValidas[categoriaSoloCrm] =
              (horasValidas[categoriaSoloCrm] ?? 0) + carga.horasTotales;
          continue;
        }

        // Leandro: llama a normalizarNombreCurso para buscar el curso CRM en el catálogo con un nombre uniforme.
        final cursoNormalizado = normalizarNombreCurso(carga.cursoNombre);
        final curso = cursosMap[cursoNormalizado];
        if (curso != null) {
          horasDeclaradas[curso.tipo] =
              (horasDeclaradas[curso.tipo] ?? 0) + carga.horasTotales;
        }
      }

      // Negocio y Blandas: cada curso finalizado en el LMS acredita su carga horaria.
      final cursosValidados = <String>{};
      final certificacionesEmpleado =
          certificacionesPorLegajo[empleado.legajo] ??
          const <CertificacionMoodle>[];
      for (final certificacion in certificacionesEmpleado) {
        // Leandro: llama a normalizarNombreCurso para buscar el curso finalizado en el catálogo.
        final cursoNormalizado = normalizarNombreCurso(
          certificacion.cursoNombre,
        );
        if (!certificacion.finalizoCurso ||
            !cursosValidados.add(cursoNormalizado)) {
          continue;
        }

        final curso = cursosMap[cursoNormalizado];
        // Libres y Dictado se acreditan solo por CRM.
        if (curso == null ||
            curso.tipo == TipoCurso.libresExploracion ||
            curso.tipo == TipoCurso.dictadoCapacitaciones) {
          continue;
        }

        final horasAcreditadas = curso.cargaHorariaHs < 0
            ? 0.0
            : curso.cargaHorariaHs;
        horasValidas[curso.tipo] =
            (horasValidas[curso.tipo] ?? 0) + horasAcreditadas;
      }

      // Requerimientos mensuales según el seniority del empleado.
      final horasRequeridas = empleado.seniority.planFormacion;

      // Leandro: llama a CumplimientoEmpleado para entregar las horas validadas, declaradas y requeridas de cada persona.
      return CumplimientoEmpleado(
        empleado: empleado,
        horasValidas: horasValidas,
        horasDeclaradas: horasDeclaradas,
        horasRequeridas: horasRequeridas,
      );
    }).toList();
  }

  static Map<TipoCurso, double> _horasPorCategoriaEnCero() => {
    for (final tipo in TipoCurso.values) tipo: 0.0,
  };

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
