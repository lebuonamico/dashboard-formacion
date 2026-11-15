import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

void main() {
  testWidgets('El mes solo se muestra con el período mensual', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          availableTeamYearsProvider.overrideWith((ref) async => [2026]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PeriodFilterPanel()),
        ),
      ),
    );
    await tester.pump();

    final month = find.byIcon(Icons.calendar_month_outlined);
    expect(month, findsOne);

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(PeriodFilterPanel)),
    ).read(periodFilterProvider.notifier);

    scope.setScope(PeriodScope.annual);
    await tester.pump();
    expect(month, findsNothing);

    scope.setScope(PeriodScope.monthly);
    await tester.pump();
    expect(month, findsOne);
  });

  group('En el teléfono', () {
    Future<ProviderContainer> show(WidgetTester tester, Size size) async {
      final (router: _, :container) = await pumpScreen(
        tester,
        initialLocation: '/',
        size: size,
        overrides: [
          availableTeamYearsProvider.overrideWith((ref) async => [2025, 2026]),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: PeriodFilterPanel(
                  action: OutlinedButton(
                    onPressed: null,
                    child: Text('Imprimir reporte'),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      return container;
    }

    final segments = find.byKey(const Key('period_scope_segments'));

    testWidgets('A 390 px: segmentado a lo ancho y mes y año en una fila', (
      tester,
    ) async {
      await show(tester, compactSize);

      expect(segments, findsOneWidget);
      // Sin íconos, para que el valor entre.
      expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
      final monthTop = tester.getTopLeft(find.text('Mes').first).dy;
      expect(tester.getTopLeft(find.text('Año').first).dy, monthTop);
      expect(
        tester.getSize(find.byType(PeriodFilterPanel)).height,
        lessThan(220),
      );
      // Across the panel, inside its padding and border.
      expect(
        tester.getSize(segments).width,
        closeTo(tester.getSize(find.byType(PeriodFilterPanel)).width - 34, 1),
      );
    });

    testWidgets('El segmentado cambia el alcance y el mes se elige en un '
        'sheet', (tester) async {
      final container = await show(tester, compactSize);

      await tester.tap(find.text('Anual'));
      await tester.pumpAndSettle();
      expect(container.read(periodFilterProvider).scope, PeriodScope.annual);
      expect(find.text('Mes'), findsNothing);

      await tester.tap(find.text('Mensual'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilterDropdown<int>).first);
      await tester.pumpAndSettle();
      // Doce meses: sin búsqueda y en su orden, aunque el elegido no sea enero.
      expect(find.byType(TextField), findsNothing);
      final firstTile = find.byType(ListTile).first;
      expect(
        find.descendant(of: firstTile, matching: find.text('Enero')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Marzo'));
      await tester.pumpAndSettle();

      expect(container.read(periodFilterProvider).month, 3);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A 360×640 entra sin desbordes', (tester) async {
      await show(tester, const Size(360, 640));
      expect(segments, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('En la tablet (768 px): alcance, mes y año en una fila', (
      tester,
    ) async {
      final container = await show(tester, const Size(768, 1024));

      expect(find.byKey(const Key('period_single_row')), findsOneWidget);
      final fields = find.byType(FilterDropdown<int>);
      expect(fields, findsNWidgets(2));
      final scopeY = tester.getCenter(find.text('Mensual')).dy;
      expect(tester.getCenter(fields.first).dy, closeTo(scopeY, 1));
      expect(tester.getCenter(fields.last).dy, closeTo(scopeY, 1));

      container
          .read(periodFilterProvider.notifier)
          .setScope(PeriodScope.annual);
      await tester.pumpAndSettle();
      expect(fields, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Una ventana de escritorio angosta conserva el apilado', (
      tester,
    ) async {
      await show(tester, const Size(850, 800));
      // 850 - 64 de márgenes: menos de 820, pero la ventana es de escritorio.
      expect(find.byKey(const Key('period_single_row')), findsNothing);
      final fields = find.byType(FilterDropdown<int>);
      expect(
        tester.getCenter(fields.last).dy,
        greaterThan(tester.getCenter(fields.first).dy),
      );
    });
  });
}
