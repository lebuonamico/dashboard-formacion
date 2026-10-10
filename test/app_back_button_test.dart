import 'package:app_finnegans/presentation/widgets/shared/app_back_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color? _fondo(WidgetTester tester) {
  final contenedor = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(AppBackButton),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (contenedor.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('La flecha llama a onPressed al tocarla', (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppBackButton(onPressed: () => toques++)),
      ),
    );

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(toques, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El feedback es un fondo que se desvanece, sin ripple', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AppBackButton(onPressed: () {})),
        ),
      ),
    );
    expect(_fondo(tester), Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(AppBackButton)));
    await tester.pump();
    await tester.pumpAndSettle();
    // Con el mouse encima aparece el fondo.
    expect(_fondo(tester), isNot(Colors.transparent));

    // Al presionar, el fondo se oscurece un poco más (no hay ripple).
    final fondoHover = _fondo(tester);
    await mouse.down(tester.getCenter(find.byType(AppBackButton)));
    await tester.pumpAndSettle();
    expect(_fondo(tester), isNot(fondoHover));
    await mouse.up();
    await tester.pumpAndSettle();

    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(_fondo(tester), Colors.transparent);
  });
}
