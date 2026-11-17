import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/navigation/side_menu_provider.dart';
import 'package:app_finnegans/core/navigation/app_shell.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pump_screen.dart';

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

  final container = ProviderContainer(overrides: []);
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

/// A section with its top bar and a tap counter: it shows whether the screen
/// keeps its state when the window crosses 840 px.
class _Section extends StatefulWidget {
  final String title;
  final String body;
  final String? backTo;

  const _Section({required this.title, required this.body, this.backTo});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        AppTopBar(title: widget.title, backTo: widget.backTo),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.body),
              TextButton(
                onPressed: () => setState(() => _taps++),
                child: Text('Toques: $_taps'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final _sectionRoutes = <RouteBase>[
  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => _withFade(
          state,
          const _Section(title: 'Inicio', body: 'Pantalla Dashboard'),
        ),
      ),
      GoRoute(
        path: '/empleados',
        pageBuilder: (context, state) => _withFade(
          state,
          const _Section(title: 'Colaboradores', body: 'Pantalla Empleados'),
        ),
      ),
      GoRoute(
        path: '/empleados/:legajo',
        pageBuilder: (context, state) => _withFade(
          state,
          const _Section(
            title: 'Perfil',
            body: 'Pantalla Perfil',
            backTo: '/empleados',
          ),
        ),
      ),
    ],
  ),
];

final _openMenu = find.byKey(const Key('modal_menu_open'));
final _modalMenu = find.byType(ModalNavigationDrawer);

void main() {
  testWidgets('Navegar no recrea el menú y cambia el destino activo', (
    tester,
  ) async {
    await _show(tester);

    final drawerBefore = tester.element(find.byType(AppNavigationDrawer));
    expect(find.text('Pantalla Dashboard'), findsOneWidget);
    expect(_selectedIndex(tester), 0);

    await tester.tap(_destination('Colaboradores'));
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

    await tester.tap(_destination('Colaboradores'));
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

  group('En el teléfono (390 px)', () {
    testWidgets('El menú es modal: se abre desde el top bar y navegar lo '
        'cierra', (tester) async {
      final (:router, container: _) = await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: compactSize,
      );

      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect(_modalMenu, findsNothing);
      expect(find.text('Pantalla Dashboard'), findsOneWidget);

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();
      expect(_modalMenu, findsOneWidget);
      expect(_selectedIndex(tester), 0);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.byTooltip('Ocultar menú'), findsNothing);

      await tester.tap(_destination('Colaboradores'));
      await tester.pumpAndSettle();

      expect(_modalMenu, findsNothing);
      expect(find.text('Pantalla Empleados'), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Elegir la sección actual también cierra el menú', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: compactSize,
      );

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();
      await tester.tap(_destination('Inicio'));
      await tester.pumpAndSettle();

      expect(_modalMenu, findsNothing);
      expect(find.text('Pantalla Dashboard'), findsOneWidget);
    });

    testWidgets('El botón cerrar y un cambio de ruta (atrás del navegador) '
        'cierran el menú', (tester) async {
      final (:router, container: _) = await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: compactSize,
      );

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('modal_menu_close')));
      await tester.pumpAndSettle();
      expect(_modalMenu, findsNothing);

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();
      router.go('/empleados');
      await tester.pumpAndSettle();

      expect(_modalMenu, findsNothing);
      expect(find.text('Pantalla Empleados'), findsOneWidget);

      // After closing itself, it opens again.
      await tester.tap(_openMenu);
      await tester.pumpAndSettle();
      expect(_modalMenu, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Las mismas rayitas abren y cierran el menú, sin X, y el '
        'logo va a la derecha', (tester) async {
      await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: compactSize,
      );
      final openAt = tester.getCenter(_openMenu);

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();

      final close = find.byKey(const Key('modal_menu_close'));
      expect(
        find.descendant(of: close, matching: find.byIcon(Icons.menu)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _modalMenu, matching: find.byIcon(Icons.close)),
        findsNothing,
      );
      // En el mismo lugar que la hamburguesa de la barra de arriba.
      expect(tester.getCenter(close), openAt);
      final logo = find.descendant(
        of: _modalMenu,
        matching: find.byType(Image),
      );
      expect(
        tester.getRect(logo).left,
        greaterThan(tester.getRect(find.text('Finnegans')).right),
      );

      await tester.tapAt(openAt);
      await tester.pumpAndSettle();
      expect(_modalMenu, findsNothing);
    });

    testWidgets('Un detalle muestra volver en lugar de la hamburguesa', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: '/empleados/10',
        routes: _sectionRoutes,
        size: compactSize,
      );

      expect(find.byType(AppBackButton), findsOneWidget);
      expect(_openMenu, findsNothing);
    });

    testWidgets('A 360×640 el menú abierto entra sin desbordes', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: const Size(360, 640),
      );

      await tester.tap(_openMenu);
      await tester.pumpAndSettle();

      expect(tester.getSize(_modalMenu).width, lessThan(360));
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cruzar 840 px cambia el menú sin perder el estado de la '
        'pantalla', (tester) async {
      await pumpScreen(
        tester,
        initialLocation: '/dashboard',
        routes: _sectionRoutes,
        size: compactSize,
      );
      await tester.tap(find.text('Toques: 0'));
      await tester.pump();

      tester.view.physicalSize = desktopSize;
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsOneWidget);
      expect(_openMenu, findsNothing);
      expect(find.text('Toques: 1'), findsOneWidget);

      tester.view.physicalSize = const Size(700, 900);
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect(_openMenu, findsOneWidget);
      expect(find.text('Toques: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
