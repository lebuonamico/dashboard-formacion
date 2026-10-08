import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/areas_screen.dart';
import 'package:app_finnegans/presentation/certificacion_screen.dart';
import 'package:app_finnegans/presentation/cursada_screen.dart';
import 'package:app_finnegans/presentation/cursos_screen.dart';
import 'package:app_finnegans/presentation/dashboard_screen.dart';
import 'package:app_finnegans/presentation/empleados_screen.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _anio = 2026;
const _mes = 6;

final _empleado = Empleado(
  legajo: '100',
  nombre: 'Ana',
  apellido: 'Pérez',
  seniority: Seniority.junior1,
  area: 'Tecnología',
  mail: 'ana@finnegans.com',
  equipo: 'Plataforma',
  gerente: 'Beto',
  fechaIngreso: DateTime(2020, 1, 1),
);

final _curso = Curso(
  id: '1',
  nombre: 'Negociación',
  tipo: TipoCurso.habilidadesDeNegocio,
  areaCurso: '',
  instructorLegajo: '',
  cargaHorariaHs: 4,
);

CargaDeHorasCRM _carga(DateTime fecha) => CargaDeHorasCRM(
  id: 'tx-${fecha.month}',
  cursoNombre: _curso.nombre,
  empleadoLegajo: _empleado.legajo,
  fecha: fecha,
  horasTotales: 2,
  tipo: TipoCargaDeHoras.tomada,
);

