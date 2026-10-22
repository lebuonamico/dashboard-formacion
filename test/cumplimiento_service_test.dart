import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';
import 'package:app_finnegans/domain/servicios/teams_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final empleado = Empleado(
    fechaIngreso: DateTime(2024, 1, 1),
    legajo: '100',
    nombre: 'Ana',
    apellido: 'Pérez',
    seniority: Seniority.senior1,
    area: 'Desarrollo',
    mail: 'ana@example.com',
  );

  Curso curso(String nombre, TipoCurso tipo, double carga) => Curso(
    id: nombre,
    nombre: nombre,
    tipo: tipo,
    areaCurso: 'General',
    instructorLegajo: '',
    cargaHorariaHs: carga,
  );

  CargaDeHorasCRM carga(String cursoNombre, double horas, {String? clasif}) =>
      CargaDeHorasCRM(
        id: '$cursoNombre-$horas-$clasif',
        cursoNombre: cursoNombre,
        empleadoLegajo: '100',
        fecha: DateTime(2026, 5, 10),
        horasTotales: horas,
        tipo: TipoCargaDeHoras.tomada,
        clasificacion: clasif,
      );

  CertificacionMoodle finalizado(String cursoNombre) => CertificacionMoodle(
    legajo: '100',
    cursoNombre: cursoNombre,
    finalizoCurso: true,
    fechaFinalizacion: DateTime(2026, 5, 20),
  );

  CumplimientoEmpleado calcular({
    List<Curso> cursos = const [],
    required List<CargaDeHorasCRM> cargas,
    List<CertificacionMoodle> certificaciones = const [],
  }) => CumplimientoService().calcularCumplimientoGlobal(
    empleados: [empleado],
    cursos: cursos,
    cargasDeHoras: cargas,
    certificacionesMoodle: certificaciones,
  ).single;

  test('Libres / exploración del CRM es válida sin LMS ni catálogo', () {
    final resultado = calcular(
      cargas: [carga('Curso libre', 5, clasif: 'Libres / exploración')],
    );

    expect(resultado.horasValidas[TipoCurso.libresExploracion], 5);
    expect(resultado.horasDeclaradas[TipoCurso.libresExploracion], 5);
  });

  test('Dictado de capacitaciones del CRM es válido y se marca dictado', () {
    final dictado = carga(
      'Taller interno',
      3,
      clasif: 'Dictado de capacitaciones',
    );
    final resultado = calcular(cargas: [dictado]);

    expect(dictado.esDictada, isTrue);
    expect(resultado.horasValidas[TipoCurso.dictadoCapacitaciones], 3);
    expect(resultado.horasDeclaradas[TipoCurso.dictadoCapacitaciones], 3);
  });

  test('la Clasificación se reconoce sin tildes ni mayúsculas', () {
    final resultado = calcular(
      cargas: [
        carga('A', 1, clasif: '  LIBRES / EXPLORACION '),
        carga('B', 2, clasif: 'dictado de capacitaciones'),
      ],
    );

    expect(resultado.horasValidas[TipoCurso.libresExploracion], 1);
    expect(resultado.horasValidas[TipoCurso.dictadoCapacitaciones], 2);
  });

  test('Negocio declarado en CRM sin finalizar en LMS no suma', () {
    final resultado = calcular(
      cursos: [curso('Finanzas', TipoCurso.habilidadesDeNegocio, 8)],
      cargas: [carga('Finanzas', 5, clasif: 'Habilidades de negocio')],
    );

    expect(resultado.horasValidas[TipoCurso.habilidadesDeNegocio], 0);
    expect(resultado.horasDeclaradas[TipoCurso.habilidadesDeNegocio], 5);
  });

  test('curso finalizado en LMS acredita su carga horaria, no la del CRM', () {
    final cursos = [
      curso('Arquitectura Cloud', TipoCurso.habilidadesDeNegocio, 8),
      curso('Liderazgo', TipoCurso.habilidadesBlandas, 4),
    ];
    final resultado = calcular(
      cursos: cursos,
      cargas: [carga('Arquitectura Cloud', 1)],
      certificaciones: [
        finalizado('Arquitectura Cloud'),
        // Sin ninguna carga en el CRM.
        finalizado('Liderazgo'),
      ],
    );

    expect(resultado.horasValidas[TipoCurso.habilidadesDeNegocio], 8);
    expect(resultado.horasDeclaradas[TipoCurso.habilidadesDeNegocio], 1);
    expect(resultado.horasValidas[TipoCurso.habilidadesBlandas], 4);
  });

  test('el cálculo mensual usa solo las finalizaciones y cargas del mes', () {
    List<CumplimientoEmpleado> mes(int numero) =>
        EquiposService().calcularCumplimientoMensual(
          empleados: [empleado],
          cursos: [curso('Arquitectura Cloud', TipoCurso.habilidadesDeNegocio, 8)],
          cargas: [
            carga('Arquitectura Cloud', 1),
            carga('Taller', 2, clasif: 'Dictado de capacitaciones'),
          ],
          certificaciones: [finalizado('Arquitectura Cloud')],
          anio: 2026,
          mes: numero,
          cumplimientoService: CumplimientoService(),
        );

    // Cargas del 10/05 y finalización del 20/05.
    final mayo = mes(5).single;
    expect(mayo.horasValidas[TipoCurso.habilidadesDeNegocio], 8);
    expect(mayo.horasValidas[TipoCurso.dictadoCapacitaciones], 2);

    final junio = mes(6).single;
    expect(junio.totalHorasValidas, 0);
  });

  test('Libres finalizado en LMS no suma: solo cuenta el CRM', () {
    final resultado = calcular(
      cursos: [curso('Laboratorio', TipoCurso.libresExploracion, 8)],
      cargas: [carga('Laboratorio', 1, clasif: 'Libres / exploración')],
      certificaciones: [finalizado('Laboratorio')],
    );

    expect(resultado.horasValidas[TipoCurso.libresExploracion], 1);
  });
}
