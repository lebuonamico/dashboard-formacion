import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CumplimientoService {
  List<CumplimientoEmpleado> calcularCumplimientoGlobal({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<Cursada> cursadas,
  }) {
    final cursosMap = {for (var c in cursos) c.id: c};

    return empleados.map((empleado) {
      final horasCompletadas = <TipoCurso, double>{
        TipoCurso.habilidadesDeNegocio: 0.0,
        TipoCurso.habilidadesBlandas: 0.0,
        TipoCurso.libresExploracion: 0.0,
        TipoCurso.dictadoCapacitaciones: 0.0,
      };

      // 1. Horas como alumno
      final cursadasEmpleado =
          cursadas.where((c) => c.empleadoLegajo == empleado.legajo);
      for (final cursada in cursadasEmpleado) {
        final curso = cursosMap[cursada.cursoId];
        if (curso != null) {
          horasCompletadas[curso.tipo] =
              (horasCompletadas[curso.tipo] ?? 0) + curso.cargaHorariaHs;
        }
      }

      // 2. Horas como instructor (Dictado de capacitaciones)
      final cursosDictados =
          cursos.where((c) => c.instructorLegajo == empleado.legajo);
      for (final curso in cursosDictados) {
        horasCompletadas[TipoCurso.dictadoCapacitaciones] =
            (horasCompletadas[TipoCurso.dictadoCapacitaciones] ?? 0) +
                curso.cargaHorariaHs;
      }

      // 3. Requerimientos por Seniority
      final horasRequeridas = empleado.seniority.planFormacion;

      return CumplimientoEmpleado(
        empleado: empleado,
        horasCompletadas: horasCompletadas,
        horasRequeridas: horasRequeridas,
      );
    }).toList();
  }
}