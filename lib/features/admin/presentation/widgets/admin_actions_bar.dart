import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';

class AdminActionsBar extends StatelessWidget {
  final AuthorizedUser? selected;
  final bool outsideFilter;
  final String? actionInProgress;
  final String? ownEmail;
  final VoidCallback onCreate;
  final VoidCallback onRoleChange;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  const AdminActionsBar({
    super.key,
    required this.selected,
    required this.outsideFilter,
    required this.actionInProgress,
    required this.ownEmail,
    required this.onCreate,
    required this.onRoleChange,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final user = selected;
    final hasAction = actionInProgress != null;
    final isOwn = user?.isSameUser(ownEmail) ?? false;
    final enabled = user != null && !isOwn && !hasAction;
    final deleted = user?.status == UserStatus.deleted;
    final blocked = user?.status == UserStatus.blocked;
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, user, isOwn),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _button(
                context,
                key: 'admin_crear',
                label: 'Nuevo usuario',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: hasAction ? null : onCreate,
                highlighted: true,
              ),
              _button(
                context,
                key: 'admin_cambiar_rol',
                label: 'Cambiar rol',
                icon: Icons.badge_outlined,
                onPressed: enabled ? onRoleChange : null,
                tooltip: _disabledReason(user, isOwn),
              ),
              if (blocked)
                _button(
                  context,
                  key: 'admin_desbloquear',
                  label: 'Desbloquear',
                  icon: Icons.lock_open_outlined,
                  onPressed: enabled ? onUnblock : null,
                  tooltip: _disabledReason(user, isOwn),
                )
              else
                _button(
                  context,
                  key: 'admin_bloquear',
                  label: 'Bloquear',
                  icon: Icons.block_outlined,
                  onPressed: enabled && !deleted ? onBlock : null,
                  tooltip: deleted
                      ? 'El usuario está eliminado: restauralo antes de bloquearlo.'
                      : _disabledReason(user, isOwn),
                  color: colors.warning.text,
                ),
              if (deleted)
                _button(
                  context,
                  key: 'admin_restaurar',
                  label: 'Restaurar',
                  icon: Icons.restore_outlined,
                  onPressed: enabled ? onRestore : null,
                  tooltip: _disabledReason(user, isOwn),
                )
              else
                _button(
                  context,
                  key: 'admin_eliminar',
                  label: 'Eliminar',
                  icon: Icons.person_remove_outlined,
                  onPressed: enabled ? onDelete : null,
                  tooltip: _disabledReason(user, isOwn),
                  color: context.colorScheme.error,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AuthorizedUser? user, bool isOwn) {
    final cs = context.colorScheme;
    if (user == null) {
      return Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seleccioná un usuario de la lista para habilitar las acciones.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.person_outline, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Seleccionado: ${user.email}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (outsideFilter)
                Text(
                  '(no aparece con los filtros actuales)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.warning.text,
                  ),
                ),
              if (isOwn)
                Text(
                  'Es tu propio usuario: no podés modificarlo desde acá.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _disabledReason(AuthorizedUser? user, bool isOwn) {
    if (user == null) return 'Seleccioná un usuario de la lista.';
    if (isOwn) {
      return 'No podés modificar tu propio usuario: perderías el acceso al panel.';
    }
    return null;
  }

  Widget _button(
    BuildContext context, {
    required String key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    bool highlighted = false,
  }) {
    final cs = context.colorScheme;
    final inProgress = actionInProgress == key;
    final button = OutlinedButton.icon(
      key: Key(key),
      onPressed: inProgress ? null : onPressed,
      icon: inProgress
          ? SizedBox.square(
              key: Key('loading_$key'),
              dimension: 18,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      // Forma y borde vienen del outlinedButtonTheme.
      style:
          OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor: highlighted ? cs.primary : null,
            disabledForegroundColor: cs.onSurfaceVariant.withValues(
              alpha: 0.45,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ).copyWith(
            foregroundColor: highlighted
                ? WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? cs.onPrimary.withValues(alpha: 0.6)
                        : cs.onPrimary,
                  )
                : null,
          ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
