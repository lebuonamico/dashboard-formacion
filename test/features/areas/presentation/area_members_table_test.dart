import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_members_table.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeCompliance _member(String employeeId, String lastName, double hours) =>
    const EmployeeComplianceService().summarize(
      employee: Employee(
        employeeId: employeeId,
        firstName: 'Persona',
        lastName: lastName,
        seniority: Seniority.junior1,
        area: 'SERVICIOS',
        email: 'persona$employeeId@finnegans.com',
        team: 'IMPLEMENTACIONES',
        isActive: true,
      ),
      creditedHours: {CourseCategory.softSkills: hours},
      declaredHours: {CourseCategory.softSkills: hours},
      requiredHours: {CourseCategory.softSkills: 10},
    );

final _members = [
  _member('1', 'Cumplida', 10),
  _member('2', 'Riesgosa', 8),
  _member('3', 'Critica', 1),
];

class _FilteredTable extends ConsumerWidget {
  const _FilteredTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AreaMembersTable(
    members: _members,
    filter: ref.watch(areaMemberStatusFilterProvider),
    onFilter: (levels) =>
        ref.read(areaMemberStatusFilterProvider.notifier).select(levels),
  );
}

void main() {
  test('El filtro de integrantes se elige y se limpia', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(areaMemberStatusFilterProvider, (_, _) {});
    final filter = container.read(areaMemberStatusFilterProvider.notifier);

    filter.select({ComplianceLevel.critical});
    expect(container.read(areaMemberStatusFilterProvider), {
      ComplianceLevel.critical,
    });

    filter.clear();
    expect(container.read(areaMemberStatusFilterProvider), isEmpty);
  });

  testWidgets('Filtrar por Críticos deja solo a los críticos', (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: _FilteredTable()),
          ),
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

    expect(find.text('Integrantes (3)'), findsOneWidget);

    container.read(areaMemberStatusFilterProvider.notifier).select({
      ComplianceLevel.critical,
    });
    await tester.pumpAndSettle();

    expect(find.text('Integrantes (1)'), findsOneWidget);
    expect(find.text('Persona Critica'), findsOneWidget);
    expect(find.text('Persona Cumplida'), findsNothing);
    expect(find.text('Persona Riesgosa'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
