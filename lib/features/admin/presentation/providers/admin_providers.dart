import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/admin/presentation/providers/authorized_users_repository_provider.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';
import 'package:app_finnegans/features/admin/presentation/user_status_labels.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';

enum AccessAdmin { allowed, denied }

/// Without a session (local mode) everything is visible, as in the drawer.
final accessAdminProvider = Provider<AccessAdmin>((ref) {
  final auth = ref.watch(authProvider);
  return !auth.enabled || auth.canManage
      ? AccessAdmin.allowed
      : AccessAdmin.denied;
});

final authorizedUserServiceProvider = Provider<AuthorizedUserService>(
  (ref) => const AuthorizedUserService(),
);

enum AdminUserAction { create, changeRole, block, unblock, delete, restore }

const _keep = Object();

class AdminUsersState {
  final List<AuthorizedUser> users;
  final AdminUserAction? pendingAction;

  const AdminUsersState({required this.users, this.pendingAction});

  AdminUsersState copyWith({
    List<AuthorizedUser>? users,
    Object? pendingAction = _keep,
  }) => AdminUsersState(
    users: users ?? this.users,
    pendingAction: identical(pendingAction, _keep)
        ? this.pendingAction
        : pendingAction as AdminUserAction?,
  );
}

final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

/// The allowlist and its changes. One action at a time: while one is pending
/// the others are ignored. A failed action rethrows and keeps the list.
class AdminUsersNotifier extends AsyncNotifier<AdminUsersState> {
  AuthorizedUsersRepository get _repository =>
      ref.read(authorizedUsersRepositoryProvider);

  AuthorizedUserService get _users => ref.read(authorizedUserServiceProvider);

  DateTime _now() => ref.read(clockProvider)().toUtc();

  @override
  Future<AdminUsersState> build() async => AdminUsersState(
    users: await ref.watch(authorizedUsersRepositoryProvider).getUsers(),
  );

  Future<void> create({required String email, required UserRole role}) {
    final user = _users.create(email: email, role: role, now: _now());
    return _run(AdminUserAction.create, user, () => _repository.create(user));
  }

  Future<void> changeRole(AuthorizedUser user, UserRole role) =>
      _save(AdminUserAction.changeRole, _users.withRole(user, role));

  Future<void> block(AuthorizedUser user) =>
      _save(AdminUserAction.block, _users.block(user, _now()));

  Future<void> unblock(AuthorizedUser user) =>
      _save(AdminUserAction.unblock, _users.unblock(user));

  Future<void> delete(AuthorizedUser user) =>
      _save(AdminUserAction.delete, _users.delete(user, _now()));

  Future<void> restore(AuthorizedUser user) =>
      _save(AdminUserAction.restore, _users.restore(user));

  Future<void> _save(AdminUserAction action, AuthorizedUser user) =>
      _run(action, user, () => _repository.save(user));

  Future<void> _run(
    AdminUserAction action,
    AuthorizedUser user,
    Future<void> Function() write,
  ) async {
    final current = state.value;
    if (current == null || current.pendingAction != null) return;
    state = AsyncData(current.copyWith(pendingAction: action));
    try {
      await write();
      final users = await _repository.getUsers();
      if (!ref.mounted) return;
      state = AsyncData(state.requireValue.copyWith(users: users));
      // Changing a role deletes the leader assignments that stop applying.
      ref.invalidate(orgStructureProvider);
      if (_users.isSameUser(user, ref.read(authProvider).email)) {
        await ref.read(authProvider.notifier).validateAuthorization();
      }
    } finally {
      if (ref.mounted) {
        state = AsyncData(state.requireValue.copyWith(pendingAction: null));
      }
    }
  }
}

final authorizedUsersProvider =
    FutureProvider.autoDispose<List<AuthorizedUser>>(
      (ref) =>
          ref.watch(adminUsersProvider.selectAsync((state) => state.users)),
    );

final selectedAdminEmailProvider =
    NotifierProvider.autoDispose<SelectedAdminEmailNotifier, String?>(
      SelectedAdminEmailNotifier.new,
    );

class SelectedAdminEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String email) => state = email;

  void clear() => state = null;
}

FilterRow adminUserFilterRow(
  AuthorizedUser user, [
  AuthorizedUserService users = const AuthorizedUserService(),
]) => FilterRow({
  'Email': user.email,
  'Rol': users.knownRole(user)?.label ?? user.role,
  'Estado': users.status(user).label,
});

final adminUserFilterRowsProvider = FutureProvider.autoDispose<List<FilterRow>>(
  (ref) async {
    if (ref.watch(accessAdminProvider) != AccessAdmin.allowed) return const [];
    final users = await ref.watch(authorizedUsersProvider.future);
    return users.map(adminUserFilterRow).toList();
  },
);

final activeAdminFiltersProvider = Provider.autoDispose<bool>(
  (ref) => ref
      .watch(dataFilterSelectionProvider(DataFilterScope.adminUsers))
      .values
      .isNotEmpty,
);

final filteredAdminUsersProvider =
    FutureProvider.autoDispose<List<AuthorizedUser>>((ref) async {
      final selection = ref
          .watch(dataFilterSelectionProvider(DataFilterScope.adminUsers))
          .values;
      final filters = ref.watch(dataFilterServiceProvider);
      final users = await ref.watch(authorizedUsersProvider.future);
      return users
          .where((user) => filters.matches(selection, adminUserFilterRow(user)))
          .toList();
    });

final selectedAdminUserProvider = Provider.autoDispose<AuthorizedUser?>((ref) {
  final email = ref.watch(selectedAdminEmailProvider);
  if (email == null) return null;
  return ref
      .watch(authorizedUsersProvider)
      .value
      ?.firstWhereOrNull((user) => user.email == email);
});

/// Búsqueda de la pestaña "Áreas y equipos". Se descarta al salir del panel.
final adminStructureSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final adminSelectionOutsideFilterProvider = Provider.autoDispose<bool>((ref) {
  final selected = ref.watch(selectedAdminUserProvider);
  if (selected == null) return false;
  final filtered = ref.watch(filteredAdminUsersProvider).value;
  if (filtered == null) return false;
  return !filtered.any((user) => user.email == selected.email);
});
