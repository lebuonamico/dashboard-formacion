import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/certificacion_screen.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _mostrarCertificaciones(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      empleadosProvider.overrideWith(
        (ref) async => [
          Empleado(
            legajo: '10',
            nombre: 'Ana',
            apellido: 'Pérez',
            seniority: Seniority.junior1,
            area: 'Servicios',
            equipo: 'Soporte',
            mail: 'ana@finnegans.com',
          ),
        ],
      ),
      cursosProvider.overrideWith(
        (ref) async => [
          Curso(
            id: 'C1',
            nombre: 'Oratoria',
            tipo: TipoCurso.habilidadesBlandas,
            areaCurso: '',
            instructorLegajo: '',
            cargaHorariaHs: 4,
          ),
        ],
      ),
      certificacionesMoodleProvider.overrideWith(
        (ref) async => [
          CertificacionMoodle(
            legajo: '10',
            cursoNombre: 'Oratoria',
            finalizoCurso: true,
            fechaFinalizacion: DateTime(2026, 7, 20),
          ),
          // Legajo que no está en la nómina: no tiene perfil.
          CertificacionMoodle(
            legajo: '99',
            cursoNombre: 'Oratoria',
            finalizoCurso: true,
            fechaFinalizacion: DateTime(2026, 7, 10),
          ),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);

  // Cada pantalla monta el SideMenu, como el AppShell: así se ve qué sección
  // queda marcada al abrir el perfil.
  Widget conMenu(Widget pantalla) => Scaffold(
    body: Row(
      children: [
        const SideMenu(),
        Expanded(child: pantalla),
      ],
    ),
  );
  final router = GoRouter(
    initialLocation: '/certificaciones',
    routes: [
      GoRoute(
        path: '/certificaciones',
        builder: (context, state) => conMenu(const CertificacionScreen()),
      ),
      GoRoute(
        path: '/empleados/:legajo',
        builder: (context, state) =>
            conMenu(Text('Perfil de ${state.pathParameters['legajo']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
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
  return router;
}

/// Si el ítem del menú lateral con esa etiqueta está marcado.
bool _itemMarcado(WidgetTester tester, String etiqueta) {
  final item = tester.widget(
    find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_MenuItem' &&
          (widget as dynamic).label == etiqueta,
    ),
  );
  return (item as dynamic).isSelected as bool;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Click en una certificación abre el perfil del colaborador', (
    tester,
  ) async {
    final router = await _mostrarCertificaciones(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/empleados/10?origen=certificaciones');
    expect(find.text('Perfil de 10'), findsOneWidget);
    // El menú sigue en Certificaciones LMS, no salta a Empleados.
    expect(_itemMarcado(tester, 'Certificaciones LMS'), isTrue);
    expect(_itemMarcado(tester, 'Empleados'), isFalse);
  });

  testWidgets('Un legajo fuera de la nómina no abre nada', (tester) async {
    final router = await _mostrarCertificaciones(tester);

    await tester.tap(find.text('Legajo 99'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/certificaciones');
    expect(find.byType(CertificacionScreen), findsOneWidget);
  });
}
