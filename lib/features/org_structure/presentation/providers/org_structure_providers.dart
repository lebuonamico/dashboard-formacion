import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/auth/domain/user_role_parser.dart';

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

class OrgStructureState {
  final OrgStructure structure;
  final bool isSaving;

  const OrgStructureState({required this.structure, this.isSaving = false});

  OrgStructureState copyWith({OrgStructure? structure, bool? isSaving}) =>
      OrgStructureState(
        structure: structure ?? this.structure,
        isSaving: isSaving ?? this.isSaving,
      );
}

final orgStructureStateProvider =
    AsyncNotifierProvider<OrgStructureNotifier, OrgStructureState>(
      OrgStructureNotifier.new,
    );

/// Áreas, equipos y líderes, y la asignación de líderes. Una asignación a la
/// vez; si falla, se relanza el error y la estructura queda como estaba.
class OrgStructureNotifier extends AsyncNotifier<OrgStructureState> {
  @override
  Future<OrgStructureState> build() async {
    // Con RLS cada usuario recibe filas distintas: otra sesión vuelve a leer.
    ref.watch(sessionDataProvider);
    return OrgStructureState(
      structure: await ref.watch(orgStructureRepositoryProvider).getStructure(),
    );
  }

  Future<void> assignAreaLeaders(String areaId, Set<String> emails) =>
      _run((repository) => repository.assignLeadersArea(areaId, emails));

  Future<void> assignTeamLeaders(String teamId, Set<String> emails) =>
      _run((repository) => repository.assignTeamLeaders(teamId, emails));

  Future<void> _run(
    Future<void> Function(OrgStructureRepository repository) write,
  ) async {
    final current = state.value;
    if (current == null || current.isSaving) return;
    final repository = ref.read(orgStructureRepositoryProvider);
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await write(repository);
      final structure = await repository.getStructure();
      if (!ref.mounted) return;
      state = AsyncData(state.requireValue.copyWith(structure: structure));
    } finally {
      if (ref.mounted) {
        state = AsyncData(state.requireValue.copyWith(isSaving: false));
      }
    }
  }
}

/// La estructura sin el estado de la asignación en curso.
final orgStructureProvider = FutureProvider<OrgStructure>(
  (ref) => ref.watch(
    orgStructureStateProvider.selectAsync((state) => state.structure),
  ),
);

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
  final role = const UserRoleParser().tryParse(session.role);
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

/// Nombre de la nómina por email normalizado, para mostrar a los líderes.
final employeeNamesByEmailProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final employees = await ref.watch(employeesProvider.future);
  return {
    for (final employee in employees)
      if (employee.email.trim().isNotEmpty)
        normalizeLoose(employee.email): employee.fullName,
  };
});

final leaderLabelsProvider = FutureProvider<LeaderLabels>((ref) async {
  final service = ref.watch(orgStructureServiceProvider);
  final structure = await ref.watch(orgStructureProvider.future);
  final names = await ref.watch(employeeNamesByEmailProvider.future);
  return LeaderLabels(structure, service, names);
});

final structureHeadcountProvider = FutureProvider<PayrollHeadcount>((
  ref,
) async {
  final employees = await ref.watch(employeesProvider.future);
  return ref.watch(orgStructureServiceProvider).activeHeadcount(employees);
});