Future<ProviderContainer> _mostrar(
  WidgetTester tester, {
  required String ruta,
  required Widget Function(GoRouterState state) pantalla,
  List<Empleado>? empleados,
  List<Curso>? cursos,
  List<CargaDeHorasCRM> cargas = const [],
  List<CertificacionMoodle> certificaciones = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(2400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      empleadosProvider.overrideWith((ref) async => empleados ?? [_empleado]),
      empleadoHistorialProvider.overrideWith((ref) async => null),
      cursosProvider.overrideWith((ref) async => cursos ?? [_curso]),
      cargasDeHorasCRMProvider.overrideWith((ref) async => cargas),
      cargasDashboardProvider.overrideWith((ref) async => cargas),
      certificacionesMoodleProvider.overrideWith(
        (ref) async => certificaciones,
      ),
      alcancePeriodoProvider.overrideWith((ref) => AlcancePeriodo.mensual),
      filtroMesPeriodoProvider.overrideWith((ref) => _mes),
      filtroAnioPeriodoProvider.overrideWith((ref) => _anio),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: ruta,
    routes: [
      GoRoute(
        path: ruta.split('?').first,
        builder: (context, state) => pantalla(state),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard', () {
    testWidgets('sin registros en el período muestra el aviso y no los KPIs', (
      tester,
    ) async {
      await _mostrar(
        tester,
        ruta: '/dashboard',
        pantalla: (_) => const DashboardScreen(),
        cargas: [_carga(DateTime(_anio, 3, 10))],
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
      expect(find.text('COLABORADORES'), findsNothing);
    });

    testWidgets('con registros en el período muestra los KPIs', (tester) async {
      await _mostrar(
        tester,
        ruta: '/dashboard',
        pantalla: (_) => const DashboardScreen(),
        cargas: [_carga(DateTime(_anio, _mes, 10))],
      );

      expect(find.textContaining('No hay datos cargados'), findsNothing);
      expect(find.text('COLABORADORES'), findsOneWidget);
      expect(find.text('No se encontraron datos.'), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
    });
  });

  group('Áreas', () {
    testWidgets('sin registros en el período muestra el aviso del período', (
      tester,
    ) async {
      await _mostrar(
        tester,
        ruta: '/areas',
        pantalla: (_) => const AreasScreen(),
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'una búsqueda sin coincidencias no se confunde con falta de datos',
      (tester) async {
        final container = await _mostrar(
          tester,
          ruta: '/areas',
          pantalla: (_) => const AreasScreen(),
          cargas: [_carga(DateTime(_anio, _mes, 10))],
        );
        expect(find.text('Tecnología'), findsOneWidget);

        container.read(busquedaEquipoProvider.notifier).state = 'inexistente';
        await tester.pumpAndSettle();

        expect(
          find.text('No hay áreas que coincidan con la búsqueda.'),
          findsOneWidget,
        );
        expect(find.textContaining('No hay datos cargados'), findsNothing);
      },
    );
  });

  testWidgets(
    'El detalle de equipo sin datos del período no muestra un error',
    (tester) async {
      await _mostrar(
        tester,
        ruta: '/equipo',
        pantalla: (_) =>
            const EquipoScreen(area: 'Tecnología', equipo: 'Plataforma'),
      );

      expect(
        find.text('No hay datos cargados para Junio 2026.'),
        findsOneWidget,
      );
      expect(find.textContaining('No pudimos cargar'), findsNothing);
    },
  );

  group('Empleados', () {
    testWidgets('sin nómina importada lo indica', (tester) async {
      await _mostrar(
        tester,
        ruta: '/empleados',
        pantalla: (_) => const EmpleadosScreen(),
        empleados: const [],
      );

      expect(find.text('No hay empleados cargados.'), findsOneWidget);
    });

    testWidgets('con nómina y búsqueda sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _mostrar(
        tester,
        ruta: '/empleados',
        pantalla: (_) => const EmpleadosScreen(),
      );

      container.read(busquedaEmpleadoProvider.notifier).state = 'inexistente';
      await tester.pumpAndSettle();

      expect(
        find.text('Ningún empleado coincide con los filtros.'),
        findsOneWidget,
      );
      expect(find.text('No hay empleados cargados.'), findsNothing);
    });
  });

  group('Cursos', () {
    testWidgets('sin catálogo importado lo indica', (tester) async {
      await _mostrar(
        tester,
        ruta: '/cursos',
        pantalla: (_) => const CursosScreen(),
        cursos: const [],
      );

      expect(find.text('No hay cursos cargados.'), findsOneWidget);
    });

    testWidgets('con catálogo y búsqueda sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _mostrar(
        tester,
        ruta: '/cursos',
        pantalla: (_) => const CursosScreen(),
      );

      container.read(busquedaCursoProvider.notifier).state = 'inexistente';
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron cursos con los filtros aplicados.'),
        findsOneWidget,
      );
      expect(find.text('No hay cursos cargados.'), findsNothing);
    });
  });

  group('Carga de horas CRM', () {
    testWidgets('sin reporte importado lo indica', (tester) async {
      await _mostrar(
        tester,
        ruta: '/cursadas',
        pantalla: (_) => const CursadasScreen(),
      );

      expect(find.text('No hay horas CRM cargadas.'), findsOneWidget);
    });

    testWidgets('con cargas y búsqueda sin coincidencias lo distingue', (
      tester,
    ) async {
      final container = await _mostrar(
        tester,
        ruta: '/cursadas',
        pantalla: (_) => const CursadasScreen(),
        cargas: [_carga(DateTime(_anio, _mes, 10))],
      );

      container.read(busquedaCargaDeHorasProvider.notifier).state =
          'inexistente';
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna carga de horas coincide con los filtros.'),
        findsOneWidget,
      );
      expect(find.text('No hay horas CRM cargadas.'), findsNothing);
    });
  });

  group('Certificaciones', () {
    testWidgets('sin finalizaciones importadas lo indica', (tester) async {
      await _mostrar(
        tester,
        ruta: '/certificaciones',
        pantalla: (_) => const CertificacionScreen(),
      );

      expect(find.text('No hay certificaciones LMS cargadas.'), findsOneWidget);
    });

    testWidgets(
      'con finalizaciones y búsqueda sin coincidencias lo distingue',
      (tester) async {
        final container = await _mostrar(
          tester,
          ruta: '/certificaciones',
          pantalla: (_) => const CertificacionScreen(),
          certificaciones: [
            CertificacionMoodle(
              legajo: _empleado.legajo,
              cursoNombre: _curso.nombre,
              finalizoCurso: true,
              fechaFinalizacion: DateTime(_anio, _mes, 20),
            ),
          ],
        );

        container.read(busquedaCertificacionMoodleProvider.notifier).state =
            'inexistente';
        await tester.pumpAndSettle();

        expect(
          find.text('Ninguna certificación coincide con los filtros.'),
          findsOneWidget,
        );
        expect(find.text('No hay certificaciones LMS cargadas.'), findsNothing);
      },
    );

    testWidgets('el filtro por estado deja afuera las que no coinciden', (
      tester,
    ) async {
      final container = await _mostrar(
        tester,
        ruta: '/certificaciones',
        pantalla: (_) => const CertificacionScreen(),
        certificaciones: [
          CertificacionMoodle(
            legajo: _empleado.legajo,
            cursoNombre: _curso.nombre,
            finalizoCurso: true,
            fechaFinalizacion: DateTime(_anio, _mes, 20),
          ),
        ],
      );
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('20/06/2026'), findsOneWidget);

      container.read(filtroEstadoCertificacionProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(
        find.text('Ninguna certificación coincide con los filtros.'),
        findsOneWidget,
      );
    });

    testWidgets('avisa cuando el curso o el legajo quedan fuera del cálculo', (
      tester,
    ) async {
      await _mostrar(
        tester,
        ruta: '/certificaciones',
        pantalla: (_) => const CertificacionScreen(),
        certificaciones: [
          CertificacionMoodle(
            legajo: _empleado.legajo,
            cursoNombre: 'Curso que no está en el catálogo',
            finalizoCurso: true,
            fechaFinalizacion: DateTime(_anio, _mes, 20),
          ),
          CertificacionMoodle(
            legajo: '999',
            cursoNombre: _curso.nombre,
            finalizoCurso: false,
          ),
        ],
      );

      expect(find.text('2 fuera del cálculo'), findsOneWidget);
      expect(
        find.byTooltip(
          'El curso no está en el catálogo: esta finalización no acredita horas.',
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          'El legajo no está en la nómina: no suma al cumplimiento de ningún equipo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fuera de la nómina'), findsOneWidget);
    });
  });
}
