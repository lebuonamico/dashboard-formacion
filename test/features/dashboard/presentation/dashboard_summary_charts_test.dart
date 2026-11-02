import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_distribution.dart';
import 'package:app_finnegans/features/dashboard/presentation/widgets/dashboard_summary_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _distribution = (
  compliance: ComplianceDistribution(
    total: 4,
    onTarget: 2,
    atRisk: 1,
    critical: 1,
    onTargetShare: 0.5,
  ),
  categories: CategoryDistribution(
    hours: {
      CourseCategory.businessSkills: 8,
      CourseCategory.softSkills: 6,
      CourseCategory.exploration: 2,
      CourseCategory.teaching: 0,
    },
    totalHours: 16,
    averageHours: 4,
    averageTarget: 8,
    totalTarget: 32,
  ),
);

Future<GoRouter> _showDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Widget withMenu(Widget screen) => Scaffold(
    body: Row(
      children: [
        const AppNavigationDrawer(),
        Expanded(child: screen),
      ],
    ),
  );
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => withMenu(
          const SingleChildScrollView(
            child: DashboardSummaryCharts(
              distributionAsync: AsyncData(_distribution),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/empleados',
        builder: (context, state) => withMenu(const Text('Nómina')),
      ),
      GoRoute(
        path: '/cursos',
        builder: (context, state) => withMenu(const Text('Catálogo')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return router;
}

/// La etiqueta del ítem marcado en el menú lateral.
String? _selectedLabel(WidgetTester tester) {
  final drawer = tester.widget<NavigationDrawer>(find.byType(NavigationDrawer));
  final index = drawer.selectedIndex;
  if (index == null) return null;
  final destination = drawer.children
      .whereType<NavigationDrawerDestination>()
      .elementAt(index);
  return (destination.label as Text).data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ver nómina reemplaza el Dashboard y marca Empleados', (
    tester,
  ) async {
    final router = await _showDashboard(tester);

    await tester.tap(find.text('Ver nómina'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/empleados');
    expect(find.text('Nómina'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(_selectedLabel(tester), 'Empleados');
  });

  testWidgets('Ver cursos reemplaza el Dashboard y marca Cursos', (
    tester,
  ) async {
    final router = await _showDashboard(tester);

    await tester.tap(find.text('Ver cursos'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/cursos');
    expect(router.canPop(), isFalse);
    expect(_selectedLabel(tester), 'Cursos');
  });
}
