import 'package:app_finnegans/features/reports/data/printing_print_repository.dart';
import 'package:app_finnegans/features/reports/domain/print_repository.dart';
import 'package:app_finnegans/features/reports/domain/report_output.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The browser's or the system's print dialog, the same in both modes.
final printRepositoryProvider = Provider<PrintRepository>(
  (ref) => const PrintingPrintRepository(),
);

/// Phone browsers cannot print from the page: `printing` opens the PDF in a
/// new tab, which Safari may block because it opens after generating the
/// file. There the report is downloaded with its name. On the web Flutter
/// takes the platform from the browser's user agent.
final reportOutputProvider = Provider<ReportOutput>(
  (ref) =>
      kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? ReportOutput.download
      : ReportOutput.print,
);
