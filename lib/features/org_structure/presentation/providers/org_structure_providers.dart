import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/core/clock/clock_provider.dart';
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

/// Session identity that decides which data is read.
///
/// Data providers watch it to read again when another user signs in on the same
/// tab: with RLS, each user gets different rows. It watches only these three
/// fields, so it does not recompute on every session change (for example,
/// while validating).
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

final orgStructureNotifierProvider =
    AsyncNotifierProvider<OrgStructureNotifier, OrgStructureState>(
      OrgStructureNotifier.new,
    );

/// Areas, teams and leaders, and the leader assignment. One assignment at a
/// time; if it fails, the error is rethrown and the structure stays as it was.
class OrgStructureNotifier extends AsyncNotifier<OrgStructureState> {
  @override
  Future<OrgStructureState> build() async {
    // With RLS each user gets different rows: another session reads again.
    ref.watch(sessionDataProvider);
    return OrgStructureState(
      structure: await ref.watch(orgStructureRepositoryProvider).getStructure(),
    );
  }

  Future<void> assignAreaLeaders(String areaId, Set<String> emails) => _run(
    (repository) => repository.assignAreaLeaders(areaId, emails, now: _now()),
  );

  Future<void> assignTeamLeaders(String teamId, Set<String> emails) => _run(
    (repository) => repository.assignTeamLeaders(teamId, emails, now: _now()),
  );

  DateTime _now() => ref.read(clockProvider)().toUtc();

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

/// The structure without the pending assignment state.
final orgStructureProvider = FutureProvider<OrgStructure>(
  (ref) => ref.watch(
    orgStructureNotifierProvider.selectAsync((state) => state.structure),
  ),
);

final orgStructureServiceProvider = Provider<OrgStructureService>(
  (ref) => const OrgStructureService(),
);

final userScopeServiceProvider = Provider<UserScopeService>(
  (ref) => UserScopeService(structures: ref.watch(orgStructureServiceProvider)),
);

/// Which employees the session user sees. Local mode has no roles and sees
/// everything.
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

/// Payroll row of the session user, looked up by email: the area and team
/// they belong to. Uses the unfiltered payroll, not [employeesProvider],
/// because a leader may not be in what they lead (RLS lets them read their own
/// row). `null` in local mode or if they are not in it.
final sessionEmployeeProvider = FutureProvider<Employee?>((ref) async {
  final session = ref.watch(sessionDataProvider);
  if (!session.enabled || session.email == null) return null;
  final employees = await ref.watch(payrollProvider.future);
  return const EmployeeLookupService().findByEmail(employees, session.email);
});

/// Leader labels for the team and area cards.
class LeaderLabels {
  final OrgStructure _structure;
  final OrgStructureService _service;
  final Map<String, String> _nameByEmail;

  LeaderLabels(this._structure, this._service, this._nameByEmail);

  /// `null` if the team has no assigned leaders.
  String? forTeam(String area, String team) =>
      _label(_service.teamLeaders(_structure, area, team));

  String? forArea(String area) =>
      _label(_service.areaLeaders(_structure, area));

  String? _label(Set<String> emails) => emails.isEmpty
      ? null
      : OrgStructureLabels.leadersLabel(emails, _nameByEmail);
}

/// Payroll name by normalized email, to show the leaders.
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
