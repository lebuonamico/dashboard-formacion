import 'package:app_finnegans/features/reports/data/printing_print_repository.dart';
import 'package:app_finnegans/features/reports/domain/print_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The browser's or the system's print dialog, the same in both modes.
final printRepositoryProvider = Provider<PrintRepository>(
  (ref) => const PrintingPrintRepository(),
);
