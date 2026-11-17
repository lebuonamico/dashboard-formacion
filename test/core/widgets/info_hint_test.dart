import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/info_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: InfoHint(message: 'Qué mide este número'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('En el teléfono el toque cerca del ícono muestra la ayuda', (
    tester,
  ) async {
    await _show(tester, const Size(390, 844));

    final hint = tester.getRect(find.byType(InfoHint));
    expect(hint.size, InfoHint.touchTarget);
    // El ícono conserva su tamaño.
    expect(tester.getSize(find.byIcon(Icons.info_outline)), const Size(15, 15));

    // Un toque al costado del ícono, fuera de sus 15 px.
    await tester.tapAt(hint.centerLeft + const Offset(4, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Qué mide este número'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('En escritorio mide lo que el ícono', (tester) async {
    await _show(tester, const Size(1400, 900));
    expect(tester.getSize(find.byType(InfoHint)), const Size(15, 15));
  });
}
