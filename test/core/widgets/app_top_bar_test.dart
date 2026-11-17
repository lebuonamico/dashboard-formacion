import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/auth/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pump_screen.dart';

Future<GoRouter> _show(WidgetTester tester, {required String initial}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/empleados',
        builder: (context, state) => const Scaffold(body: Text('Listado')),
      ),
      GoRoute(
        path: '/empleados/:id',
        builder: (context, state) => const Scaffold(
          body: AppTopBar(title: 'Detalle', backTo: '/empleados'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: const [],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('Abierto desde un link, volver lleva a la sección padre', (
    tester,
  ) async {
    final router = await _show(tester, initial: '/empleados/10');
    expect(router.canPop(), isFalse);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Listado'), findsOneWidget);
    expect(router.state.uri.path, '/empleados');
  });

  testWidgets('Sin top bar de detalle no hay flecha para volver', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: const [],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AppTopBar(title: 'Inicio')),
        ),
      ),
    );

    expect(find.byType(AppBackButton), findsNothing);
  });

  group('Ancho de la ventana', () {
    const title = 'Catálogo de cursos y formaciones';

    Future<void> show(WidgetTester tester, Size size) => pumpScreen(
      tester,
      initialLocation: '/cursos',
      size: size,
      routes: [
        GoRoute(
          path: '/cursos',
          builder: (context, state) =>
              const Scaffold(body: AppTopBar(title: title)),
        ),
      ],
    );

    testWidgets('En escritorio el avatar muestra el nombre', (tester) async {
      await show(tester, desktopSize);

      expect(find.text('Modo local'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('A 360 px el avatar muestra solo la foto y su menú entra', (
      tester,
    ) async {
      await show(tester, const Size(360, 640));

      expect(find.text('Modo local'), findsNothing);
      // Sin shell no hay menú modal que abrir.
      expect(find.byKey(const Key('modal_menu_open')), findsNothing);
      final avatar = tester.getRect(find.byType(UserAvatar));
      expect(avatar.width, greaterThanOrEqualTo(48));
      expect(avatar.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      expect(find.text('Tema oscuro'), findsOneWidget);
      expect(find.text('Modo local'), findsOneWidget);
      final card = tester.getRect(find.text('Tema oscuro'));
      expect(card.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });
  });
}
