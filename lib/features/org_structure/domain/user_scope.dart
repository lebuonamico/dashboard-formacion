import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';

/// Qué colaboradores puede ver el usuario de la sesión.
///
/// Es el mismo criterio que `public.empleado_visible()` en la base, que es la
/// que manda: acá sirve para que la app no dependa de que el RLS esté
/// encendido y para poder probarlo sin Supabase. Compara por clave de nómina
/// ([OrgStructure.payrollKey]), igual que la base.
class UserScope {
  final bool isTotal;
  final Set<String> _areas;
  final Set<(String, String)> _teams;

  const UserScope.total()
    : isTotal = true,
      _areas = const {},
      _teams = const {};

  const UserScope.none()
    : isTotal = false,
      _areas = const {},
      _teams = const {};

  const UserScope._(this._areas, this._teams) : isTotal = false;

  /// Administrador y Academia ven todo. `area` ve las áreas que lidera y
  /// `lider` los equipos que lidera. Cualquier otro rol, nada.
  factory UserScope.of({
    required UserRole? role,
    required String? email,
    required OrgStructure? structure,
  }) {
    if (role != null && role.canManage) return const UserScope.total();
    if (email == null || structure == null) {
      return const UserScope.none();
    }
    switch (role) {
      case UserRole.areaLead:
        return UserScope._({
          for (final area in structure.ledAreasBy(email)) area.payrollKey,
        }, const {});
      case UserRole.teamLead:
        return UserScope._(const {}, {
          for (final led in structure.teamsLedBy(email))
            (led.area.payrollKey, led.team.payrollKey),
        });
      default:
        return const UserScope.none();
    }
  }

  /// Si ve a un empleado con ese Sector y ese Equipo de la nómina.
  bool includes(String sector, String team) {
    if (isTotal) return true;
    final area = OrgStructure.payrollKey(sector);
    return _areas.contains(area) ||
        _teams.contains((area, OrgStructure.payrollKey(team)));
  }

  bool includesEmployee(Employee employee) =>
      includes(employee.area, employee.team);
}
