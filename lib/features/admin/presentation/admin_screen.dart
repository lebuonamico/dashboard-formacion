import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_actions_bar.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_structure_tab.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_users_table.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_filters.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String? _actionInProgress;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessAdminProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Panel de administrador'),
          Expanded(
            child: switch (access) {
              AccessAdmin.allowed => _tabs(),
              AccessAdmin.denied => const _CenteredState(
                icon: Icons.lock_outline,
                title: 'No tenés permiso para ver esta sección',
                message:
                    'El panel de administración está reservado para los '
                    'usuarios con rol Administrador o Academia.',
              ),
              AccessAdmin.noSupabase => const _CenteredState(
                icon: Icons.cloud_off_outlined,
                title: 'El panel no está disponible',
                message:
                    'Esta versión de la aplicación no está conectada a '
                    'la lista de usuarios, así que no hay usuarios para '
                    'administrar.',
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    final cs = context.colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
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
          Expanded(
            child: TabBarView(children: [_content(), const AdminStructure()]),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final filteredUsers = ref.watch(filteredAdminUsersProvider);
    final selected = ref.watch(selectedAdminUserProvider);
    final auth = ref.watch(authControllerProvider);
    final cs = context.colorScheme;

    return ListView(
      padding: screenPadding,
      children: [
        Text(
          'Usuarios del sistema',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quién puede iniciar sesión en la aplicación y con qué rol. '
          'Bloquear y eliminar se pueden deshacer más adelante.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        const AdminFilters(),
        const SizedBox(height: 16),
        AdminActionsBar(
          selected: selected,
          outsideFilter: ref.watch(adminSelectionOutsideFilterProvider),
          actionInProgress: _actionInProgress,
          ownEmail: auth.email,
          onCreate: _createUser,
          onRoleChange: _changeRole,
          onBlock: _block,
          onUnblock: _unblock,
          onDelete: _delete,
          onRestore: _restore,
        ),
        const SizedBox(height: 20),
        filteredUsers.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _CenteredState(
            icon: Icons.error_outline,
            title: 'No pudimos cargar los usuarios',
            message: _errorMessage(error),
            color: cs.error,
          ),
          data: (users) => FadeIn(
            child: users.isEmpty
                ? const _CenteredState(
                    icon: Icons.manage_accounts_outlined,
                    title: 'No hay usuarios para mostrar',
                    message:
                        'Probá limpiar los filtros o dar de alta un usuario nuevo.',
                  )
                : AdminUsersTable(
                    users: users,
                    structure: ref.watch(orgStructureProvider).value,
                    payroll: ref.watch(employeesProvider).value,
                    selectedEmail: ref.watch(selectedAdminEmailProvider),
                    ownEmail: auth.email,
                    onSelect: (email) =>
                        ref.read(selectedAdminEmailProvider.notifier).state =
                            email,
                  ),
          ),
        ),
      ],
    );
  }

  AuthorizedUsersRepository _repository() {
    final repository = ref.read(authorizedUsersRepositoryProvider);
    if (repository == null) {
      throw const FormatException(
        'El panel de administración no está disponible en esta versión.',
      );
    }
    return repository;
  }

  Future<void> _createUser() async {
    final data = await showUserCreationDialog(context);
    if (data == null) return;
    await _run(
      key: 'admin_crear',
      affectedEmail: data.email,
      success: 'Se dio de alta a ${data.email}.',
      action: (repository) => repository.create(
        AuthorizedUser.create(
          email: data.email,
          role: data.role,
          now: DateTime.now().toUtc(),
        ),
      ),
      onFinish: () {
        ref
            .read(
              dataFilterSelectionProvider(DataFilterScope.adminUsers).notifier,
            )
            .clear();
        ref.read(selectedAdminEmailProvider.notifier).state = data.email;
      },
    );
  }

  Future<void> _changeRole() async {
    final user = ref.read(selectedAdminUserProvider);
    if (user == null) return;
    final role = await showRoleChangeDialog(
      context,
      email: user.email,
      currentRole: user.knownRole,
    );
    if (role == null) return;
    await _save(
      key: 'admin_cambiar_rol',
      user: user.withRole(role),
      success: '${user.email} ahora tiene el rol ${role.label}.',
    );
  }

  Future<void> _block() async {
    final user = ref.read(selectedAdminUserProvider);
    if (user == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Bloquear usuario',
      message:
          '${user.email} no va a poder entrar a la aplicación hasta que lo '
          'desbloquees.',
      confirmLabel: 'Bloquear',
      color: context.colors.warning.text,
    );
    if (!confirmed) return;
    await _save(
      key: 'admin_bloquear',
      user: user.blocked(DateTime.now().toUtc()),
      success: 'Se bloqueó a ${user.email}.',
    );
  }

  Future<void> _unblock() async {
    final user = ref.read(selectedAdminUserProvider);
    if (user == null) return;
    await _save(
      key: 'admin_desbloquear',
      user: user.unblocked(),
      success: 'Se desbloqueó a ${user.email}.',
    );
  }

  Future<void> _delete() async {
    final user = ref.read(selectedAdminUserProvider);
    if (user == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Eliminar usuario',
      message:
          '${user.email} ya no va a poder entrar a la aplicación. Si más '
          'adelante lo necesitás, lo podés restaurar desde la lista.',
      confirmLabel: 'Eliminar',
      color: context.colorScheme.error,
    );
    if (!confirmed) return;
    await _save(
      key: 'admin_eliminar',
      user: user.deleted(DateTime.now().toUtc()),
      success: 'Se eliminó a ${user.email}.',
    );
  }

  Future<void> _restore() async {
    final user = ref.read(selectedAdminUserProvider);
    if (user == null) return;
    await _save(
      key: 'admin_restaurar',
      user: user.restored(),
      success: 'Se restauró a ${user.email}.',
    );
  }

  Future<void> _save({
    required String key,
    required AuthorizedUser user,
    required String success,
  }) {
    return _run(
      key: key,
      affectedEmail: user.email,
      success: success,
      action: (repository) => repository.save(user),
    );
  }

  Future<void> _run({
    required String key,
    required String affectedEmail,
    required String success,
    required Future<void> Function(AuthorizedUsersRepository) action,
    VoidCallback? onFinish,
  }) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = key);
    try {
      await action(_repository());
      ref.invalidate(authorizedUsersProvider);
      // Cambiar un rol borra en la base las asignaciones que dejan de
      // aplicar: la columna Lidera y los líderes tienen que recargarse.
      ref.invalidate(orgStructureProvider);
      await ref.read(authorizedUsersProvider.future);
      final auth = ref.read(authControllerProvider);
      if (affectedEmail == auth.email) {
        await auth.validateAuthorization();
      }
      onFinish?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      debugPrint('Panel de administración: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar la acción. Intentá nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  static String _errorMessage(Object error) => error is FormatException
      ? error.message
      : 'Revisá tu conexión e intentá nuevamente.';
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
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
            Icon(icon, size: 34, color: color ?? cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color ?? cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
