import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/features/admin/presentation/user_status_labels.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_styles.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_users_table.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:flutter/material.dart';

const _users = AuthorizedUserService();

/// A row of the users table as a card, below 840 px. Without rows to select,
/// each card has its own menu with the actions of the desktop bar and the
/// same rules: your own user cannot be changed, and a deleted user must be
/// restored before blocking it.
class AdminUserCard extends StatelessWidget {
  final AuthorizedUser user;
  final OrgStructure? structure;
  final List<Employee>? payroll;
  final String? ownEmail;
  final AdminUserAction? pendingAction;

  /// The user of [pendingAction], to show its progress on this card.
  final String? selectedEmail;
  final ValueChanged<AdminUserAction> onAction;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.structure,
    required this.payroll,
    required this.ownEmail,
    required this.pendingAction,
    required this.selectedEmail,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = _users.status(user);
    final isOwn = _users.isSameUser(user, ownEmail);
    final role = _users.knownRole(user);
    final scope = userScope(user, structure);
    final membership = userMembership(user, payroll);
    final pending = pendingAction;
    final inProgress =
        pending != null &&
        pending != AdminUserAction.create &&
        selectedEmail == user.email;

    return RecordCard(
      key: Key('admin_usuario_${user.email}'),
      title: user.email,
      subtitle: isOwn
          ? 'Es tu usuario: no podés modificarlo desde acá, perderías el '
                'acceso al panel.'
          : null,
      subtitleMaxLines: 2,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorLabel(
            text: status.label,
            colors: userStatusColors(colors, status),
          ),
          if (inProgress)
            const SizedBox.square(
              key: Key('loading_admin_menu'),
              dimension: 48,
              child: Padding(
                padding: EdgeInsets.all(15),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!isOwn)
            _ActionsMenu(
              user: user,
              status: status,
              enabled: pending == null,
              onSelected: onAction,
            ),
        ],
      ),
      metrics: [
        RecordMetric(
          'Rol',
          role?.label ?? (user.role.isEmpty ? 'Sin rol' : user.role),
          warning: role == null,
        ),
        RecordMetric(
          'Lidera',
          scope.text,
          muted: scope.text == '—',
          warning: scope.warning,
        ),
        RecordMetric(
          'Pertenece a',
          membership.text,
          muted: membership.text == '—',
          warning: membership.warning,
        ),
        RecordMetric('Alta', formatStamp(user.createdAt)),
        if (user.blockedAt != null)
          RecordMetric('Bloqueo', formatStamp(user.blockedAt)),
        if (user.deletedAt != null)
          RecordMetric('Eliminación', formatStamp(user.deletedAt)),
      ],
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final AuthorizedUser user;
  final UserStatus status;
  final bool enabled;
  final ValueChanged<AdminUserAction> onSelected;

  const _ActionsMenu({
    required this.user,
    required this.status,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final deleted = status == UserStatus.deleted;
    return PopupMenuButton<AdminUserAction>(
      key: Key('admin_menu_${user.email}'),
      tooltip: 'Acciones de ${user.email}',
      enabled: enabled,
      // Above the assistant's button, like the filter sheets.
      useRootNavigator: true,
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          key: Key('admin_menu_cambiar_rol'),
          value: AdminUserAction.changeRole,
          child: _MenuEntry(icon: Icons.badge_outlined, label: 'Cambiar rol'),
        ),
        if (status == UserStatus.blocked)
          const PopupMenuItem(
            key: Key('admin_menu_desbloquear'),
            value: AdminUserAction.unblock,
            child: _MenuEntry(
              icon: Icons.lock_open_outlined,
              label: 'Desbloquear',
            ),
          )
        else
          PopupMenuItem(
            key: const Key('admin_menu_bloquear'),
            value: AdminUserAction.block,
            enabled: !deleted,
            child: _MenuEntry(
              icon: Icons.block_outlined,
              label: 'Bloquear',
              color: context.colors.warning.text,
              // A disabled action says why, in text: no hover on a phone.
              reason: deleted
                  ? 'Está eliminado: restauralo antes de bloquearlo.'
                  : null,
            ),
          ),
        if (deleted)
          const PopupMenuItem(
            key: Key('admin_menu_restaurar'),
            value: AdminUserAction.restore,
            child: _MenuEntry(icon: Icons.restore_outlined, label: 'Restaurar'),
          )
        else
          PopupMenuItem(
            key: const Key('admin_menu_eliminar'),
            value: AdminUserAction.delete,
            child: _MenuEntry(
              icon: Icons.person_remove_outlined,
              label: 'Eliminar',
              color: cs.error,
            ),
          ),
      ],
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final String? reason;

  const _MenuEntry({
    required this.icon,
    required this.label,
    this.color,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final reason = this.reason;
    // Disabled entries keep the menu's grey.
    final color = reason == null ? this.color : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: color)),
              if (reason != null)
                Text(
                  reason,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
