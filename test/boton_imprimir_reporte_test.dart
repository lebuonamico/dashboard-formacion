import 'dart:async';

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/boton_imprimir_reporte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _reporte = ReporteFormacion(
  tipo: TipoReporte.equipo,
  titulo: 'Core',
  periodo: 'Octubre 2026',
  integrantes: 0,
  enObjetivo: 0,
  horas: 0,
  objetivo: 0,
  porcentaje: 0,
  estado: 'Crítico',
  nivel: NivelReporte.critico,
  miembros: [],
);

Future<void> _montar(
  WidgetTester tester, {
  required Future<ReporteFormacion?> Function() reporte,
  required ImprimirReporte imprimir,
}) async {
  final reporteProvider = FutureProvider<ReporteFormacion?>((ref) => reporte());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [imprimirReporteProvider.overrideWithValue(imprimir)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(child: BotonImprimirReporte(reporte: reporteProvider)),
        ),
      ),
    ),
  );
  await tester.pump();
}

OutlinedButton _boton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.bySubtype<OutlinedButton>());

String _ayuda(WidgetTester tester) =>
    tester.widget<Tooltip>(find.byType(Tooltip)).message!;

Future<void> _sinImprimir(ReporteFormacion _) async =>
    fail('No debería imprimir');

void main() {
  testWidgets('Con el reporte listo imprime ese reporte', (tester) async {
    final impresos = <ReporteFormacion>[];
    await _montar(
      tester,
      reporte: () async => _reporte,
      imprimir: (reporte) async => impresos.add(reporte),
    );

    expect(_boton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(impresos, [same(_reporte)]);
    expect(find.text('Imprimir reporte'), findsOne);
  });

  testWidgets('Sin datos en el período queda deshabilitado', (tester) async {
    await _montar(tester, reporte: () async => null, imprimir: _sinImprimir);

    expect(_boton(tester).onPressed, isNull);
    expect(_ayuda(tester), 'No hay datos para reportar en este período');
  });

  testWidgets('Mientras cargan los datos queda deshabilitado', (tester) async {
    final pendiente = Completer<ReporteFormacion?>();
    await _montar(
      tester,
      reporte: () => pendiente.future,
      imprimir: _sinImprimir,
    );

    expect(_boton(tester).onPressed, isNull);
    expect(_ayuda(tester), 'Cargando datos…');
  });

  testWidgets('Si falla la impresión lo avisa y se puede reintentar', (
    tester,
  ) async {
    await _montar(
      tester,
      reporte: () async => _reporte,
      imprimir: (_) async => throw StateError('sin fuentes'),
    );

    await tester.tap(find.text('Imprimir reporte'));
    await tester.pump();

    expect(
      find.text('No se pudo generar el reporte: Bad state: sin fuentes'),
      findsOne,
    );
    expect(_boton(tester).onPressed, isNotNull);
  });
}
