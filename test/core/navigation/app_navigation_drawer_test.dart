import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/navigation/side_menu_provider.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _showScreen(
  WidgetTester tester, {
  UserRole? role,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      if (role != null)
        authProvider.overrideWith(
          () => AuthNotifier(
            AuthState(
              user: const AuthUser(
                id: 'test-user',
                email: 'usuario@finnegans.com',
              ),
              isAuthorized: true,
              role: role.name,
            ),
          ),
        ),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Row(
            children: [
              AppNavigationDrawer(),
              Expanded(
                child: Column(children: [AppTopBar(title: 'Inicio')]),
              ),
            ],
          ),
        ),
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
  return container;
}

final _toggle = find.byKey(const Key('side_menu_toggle'));

double _drawerWidth(WidgetTester tester) =>
    tester.getSize(find.byType(AppNavigationDrawer)).width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arranca desplegada con el header alineado al top bar', (
    tester,
  ) async {
    final container = await _showScreen(tester);

    expect(container.read(sideMenuExpandedProvider), isTrue);
    expect(_drawerWidth(tester), expandedDrawerWidth);
    expect(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Inicio'),
      ),
      findsOneWidget,
    );
    expect(tester.getBottomLeft(find.byType(AppTopBar)).dy, drawerHeaderHeight);
  });

  testWidgets('El botón pliega y vuelve a desplegar el menú', (tester) async {
    final container = await _showScreen(tester);
    expect(find.byTooltip('Ocultar menú'), findsOneWidget);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isFalse);
    expect(_drawerWidth(tester), collapsedDrawerWidth);
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(find.byTooltip('Mostrar menú'), findsOneWidget);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isTrue);
    expect(_drawerWidth(tester), expandedDrawerWidth);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Ítems según el rol', () {
    const areas = 'Áreas';
    const settings = 'Configuración';
    const panel = 'Panel de administrador';

    testWidgets('En modo local se ve todo', (tester) async {
      await _showScreen(tester);
      for (final item in [areas, settings, panel]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('Academia ve Configuración y el panel', (tester) async {
      await _showScreen(tester, role: UserRole.academy);
      for (final item in [areas, settings, panel]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('Un usuario de área ve Áreas pero no lo administrativo', (
      tester,
    ) async {
      await _showScreen(tester, role: UserRole.areaLead);
      expect(find.text(areas), findsOneWidget);
      expect(find.text(settings), findsNothing);
      expect(find.text(panel), findsNothing);
      expect(find.text('Equipos'), findsOneWidget);
    });

    testWidgets('Un líder no ve Áreas ni lo administrativo', (tester) async {
      await _showScreen(tester, role: UserRole.teamLead);
      expect(find.text(areas), findsNothing);
      expect(find.text(settings), findsNothing);
      expect(find.text(panel), findsNothing);
      expect(find.text('Equipos'), findsOneWidget);
      expect(find.text('Empleados'), findsOneWidget);
    });
  });
}
