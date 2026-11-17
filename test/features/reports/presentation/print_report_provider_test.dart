import 'dart:typed_data';

import 'package:app_finnegans/features/reports/domain/print_repository.dart';
import 'package:app_finnegans/features/reports/domain/report_output.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/domain/training_report_builder.dart';
import 'package:app_finnegans/features/reports/presentation/providers/print_repository_provider.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/features/reports/presentation/report_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _report = const TrainingReportBuilder().build(
  type: ReportType.team,
  title: 'Core',
  period: 'Octubre 2026',
  memberCount: 0,
  onTarget: 0,
  hours: 0,
  target: 0,
  percentage: 0,
  level: ReportLevel.critical,
  members: const [],
);

class _FakePrintRepository implements PrintRepository {
  final printed = <String>[];
  final downloaded = <String>[];

  @override
  Future<void> printPdf(Uint8List bytes, {required String fileName}) async {
    expect(bytes, isNotEmpty);
    printed.add(fileName);
  }

  @override
  Future<void> downloadPdf(Uint8List bytes, {required String fileName}) async {
    expect(bytes, isNotEmpty);
    downloaded.add(fileName);
  }
}

Future<_FakePrintRepository> _run({ReportOutput? output}) async {
  final repository = _FakePrintRepository();
  final container = ProviderContainer(
    overrides: [
      printRepositoryProvider.overrideWithValue(repository),
      if (output != null) reportOutputProvider.overrideWithValue(output),
    ],
  );
  addTearDown(container.dispose);
  await container.read(printReportProvider)(_report);
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Fuera del navegador del celular abre el diálogo de impresión',
    () async {
      final repository = await _run();

      expect(repository.printed, [reportFileName(_report)]);
      expect(repository.downloaded, isEmpty);
    },
  );

  test('En el celular descarga el PDF con su nombre', () async {
    final repository = await _run(output: ReportOutput.download);

    expect(repository.downloaded, ['reporte_de_equipo_core_octubre_2026.pdf']);
    expect(repository.printed, isEmpty);
  });
}
