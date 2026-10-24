import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Curso _curso(
  String nombre, {
  double carga = 8,
  TipoCurso tipo = TipoCurso.habilidadesDeNegocio,
}) => Curso(
  id: nombre,
  nombre: nombre,
  tipo: tipo,
  areaCurso: '',
  instructorLegajo: '',
  cargaHorariaHs: carga,
);

CargaDeHorasCRM _carga(
  String id,
  String curso,
  String legajo,
  double horas,
  DateTime fecha, {
  String? clasificacion,
}) => CargaDeHorasCRM(
  id: id,
  cursoNombre: curso,
  empleadoLegajo: legajo,
  fecha: fecha,
  horasTotales: horas,
  tipo: TipoCargaDeHoras.tomada,
  clasificacion: clasificacion,
);

CertificacionMoodle _finalizacion(
  String curso,
  String legajo,
  DateTime? fecha, {
  bool finalizo = true,
}) => CertificacionMoodle(
  legajo: legajo,
  cursoNombre: curso,
  finalizoCurso: finalizo,
  fechaFinalizacion: fecha,
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      cursosProvider.overrideWith(
        (ref) async => [
          _curso('Finanzas para no financieros'),
          _curso('Oratoria', carga: 4),
          _curso('Curso sin alumnos'),
          _curso(
            'Dictado interno: SQL',
            carga: 4,
            tipo: TipoCurso.dictadoCapacitaciones,
          ),
        ],
      ),
      empleadosProvider.overrideWith((ref) async => []),
      cargasDeHorasCRMProvider.overrideWith(
        (ref) async => [
          // Finanzas: dos personas en julio y una de ellas también en agosto.
          _carga(
            '1',
            'Finanzas para no financieros',
            '10',
            3,
            DateTime(2026, 7, 5),
          ),
          _carga(
            '2',
            'Finanzas para no financieros',
            '10',
            2,
            DateTime(2026, 8, 3),
          ),
          // El nombre del CRM se cruza normalizado, como en el cumplimiento.
          _carga(
            '3',
            ' FINANZAS para no-financieros ',
            '20',
            4,
            DateTime(2026, 7, 9),
          ),
          // En un curso de dictado, quien carga horas es quien lo dicta.
          _carga(
            '4',
            'Dictado interno: SQL',
            '30',
            6,
            DateTime(2026, 7, 9),
            clasificacion: 'Dictado de capacitaciones',
          ),
          _carga('5', 'Oratoria', '20', 1.5, DateTime(2025, 12, 1)),
        ],
      ),
      certificacionesMoodleProvider.overrideWith(
        (ref) async => [
          _finalizacion(
            'Finanzas para no financieros',
            '10',
            DateTime(2026, 7, 20),
          ),
          _finalizacion(
            'Finanzas para no financieros',
            '20',
            DateTime(2026, 8, 2),
          ),
          // Una pendiente no cuenta como finalizada.
          _finalizacion(
            'Finanzas para no financieros',
            '40',
            null,
            finalizo: false,
          ),
          _finalizacion('Oratoria', '20', DateTime(2025, 12, 10)),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<Map<String, CursoViewModel>> _metricas(
  ProviderContainer container,
) async {
  // Los providers base son futuros: se espera a que estén listos.
  await container.read(cursosProvider.future);
  await container.read(empleadosProvider.future);
  await container.read(cargasDeHorasCRMProvider.future);
  await container.read(certificacionesMoodleProvider.future);
  final cursos = container.read(cursosConInstructorProvider).requireValue;
  return {for (final vm in cursos) vm.curso.nombre: vm};
}

void main() {
  test('Sin período suma todo el histórico de cada curso', () async {
    final metricas = await _metricas(_container());

    final finanzas = metricas['Finanzas para no financieros']!;
    expect(finanzas.personas, 2);
    expect(finanzas.horasCrm, 9);
    expect(finanzas.promedioHorasPorPersona, 4.5);
    expect(finanzas.finalizaron, 2);

    final oratoria = metricas['Oratoria']!;
    expect(oratoria.personas, 1);
    expect(oratoria.horasCrm, 1.5);
    expect(oratoria.finalizaron, 1);
  });

  test('Un curso de dictado cuenta a quienes lo dictaron', () async {
    final metricas = await _metricas(_container());

    final dictado = metricas['Dictado interno: SQL']!;
    expect(dictado.personas, 1);
    expect(dictado.horasCrm, 6);
    expect(dictado.promedioHorasPorPersona, 6);
  });

  test('Un curso que nadie tomó no tiene promedio', () async {
    final metricas = await _metricas(_container());

    final vacio = metricas['Curso sin alumnos']!;
    expect(vacio.personas, 0);
    expect(vacio.horasCrm, 0);
    expect(vacio.promedioHorasPorPersona, isNull);
    expect(vacio.finalizaron, 0);
  });

  test('El año y el mes acotan las métricas, no el catálogo', () async {
    final container = _container();
    container.read(filtroAnioCursosProvider.notifier).state = 2026;
    container.read(filtroMesCursosProvider.notifier).state = 7;

    final metricas = await _metricas(container);

    // El catálogo sigue completo.
    expect(metricas, hasLength(4));
    final finanzas = metricas['Finanzas para no financieros']!;
    expect(finanzas.personas, 2);
    expect(finanzas.horasCrm, 7);
    expect(finanzas.finalizaron, 1);
    expect(metricas['Oratoria']!.personas, 0);

    // Sin mes, todo el año.
    container.read(filtroMesCursosProvider.notifier).state = null;
    final anual = container.read(cursosConInstructorProvider).requireValue;
    final finanzasAnual = anual.firstWhere(
      (vm) => vm.curso.nombre == 'Finanzas para no financieros',
    );
    expect(finanzasAnual.horasCrm, 9);
    expect(finanzasAnual.finalizaron, 2);
  });

  test(
    'Los años del filtro salen de las cargas y las finalizaciones',
    () async {
      final container = _container();
      await container.read(cargasDeHorasCRMProvider.future);
      await container.read(certificacionesMoodleProvider.future);

      expect(container.read(aniosCursosDisponiblesProvider).requireValue, [
        2026,
        2025,
      ]);
    },
  );
}
