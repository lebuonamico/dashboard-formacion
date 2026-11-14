import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/features/dashboard/domain/monthly_hours.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_monthly_hours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(
  WidgetTester tester,
  List<MonthlyHours> points, {
  double width = 800,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DashboardMonthlyHours(evolutionAsync: AsyncData(points)),
        ),
      ),
    ),
  ),
);

/// A full year: January 1,5 hs, February 3 hs… December 18 hs.
final _year = [
  for (var month = 1; month <= 12; month++)
    MonthlyHours(month: DateTime(2026, month), hours: month * 1.5, target: 8),
];

String _footer(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('monthly_hours_footer')))
    .textSpan!
    .toPlainText();

/// Taps the middle of the bar of [month] (1–12) in the twelve-month chart.
Future<void> _tapBar(WidgetTester tester, int month) async {
  final chart = tester.getRect(find.byKey(const Key('monthly_hours_chart')));
  final slot = (chart.width - 16) / 12;
  await tester.tapAt(
    Offset(chart.left + 8 + slot * (month - 0.5), chart.center.dy),
  );
  await tester.pump();
}

void main() {
  testWidgets('El objetivo es el del último mes, no 8 h fijas', (tester) async {
    await _show(tester, [
      MonthlyHours(month: DateTime(2026, 8), hours: 5, target: 8),
      MonthlyHours(month: DateTime(2026, 9), hours: 4, target: 6.5),
    ]);

    expect(find.text('Objetivo: 6,5 hs'), findsOne);
    expect(
      find.text('Horas válidas promedio por colaborador vs objetivo (6,5 hs)'),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sin objetivo ni horas no rompe el gráfico', (tester) async {
    await _show(tester, [
      MonthlyHours(month: DateTime(2026, 9), hours: 0, target: 0),
    ]);

    expect(find.text('Objetivo: 0 hs'), findsOne);
    expect(tester.takeException(), isNull);
  });

  group('Con barras angostas (teléfono)', () {
    testWidgets('Tocar una barra muestra su mes y sus horas con decimales', (
      tester,
    ) async {
      await _show(tester, _year, width: 358);

      expect(_footer(tester), 'Último mes: 18 hs promedio');
      expect(find.text('Tocá una barra'), findsOneWidget);

      await _tapBar(tester, 1);
      expect(_footer(tester), 'Enero: 1,5 hs promedio');
      expect(find.text('Tocá una barra'), findsNothing);

      await _tapBar(tester, 7);
      expect(_footer(tester), 'Julio: 10,5 hs promedio');

      // Tocar la misma barra vuelve al último mes.
      await _tapBar(tester, 7);
      expect(_footer(tester), 'Último mes: 18 hs promedio');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Con barras anchas no se puede tocar, como en escritorio', (
      tester,
    ) async {
      await _show(tester, _year.sublist(8), width: 358);

      expect(find.byKey(const Key('monthly_hours_chart')), findsNothing);
      expect(find.text('Tocá una barra'), findsNothing);
      expect(_footer(tester), 'Último mes: 18 hs promedio');
    });

    testWidgets('En escritorio los doce meses no se pueden tocar', (
      tester,
    ) async {
      await _show(tester, _year, width: 1100);

      expect(find.byKey(const Key('monthly_hours_chart')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Sin meses muestra el aviso', (tester) async {
    await _show(tester, const []);

    expect(find.byType(EmptyDataState), findsOne);
  });

  testWidgets('Si falla, Reintentar vuelve a pedir la sección', (tester) async {
    var attempts = 0;
    final evolution = FutureProvider<List<MonthlyHours>>((ref) async {
      attempts++;
      if (attempts == 1) throw Exception('timeout');
      return [MonthlyHours(month: DateTime(2026, 9), hours: 4, target: 8)];
    });
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: Consumer(
                builder: (context, ref, _) => DashboardMonthlyHours(
                  evolutionAsync: ref.watch(evolution),
                  onRetry: () => ref.invalidate(evolution),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorDataState), findsOne);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(ErrorDataState), findsNothing);
    expect(find.text('Objetivo: 8 hs'), findsOne);
  });
}
