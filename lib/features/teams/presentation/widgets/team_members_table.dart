import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/member_sort.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeamMembersTable extends StatefulWidget {
  final List<EmployeeCompliance> members;

  const TeamMembersTable({super.key, required this.members});

  @override
  State<TeamMembersTable> createState() => _TeamMembersTableState();
}

class _TeamMembersTableState extends State<TeamMembersTable> {
  static const _membersPerPage = 8;
  static const _minimumTableWidth = 980.0;
  int _currentPage = 0;
  var _sortState = const MemberSortState();
  late List<EmployeeCompliance> _sortedMembers;

  static const _columns = <(String, MemberSort?)>[
    ('Legajo', MemberSort.employeeId),
    ('Colaborador', MemberSort.employee),
    ('Seniority', MemberSort.seniority),
    ('Horas realizadas / objetivo', MemberSort.hours),
    ('Cumplimiento', MemberSort.compliance),
    ('Por categoría', null),
  ];

  @override
  void initState() {
    super.initState();
    _sortedMembers = _sortState.apply(widget.members);
  }

  @override
  void didUpdateWidget(covariant TeamMembersTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members) {
      _currentPage = 0;
      _sortedMembers = _sortState.apply(widget.members);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = widget.members.length;
    final pageCount = memberCount == 0
        ? 1
        : (memberCount + _membersPerPage - 1) ~/ _membersPerPage;
    final safePage = _currentPage.clamp(0, pageCount - 1);
    final startIndex = safePage * _membersPerPage;
    final calculatedEnd = startIndex + _membersPerPage;
    final endIndex = calculatedEnd > memberCount ? memberCount : calculatedEnd;
    final visibleMembers = _sortedMembers.sublist(startIndex, endIndex);
    final sortColumnIndex = _columns.indexWhere(
      (column) => column.$2 != null && column.$2 == _sortState.column,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrantes ($memberCount)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (pageCount > 1) ...[
          ResultsPagination(
            currentPage: safePage,
            pageCount: pageCount,
            from: startIndex + 1,
            until: endIndex,
            totalResults: memberCount,
            resultsLabel: 'integrantes',
            icon: Icons.people_outline,
            onPrevious: safePage > 0
                ? () => setState(() => _currentPage = safePage - 1)
                : null,
            onNext: safePage < pageCount - 1
                ? () => setState(() => _currentPage = safePage + 1)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          decoration: context.panel(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth < _minimumTableWidth
                        ? _minimumTableWidth
                        : constraints.maxWidth,
                  ),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(
                      context.colorScheme.surfaceContainerLow,
                    ),
                    sortColumnIndex: sortColumnIndex < 0
                        ? null
                        : sortColumnIndex,
                    sortAscending: _sortState.ascending,
                    columns: [
                      for (final (title, sortColumn) in _columns)
                        DataColumn(
                          label: Text(title),
                          onSort: sortColumn == null
                              ? null
                              : (_, _) => setState(() {
                                  _sortState = _sortState.toggle(sortColumn);
                                  _sortedMembers = _sortState.apply(
                                    widget.members,
                                  );
                                  _currentPage = 0;
                                }),
                        ),
                    ],
                    rows: visibleMembers.map(_buildRow).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(EmployeeCompliance member) {
    final employee = member.employee;
    final isOnTarget = member.meetsTarget;

    return DataRow(
      onSelectChanged: (_) => context.push(
        '/empleados/${Uri.encodeComponent(employee.employeeId)}',
      ),
      cells: [
        DataCell(Text(employee.employeeId)),
        DataCell(
          Text(
            employee.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(employee.seniority.label)),
        DataCell(
          Text(
            '${member.totalCreditedHours.toStringAsFixed(1)} / ${member.totalRequiredHours.toStringAsFixed(1)} h',
          ),
        ),
        DataCell(
          Text(
            formatPercentage(member.totalPercentage),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isOnTarget
                  ? context.colors.success.text
                  : context.colors.warning.text,
            ),
          ),
        ),
        DataCell(
          CategoryHoursProgress(
            compliance: member,
            showOnlyApplicableHours: true,
          ),
        ),
      ],
    );
  }
}
