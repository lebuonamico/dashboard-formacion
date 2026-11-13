import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/compliance_kpi_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _showMonthly(
  WidgetTester tester, {
  required double hoursPerPerson,
  required double previous,
}) {
  tester.view.physicalSize = const Size(2400, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: ComplianceKpiCard(
            isAnnual: false,
            year: 2026,
            month: 7,
            percentage: 76,
            variation: ComplianceVariation(
              points: null,
              hoursPerPerson: hoursPerPerson,
              previousHoursPerPerson: previous,
              hours: hoursPerPerson - previous,
            ),
          ),
        ),
      ),
    ),
  );
}

String _badge(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('kpi_variacion_mes')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  testWidgets('La variación es la resta de las horas que se muestran', (
    tester,
  ) async {
    // Sin redondear la resta da -0,11 ("-0,1"); se ven 4,2 y 4,4.
    await _showMonthly(tester, hoursPerPerson: 4.24, previous: 4.35);

    expect(find.text('CUMPLIMIENTO · JULIO 2026'), findsOne);
    expect(find.text('4,2 hs por colaborador'), findsOne);
    expect(find.text('Mes anterior: 4,4 hs'), findsOne);
    expect(_badge(tester), '▼ -0,2 hs vs mes anterior');
  });

  testWidgets('Si las horas que se muestran son iguales, no hay variación', (
    tester,
  ) async {
    await _showMonthly(tester, hoursPerPerson: 4.21, previous: 4.24);

    expect(_badge(tester), '= 0,0 hs vs mes anterior');
  });

  testWidgets('Una mejora lleva signo más', (tester) async {
    await _showMonthly(tester, hoursPerPerson: 5, previous: 4.4);

    expect(find.text('5 hs por colaborador'), findsOne);
    expect(_badge(tester), '▲ +0,6 hs vs mes anterior');
  });
}
