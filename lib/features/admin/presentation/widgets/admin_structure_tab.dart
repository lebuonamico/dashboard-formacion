import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_styles.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestaña "Áreas y equipos" del panel. Las áreas y los equipos vienen de la
/// importación de nómina y acá solo se consultan; lo único que se cambia son
/// sus líderes.
class AdminStructure extends ConsumerWidget {
  const AdminStructure({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final view = ref.watch(adminStructureViewProvider);
    final isSaving = ref.watch(
      orgStructureNotifierProvider.select(
        (structure) => structure.value?.isSaving ?? false,
      ),
    );

    return ListView(
      padding: screenPadding,
      children: [
        Text(
          'Áreas y equipos',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Las áreas y los equipos se crean al importar la nómina, con el '
          'Sector y el Equipo de cada colaborador. Desde acá se asignan sus '
          'líderes.',
          style: context.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 420,
          child: TextField(
            key: const Key('estructura_busqueda'),
            decoration: adminInputDecoration(
              'Buscar área o equipo',
              Icons.search,
            ),
            onChanged: (value) =>
                ref.read(adminStructureSearchProvider.notifier).setQuery(value),
          ),
        ),
        const SizedBox(height: 20),
        view.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _Notice(
            icon: Icons.error_outline,
            title: 'No pudimos cargar las áreas y los equipos',
            message: error is FormatException
                ? error.message
                : 'Revisá tu conexión e intentá nuevamente.',
            color: cs.error,
          ),
          data: (view) => FadeIn(
            child: view.areas.isEmpty
                ? _EmptyAreas(
                    searching: ref
                        .watch(adminStructureSearchProvider)
                        .trim()
                        .isNotEmpty,
                  )
                : Column(
                    children: [
                      for (final row in view.areas) ...[
                        _CardArea(
                          row: row,
                          nameByEmail: view.nameByEmail,
                          enabled: !isSaving,
                          onLeaders: () => _areaLeaders(
                            context,
                            ref,
                            row.area,
                            view.nameByEmail,
                          ),
                          onTeamLeaders: (team) => _teamLeaders(
                            context,
                            ref,
                            team,
                            view.nameByEmail,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  OrgStructureNotifier _structure(WidgetRef ref) =>
      ref.read(orgStructureNotifierProvider.notifier);

  Future<void> _areaLeaders(
    BuildContext context,
    WidgetRef ref,
    Area area,
    Map<String, String> nameByEmail,
  ) async {
    final chosen = await _chooseLeaders(
      context,
      ref,
      title: 'Líderes de ${area.name}',
      subtitle:
          'Ven todos los equipos del área. Solo se pueden elegir usuarios '
          'activos con el rol Área.',
      role: UserRole.areaLead,
      current: area.leaders,
      nameByEmail: nameByEmail,
    );
    if (chosen == null || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _structure(ref).assignAreaLeaders(area.id, chosen),
      success: 'Se actualizaron los líderes de ${area.name}.',
    );
  }

  Future<void> _teamLeaders(
    BuildContext context,
    WidgetRef ref,
    Team team,
    Map<String, String> nameByEmail,
  ) async {
    final chosen = await _chooseLeaders(
      context,
      ref,
      title: 'Líderes de ${team.name}',
      subtitle:
          'Ven a los integrantes del equipo. Solo se pueden elegir usuarios '
          'activos con el rol Líder de equipo.',
      role: UserRole.teamLead,
      current: team.leaders,
      nameByEmail: nameByEmail,
    );
    if (chosen == null || !context.mounted) return;
    await runWithFeedback(
      context,
      action: () => _structure(ref).assignTeamLeaders(team.id, chosen),
      success: 'Se actualizaron los líderes de ${team.name}.',
    );
  }

  Future<Set<String>?> _chooseLeaders(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required UserRole role,
    required Set<String> current,
    required Map<String, String> nameByEmail,
  }) async {
    final List<AuthorizedUser> users;
    try {
      users = await ref.read(authorizedUsersProvider.future);
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          error is FormatException
              ? error.message
              : 'No se pudo cargar la lista de usuarios.',
        );
      }
      return null;
    }
    if (!context.mounted) return null;
    return showLeadersDialog(
      context,
      title: title,
      subtitle: subtitle,
      role: role,
      users: users,
      selected: current,
      nameByEmail: nameByEmail,
    );
  }
}

class _EmptyAreas extends StatelessWidget {
  final bool searching;

  const _EmptyAreas({required this.searching});

  @override
  Widget build(BuildContext context) => _Notice(
    icon: Icons.account_tree_outlined,
    title: searching
        ? 'Ningún área o equipo coincide con la búsqueda'
        : 'Todavía no hay áreas',
    message: searching
        ? 'Probá con otro nombre.'
        : 'Se crean al importar la nómina desde Configuración.',
  );
}

String _employees(int count) =>
    '$count ${count == 1 ? 'colaborador' : 'colaboradores'}';

class _CardArea extends StatelessWidget {
  final StructureAreaRow row;
  final Map<String, String> nameByEmail;
  final bool enabled;
  final VoidCallback onLeaders;
  final ValueChanged<Team> onTeamLeaders;

  const _CardArea({
    required this.row,
    required this.nameByEmail,
    required this.enabled,
    required this.onLeaders,
    required this.onTeamLeaders,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final area = row.area;
    final teams = row.teams;
    final detail =
        '${teams.length} ${teams.length == 1 ? 'equipo' : 'equipos'} · '
        '${_employees(row.employees)}';

    return Container(
      key: Key('estructura_area_${area.id}'),
      width: double.infinity,
      decoration: context.panel(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_tree_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
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
          _Leaders(
            itemKey: 'estructura_lideres_area_${area.id}',
            label: 'Líderes de área',
            emails: area.leaders,
            nameByEmail: nameByEmail,
            enabled: enabled,
            onEdit: onLeaders,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          if (teams.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'La nómina no trae equipos para esta área.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          for (final teamRow in teams)
            _TeamRow(
              team: teamRow.team,
              employees: teamRow.employees,
              nameByEmail: nameByEmail,
              enabled: enabled,
              onLeaders: () => onTeamLeaders(teamRow.team),
            ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final Team team;
  final int employees;
  final Map<String, String> nameByEmail;
  final bool enabled;
  final VoidCallback onLeaders;

  const _TeamRow({
    required this.team,
    required this.employees,
    required this.nameByEmail,
    required this.enabled,
    required this.onLeaders,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Padding(
      key: Key('estructura_equipo_${team.id}'),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: Icon(
              Icons.groups_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employees == 0
                      ? 'Sin colaboradores activos en la nómina'
                      : _employees(employees),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Leaders(
              itemKey: 'estructura_lideres_equipo_${team.id}',
              label: 'Líderes',
              emails: team.leaders,
              nameByEmail: nameByEmail,
              enabled: enabled,
              onEdit: onLeaders,
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaders extends StatelessWidget {
  final String itemKey;
  final String label;
  final Set<String> emails;
  final Map<String, String> nameByEmail;
  final bool enabled;
  final VoidCallback onEdit;

  const _Leaders({
    required this.itemKey,
    required this.label,
    required this.emails,
    required this.nameByEmail,
    required this.enabled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final sorted = emails.toList()..sort();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$label:',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        if (sorted.isEmpty)
          Text(
            'Sin líderes asignados',
            style: context.textTheme.labelMedium?.copyWith(
              color: colors.faintText,
            ),
          ),
        for (final email in sorted)
          Tooltip(
            message: email,
            child: ColorLabel(
              text: nameByEmail[email] ?? email,
              colors: ColorPair(cs.onPrimaryContainer, cs.primaryContainer),
              icon: Icons.person_outline,
            ),
          ),
        TextButton(
          key: Key(itemKey),
          onPressed: enabled ? onEdit : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
          ),
          child: Text(sorted.isEmpty ? 'Asignar' : 'Editar'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _Notice({
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
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
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
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? cs.onSurface,
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
