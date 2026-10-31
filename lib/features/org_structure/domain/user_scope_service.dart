import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';

/// Same criterion as `public.empleado_visible()` in the database, which is
/// the one in charge: here it keeps the app from depending on RLS being on,
/// and lets it be tested without Supabase.
class UserScopeService {
  final OrgStructureService structures;

  const UserScopeService({this.structures = const OrgStructureService()});

  /// Admin and academy see everything. `area` sees the areas they lead and
  /// `lider` the teams they lead. Any other role, nothing.
  UserScope scopeFor({
    required UserRole? role,
    required String? email,
    required OrgStructure? structure,
  }) {
    if (role != null && role.canManage) return const UserScope.total();
    if (email == null || structure == null) return const UserScope.none();
    return switch (role) {
      UserRole.areaLead => UserScope(
        areaKeys: structures
            .ledAreasBy(structure, email)
            .map((area) => normalizeLoose(area.name))
            .toSet(),
      ),
      UserRole.teamLead => UserScope(
        teamKeys: structures
            .teamsLedBy(structure, email)
            .map(
              (led) => (
                normalizeLoose(led.area.name),
                normalizeLoose(led.team.name),
              ),
            )
            .toSet(),
      ),
      _ => const UserScope.none(),
    };
  }

  /// Whether it sees an employee with that payroll Sector and Team.
  bool includes(UserScope scope, String sector, String team) {
    if (scope.isTotal) return true;
    final area = normalizeLoose(sector);
    return scope.areaKeys.contains(area) ||
        scope.teamKeys.contains((area, normalizeLoose(team)));
  }

  bool includesEmployee(UserScope scope, Employee employee) =>
      includes(scope, employee.area, employee.team);

  /// Employee filter for the period calculation: `null` if it sees everything.
  bool Function(Employee employee)? employeeFilter(UserScope scope) =>
      scope.isTotal ? null : (employee) => includesEmployee(scope, employee);
}
