import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/side_menu_providers.dart';
import 'package:app_finnegans/presentation/widgets/app_shell.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Page<void> _conFundido(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

Future<ProviderContainer> _mostrar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _conFundido(
              state,
              const Scaffold(body: Center(child: Text('Pantalla Dashboard'))),
            ),
          ),
          GoRoute(
            path: '/empleados',
            pageBuilder: (context, state) => _conFundido(
              state,
              const Scaffold(body: Center(child: Text('Pantalla Empleados'))),
            ),
          ),
        ],
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
  return container;
}

Color? _colorDelItem(WidgetTester tester, String etiqueta) {
  final texto = tester.widget<Text>(
    find.descendant(of: find.byType(SideMenu), matching: find.text(etiqueta)),
  );
  return texto.style?.color;
}

void main() {
  testWidgets('Navegar no reconstruye el menú y cambia el ítem activo', (
    tester,
  ) async {
    await _mostrar(tester);

    final estadoAntes = tester.state(find.byType(SideMenu));
    expect(find.text('Pantalla Dashboard'), findsOneWidget);
    expect(_colorDelItem(tester, 'Empleados'), isNot(const Color(0xFF0D53C3)));

    // El menú navega con context.push, igual que en la app.
    await tester.tap(
      find.descendant(
        of: find.byType(SideMenu),
        matching: find.text('Empleados'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantalla Empleados'), findsOneWidget);
    // Misma instancia: el menú no se recreó, así su animación no se corta.
    expect(tester.state(find.byType(SideMenu)), same(estadoAntes));
    expect(find.byType(SideMenu), findsOneWidget);
    // El ítem activo sigue a la ruta.
    expect(_colorDelItem(tester, 'Empleados'), const Color(0xFF0D53C3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('El ítem activo cambia de color con una transición', (
    tester,
  ) async {
    await _mostrar(tester);
    final inicial = _colorDelItem(tester, 'Empleados');

    await tester.tap(
      find.descendant(
        of: find.byType(SideMenu),
        matching: find.text('Empleados'),
      ),
    );
    // A mitad de la transición el color no es ni el inicial ni el final.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final enTransicion = _colorDelItem(tester, 'Empleados');
    expect(enTransicion, isNot(inicial));
    expect(enTransicion, isNot(const Color(0xFF0D53C3)));

    await tester.pumpAndSettle();
    expect(_colorDelItem(tester, 'Empleados'), const Color(0xFF0D53C3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plegar el menú mientras se navega no se interrumpe', (
    tester,
  ) async {
    final container = await _mostrar(tester);

    await tester.tap(find.byKey(const Key('side_menu_toggle')));
    // A mitad de la animación, se navega a otra pantalla.
    await tester.pump(const Duration(milliseconds: 80));
    final contexto = tester.element(find.byType(AppShell));
    GoRouter.of(contexto).push('/empleados');
    await tester.pumpAndSettle();

    expect(container.read(sideMenuDesplegadoProvider), isFalse);
    expect(tester.getSize(find.byType(SideMenu)).width, 0);
    expect(find.text('Pantalla Empleados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FadeIn aparece con fundido y deja el contenido visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FadeIn(child: Text('Contenido'))),
    );

    // Recién montado: casi transparente.
    final opacidadInicial = tester
        .widget<Opacity>(find.byType(Opacity))
        .opacity;
    expect(opacidadInicial, lessThan(0.1));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('Contenido'), findsOneWidget);
  });
}
