import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';

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

/// Áreas, equipos y líderes.
final orgStructureProvider = FutureProvider<OrgStructure>((ref) {
  // Con RLS cada usuario recibe filas distintas: otra sesión vuelve a leer.
  ref.watch(sessionDataProvider);
  return ref.watch(orgStructureRepositoryProvider).getStructure();
});

final orgStructureServiceProvider = Provider<OrgStructureService>(
  (ref) => const OrgStructureService(),
);

final userScopeServiceProvider = Provider<UserScopeService>(
  (ref) => UserScopeService(structures: ref.watch(orgStructureServiceProvider)),
);

/// Qué colaboradores ve el usuario de la sesión. En modo local no hay roles
/// y se ve todo.
final userScopeProvider = FutureProvider<UserScope>((ref) async {
  final session = ref.watch(sessionDataProvider);
  if (!session.enabled) return const UserScope.total();
  final role = UserRole.fromString(session.role);
  if (role != null && role.canManage) return const UserScope.total();
  final scopes = ref.watch(userScopeServiceProvider);
  final structure = await ref.watch(orgStructureProvider.future);
  return scopes.scopeFor(
    role: role,
    email: session.email,
    structure: structure,
  );
});

/// Fila de la nómina del usuario de la sesión, buscada por su email: el área
/// y el equipo a los que pertenece. Usa la nómina sin filtrar y no
/// [employeesProvider], porque un líder puede no estar en lo que lidera (el
/// RLS le deja leer su propia fila). `null` en modo local o si no figura.
final sessionEmployeeProvider = FutureProvider<Employee?>((ref) async {
  final session = ref.watch(sessionDataProvider);
  if (!session.enabled || session.email == null) return null;
  final employees = await ref.watch(payrollProvider.future);
  return const EmployeeLookupService().findByEmail(employees, session.email);
});

/// Etiquetas de líderes para las tarjetas de equipos y áreas.
class LeaderLabels {
  final OrgStructure _structure;
  final OrgStructureService _service;
  final Map<String, String> _nameByEmail;

  LeaderLabels(this._structure, this._service, this._nameByEmail);

  /// `null` si el equipo no tiene líderes asignados.
  String? forTeam(String area, String team) =>
      _label(_service.teamLeaders(_structure, area, team));

  String? forArea(String area) =>
      _label(_service.areaLeaders(_structure, area));

  String? _label(Set<String> emails) => emails.isEmpty
      ? null
      : OrgStructureLabels.leadersLabel(emails, _nameByEmail);
}

final leaderLabelsProvider = FutureProvider<LeaderLabels>((ref) async {
  final service = ref.watch(orgStructureServiceProvider);
  final structure = await ref.watch(orgStructureProvider.future);
  final employees = await ref.watch(employeesProvider.future);
  return LeaderLabels(structure, service, {
    for (final employee in employees)
      if (employee.email.trim().isNotEmpty)
        normalizeLoose(employee.email): employee.fullName,
  });
});
