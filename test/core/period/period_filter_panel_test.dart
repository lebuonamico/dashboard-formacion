import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/period_filter_panel.dart';
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
          home: const Scaffold(body: PeriodFilterPanel()),
        ),
      ),
    );
    await tester.pump();

    final month = find.byIcon(Icons.calendar_month_outlined);
    expect(month, findsOne);

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(PeriodFilterPanel)),
    ).read(periodScopeProvider.notifier);

    scope.state = PeriodScope.annual;
    await tester.pump();
    expect(month, findsNothing);

    scope.state = PeriodScope.monthly;
    await tester.pump();
    expect(month, findsOne);
  });
}
