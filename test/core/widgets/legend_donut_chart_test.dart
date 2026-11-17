import 'package:app_finnegans/core/widgets/donut_chart.dart';
import 'package:app_finnegans/core/widgets/info_hint.dart';
import 'package:app_finnegans/core/widgets/legend_donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pump_screen.dart';

const _slices = [
  DonutSlice(
    label: 'En objetivo',
    value: 3,
    color: Colors.green,
    help: 'Cumplen el objetivo.',
  ),
  DonutSlice(
    label: 'Críticos',
    value: 1,
    color: Colors.red,
    help: 'Muy por debajo del objetivo.',
  ),
];

Future<void> _show(WidgetTester tester, Size size) => pumpScreen(
  tester,
  initialLocation: '/',
  size: size,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: LegendDonutChart(
            slices: _slices,
            centerValue: '4',
            centerLabel: 'EQUIPOS',
          ),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('En escritorio la leyenda va al costado del donut', (
    tester,
  ) async {
    await _show(tester, desktopSize);

    final donut = tester.getRect(find.byType(DonutChart));
    final legend = tester.getRect(find.text('En objetivo'));
    expect(legend.left, greaterThan(donut.right));
  });

  testWidgets('En el teléfono la leyenda va debajo del donut', (tester) async {
    await _show(tester, const Size(360, 640));

    final donut = tester.getRect(find.byType(DonutChart));
    final legend = tester.getRect(find.text('En objetivo'));
    expect(legend.top, greaterThan(donut.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('La ayuda de cada ítem se lee con un toque', (tester) async {
    await _show(tester, compactSize);

    await tester.tap(find.byType(InfoHint).first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cumplen el objetivo.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
