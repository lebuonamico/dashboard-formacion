import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class CumplimientoService {
  List<CumplimientoEmpleado> calcularCumplimientoGlobal({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<CargaDeHorasCRM> cargasDeHoras,
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
      final cargasTomadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && !carga.esDictada,
      );
      for (final carga in cargasTomadas) {
        final curso = cursosMap[carga.cursoId];
        if (curso != null) {
          horasCompletadas[curso.tipo] =
              (horasCompletadas[curso.tipo] ?? 0) + carga.horasTotales;
        }
      }

      // 2. Horas como instructor (Dictado de capacitaciones)
      final cargasDictadas = cargasDeHoras.where(
        (carga) => carga.empleadoLegajo == empleado.legajo && carga.esDictada,
      );
      for (final carga in cargasDictadas) {
        horasCompletadas[TipoCurso.dictadoCapacitaciones] =
            (horasCompletadas[TipoCurso.dictadoCapacitaciones] ?? 0) +
            carga.horasTotales;
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
