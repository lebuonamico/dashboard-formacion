import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_styles.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';

class AdminUsersTable extends StatefulWidget {
  static const usersPerPage = 8;

  final List<AuthorizedUser> users;

  /// Para la columna Lidera. `null` mientras carga o sin base conectada.
  final OrgStructure? structure;

  /// Para la columna Pertenece a. `null` mientras carga.
  final List<Employee>? payroll;
  final String? selectedEmail;
  final String? ownEmail;
  final ValueChanged<String?> onSelect;

  const AdminUsersTable({
    super.key,
    required this.users,
    this.structure,
    this.payroll,
    required this.selectedEmail,
    required this.ownEmail,
    required this.onSelect,
  });

  @override
  State<AdminUsersTable> createState() => _AdminUsersTableState();
}

class _AdminUsersTableState extends State<AdminUsersTable> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant AdminUsersTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const perPage = AdminUsersTable.usersPerPage;
    final total = widget.users.length;
    final totalPages = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final start = safePage * perPage;
    final calculatedEnd = start + perPage;
    final end = calculatedEnd > total ? total : calculatedEnd;
    final visible = widget.users.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalPages > 1) ...[
          ResultsPagination(
            currentPage: safePage,
            pageCount: totalPages,
            from: start + 1,
            until: end,
            totalResults: total,
            resultsLabel: 'usuarios',
            icon: Icons.manage_accounts_outlined,
            onPrevious: safePage > 0
                ? () => setState(() => _currentPage = safePage - 1)
                : null,
            onNext: safePage < totalPages - 1
                ? () => setState(() => _currentPage = safePage + 1)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          decoration: context.panel(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 900
                          ? 900
                          : constraints.maxWidth,
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(
                        context.colorScheme.surfaceContainerLow,
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Email',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Rol',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Lidera',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Pertenece a',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Estado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de alta',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de bloqueo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de eliminación',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: visible.map(_buildRow).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(AuthorizedUser user) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final selected = user.email == widget.selectedEmail;
    final isOwn = user.isSameUser(widget.ownEmail);
    final role = user.knownRole;
    final brand = ColorPair(cs.onPrimaryContainer, cs.primaryContainer);

    return DataRow(
      selected: selected,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? cs.primary.withValues(alpha: 0.06)
            : null,
      ),
      onSelectChanged: (value) =>
          widget.onSelect(value == true ? user.email : null),
      cells: [
        DataCell(
          Row(
            children: [
              Text(
                user.email,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (isOwn) ...[
                const SizedBox(width: 8),
                ColorLabel(text: 'Vos', colors: brand),
              ],
            ],
          ),
        ),
        DataCell(
          role == null
              ? ColorLabel(
                  text: user.role.isEmpty ? 'Sin rol' : user.role,
                  colors: colors.warning,
                  icon: Icons.help_outline,
                )
              : ColorLabel(text: role.label, colors: brand),
        ),
        DataCell(_scope(user)),
        DataCell(_membership(user)),
        DataCell(
          ColorLabel(
            text: user.status.label,
            colors: userStatusColors(colors, user.status),
          ),
        ),
        DataCell(_stamp(user.createdAt)),
        DataCell(_stamp(user.blockedAt)),
        DataCell(_stamp(user.deletedAt)),
      ],
    );
  }

  /// Qué ve el usuario: toda la empresa, o las áreas o los equipos que
  /// lidera según su rol.
  Widget _scope(AuthorizedUser user) {
    final role = user.knownRole;
    // Los gestores ven todo aunque la estructura no haya cargado.
    final text = role != null && role.canManage
        ? 'Toda la empresa'
        : widget.structure?.leads(role: role, email: user.email) ?? '—';
    return _textCell(text, warning: text.startsWith('Sin '));
  }

  /// Equipo y área de su fila en la nómina, buscada por email. Solo para los
  /// líderes: puede no coincidir con lo que lideran.
  Widget _membership(AuthorizedUser user) {
    final role = user.knownRole;
    final payroll = widget.payroll;
    if (payroll == null ||
        (role != UserRole.teamLead && role != UserRole.areaLead)) {
      return _textCell('—');
    }
    final employee = const EmployeeLookupService().findByEmail(
      payroll,
      user.email,
    );
    return _textCell(
      OrgStructure.membership(employee),
      warning: employee == null,
    );
  }

  Widget _textCell(String text, {bool warning = false}) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: Tooltip(
      message: text,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: warning
              ? context.colors.warning.text
              : context.colors.intermediateText,
        ),
      ),
    ),
  );

  Widget _stamp(DateTime? date) => Text(
    formatStamp(date),
    style: context.textTheme.bodySmall?.copyWith(
      color: date == null
          ? context.colors.faintText
          : context.colors.intermediateText,
    ),
  );
}
