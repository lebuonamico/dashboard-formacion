import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/admin/presentation/providers/authorized_users_repository_provider.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';
import 'package:app_finnegans/features/admin/presentation/user_status_labels.dart';

enum AccessAdmin { allowed, denied }

/// Without a session (local mode) everything is visible, as in the drawer.
final accessAdminProvider = Provider<AccessAdmin>((ref) {
  final auth = ref.watch(authProvider);
  return !auth.enabled || auth.canManage
      ? AccessAdmin.allowed
      : AccessAdmin.denied;
});

final authorizedUsersProvider =
    FutureProvider.autoDispose<List<AuthorizedUser>>(
      (ref) => ref.watch(authorizedUsersRepositoryProvider).getUsers(),
    );

final selectedAdminEmailProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final authorizedUserServiceProvider = Provider<AuthorizedUserService>(
  (ref) => const AuthorizedUserService(),
);

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
  final items = ref.watch(authorizedUsersProvider).value;
  if (items == null) return null;
  for (final user in items) {
    if (user.email == email) return user;
  }
  return null;
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
