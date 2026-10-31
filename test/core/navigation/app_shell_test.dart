import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/navigation/side_menu_provider.dart';
import 'package:app_finnegans/core/navigation/app_shell.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Page<void> _withFade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

Future<ProviderContainer> _show(WidgetTester tester) async {
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
            pageBuilder: (context, state) => _withFade(
              state,
              const Scaffold(body: Center(child: Text('Pantalla Dashboard'))),
            ),
          ),
          GoRoute(
            path: '/empleados',
            pageBuilder: (context, state) => _withFade(
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
  return container;
}

int? _selectedIndex(WidgetTester tester) => tester
    .widget<NavigationDrawer>(find.byType(NavigationDrawer))
    .selectedIndex;

Finder _destination(String label) => find.descendant(
  of: find.byType(NavigationDrawer),
  matching: find.text(label),
);

void main() {
  testWidgets('Navegar no recrea el menú y cambia el destino activo', (
    tester,
  ) async {
    await _show(tester);

    final drawerBefore = tester.element(find.byType(AppNavigationDrawer));
    expect(find.text('Pantalla Dashboard'), findsOneWidget);
    expect(_selectedIndex(tester), 0);

    await tester.tap(_destination('Empleados'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla Empleados'), findsOneWidget);
    expect(
      tester.element(find.byType(AppNavigationDrawer)),
      same(drawerBefore),
    );
    expect(_selectedIndex(tester), 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Las secciones navegan con go: no apilan pantallas', (
    tester,
  ) async {
    await _show(tester);

    await tester.tap(_destination('Empleados'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AppShell));
    expect(GoRouter.of(context).canPop(), isFalse);
  });

  testWidgets('Plegar el menú mientras se navega no se interrumpe', (
    tester,
  ) async {
    final container = await _show(tester);

    await tester.tap(find.byKey(const Key('side_menu_toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    final context = tester.element(find.byType(AppShell));
    GoRouter.of(context).go('/empleados');
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isFalse);
    expect(
      tester.getSize(find.byType(AppNavigationDrawer)).width,
      collapsedDrawerWidth,
    );
    expect(find.text('Pantalla Empleados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FadeIn aparece con fundido y deja el contenido visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const FadeIn(child: Text('Contenido')),
      ),
    );

    // Recién montado: casi transparente.
    final initialOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(initialOpacity, lessThan(0.1));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('Contenido'), findsOneWidget);
  });
}
