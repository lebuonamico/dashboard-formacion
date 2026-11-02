import 'package:app_finnegans/core/theme/app_theme.dart';
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
}
