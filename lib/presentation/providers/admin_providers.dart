import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';

enum AccessAdmin { allowed, denied, noSupabase }

final accessAdminProvider = Provider<AccessAdmin>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (ref.watch(authorizedUsersRepositoryProvider) == null) {
    return AccessAdmin.noSupabase;
  }
  return auth.canManage ? AccessAdmin.allowed : AccessAdmin.denied;
});

final authorizedUsersProvider =
    FutureProvider.autoDispose<List<AuthorizedUser>>((ref) async {
      final repository = ref.watch(authorizedUsersRepositoryProvider);
      if (repository == null) {
        throw const FormatException(
          'El panel de administración no está disponible en esta versión.',
        );
      }
      return repository.getUsers();
    });

final searchUserAdminProvider = StateProvider.autoDispose<String>((ref) => '');
final adminRoleFilterProvider = StateProvider.autoDispose<UserRole?>(
  (ref) => null,
);

final adminStatusFilterProvider = StateProvider.autoDispose<UserStatus?>(
  (ref) => null,
);
final selectedAdminEmailProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final activeAdminFiltersProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(searchUserAdminProvider).trim().isNotEmpty ||
      ref.watch(adminRoleFilterProvider) != null ||
      ref.watch(adminStatusFilterProvider) != null ||
      ref.watch(dataFilterSelectionProvider('admin')).isNotEmpty,
);

final filteredAdminUsersProvider =
    Provider.autoDispose<AsyncValue<List<AuthorizedUser>>>((ref) {
      final users = ref.watch(authorizedUsersProvider);
      final search = ref.watch(searchUserAdminProvider).trim();
      final role = ref.watch(adminRoleFilterProvider);
      final status = ref.watch(adminStatusFilterProvider);
      final selection = ref.watch(dataFilterSelectionProvider('admin'));

      return users.whenData((items) {
        final query = search.toLowerCase();
        return items.where((user) {
          final matchesText =
              query.isEmpty || user.email.toLowerCase() == query;
          final matchesRole = role == null || user.knownRole == role;
          final matchesStatus = status == null || user.status == status;
          return matchesText &&
              matchesRole &&
              matchesStatus &&
              matchesDataFilters(selection, adminFilterRow(user));
        }).toList();
      });
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
