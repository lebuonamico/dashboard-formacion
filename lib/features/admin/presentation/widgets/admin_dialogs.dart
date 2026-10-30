import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_styles.dart';

Future<({String email, UserRole role})?> showUserCreationDialog(
  BuildContext context,
) {
  return showDialog<({String email, UserRole role})>(
    context: context,
    builder: (_) => const _UserCreationDialog(),
  );
}

Future<UserRole?> showRoleChangeDialog(
  BuildContext context, {
  required String email,
  required UserRole? currentRole,
}) {
  return showDialog<UserRole>(
    context: context,
    builder: (_) => _RoleChangeDialog(email: email, currentRole: currentRole),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color color,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DialogFrame(
      title: title,
      width: 460,
      children: [
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.intermediateText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_confirmar'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Elige los líderes de un área o un equipo entre los usuarios activos con
/// [role]. Devuelve el conjunto completo de emails, o `null` si se cancela.
Future<Set<String>?> showLeadersDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required UserRole role,
  required List<AuthorizedUser> users,
  required Set<String> selected,
  required Map<String, String> nameByEmail,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _LeadersDialog(
      title: title,
      subtitle: subtitle,
      role: role,
      users: users,
      selected: selected,
      nameByEmail: nameByEmail,
    ),
  );
}

class _LeadersDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final UserRole role;
  final List<AuthorizedUser> users;
  final Set<String> selected;
  final Map<String, String> nameByEmail;

  const _LeadersDialog({
    required this.title,
    required this.subtitle,
    required this.role,
    required this.users,
    required this.selected,
    required this.nameByEmail,
  });

  @override
  State<_LeadersDialog> createState() => _LeadersDialogState();
}

class _LeadersDialogState extends State<_LeadersDialog> {
  late final Set<String> _checked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final candidates = {
      for (final user in widget.users)
        if (user.status == UserStatus.active && user.knownRole == widget.role)
          user.email,
    };
    // Los asignados que perdieron el rol o el acceso se listan igual, para
    // poder quitarlos.
    final noAccess = widget.selected.difference(candidates);
    final emails = [...candidates, ...noAccess]..sort();
    final noChanges =
        _checked.length == widget.selected.length &&
        _checked.containsAll(widget.selected);

    return _DialogFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      children: [
        if (emails.isEmpty)
          Text(
            'No hay usuarios activos con el rol ${widget.role.label}. Dalos de '
            'alta o cambiales el rol desde la pestaña Usuarios.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final email in emails)
                    CheckboxListTile(
                      key: Key('admin_lider_$email'),
                      value: _checked.contains(email),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: cs.primary,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _checked.add(email);
                        } else {
                          _checked.remove(email);
                        }
                      }),
                      title: Text(
                        email,
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                      subtitle: _subtitle(email, noAccess.contains(email)),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_lideres_confirmar'),
              onPressed: noChanges
                  ? null
                  : () => Navigator.of(context).pop({..._checked}),
              child: const Text('Guardar líderes'),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _subtitle(String email, bool noAccess) {
    final name = widget.nameByEmail[email];
    final parts = [
      ?name,
      if (noAccess) 'Ya no tiene el rol ${widget.role.label} o está sin acceso',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: 12,
        color: noAccess
            ? context.colors.warning.text
            : context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _UserCreationDialog extends StatefulWidget {
  const _UserCreationDialog();

  @override
  State<_UserCreationDialog> createState() => _UserCreationDialogState();
}

class _UserCreationDialogState extends State<_UserCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllerEmail = TextEditingController();
  UserRole _role = UserRole.teamLead;

  @override
  void dispose() {
    _controllerEmail.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(
      context,
    ).pop((email: _controllerEmail.text.trim().toLowerCase(), role: _role));
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      title: 'Nuevo usuario',
      subtitle:
          'El usuario queda habilitado para iniciar sesión con su cuenta de Google.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('admin_alta_email'),
                controller: _controllerEmail,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: adminInputDecoration(
                  'nombre.apellido@finnegans.com',
                  Icons.alternate_email,
                  label: 'Email corporativo',
                ),
                onFieldSubmitted: (_) => _confirm(),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                key: const Key('admin_alta_rol'),
                initialValue: _role,
                isExpanded: true,
                decoration: adminInputDecoration(
                  'Rol',
                  Icons.badge_outlined,
                  label: 'Rol',
                ),
                items: UserRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(
                          '${role.label} — ${role.description}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _role = value ?? UserRole.teamLead),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_alta_confirmar'),
              onPressed: _confirm,
              child: const Text('Crear usuario'),
            ),
          ],
        ),
      ],
    );
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresá un email.';
    if (!RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(email)) {
      return 'El email no tiene un formato válido.';
    }
    return null;
  }
}

class _RoleChangeDialog extends StatefulWidget {
  final String email;
  final UserRole? currentRole;

  const _RoleChangeDialog({required this.email, required this.currentRole});

  @override
  State<_RoleChangeDialog> createState() => _RoleChangeDialogState();
}

class _RoleChangeDialogState extends State<_RoleChangeDialog> {
  late UserRole _role = widget.currentRole ?? UserRole.teamLead;

  @override
  Widget build(BuildContext context) {
    final unchanged = _role == widget.currentRole;
    final cs = context.colorScheme;

    return _DialogFrame(
      title: 'Cambiar rol',
      subtitle: widget.email,
      children: [
        if (widget.currentRole == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Este usuario tiene un rol que ya no se usa. Elegí uno de la '
              'lista para reemplazarlo.',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.warning.text,
              ),
            ),
          ),
        RadioGroup<UserRole>(
          groupValue: _role,
          onChanged: (value) => setState(() => _role = value ?? _role),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: UserRole.values
                .map(
                  (role) => RadioListTile<UserRole>(
                    key: Key('admin_rol_${role.name}'),
                    value: role,
                    contentPadding: EdgeInsets.zero,
                    activeColor: cs.primary,
                    title: Text(
                      role.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      role.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_rol_confirmar'),
              onPressed: unchanged
                  ? null
                  : () => Navigator.of(context).pop(_role),
              child: const Text('Guardar rol'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double width;
  final List<Widget> children;

  const _DialogFrame({
    required this.title,
    required this.children,
    this.subtitle,
    this.width = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
