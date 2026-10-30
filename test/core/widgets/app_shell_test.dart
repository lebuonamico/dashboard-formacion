import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/widgets/side_menu_providers.dart';
import 'package:app_finnegans/core/widgets/app_shell.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/side_menu.dart';
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

final _brand = AppTheme.light().colorScheme.primary;

Color? _itemColor(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(SideMenu), matching: find.text(label)),
  );
  return text.style?.color;
}

void main() {
  testWidgets('Navegar no reconstruye el menú y cambia el ítem activo', (
    tester,
  ) async {
    await _show(tester);

    final statusBefore = tester.state(find.byType(SideMenu));
    expect(find.text('Pantalla Dashboard'), findsOneWidget);
    expect(_itemColor(tester, 'Empleados'), isNot(_brand));

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
    expect(tester.state(find.byType(SideMenu)), same(statusBefore));
    expect(find.byType(SideMenu), findsOneWidget);
    // El ítem activo sigue a la ruta.
    expect(_itemColor(tester, 'Empleados'), _brand);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El ítem activo cambia de color con una transición', (
    tester,
  ) async {
    await _show(tester);
    final initial = _itemColor(tester, 'Empleados');

    await tester.tap(
      find.descendant(
        of: find.byType(SideMenu),
        matching: find.text('Empleados'),
      ),
    );
    // A mitad de la transición el color no es ni el inicial ni el final.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final inTransition = _itemColor(tester, 'Empleados');
    expect(inTransition, isNot(initial));
    expect(inTransition, isNot(_brand));

    await tester.pumpAndSettle();
    expect(_itemColor(tester, 'Empleados'), _brand);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plegar el menú mientras se navega no se interrumpe', (
    tester,
  ) async {
    final container = await _show(tester);

    await tester.tap(find.byKey(const Key('side_menu_toggle')));
    // A mitad de la animación, se navega a otra pantalla.
    await tester.pump(const Duration(milliseconds: 80));
    final context = tester.element(find.byType(AppShell));
    GoRouter.of(context).push('/empleados');
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isFalse);
    expect(tester.getSize(find.byType(SideMenu)).width, 0);
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
