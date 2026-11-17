import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color? _background(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(AppBackButton),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('La flecha llama a onPressed al tocarla', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: AppBackButton(onPressed: () => taps++)),
      ),
    );

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El feedback es un fondo que se desvanece, sin ripple', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(child: AppBackButton(onPressed: () {})),
        ),
      ),
    );
    expect(_background(tester), Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(AppBackButton)));
    await tester.pump();
    await tester.pumpAndSettle();
    // Con el mouse encima aparece el fondo.
    expect(_background(tester), isNot(Colors.transparent));

    // Al presionar, el fondo se oscurece un poco más (no hay ripple).
    final hoverBackground = _background(tester);
    await mouse.down(tester.getCenter(find.byType(AppBackButton)));
    await tester.pumpAndSettle();
    expect(_background(tester), isNot(hoverBackground));
    await mouse.up();
    await tester.pumpAndSettle();

    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(_background(tester), Colors.transparent);
  });

  group('Área táctil', () {
    Future<List<int>> show(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AppBackButton(onPressed: () => taps.add(1)),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('En el teléfono mide 48 y el toque cerca del borde cuenta', (
      tester,
    ) async {
      final taps = await show(tester, const Size(390, 844));
      final rect = tester.getRect(find.byType(AppBackButton));
      expect(rect.size, const Size(48, 48));
      // El cuadrado visible sigue de 40.
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(AppBackButton),
            matching: find.byType(AnimatedContainer),
          ),
        ),
        const Size(40, 40),
      );

      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(taps, hasLength(1));
    });

    testWidgets('En escritorio sigue de 40', (tester) async {
      await show(tester, const Size(1400, 900));
      expect(tester.getSize(find.byType(AppBackButton)), const Size(40, 40));
    });
  });
}
