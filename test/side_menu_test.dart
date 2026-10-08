import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/side_menu_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _mostrarPantalla(WidgetTester tester) async {
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

double _anchoSideMenu(WidgetTester tester) =>
    tester.getSize(find.byType(SideMenu)).width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arranca desplegada con el header alineado al top bar', (
    tester,
  ) async {
    final container = await _mostrarPantalla(tester);

    expect(container.read(sideMenuDesplegadoProvider), isTrue);
    expect(_anchoSideMenu(tester), 260);
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
    final container = await _mostrarPantalla(tester);

    // Desplegada: la pestaña queda centrada sobre el borde derecho.
    expect(tester.getCenter(_toggle).dx, closeTo(260, 0.5));
    final altoDesplegada = tester.getCenter(_toggle).dy;

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuDesplegadoProvider), isFalse);
    expect(_anchoSideMenu(tester), 0);
    expect(find.text('Cerrar sesión'), findsNothing);
    // Oculta: la pestaña sigue entera dentro de la pantalla y a la misma
    // altura, sobre la línea del top bar (no centrada en la pantalla).
    expect(tester.getTopLeft(_toggle).dx, greaterThanOrEqualTo(0));
    expect(tester.getCenter(_toggle).dy, altoDesplegada);
    expect(tester.getTopLeft(find.byType(AppTopBar)).dx, 0);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();

    expect(container.read(sideMenuDesplegadoProvider), isTrue);
    expect(_anchoSideMenu(tester), 260);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // El Tooltip se dibuja con OverlayPortal.overlayChildLayoutBuilder, que no
  // tolera un CompositedTransformFollower entre él y el Overlay: con el mouse
  // encima, el clic rompía el layout (pantalla roja) y la sidebar no se movía.
  testWidgets('Hover muestra el tooltip y el clic oculta la sidebar', (
    tester,
  ) async {
    final container = await _mostrarPantalla(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_toggle));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Ocultar menú'), findsOneWidget);

    await tester.tap(_toggle, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(sideMenuDesplegadoProvider), isFalse);
    expect(_anchoSideMenu(tester), 0);

    await mouse.moveTo(tester.getCenter(_toggle));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Mostrar menú'), findsOneWidget);

    await tester.tap(_toggle, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_anchoSideMenu(tester), 260);
  });
}
