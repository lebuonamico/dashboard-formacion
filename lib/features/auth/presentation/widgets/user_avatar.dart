import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/core/theme/theme_mode_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';
import 'package:app_finnegans/features/auth/domain/user_role_parser.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';

/// Signed-in user in the top bar: photo, name and email. A click opens a
/// card with the account details, the role included, and the dark mode switch.
///
/// Without Supabase (local mode) there is no session, so it falls back to a
/// generic 'U' and "Modo local".
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final cs = context.colorScheme;
    final role = const UserRoleParser().tryParse(auth.role);
    final isLeader = role == UserRole.teamLead || role == UserRole.areaLead;
    final data = _UserData(
      email: auth.email,
      name: auth.name,
      photoUrl: auth.photoUrl,
      role: auth.role,
      localMode: !auth.enabled,
      // What they lead (assigned in the panel) and the team and area they
      // belong to in the payroll: they may differ, so both are shown.
      leads: isLeader
          ? ref
                .watch(orgStructureProvider)
                .whenData(
                  (structure) =>
                      structure.leads(role: role, email: auth.email ?? ''),
                )
          : null,
      belongs: isLeader ? ref.watch(sessionEmployeeProvider) : null,
    );

    return PopupMenuButton<Never>(
      tooltip: 'Mi cuenta',
      offset: const Offset(0, 52),
      itemBuilder: (_) => [
        PopupMenuItem<Never>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _UserCard(data: data),
        ),
        const PopupMenuDivider(),
        const _DarkModeEntry(),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UserPhoto(data: data, radius: 18),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (data.subtitle != null)
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark mode switch of the account menu. Its own entry (not a
/// `PopupMenuItem`) so it has the side menu's feedback: no ripple, with a
/// background that fades between rest, hover and press. Switching the theme
/// does not close the menu, so the result shows at once.
///
/// Until the user chooses, the app follows the operating system and the switch
/// reflects the theme on screen.
class _DarkModeEntry extends PopupMenuEntry<Never> {
  const _DarkModeEntry();

  @override
  double get height => 44;

  @override
  bool represents(Object? value) => false;

  @override
  State<_DarkModeEntry> createState() => _DarkModeEntryState();
}

class _DarkModeEntryState extends State<_DarkModeEntry> {
  /// Same as the color transition of the side menu items.
  static const _duration = Duration(milliseconds: 200);
  static final _radius = BorderRadius.circular(8);

  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = _pressed
        ? cs.primary.withValues(alpha: 0.1)
        : _hover
        ? cs.onSurface.withValues(alpha: 0.05)
        : cs.onSurface.withValues(alpha: 0);

    return Consumer(
      builder: (context, ref, _) {
        void change(bool value) => ref
            .read(themeModeProvider.notifier)
            .change(value ? ThemeMode.dark : ThemeMode.light);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOut,
                height: widget.height - 4,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: _radius,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: _radius,
                    // No ripple or highlights of its own: the background is the feedback.
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: cs.primary.withValues(alpha: 0.08),
                    onTap: () => change(!dark),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Row(
                        children: [
                          Icon(
                            dark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tema oscuro',
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              key: const Key('apariencia_switch'),
                              value: dark,
                              onChanged: change,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserData {
  final String? email;
  final String? name;
  final String? photoUrl;
  final String? role;
  final bool localMode;

  /// Only for team and area leads; `null` for the rest.
  final AsyncValue<String?>? leads;
  final AsyncValue<Employee?>? belongs;

  const _UserData({
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.role,
    required this.localMode,
    this.leads,
    this.belongs,
  });

  /// First line of the chip: the name if Google provides it, else the email.
  String get title =>
      name ?? email ?? (localMode ? 'Modo local' : 'Sin sesión iniciada');

  /// Second line: the email, only when it was not used as the title.
  String? get subtitle {
    if (name != null) return email;
    if (email == null && localMode) return 'Sin sesión iniciada';
    return null;
  }

  /// First letter of the name or email. Without a session, 'U'.
  String get initial {
    final clean = (name ?? email)?.trim() ?? '';
    if (clean.isEmpty) return 'U';
    final initial = clean.characters.first.toUpperCase();
    return RegExp(r'[A-ZÁÉÍÓÚÑ0-9]').hasMatch(initial) ? initial : 'U';
  }
}

/// Google photo cropped to a circle; without one, or if it fails, the initial.
class _UserPhoto extends StatelessWidget {
  final _UserData data;
  final double radius;

  const _UserPhoto({required this.data, required this.radius});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final initial = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary,
      child: Text(
        data.initial,
        style: TextStyle(color: cs.onPrimary, fontSize: radius * 0.85),
      ),
    );
    final url = data.photoUrl;
    if (url == null) return initial;

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initial,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final _UserData data;

  const _UserCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _UserPhoto(data: data, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name ??
                            (data.localMode ? 'Modo local' : 'Usuario'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.email ?? 'Sin sesión iniciada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Rol',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _RoleBadge(role: data.role, localMode: data.localMode),
            if (data.leads case final leads?) ...[
              const SizedBox(height: 12),
              _AccountData(
                itemKey: 'cuenta_lidera',
                title: 'Lidera',
                value: leads.whenData((text) => (text ?? '—', false)),
              ),
            ],
            if (data.belongs case final belongs?) ...[
              const SizedBox(height: 10),
              _AccountData(
                itemKey: 'cuenta_pertenece',
                title: 'Pertenece a',
                value: belongs.whenData(
                  (employee) => (
                    OrgStructureLabels.membership(employee),
                    employee == null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An account detail with its small title, like the role. The value is the
/// text and whether it goes in amber.
class _AccountData extends StatelessWidget {
  final String itemKey;
  final String title;
  final AsyncValue<(String, bool)> value;

  const _AccountData({
    required this.itemKey,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final (text, warning) = value.when(
      data: (data) => data,
      error: (_, _) => ('No disponible', true),
      loading: () => ('Cargando…', false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          key: Key(itemKey),
          style: context.textTheme.bodySmall?.copyWith(
            color: warning ? colors.warning.text : colors.intermediateText,
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String? role;
  final bool localMode;

  const _RoleBadge({required this.role, required this.localMode});

  @override
  Widget build(BuildContext context) {
    final known = const UserRoleParser().tryParse(role);
    final raw = role?.trim() ?? '';

    final cs = context.colorScheme;
    final warning = context.colors.warning;

    // An unknown role is shown as is, in amber, as in the admin panel.
    final (text, color, background, description) = known != null
        ? (known.label, cs.primary, cs.primaryContainer, known.description)
        : (
            localMode ? 'Sin rol' : (raw.isEmpty ? 'Sin rol' : raw),
            warning.text,
            warning.background,
            localMode
                ? 'La app corre sin Supabase, no hay usuario autenticado.'
                : 'Rol no reconocido por el sistema.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.intermediateText,
          ),
        ),
      ],
    );
  }
}
