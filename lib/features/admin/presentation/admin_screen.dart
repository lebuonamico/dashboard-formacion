import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/adaptive_record_list.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_actions_bar.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_structure_tab.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_users_table.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_filters.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessAdminProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Panel de administrador'),
          Expanded(
            child: switch (access) {
              AccessAdmin.allowed => const _Tabs(),
              AccessAdmin.denied => const _CenteredState(
                icon: Icons.lock_outline,
                title: 'No tenés permiso para ver esta sección',
                message:
                    'El panel de administración está reservado para los '
                    'usuarios con rol Administrador o Academia.',
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: screenPaddingOf(context).left,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: const TabBar(
              key: Key('admin_pestanas'),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Usuarios'),
                Tab(text: 'Áreas y equipos'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_UsersTab(), AdminStructure()]),
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredUsers = ref.watch(filteredAdminUsersProvider);
    final selected = ref.watch(selectedAdminUserProvider);
    final selectedEmail = ref.watch(selectedAdminEmailProvider);
    final pendingAction = ref.watch(
      adminUsersProvider.select((users) => users.value?.pendingAction),
    );
    final auth = ref.watch(authProvider);
    final structure = ref.watch(orgStructureProvider).value;
    final payroll = ref.watch(employeesProvider).value;
    final cs = context.colorScheme;
    // Below 840 px each card has its own menu instead of the selection bar.
    final cards = context.windowSize != WindowSize.expanded;

    return ListView(
      padding: screenPaddingOf(context),
      children: [
        Text(
          'Usuarios del sistema',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quién puede iniciar sesión en la aplicación y con qué rol. '
          'Bloquear y eliminar se pueden deshacer más adelante.',
          style: context.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        const AdminFilters(),
        const SizedBox(height: 16),
        if (cards)
          _CreateUserButton(
            pendingAction: pendingAction,
            onCreate: () => _create(context, ref),
          )
        else
          AdminActionsBar(
            selected: selected,
            outsideFilter: ref.watch(adminSelectionOutsideFilterProvider),
            pendingAction: pendingAction,
            ownEmail: auth.email,
            onCreate: () => _create(context, ref),
            onRoleChange: () => _changeRole(context, ref, selected),
            onBlock: () => _block(context, ref, selected),
            onUnblock: () => _unblock(context, ref, selected),
            onDelete: () => _delete(context, ref, selected),
            onRestore: () => _restore(context, ref, selected),
          ),
        const SizedBox(height: 20),
        filteredUsers.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar los usuarios',
            error: error,
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
          data: (users) => FadeIn(
            child: users.isEmpty
                ? const _CenteredState(
                    icon: Icons.manage_accounts_outlined,
                    title: 'No hay usuarios para mostrar.',
                    message:
                        'Probá limpiar los filtros o dar de alta un usuario nuevo.',
                  )
                : AdaptiveRecordList<AuthorizedUser>(
                    items: users,
                    // Every action reads the users again as new objects.
                    itemId: (user) => user.email,
                    pageSize: AdminUsersTable.usersPerPage,
                    resultsLabel: 'usuarios',
                    icon: Icons.manage_accounts_outlined,
                    table: (users) => AdminUsersTable(
                      users: users,
                      structure: structure,
                      payroll: payroll,
                      selectedEmail: selectedEmail,
                      ownEmail: auth.email,
                      onSelect: (email) {
                        final selection = ref.read(
                          selectedAdminEmailProvider.notifier,
                        );
                        email == null
                            ? selection.clear()
                            : selection.select(email);
                      },
                    ),
                    card: (user) => AdminUserCard(
                      user: user,
                      structure: structure,
                      payroll: payroll,
                      ownEmail: auth.email,
                      pendingAction: pendingAction,
                      selectedEmail: selectedEmail,
                      onAction: (action) =>
                          _runFromMenu(context, ref, user, action),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// The card's menu selects the user first, as a click on its row does, so
  /// the progress and the desktop bar agree if the window grows.
  Future<void> _runFromMenu(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser user,
    AdminUserAction action,
  ) {
    ref.read(selectedAdminEmailProvider.notifier).select(user.email);
    return switch (action) {
      AdminUserAction.create => _create(context, ref),
      AdminUserAction.changeRole => _changeRole(context, ref, user),
      AdminUserAction.block => _block(context, ref, user),
      AdminUserAction.unblock => _unblock(context, ref, user),
      AdminUserAction.delete => _delete(context, ref, user),
      AdminUserAction.restore => _restore(context, ref, user),
    };
  }

  AdminUsersNotifier _users(WidgetRef ref) =>
      ref.read(adminUsersProvider.notifier);

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final data = await showUserCreationDialog(context);
    if (data == null || !context.mounted) return;
    final created = await runWithFeedback(
      context,
      action: () => _users(ref).create(email: data.email, role: data.role),
      success: 'Se dio de alta a ${data.email}.',
    );
    if (!created || !context.mounted) return;
    ref
        .read(dataFilterSelectionProvider(DataFilterScope.adminUsers).notifier)
        .clear();
    ref.read(selectedAdminEmailProvider.notifier).select(data.email);
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser? user,
  ) async {
    if (user == null) return;
    final role = await showRoleChangeDialog(
      context,
      email: user.email,
      currentRole: ref.read(authorizedUserServiceProvider).knownRole(user),
    );
    if (role == null || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _users(ref).changeRole(user, role),
      success: '${user.email} ahora tiene el rol ${role.label}.',
    );
  }

  Future<void> _block(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser? user,
  ) async {
    if (user == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Bloquear usuario',
      message:
          '${user.email} no va a poder entrar a la aplicación hasta que lo '
          'desbloquees.',
      confirmLabel: 'Bloquear',
      confirmColor: context.colors.warning.text,
      confirmKey: const Key('admin_confirmar'),
    );
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _users(ref).block(user),
      success: 'Se bloqueó a ${user.email}.',
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser? user,
  ) async {
    if (user == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Desbloquear usuario',
      message: '${user.email} va a poder volver a entrar a la aplicación.',
      confirmLabel: 'Desbloquear',
      confirmKey: const Key('admin_confirmar'),
    );
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _users(ref).unblock(user),
      success: 'Se desbloqueó a ${user.email}.',
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser? user,
  ) async {
    if (user == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Eliminar usuario',
      message:
          '${user.email} ya no va a poder entrar a la aplicación. Si más '
          'adelante lo necesitás, lo podés restaurar desde la lista.',
      confirmLabel: 'Eliminar',
      confirmColor: context.colorScheme.error,
      confirmKey: const Key('admin_confirmar'),
    );
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _users(ref).delete(user),
      success: 'Se eliminó a ${user.email}.',
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    AuthorizedUser? user,
  ) async {
    if (user == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Restaurar usuario',
      message:
          '${user.email} vuelve a la lista y, si no está bloqueado, puede entrar a la aplicación.',
      confirmLabel: 'Restaurar',
      confirmKey: const Key('admin_confirmar'),
    );
    if (!confirmed || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _users(ref).restore(user),
      success: 'Se restauró a ${user.email}.',
    );
  }
}

/// "Nuevo usuario" across the width, for the cards layout.
class _CreateUserButton extends StatelessWidget {
  final AdminUserAction? pendingAction;
  final VoidCallback onCreate;

  const _CreateUserButton({
    required this.pendingAction,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final pending = pendingAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('admin_crear'),
          onPressed: pending == null ? onCreate : null,
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          icon: pending == AdminUserAction.create
              ? const SizedBox.square(
                  key: Key('loading_admin_crear'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('Nuevo usuario'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tocá el menú de un usuario para cambiar su rol, '
                'bloquearlo o eliminarlo.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: context.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
