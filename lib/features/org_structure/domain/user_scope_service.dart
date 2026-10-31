import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';

/// Mismo criterio que `public.empleado_visible()` en la base, que es la que
/// manda: acá sirve para que la app no dependa de que el RLS esté encendido y
/// para poder probarlo sin Supabase.
class UserScopeService {
  final OrgStructureService structures;

  const UserScopeService({this.structures = const OrgStructureService()});

  /// Administrador y Academia ven todo. `area` ve las áreas que lidera y
  /// `lider` los equipos que lidera. Cualquier otro rol, nada.
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

  /// Si ve a un empleado con ese Sector y ese Equipo de la nómina.
  bool includes(UserScope scope, String sector, String team) {
    if (scope.isTotal) return true;
    final area = normalizeLoose(sector);
    return scope.areaKeys.contains(area) ||
        scope.teamKeys.contains((area, normalizeLoose(team)));
  }

  bool includesEmployee(UserScope scope, Employee employee) =>
      includes(scope, employee.area, employee.team);

  /// Filtro de empleados para el cálculo por período: `null` si ve todo.
  bool Function(Employee employee)? employeeFilter(UserScope scope) =>
      scope.isTotal ? null : (employee) => includesEmployee(scope, employee);
}
