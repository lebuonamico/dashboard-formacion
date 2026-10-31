import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/admin/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
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
class AdminStructure extends ConsumerStatefulWidget {
  const AdminStructure({super.key});

  @override
  ConsumerState<AdminStructure> createState() => _AdminStructureState();
}

class _AdminStructureState extends ConsumerState<AdminStructure> {
  String? _actionInProgress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    if (ref.watch(orgStructureRepositoryProvider) == null) {
      return const _Notice(
        icon: Icons.cloud_off_outlined,
        title: 'Las áreas y los equipos no están disponibles',
        message:
            'Esta versión de la aplicación no está conectada a la base, así '
            'que no hay líderes para asignar.',
      );
    }
    final structure = ref.watch(orgStructureProvider);

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
                ref.read(adminStructureSearchProvider.notifier).state = value,
          ),
        ),
        const SizedBox(height: 20),
        structure.when(
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
          data: (data) => FadeIn(child: _list(data!)),
        ),
      ],
    );
  }

  Widget _list(OrgStructure structure) {
    final query = ref.watch(adminStructureSearchProvider).trim().toLowerCase();
    final counts = _Counts(ref.watch(employeesProvider).value ?? const []);
    final names = _nameByEmail();
    final areas = structure.sortedAreas.where((area) {
      if (query.isEmpty) return true;
      return area.name.toLowerCase().contains(query) ||
          structure
              .teamsOf(area.id)
              .any((team) => team.name.toLowerCase().contains(query));
    }).toList();

    if (areas.isEmpty) {
      return _Notice(
        icon: Icons.account_tree_outlined,
        title: query.isEmpty
            ? 'Todavía no hay áreas'
            : 'Ningún área o equipo coincide con la búsqueda',
        message: query.isEmpty
            ? 'Se crean al importar la nómina desde Configuración.'
            : 'Probá con otro nombre.',
      );
    }

    return Column(
      children: [
        for (final area in areas) ...[
          _CardArea(
            area: area,
            teams: structure.teamsOf(area.id),
            counts: counts,
            nameByEmail: names,
            enabled: _actionInProgress == null,
            onLeaders: () => _leadersArea(area),
            onTeamLeaders: (team) => _teamLeaders(team),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Map<String, String> _nameByEmail() => {
    for (final employee
        in ref.watch(employeesProvider).value ?? const <Employee>[])
      if (employee.email.trim().isNotEmpty)
        OrgStructure.normalizeEmail(employee.email): employee.fullName,
  };

  Future<void> _leadersArea(Area area) async {
    final chosen = await _chooseLeaders(
      title: 'Líderes de ${area.name}',
      subtitle:
          'Ven todos los equipos del área. Solo se pueden elegir usuarios '
          'activos con el rol Área.',
      role: UserRole.areaLead,
      current: area.leaders,
    );
    if (chosen == null) return;
    await _run(
      key: 'lideres_area',
      success: 'Se actualizaron los líderes de ${area.name}.',
      action: (repository) => repository.assignLeadersArea(area.id, chosen),
    );
  }

  Future<void> _teamLeaders(Team team) async {
    final chosen = await _chooseLeaders(
      title: 'Líderes de ${team.name}',
      subtitle:
          'Ven a los integrantes del equipo. Solo se pueden elegir usuarios '
          'activos con el rol Líder de equipo.',
      role: UserRole.teamLead,
      current: team.leaders,
    );
    if (chosen == null) return;
    await _run(
      key: 'lideres_equipo',
      success: 'Se actualizaron los líderes de ${team.name}.',
      action: (repository) => repository.assignTeamLeaders(team.id, chosen),
    );
  }

  Future<Set<String>?> _chooseLeaders({
    required String title,
    required String subtitle,
    required UserRole role,
    required Set<String> current,
  }) async {
    final List<AuthorizedUser> users;
    try {
      users = await ref.read(authorizedUsersProvider.future);
    } on Object catch (error) {
      if (!mounted) return null;
      showAppSnackBar(
        context,
        error is FormatException
            ? error.message
            : 'No se pudo cargar la lista de usuarios.',
      );
      return null;
    }
    if (!mounted) return null;
    return showLeadersDialog(
      context,
      title: title,
      subtitle: subtitle,
      role: role,
      users: users,
      selected: current,
      nameByEmail: _nameByEmail(),
    );
  }

  Future<void> _run({
    required String key,
    required String success,
    required Future<void> Function(OrgStructureRepository) action,
  }) async {
    if (_actionInProgress != null) return;
    final repository = ref.read(orgStructureRepositoryProvider);
    if (repository == null) return;
    setState(() => _actionInProgress = key);
    try {
      await action(repository);
      // Los líderes definen qué ve cada uno y se muestran en Equipos y
      // Áreas: recargar la estructura actualiza todo.
      ref.invalidate(orgStructureProvider);
      await ref.read(orgStructureProvider.future);
      if (!mounted) return;
      showAppSnackBar(context, success);
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      debugPrint('Panel de áreas y equipos: $error');
      if (!mounted) return;
      showAppSnackBar(
        context,
        'No se pudo completar la acción. Intentá nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }
}

/// Colaboradores activos por área y por equipo, por clave de nómina.
class _Counts {
  final Map<String, int> _byArea = {};
  final Map<(String, String), int> _byTeam = {};

  _Counts(Iterable<Employee> employees) {
    for (final employee in employees) {
      if (!employee.isActive) continue;
      final area = OrgStructure.payrollKey(employee.area);
      _byArea[area] = (_byArea[area] ?? 0) + 1;
      final team = (area, OrgStructure.payrollKey(employee.team));
      _byTeam[team] = (_byTeam[team] ?? 0) + 1;
    }
  }

  int forArea(Area area) => _byArea[area.payrollKey] ?? 0;

  int forTeam(Area area, Team team) =>
      _byTeam[(area.payrollKey, team.payrollKey)] ?? 0;
}

String _employees(int count) =>
    '$count ${count == 1 ? 'colaborador' : 'colaboradores'}';

class _CardArea extends StatelessWidget {
  final Area area;
  final List<Team> teams;
  final _Counts counts;
  final Map<String, String> nameByEmail;
  final bool enabled;
  final VoidCallback onLeaders;
  final ValueChanged<Team> onTeamLeaders;

  const _CardArea({
    required this.area,
    required this.teams,
    required this.counts,
    required this.nameByEmail,
    required this.enabled,
    required this.onLeaders,
    required this.onTeamLeaders,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final detail =
        '${teams.length} ${teams.length == 1 ? 'equipo' : 'equipos'} · '
        '${_employees(counts.forArea(area))}';

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
          for (final team in teams)
            _TeamRow(
              team: team,
              employees: counts.forTeam(area, team),
              nameByEmail: nameByEmail,
              enabled: enabled,
              onLeaders: () => onTeamLeaders(team),
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
