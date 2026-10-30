import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
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
    clasificacion: tipo,
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
  }) => const CumplimientoService().calcularCumplimientoGlobal(
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

  test('reconoce las Clasificaciones tal como vienen del CRM', () {
    expect(
      TipoCurso.desdeTexto('Habilidades de Negocio y Herramientas'),
      TipoCurso.habilidadesDeNegocio,
    );
    expect(
      TipoCurso.desdeTexto('Habilidades Blandas'),
      TipoCurso.habilidadesBlandas,
    );
    expect(
      TipoCurso.desdeTexto('Exploracion / Profundizacion'),
      TipoCurso.libresExploracion,
    );
    expect(
      TipoCurso.desdeTexto('Horas de Dictado'),
      TipoCurso.dictadoCapacitaciones,
    );
    expect(TipoCurso.desdeTexto('Otra cosa'), isNull);

    final resultado = calcular(
      cargas: [
        carga('A', 1, clasif: 'Exploracion / Profundizacion'),
        carga('B', 2, clasif: 'Horas de Dictado'),
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
        const EquiposService().calcularCumplimientoMensual(
          empleados: [empleado],
          cursos: [curso('Arquitectura Cloud', TipoCurso.habilidadesDeNegocio, 8)],
          cargas: [
            carga('Arquitectura Cloud', 1),
            carga('Taller', 2, clasif: 'Dictado de capacitaciones'),
          ],
          certificaciones: [finalizado('Arquitectura Cloud')],
          anio: 2026,
          mes: numero,
          cumplimientoService: const CumplimientoService(),
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

  group('Plan de formación configurable', () {
    // Senior 1 por defecto: 0 negocio, 2 blandas, 2 libres, 4 dictado.
    final seisDeDictado = PlanFormacion({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.senior1
            ? {
                TipoCurso.habilidadesDeNegocio: 0,
                TipoCurso.habilidadesBlandas: 2,
                TipoCurso.libresExploracion: 2,
                TipoCurso.dictadoCapacitaciones: 6,
              }
            : seniority.planFormacion,
    });
    final desdeJunio = PlanesFormacion([
      VersionPlanFormacion(
        vigenteDesde: DateTime(2026, 6),
        plan: seisDeDictado,
      ),
    ]);
    final servicio = CumplimientoService(planes: desdeJunio);

    test('el objetivo sale de la versión vigente en el mes evaluado', () {
      List<CumplimientoEmpleado> mes(int numero) =>
          const EquiposService().calcularCumplimientoMensual(
            empleados: [empleado],
            cursos: const [],
            cargas: [carga('Taller', 5, clasif: 'Dictado de capacitaciones')],
            certificaciones: const [],
            anio: 2026,
            mes: numero,
            cumplimientoService: servicio,
          );

      // Mayo es anterior al cambio: el dictado pedido sigue siendo 4 h.
      final mayo = mes(5).single;
      expect(mayo.horasRequeridas[TipoCurso.dictadoCapacitaciones], 4);
      expect(mayo.totalHorasRequeridas, 8);
      expect(
        mayo.horasAplicablesAlObjetivo(TipoCurso.dictadoCapacitaciones),
        4,
      );

      // Junio ya usa el plan nuevo: 10 h en total.
      final junio = mes(6).single;
      expect(junio.horasRequeridas[TipoCurso.dictadoCapacitaciones], 6);
      expect(junio.totalHorasRequeridas, 10);
    });

    test('el anual suma los objetivos de cada mes con su versión', () {
      final anual = const EquiposService()
          .calcularCumplimientoAnual(
            empleados: [empleado],
            cursos: const [],
            cargas: [
              carga('Taller', 5, clasif: 'Dictado de capacitaciones'),
              CargaDeHorasCRM(
                id: 'junio',
                cursoNombre: 'Taller',
                empleadoLegajo: '100',
                fecha: DateTime(2026, 6, 10),
                horasTotales: 5,
                tipo: TipoCargaDeHoras.tomada,
                clasificacion: 'Dictado de capacitaciones',
              ),
            ],
            certificaciones: const [],
            anio: 2026,
            cumplimientoService: servicio,
          )
          .single;

      // Mayo (8 h) + junio (10 h): los dos meses con datos.
      expect(anual.totalHorasRequeridas, 18);
      expect(anual.horasRequeridas[TipoCurso.dictadoCapacitaciones], 10);
      // En el anual mayo ya no topea en 4: suma 5 + 5, contra 10 requeridas.
      expect(anual.horasValidas[TipoCurso.dictadoCapacitaciones], 10);
      expect(
        anual.horasAplicablesAlObjetivo(TipoCurso.dictadoCapacitaciones),
        10,
      );
    });

    test('el anual compensa un mes flojo con uno fuerte de la misma '
        'categoría, con tope en el objetivo anual', () {
      CargaDeHorasCRM dictado(String id, int mes, double horas) =>
          CargaDeHorasCRM(
            id: id,
            cursoNombre: 'Taller',
            empleadoLegajo: '100',
            fecha: DateTime(2026, mes, 10),
            horasTotales: horas,
            tipo: TipoCargaDeHoras.tomada,
            clasificacion: 'Dictado de capacitaciones',
          );
      CumplimientoEmpleado anual(List<CargaDeHorasCRM> cargas) =>
          const EquiposService()
              .calcularCumplimientoAnual(
                empleados: [empleado],
                cursos: const [],
                cargas: cargas,
                certificaciones: const [],
                anio: 2026,
                cumplimientoService: servicio,
              )
              .single;

      // Junio y julio piden 6 h de dictado: 2 + 10 cubren las 12.
      final compensado = anual([dictado('j', 6, 2), dictado('k', 7, 10)]);
      expect(
        compensado.horasAplicablesAlObjetivo(TipoCurso.dictadoCapacitaciones),
        12,
      );

      // El excedente no pasa del objetivo anual de la categoría.
      final excedido = anual([dictado('j', 6, 10), dictado('k', 7, 10)]);
      expect(
        excedido.horasAplicablesAlObjetivo(TipoCurso.dictadoCapacitaciones),
        12,
      );
      expect(excedido.horasAplicablesAlObjetivo(TipoCurso.habilidadesBlandas), 0);
    });

    test('sin período usa la versión vigente hoy', () {
      final hoy = DateTime.now();
      final resultado =
          CumplimientoService(
                planes: PlanesFormacion([
                  VersionPlanFormacion(
                    vigenteDesde: DateTime(hoy.year, hoy.month),
                    plan: seisDeDictado,
                  ),
                ]),
              )
              .calcularCumplimientoGlobal(
                empleados: [empleado],
                cursos: const [],
                cargasDeHoras: const [],
                certificacionesMoodle: const [],
              )
              .single;

      expect(resultado.horasRequeridas[TipoCurso.dictadoCapacitaciones], 6);
    });
  });
}
