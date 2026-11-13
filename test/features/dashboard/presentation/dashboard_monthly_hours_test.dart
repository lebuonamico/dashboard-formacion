import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
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
