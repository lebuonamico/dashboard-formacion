import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_members_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

const _section = (area: 'Desarrollo', team: 'Core');

EmployeeCompliance _member(int index) =>
    const EmployeeComplianceService().summarize(
      employee: Employee(
        employeeId: '$index',
        firstName: 'Persona',
        lastName: 'N${index.toString().padLeft(2, '0')}',
        seniority: Seniority.junior1,
        area: 'Desarrollo',
        email: 'persona$index@finnegans.com',
        team: 'Core',
        isActive: true,
      ),
      creditedHours: {CourseCategory.softSkills: index.toDouble()},
      declaredHours: {CourseCategory.softSkills: index.toDouble()},
      requiredHours: {CourseCategory.softSkills: 10},
    );

final _members = [for (var index = 1; index <= 10; index++) _member(index)];

const _overview = TeamOverview(
  id: 'desarrollo-core',
  name: 'Core',
  area: 'Desarrollo',
  leader: 'Ana',
  memberCount: 10,
  membersOnTarget: 1,
  completedHours: 55,
  targetHours: 100,
  hoursDeviation: -45,
  businessHours: 0,
  softSkillsHours: 55,
  explorationHours: 0,
  teachingHours: 0,
  averageHoursPerMember: 5.5,
  completionPercentage: 55,
  status: TeamStatus.critical,
);

Future<void> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teamDetailProvider(_section).overrideWith(
          (ref) async => TeamDetail(overview: _overview, members: _members),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: TeamMembersTable(section: _section),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showCompact(WidgetTester tester) => pumpScreen(
  tester,
  size: compactSize,
  initialLocation: '/',
  overrides: [
    teamDetailProvider(_section).overrideWith(
      (ref) async => TeamDetail(overview: _overview, members: _members),
    ),
  ],
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(
        body: SingleChildScrollView(child: TeamMembersTable(section: _section)),
      ),
    ),
    GoRoute(
      path: '/empleados/:legajo',
      builder: (_, state) => Text(
        'Perfil ${state.pathParameters['legajo']} '
        'desde ${state.uri.queryParameters['origen']}',
      ),
    ),
  ],
);

/// The pagination sits below the cards, off a phone's screen.
Future<void> _nextPage(WidgetTester tester) async {
  final next = find.byTooltip('Página siguiente');
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Finder _card(int index) => find.byKey(ValueKey('member_card_$index'));

void main() {
  testWidgets('Tocar una columna reordena y vuelve a la primera página', (
    tester,
  ) async {
    await _show(tester);
    expect(find.text('Persona N01'), findsOne);
    expect(find.text('Persona N10'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.text('Persona N10'), findsOne);
    expect(find.text('Persona N01'), findsNothing);

    await tester.tap(find.text('Cumplimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cumplimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Persona N10'), findsOne);
    expect(find.text('Persona N01'), findsNothing);
    expect(find.text('Integrantes (10)'), findsOne);
    expect(tester.takeException(), isNull);
  });

  group('A 390 px', () {
    testWidgets('Ocho tarjetas por página con la paginación debajo', (
      tester,
    ) async {
      await _showCompact(tester);

      expect(find.byType(DataTable), findsNothing);
      expect(_card(8), findsOne);
      expect(_card(9), findsNothing);
      expect(
        tester.getTopLeft(find.byType(ResultsPagination)).dy,
        greaterThan(tester.getBottomLeft(_card(8)).dy),
      );
      // A team does not repeat its own name on every card.
      expect(find.text('Equipo'), findsNothing);
      expect(find.text('Seniority'), findsNWidgets(8));

      await _nextPage(tester);
      expect(_card(9), findsOne);
      expect(_card(10), findsOne);
      expect(_card(1), findsNothing);
    });

    testWidgets('Ordenar desde el menú vuelve a la primera página', (
      tester,
    ) async {
      await _showCompact(tester);
      await _nextPage(tester);
      expect(_card(10), findsOne);

      await tester.ensureVisible(find.byKey(const Key('member_order_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('member_order_button')));
      await tester.pumpAndSettle();
      // The team's menu has no Equipo column.
      expect(find.text('Equipo'), findsNothing);
      await tester.tap(find.text('Cumplimiento').last);
      await tester.pumpAndSettle();
      // Ascending is the order they already had; choosing it again reverses
      // it: page 1 shows 10 to 3, and page 2 would have shown 2 and 1.
      await tester.tap(find.byKey(const Key('member_order_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cumplimiento').last);
      await tester.pumpAndSettle();

      expect(_card(10), findsOne);
      expect(_card(3), findsOne);
      expect(_card(2), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tocar una tarjeta abre el perfil desde Equipos', (
      tester,
    ) async {
      await _showCompact(tester);

      await tester.tap(_card(3));
      await tester.pumpAndSettle();

      expect(find.text('Perfil 3 desde equipos'), findsOne);
    });
  });
}
