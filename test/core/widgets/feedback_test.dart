import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (built) {
            context = built;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  group('runWithResultFeedback', () {
    testWidgets('avisa el éxito con el resultado', (tester) async {
      final context = await _context(tester);

      final result = await runWithResultFeedback<int>(
        context,
        action: () async => 3,
        success: (count) => 'Se importaron $count registros.',
      );
      await tester.pump();

      expect(result, 3);
      expect(find.text('Se importaron 3 registros.'), findsOneWidget);
    });

    testWidgets('un resultado nulo es una cancelación y no avisa nada', (
      tester,
    ) async {
      final context = await _context(tester);

      final result = await runWithResultFeedback<int>(
        context,
        action: () async => null,
        success: (_) => fail('Una cancelación no es un éxito.'),
      );
      await tester.pump();

      expect(result, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('un error muestra su mensaje y devuelve nulo', (tester) async {
      final context = await _context(tester);

      final result = await runWithResultFeedback<int>(
        context,
        action: () async => throw const FormatException('Archivo inválido'),
        success: (_) => fail('Un error no es un éxito.'),
      );
      await tester.pump();

      expect(result, isNull);
      expect(find.text('Archivo inválido'), findsOneWidget);
    });

    testWidgets('el mensaje de error se puede reemplazar', (tester) async {
      final context = await _context(tester);

      await runWithResultFeedback<int>(
        context,
        action: () async => throw StateError('sin conexión'),
        success: (_) => '',
        failure: (error) => 'No se pudo importar: $error',
      );
      await tester.pump();

      expect(
        find.text('No se pudo importar: Bad state: sin conexión'),
        findsOneWidget,
      );
    });
  });
}
