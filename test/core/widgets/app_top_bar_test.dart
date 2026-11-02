import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
}
