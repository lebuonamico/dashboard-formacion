import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';

/// Identidad de la sesión que define qué datos se leen.
///
/// Los providers de datos la miran para volver a consultar cuando entra otro
/// usuario en la misma pestaña: con RLS, cada usuario recibe filas distintas.
/// Mira solo estos tres campos, así no se recalcula en cada cambio de la
/// sesión (por ejemplo, mientras se valida).
final sessionDataProvider =
    Provider<({bool enabled, String? email, String? role})>(
      (ref) => ref.watch(
        authProvider.select(
          (auth) => (enabled: auth.enabled, email: auth.email, role: auth.role),
        ),
      ),
    );

/// Áreas, equipos y líderes. `null` en modo local, donde no hay sesión.
final orgStructureProvider = FutureProvider<OrgStructure?>((ref) async {
  if (!ref.watch(sessionDataProvider).enabled) return null;
  final repository = ref.watch(orgStructureRepositoryProvider);
  if (repository == null) return null;
  return repository.getStructure();
});

/// Qué colaboradores ve el usuario de la sesión. En modo local no hay roles
/// y se ve todo.
final userScopeProvider = FutureProvider<UserScope>((ref) async {
  final session = ref.watch(sessionDataProvider);
  if (!session.enabled) return const UserScope.total();
  final role = UserRole.fromString(session.role);
  if (role != null && role.canManage) return const UserScope.total();
  final structure = await ref.watch(orgStructureProvider.future);
  return UserScope.of(role: role, email: session.email, structure: structure);
});

/// Fila de la nómina del usuario de la sesión, buscada por su email: el área
/// y el equipo a los que pertenece. Usa la nómina sin filtrar y no
/// [employeesProvider], porque un líder puede no estar en lo que lidera (el
/// RLS le deja leer su propia fila). `null` en modo local o si no figura.
final sessionEmployeeProvider = FutureProvider<Employee?>((ref) async {
  final session = ref.watch(sessionDataProvider);
  if (!session.enabled || session.email == null) return null;
  final employees = await ref.watch(payrollProvider.future);
  return Employee.byEmail(employees, session.email);
});

/// Etiquetas de líderes para las tarjetas de equipos y áreas.
class LeaderLabels {
  final OrgStructure _structure;
  final Map<String, String> _nameByEmail;

  LeaderLabels(this._structure, this._nameByEmail);

  /// `null` si el equipo no tiene líderes asignados.
  String? forTeam(String area, String team) =>
      _label(_structure.teamLeaders(area, team));

  String? forArea(String area) => _label(_structure.areaLeaders(area));

  String? _label(Set<String> emails) =>
      emails.isEmpty ? null : OrgStructure.leadersLabel(emails, _nameByEmail);
}

/// `null` en modo local, donde no hay líderes asignados.
final leaderLabelsProvider = FutureProvider<LeaderLabels?>((ref) async {
  final structure = await ref.watch(orgStructureProvider.future);
  if (structure == null) return null;
  final employees = await ref.watch(employeesProvider.future);
  return LeaderLabels(structure, {
    for (final employee in employees)
      if (employee.email.trim().isNotEmpty)
        OrgStructure.normalizeEmail(employee.email): employee.fullName,
  });
});
