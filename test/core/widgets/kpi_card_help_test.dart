import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card({String? help}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SizedBox(
      width: 300,
      child: DashboardKpiCard(
        title: 'HORAS VÁLIDAS',
        value: '10 h',
        suffix: 'para el objetivo',
        progress: 0.5,
        progressLabel: 'Meta: 20 h',
        footer: '',
        icon: Icons.schedule_outlined,
        color: Colors.blue,
        help: help,
      ),
    ),
  ),
);

void main() {
  testWidgets('Con ayuda muestra el ícono y su explicación', (tester) async {
    await tester.pumpWidget(_card(help: monthCreditedHoursHelp));

    expect(find.byIcon(Icons.info_outline), findsOne);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      monthCreditedHoursHelp,
    );
  });

  testWidgets('Sin ayuda no muestra el ícono', (tester) async {
    await tester.pumpWidget(_card());

    expect(find.byIcon(Icons.info_outline), findsNothing);
  });
}
