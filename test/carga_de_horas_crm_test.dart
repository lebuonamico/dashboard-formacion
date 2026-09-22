import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

void main() {
  test('calcula horas tomadas y dictadas desde el CRM', () {
    final empleado = Empleado(
      legajo: 'EMP-001',
      nombre: 'Ana',
      apellido: 'Pérez',
      seniority: Seniority.senior1,
      area: 'Tecnología',
      mail: 'ana@example.com',
    );
    final curso = Curso(
      id: '42',
      nombre: 'Curso CRM',
      tipo: TipoCurso.habilidadesBlandas,
      areaCurso: '',
      instructorLegajo: '',
      cargaHorariaHs: 99,
    );
    final resultado = CumplimientoService().calcularCumplimientoGlobal(
      empleados: [empleado],
      cursos: [curso],
      cargasDeHoras: [
        CargaDeHorasCRM(
          id: '1',
          cursoId: '42',
          empleadoLegajo: 'EMP-001',
          fecha: DateTime(2026, 9, 1),
          horasTotales: 2.5,
          tipo: TipoCargaDeHoras.tomada,
        ),
        CargaDeHorasCRM(
          id: '2',
          cursoId: '42',
          empleadoLegajo: 'EMP-001',
          fecha: DateTime(2026, 9, 2),
          horasTotales: 1.5,
          tipo: TipoCargaDeHoras.dictada,
        ),
      ],
    );

    expect(
      resultado.single.horasCompletadas[TipoCurso.habilidadesBlandas],
      2.5,
    );
    expect(
      resultado.single.horasCompletadas[TipoCurso.dictadoCapacitaciones],
      1.5,
    );
  });
}
