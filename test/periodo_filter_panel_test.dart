import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
          home: const Scaffold(body: PeriodoFilterPanel()),
        ),
      ),
    );
    await tester.pump();

    final mes = find.byIcon(Icons.calendar_month_outlined);
    expect(mes, findsOne);

    final alcance = ProviderScope.containerOf(
      tester.element(find.byType(PeriodoFilterPanel)),
    ).read(alcancePeriodoProvider.notifier);

    alcance.state = AlcancePeriodo.anual;
    await tester.pump();
    expect(mes, findsNothing);

    alcance.state = AlcancePeriodo.mensual;
    await tester.pump();
    expect(mes, findsOne);
  });
}
