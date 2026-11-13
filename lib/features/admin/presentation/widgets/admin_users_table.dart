import 'package:app_finnegans/core/widgets/page_window.dart';
import 'package:collection/collection.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user_service.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_styles.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';
import 'package:app_finnegans/features/auth/presentation/user_role_labels.dart';
import 'package:app_finnegans/features/admin/presentation/user_status_labels.dart';

const _users = AuthorizedUserService();

class AdminUsersTable extends StatefulWidget {
  static const usersPerPage = 8;

  final List<AuthorizedUser> users;

  /// For the "Lidera" column. `null` while it loads.
  final OrgStructure? structure;

  /// For the "Pertenece a" column. `null` while it loads.
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
    // An action on a user rebuilds the list: only another set of users
    // (a filter) goes back to the first page.
    final emails = widget.users.map((user) => user.email);
    final oldEmails = oldWidget.users.map((user) => user.email);
    if (!const IterableEquality<String>().equals(emails, oldEmails)) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.users.length;
    final (page: safePage, pageCount: totalPages, :start, :end) = pageWindow(
      page: _currentPage,
      pageSize: AdminUsersTable.usersPerPage,
      total: total,
    );
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
    final isOwn = _users.isSameUser(user, widget.ownEmail);
    final role = _users.knownRole(user);
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
        DataCell(_ScopeCell(user: user, structure: widget.structure)),
        DataCell(_MembershipCell(user: user, payroll: widget.payroll)),
        DataCell(
          ColorLabel(
            text: _users.status(user).label,
            colors: userStatusColors(colors, _users.status(user)),
          ),
        ),
        DataCell(_StampCell(user.createdAt)),
        DataCell(_StampCell(user.blockedAt)),
        DataCell(_StampCell(user.deletedAt)),
      ],
    );
  }
}

/// What the user sees: the whole company, or the areas or teams they lead
/// according to their role.
class _ScopeCell extends StatelessWidget {
  final AuthorizedUser user;
  final OrgStructure? structure;

  const _ScopeCell({required this.user, required this.structure});

  @override
  Widget build(BuildContext context) {
    final role = _users.knownRole(user);
    // Managers see everything even before the structure loads.
    final text = role != null && role.canManage
        ? 'Toda la empresa'
        : structure?.leads(role: role, email: user.email) ?? '—';
    return _TextCell(text, warning: text.startsWith('Sin '));
  }
}

/// Team and area of the user's payroll row, looked up by email. Only for
/// leaders: it may differ from what they lead.
class _MembershipCell extends StatelessWidget {
  final AuthorizedUser user;
  final List<Employee>? payroll;

  const _MembershipCell({required this.user, required this.payroll});

  @override
  Widget build(BuildContext context) {
    final role = _users.knownRole(user);
    final payroll = this.payroll;
    if (payroll == null ||
        (role != UserRole.teamLead && role != UserRole.areaLead)) {
      return const _TextCell('—');
    }
    final employee = const EmployeeLookupService().findByEmail(
      payroll,
      user.email,
    );
    return _TextCell(
      OrgStructureLabels.membership(employee),
      warning: employee == null,
    );
  }
}

class _TextCell extends StatelessWidget {
  final String text;
  final bool warning;

  const _TextCell(this.text, {this.warning = false});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
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
}

class _StampCell extends StatelessWidget {
  final DateTime? date;

  const _StampCell(this.date);

  @override
  Widget build(BuildContext context) => Text(
    formatStamp(date),
    style: context.textTheme.bodySmall?.copyWith(
      color: date == null
          ? context.colors.faintText
          : context.colors.intermediateText,
    ),
  );
}
