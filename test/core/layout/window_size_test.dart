import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pump_screen.dart';

/// Mounts a screen that publishes what it reads from its context.
Future<({WindowSize size, bool modal, EdgeInsets padding})> _readAt(
  WidgetTester tester,
  Size size,
) async {
  late WindowSize windowSize;
  late bool modal;
  late EdgeInsets padding;
  await pumpScreen(
    tester,
    initialLocation: '/',
    size: size,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          windowSize = context.windowSize;
          modal = context.usesModalNavigation;
          padding = screenPaddingOf(context);
          return const SizedBox.expand();
        },
      ),
    ],
  );
  return (size: windowSize, modal: modal, padding: padding);
}

void main() {
  group('WindowSize.fromWidth', () {
    final cases = <double, WindowSize>{
      0: WindowSize.compact,
      360: WindowSize.compact,
      599.9: WindowSize.compact,
      600: WindowSize.medium,
      768: WindowSize.medium,
      839.9: WindowSize.medium,
      840: WindowSize.expanded,
      1400: WindowSize.expanded,
    };
    for (final MapEntry(key: width, value: expected) in cases.entries) {
      test('$width px es $expected', () {
        expect(WindowSize.fromWidth(width), expected);
      });
    }
  });

  test('solo el escritorio usa el menú lateral fijo', () {
    expect(WindowSize.compact.usesModalNavigation, isTrue);
    expect(WindowSize.medium.usesModalNavigation, isTrue);
    expect(WindowSize.expanded.usesModalNavigation, isFalse);
  });

  testWidgets('en el teléfono la ventana es compacta y el margen es 16', (
    tester,
  ) async {
    final read = await _readAt(tester, compactSize);
    expect(read.size, WindowSize.compact);
    expect(read.modal, isTrue);
    expect(
      read.padding,
      const EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomFloatingReserve),
    );
  });

  testWidgets('en una tablet vertical la ventana es mediana', (tester) async {
    final read = await _readAt(tester, const Size(768, 1024));
    expect(read.size, WindowSize.medium);
    expect(read.modal, isTrue);
    expect(read.padding, screenPadding);
  });

  testWidgets('en escritorio el layout y el margen no cambian', (tester) async {
    final read = await _readAt(tester, desktopSize);
    expect(read.size, WindowSize.expanded);
    expect(read.modal, isFalse);
    expect(read.padding, screenPadding);
  });

  group('Teléfono en horizontal', () {
    test('ancho de escritorio pero bajo es mediano', () {
      expect(WindowSize.fromSize(const Size(844, 390)), WindowSize.medium);
      expect(WindowSize.fromSize(const Size(1024, 479)), WindowSize.medium);
    });

    test('desde 480 de alto vuelve a ser escritorio', () {
      expect(WindowSize.fromSize(const Size(1024, 480)), WindowSize.expanded);
      expect(WindowSize.fromSize(desktopSize), WindowSize.expanded);
    });

    test('los anchos chicos no cambian por la altura', () {
      expect(WindowSize.fromSize(const Size(390, 300)), WindowSize.compact);
      expect(WindowSize.fromSize(const Size(700, 300)), WindowSize.medium);
    });

    testWidgets('844×390 usa el menú modal', (tester) async {
      final read = await _readAt(tester, const Size(844, 390));
      expect(read.size, WindowSize.medium);
      expect(read.modal, isTrue);
    });
  });
}
