import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/admin/data/authorized_users_seed.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/certifications/data/lms_certifications_seed.dart';
import 'package:app_finnegans/features/courses/data/courses_seed.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/data/employees_seed.dart';
import 'package:app_finnegans/features/org_structure/data/org_structure_seed.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/data/crm_time_entries_seed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coherencia del seed', () {
    final employeeIds = employeesSeed.map((e) => e.employeeId).toSet();
    final courseNames = coursesSeed.map((c) => c.name).toSet();

    test(
      'las horas y las finalizaciones son de empleados y cursos que existen',
      () {
        for (final entry in crmTimeEntriesSeed) {
          expect(employeeIds, contains(entry.employeeId), reason: entry.id);
          expect(courseNames, contains(entry.courseName), reason: entry.id);
        }
        for (final certification in lmsCertificationsSeed) {
          expect(employeeIds, contains(certification.employeeId));
          expect(courseNames, contains(certification.courseName));
        }
      },
    );

    test(
      'el catálogo tiene las cuatro categorías y todos los empleados su ingreso',
      () {
        expect(
          coursesSeed.map((course) => course.category).toSet(),
          CourseCategory.values.toSet(),
        );
        expect(employeesSeed.every((e) => e.hireDate != null), isTrue);
      },
    );

    test('cada área y equipo de la nómina figura en la estructura', () {
      final structure = OrgStructure(areas: areasSeed, teams: teamsSeed);
      for (final employee in employeesSeed) {
        expect(
          const OrgStructureService().payrollTeam(
            structure,
            employee.area,
            employee.team,
          ),
          isNotNull,
          reason: employee.employeeId,
        );
      }
    });

    test('cada líder es un usuario activo con el rol que corresponde', () {
      final usersByEmail = {
        for (final user in authorizedUsersSeed) user.email: user,
      };
      void expectLeader(String email, UserRole role) {
        final AuthorizedUser? user = usersByEmail[email];
        expect(user?.knownRole, role, reason: email);
        expect(user?.isActive, isTrue, reason: email);
      }

      for (final area in areasSeed) {
        for (final email in area.leaders) {
          expectLeader(email, UserRole.areaLead);
        }
      }
      for (final team in teamsSeed) {
        for (final email in team.leaders) {
          expectLeader(email, UserRole.teamLead);
        }
      }
    });
  });

  group('Estados de los equipos con el seed', () {
    for (final month in [7, 8, 9]) {
      test('en $month/2026 hay un equipo en objetivo, uno en riesgo y uno '
          'crítico', () async {
        final container = ProviderContainer(
          overrides: [
            periodFilterProvider.overrideWith(
              () => PeriodFilterNotifier(
                PeriodFilter(
                  scope: PeriodScope.monthly,
                  month: month,
                  year: 2026,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final summary = await container.read(teamsPeriodSummaryProvider.future);

        expect(
          {for (final team in summary.teams) team.name: team.status},
          {
            'Core ERP Backend': TeamStatus.onTarget,
            'Frontend Arquitectura & UI': TeamStatus.atRisk,
            'QA Automation': TeamStatus.critical,
          },
        );
        final coreErp = summary.teams.firstWhere(
          (team) => team.name == 'Core ERP Backend',
        );
        // La baja de junio no cuenta.
        expect(coreErp.memberCount, 3);
        expect(coreErp.leader, 'Lucas Gómez');
      });
    }
  }, skip: SupabaseConfig.enabled);
}
