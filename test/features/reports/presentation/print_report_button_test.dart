import 'package:app_finnegans/features/reports/domain/training_report_builder.dart';
import 'dart:async';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/reports/domain/report_output.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/print_repository_provider.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/features/reports/presentation/widgets/print_report_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_screen.dart';

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

Future<void> _mount(
  WidgetTester tester, {
  required Future<TrainingReport?> Function() report,
  required PrintReport print,
  Size? size,
  ReportOutput? output,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final reportProvider = FutureProvider<TrainingReport?>((ref) => report());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        printReportProvider.overrideWithValue(print),
        if (output != null) reportOutputProvider.overrideWithValue(output),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(child: PrintReportButton(report: reportProvider)),
        ),
      ),
    ),
  );
  await tester.pump();
}

OutlinedButton _button(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.bySubtype<OutlinedButton>());

String _help(WidgetTester tester) =>
    tester.widget<Tooltip>(find.byType(Tooltip)).message!;

Future<void> _noPrint(TrainingReport _) async => fail('No debería imprimir');

void main() {
  testWidgets('Con el reporte listo imprime ese reporte', (tester) async {
    final printed = <TrainingReport>[];
    await _mount(
      tester,
      report: () async => _report,
      print: (report) async => printed.add(report),
    );

    expect(_button(tester).onPressed, isNotNull);
    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(printed, [same(_report)]);
    expect(find.text('Imprimir reporte'), findsOne);
  });

  testWidgets('Sin datos en el período avisa que no hay datos cargados', (
    tester,
  ) async {
    await _mount(tester, report: () async => null, print: _noPrint);

    expect(_help(tester), noReportData);
    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(find.text('No hay datos cargados para este período.'), findsOne);
  });

  testWidgets('Si no se pudieron cargar los datos lo explica', (tester) async {
    await _mount(
      tester,
      report: () async => throw StateError('detalle técnico'),
      print: _noPrint,
    );

    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(find.textContaining('No se pudieron cargar los datos.'), findsOne);
    expect(find.textContaining('detalle técnico'), findsNothing);
  });

  testWidgets('Mientras cargan los datos queda deshabilitado', (tester) async {
    final pending = Completer<TrainingReport?>();
    await _mount(tester, report: () => pending.future, print: _noPrint);

    expect(_button(tester).onPressed, isNull);
    expect(_help(tester), 'Cargando datos…');
  });

  testWidgets('Mientras genera muestra el progreso y no deja reimprimir', (
    tester,
  ) async {
    final pending = Completer<void>();
    await _mount(
      tester,
      report: () async => _report,
      print: (_) => pending.future,
    );

    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(find.text('Generando…'), findsOne);
    expect(_button(tester).onPressed, isNull);

    pending.complete();
    await tester.pump();
    expect(find.text('Imprimir reporte'), findsOne);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('Si falla la impresión lo avisa y se puede reintentar', (
    tester,
  ) async {
    await _mount(
      tester,
      report: () async => _report,
      print: (_) async => throw StateError('sin fuentes'),
    );

    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(
      find.text('No se pudo generar el reporte. Intentá nuevamente.'),
      findsOne,
    );
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('En escritorio sigue el botón chico de imprimir', (tester) async {
    await _mount(
      tester,
      report: () async => _report,
      print: _noPrint,
      size: desktopSize,
    );

    expect(find.text('Imprimir reporte'), findsOne);
    expect(find.byIcon(Icons.print_outlined), findsOne);
    expect(
      tester.getSize(find.bySubtype<OutlinedButton>()).height,
      lessThanOrEqualTo(30),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('En el teléfono es un ícono de 48 px que descarga el reporte', (
    tester,
  ) async {
    final printed = <TrainingReport>[];
    await _mount(
      tester,
      report: () async => _report,
      print: (report) async => printed.add(report),
      size: compactSize,
      output: ReportOutput.download,
    );

    final button = find.byKey(const Key('print_report_icon'));
    expect(find.text('Descargar reporte'), findsNothing);
    expect(find.bySemanticsLabel('Descargar reporte'), findsOne);
    expect(find.byIcon(Icons.download_outlined), findsOne);
    expect(_help(tester), 'Descarga un PDF con los datos de esta pantalla');
    expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));

    await tester.tap(button);
    await tester.pump();

    expect(printed, [same(_report)]);
  });

  testWidgets('En el teléfono, sin datos lo explica al tocar el ícono', (
    tester,
  ) async {
    await _mount(
      tester,
      report: () async => null,
      print: _noPrint,
      size: compactSize,
      output: ReportOutput.download,
    );

    expect(_help(tester), noReportData);
    await tester.tap(find.byKey(const Key('print_report_icon')));
    await tester.pump();

    expect(find.text(noReportData), findsOne);
  });

  testWidgets('En una tablet muestra la etiqueta con 48 px de alto', (
    tester,
  ) async {
    await _mount(
      tester,
      report: () async => _report,
      print: _noPrint,
      size: const Size(700, 1000),
      output: ReportOutput.download,
    );

    expect(find.text('Descargar reporte'), findsOne);
    expect(
      tester.getSize(find.bySubtype<OutlinedButton>()).height,
      greaterThanOrEqualTo(48),
    );
  });
}
