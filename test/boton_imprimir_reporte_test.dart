import 'dart:async';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/boton_imprimir_reporte.dart';
import 'package:flutter/material.dart';
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

Future<void> _mount(
  WidgetTester tester, {
  required Future<TrainingReport?> Function() report,
  required PrintReport print,
}) async {
  final reportProvider = FutureProvider<TrainingReport?>((ref) => report());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [printReportProvider.overrideWithValue(print)],
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
      find.text('No se pudo generar el reporte: Bad state: sin fuentes'),
      findsOne,
    );
    expect(_button(tester).onPressed, isNotNull);
  });
}
