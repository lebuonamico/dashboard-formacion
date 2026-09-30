import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

void main() {
  test('calcula cumplimiento con horas LMS y conserva CRM como declaradas', () {
    final empleado = Empleado(
      legajo: 'EMP-001',
      nombre: 'Ana',
      apellido: 'Pérez',
      seniority: Seniority.trainee,
      area: 'Tecnología',
      mail: 'ana@example.com',
    );
    final cursos = [
      Curso(
        id: '42',
        nombre: 'Curso de Negocio',
        tipo: TipoCurso.habilidadesDeNegocio,
        areaCurso: '',
        instructorLegajo: '',
        cargaHorariaHs: 99,
      ),
      Curso(
        id: '43',
        nombre: 'Curso Libre',
        tipo: TipoCurso.libresExploracion,
        areaCurso: '',
        instructorLegajo: '',
        cargaHorariaHs: 99,
      ),
      Curso(
        id: '44',
        nombre: 'Comunicación Asertiva',
        tipo: TipoCurso.habilidadesBlandas,
        areaCurso: '',
        instructorLegajo: '',
        cargaHorariaHs: 99,
      ),
    ];
    final resultado = CumplimientoService().calcularCumplimientoGlobal(
      empleados: [empleado],
      cursos: cursos,
      cargasDeHoras: [
        CargaDeHorasCRM(
          id: '1',
          cursoNombre: 'Curso de Negocio',
          empleadoLegajo: 'EMP-001',
          fecha: DateTime(2026, 9, 1),
          horasTotales: 38,
          tipo: TipoCargaDeHoras.tomada,
        ),
        CargaDeHorasCRM(
          id: '2',
          cursoNombre: 'Curso de Negocio',
          empleadoLegajo: 'EMP-001',
          fecha: DateTime(2026, 9, 2),
          horasTotales: 1,
          tipo: TipoCargaDeHoras.dictada,
        ),
      ],
      certificacionesMoodle: [
        const CertificacionMoodle(
          legajo: 'EMP-001',
          cursoNombre: ' Curso de Negocio ',
          finalizoCurso: true,
          cargaEstimada: 4,
        ),
        const CertificacionMoodle(
          legajo: 'EMP-001',
          cursoNombre: 'Curso Libre',
          finalizoCurso: true,
          cargaEstimada: 20,
        ),
        const CertificacionMoodle(
          legajo: 'EMP-001',
          cursoNombre: 'Comunicacion Asertiva',
          finalizoCurso: false,
          cargaEstimada: 4,
        ),
      ],
    );

    expect(resultado.single.horasValidas[TipoCurso.habilidadesDeNegocio], 4);
    expect(resultado.single.horasValidas[TipoCurso.libresExploracion], 20);
    expect(resultado.single.horasValidas[TipoCurso.habilidadesBlandas], 0);
    expect(resultado.single.totalHorasRequeridas, 8);
    expect(resultado.single.totalHorasValidas, 4);
    expect(resultado.single.porcentajeTotal, 50);
    expect(resultado.single.cumpleObjetivo, isFalse);
    expect(
      resultado.single.horasDeclaradas[TipoCurso.habilidadesDeNegocio],
      38,
    );
    expect(
      resultado.single.horasDeclaradas[TipoCurso.dictadoCapacitaciones],
      1,
    );
  });
}
