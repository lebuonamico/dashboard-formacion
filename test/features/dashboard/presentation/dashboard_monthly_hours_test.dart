import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_monthly_hours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, List<MonthlyHours> points) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: DashboardMonthlyHours(evolutionAsync: AsyncData(points)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('La meta es la del último mes, no 8 h fijas', (tester) async {
    await _show(tester, [
      MonthlyHours(month: DateTime(2026, 8), hours: 5, target: 8),
      MonthlyHours(month: DateTime(2026, 9), hours: 4, target: 6.5),
    ]);

    expect(find.text('Meta: 6.5 h'), findsOne);
    expect(
      find.text('Horas válidas promedio por colaborador vs meta (6,5 h)'),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sin meta ni horas no rompe el gráfico', (tester) async {
    await _show(tester, [
      MonthlyHours(month: DateTime(2026, 9), hours: 0, target: 0),
    ]);

    expect(find.text('Meta: 0.0 h'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sin meses muestra el aviso', (tester) async {
    await _show(tester, const []);

    expect(find.byType(EmptyDataState), findsOne);
  });
}
