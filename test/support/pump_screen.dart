import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Desktop window used by the existing screen tests.
const desktopSize = Size(1400, 900);

/// Phone window (iPhone 12–15) for the compact layout tests.
const compactSize = Size(390, 844);

/// Mounts [routes] under a `GoRouter` and a `ProviderContainer` with
/// [overrides], in a window of [size] logical pixels, and returns both so the
/// test can navigate or read providers. Everything is disposed on teardown.
///
/// [textScale] is 0.5 by default because the test font draws every glyph one
/// em wide: at 0.5 the text is about as wide as Roboto in the browser, so a
/// compact test does not report overflows a real phone would not have.
///
/// With [retryErrors] false, providers do not retry a failed load (needed when
/// the test checks that an error reaches the screen). With [settle], it waits
/// for `pumpAndSettle` and checks that nothing threw.
Future<({GoRouter router, ProviderContainer container})> pumpScreen(
  WidgetTester tester, {
  required String initialLocation,
  required List<RouteBase> routes,
  List<Override> overrides = const [],
  Size size = desktopSize,
  double textScale = 0.5,
  ThemeData? theme,
  bool retryErrors = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: overrides,
    retry: retryErrors ? null : (_, _) => null,
  );
  addTearDown(container.dispose);

  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
  return (router: router, container: container);
}
