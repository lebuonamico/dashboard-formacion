import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/widgets/side_menu_providers.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/core/widgets/side_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Sesión con Supabase habilitado y un rol fijo, sin cliente real.
class _AuthWithRole extends AuthController {
  final UserRole _role;

  _AuthWithRole(this._role) : super(null);

  @override
  bool get enabled => true;

  @override
  UserRole? get knownRole => _role;

  @override
  bool get canManage => _role.canManage;
}

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
      authControllerProvider.overrideWith(
        (ref) => role == null ? AuthController(null) : _AuthWithRole(role),
      ),
    ],
  );
  addTearDown(container.dispose);

  // SideMenu.build llama a GoRouterState.of(context): hay que montarlo bajo un
  // GoRouter aunque no se navegue.
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Row(
            children: [
              SideMenu(),
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

double _widthSideMenu(WidgetTester tester) =>
    tester.getSize(find.byType(SideMenu)).width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arranca desplegada con el header alineado al top bar', (
    tester,
  ) async {
    final container = await _showScreen(tester);

    expect(container.read(sideMenuExpandedProvider), isTrue);
    expect(_widthSideMenu(tester), 260);
    expect(find.text('Inicio'), findsWidgets);

    // La línea bajo el logo y la del top bar tienen que caer a la misma altura.
    final headerSidebar = find.ancestor(
      of: find.text('Finnegans'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 64,
      ),
    );
    expect(
      tester.getBottomLeft(headerSidebar).dy,
      tester.getBottomLeft(find.byType(AppTopBar)).dy,
    );
  });

  testWidgets('La pestaña oculta y vuelve a mostrar la sidebar', (
    tester,
  ) async {
    final container = await _showScreen(tester);

    // Desplegada: la pestaña sale pegada al borde derecho (superpuesta 1px
    // para tapar la línea).
    expect(tester.getTopLeft(_toggle).dx, closeTo(259, 0.5));
    final expandedHeight = tester.getCenter(_toggle).dy;

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isFalse);
    expect(_widthSideMenu(tester), 0);
    expect(find.text('Cerrar sesión'), findsNothing);
    // Oculta: la pestaña sigue entera dentro de la pantalla, pegada al borde
    // izquierdo y a la misma altura (no centrada en la pantalla).
    expect(tester.getTopLeft(_toggle).dx, greaterThanOrEqualTo(0));
    expect(tester.getCenter(_toggle).dy, expandedHeight);
    expect(tester.getTopLeft(find.byType(AppTopBar)).dx, 0);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuExpandedProvider), isTrue);
    expect(_widthSideMenu(tester), 260);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // El Tooltip se dibuja con OverlayPortal.overlayChildLayoutBuilder, que no
  // tolera un CompositedTransformFollower entre él y el Overlay: con el mouse
  // encima, el clic rompía el layout (pantalla roja) y la sidebar no se movía.
  testWidgets('Hover muestra el tooltip y el clic oculta la sidebar', (
    tester,
  ) async {
    final container = await _showScreen(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_toggle));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Ocultar menú'), findsOneWidget);

    await tester.tap(_toggle, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(sideMenuExpandedProvider), isFalse);
    expect(_widthSideMenu(tester), 0);

    await mouse.moveTo(tester.getCenter(_toggle));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Mostrar menú'), findsOneWidget);

    await tester.tap(_toggle, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_widthSideMenu(tester), 260);
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
