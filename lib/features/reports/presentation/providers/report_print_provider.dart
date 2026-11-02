import 'dart:async';

import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportPrintProvider = AsyncNotifierProvider<ReportPrintNotifier, void>(
  ReportPrintNotifier.new,
);

/// Loading while a report is generated. A failure is rethrown and the state
/// goes back to idle, so the button can retry.
class ReportPrintNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> printReport(TrainingReport report) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(printReportProvider)(report);
    } finally {
      if (ref.mounted) state = const AsyncData(null);
    }
  }
}
