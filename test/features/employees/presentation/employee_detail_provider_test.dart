import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer july() {
    final container = ProviderContainer(
      overrides: [
        periodFilterProvider.overrideWith(
          () => PeriodFilterNotifier(
            const PeriodFilter(
              scope: PeriodScope.monthly,
              month: 7,
              year: 2026,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('el perfil de EMP-005 en julio de 2026 sale del seed', () async {
    final detail = await july().read(employeeDetailProvider('EMP-005').future);

    expect(detail, isNotNull);
    expect(detail!.employee.employeeId, 'EMP-005');
    expect(detail.hasPeriodData, isTrue);
    expect(detail.hasEmployeeData, isTrue);
    expect(detail.crmHours, 10);
    expect(detail.creditedLmsHours, 4);
    expect(
      detail.timeEntryGroups.map(
        (group) => (group.key, group.hours, group.isCompleted),
      ),
      [
        ('id:CUR-S1', 4, true),
        ('id:CUR-E1', 2, false),
        ('id:CUR-T1', 4, false),
      ],
    );
    expect(detail.certifications.map((item) => item.course?.id), ['CUR-S1']);
    expect(detail.taughtCourses.map((course) => (course.code, course.hours)), [
      ('CUR-T1', 4),
    ]);
  }, skip: SupabaseConfig.enabled);

  test('un legajo que no está en la nómina da null', () async {
    final detail = await july().read(employeeDetailProvider('EMP-999').future);

    expect(detail, isNull);
  }, skip: SupabaseConfig.enabled);
}
