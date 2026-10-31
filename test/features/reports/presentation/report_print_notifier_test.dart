import 'dart:async';

import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/report_print_provider.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _report = TrainingReport(
  type: ReportType.team,
  title: 'Core',
  period: 'Octubre 2026',
  memberCount: 0,
  onTarget: 0,
  hours: 0,
  target: 0,
  percentage: 0,
  status: 'Crítico',
  level: ReportLevel.critical,
  members: [],
);

ProviderContainer _container(PrintReport print) {
  final container = ProviderContainer(
    overrides: [printReportProvider.overrideWithValue(print)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(reportPrintProvider, (_, _) {});
  return container;
}

void main() {
  test('Imprime el reporte y vuelve a quedar libre', () async {
    final printed = <TrainingReport>[];
    final container = _container((report) async => printed.add(report));

    await container.read(reportPrintProvider.notifier).printReport(_report);

    expect(printed, [same(_report)]);
    expect(container.read(reportPrintProvider).isLoading, isFalse);
  });

  test('Un error se relanza y no deja el estado en error', () async {
    final container = _container((_) async => throw StateError('sin fuentes'));

    await expectLater(
      container.read(reportPrintProvider.notifier).printReport(_report),
      throwsStateError,
    );

    final state = container.read(reportPrintProvider);
    expect(state.isLoading, isFalse);
    expect(state.hasError, isFalse);
  });

  test('Mientras genera queda en curso e ignora otro pedido', () async {
    final pending = Completer<void>();
    var calls = 0;
    final container = _container((_) {
      calls++;
      return pending.future;
    });
    final notifier = container.read(reportPrintProvider.notifier);

    final printing = notifier.printReport(_report);
    expect(container.read(reportPrintProvider).isLoading, isTrue);

    await notifier.printReport(_report);
    expect(calls, 1);

    pending.complete();
    await printing;
    expect(container.read(reportPrintProvider).isLoading, isFalse);
  });
}
