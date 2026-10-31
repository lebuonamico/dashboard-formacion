import 'package:app_finnegans/core/data_filters/domain/data_filter.dart';
import 'package:app_finnegans/core/data_filters/domain/data_filter_service.dart';
import 'package:app_finnegans/features/compliance/presentation/member_sort.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';

/// Integrantes del área, paginados y con selector para filtrar por avance.
class AreaMembersTable extends StatefulWidget {
  final List<EmployeeCompliance> members;

  /// Vacío = todos.
  final Set<ComplianceLevel> filter;
  final ValueChanged<Set<ComplianceLevel>> onFilter;

  const AreaMembersTable({
    super.key,
    required this.members,
    required this.filter,
    required this.onFilter,
  });

  @override
  State<AreaMembersTable> createState() => _AreaMembersTableState();
}

class _AreaMembersTableState extends State<AreaMembersTable> {
  static const _membersPerPage = 8;
  int _currentPage = 0;
  var _order = const MemberSortState();

  /// Columnas en el orden en que se muestran; null = no ordenable.
  static const _columns = <(String, MemberSort?)>[
    ('Legajo', MemberSort.employeeId),
    ('Colaborador', MemberSort.employee),
    ('Equipo', MemberSort.team),
    ('Seniority', MemberSort.seniority),
    ('Horas realizadas / objetivo', MemberSort.hours),
    ('Cumplimiento', MemberSort.compliance),
    ('Por categoría', null),
  ];

  @override
  void didUpdateWidget(covariant AreaMembersTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members ||
        oldWidget.filter != widget.filter) {
      _currentPage = 0;
    }
  }

  ComplianceLevel _memberLevel(EmployeeCompliance member) =>
      const ComplianceLevelService().fromPercentage(member.totalPercentage);

  List<EmployeeCompliance> get _filteredMembers => widget.members
      .where(
        (member) =>
            widget.filter.isEmpty ||
            widget.filter.contains(_memberLevel(member)),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final statusOptions = const DataFilterService().cascade(
      [
        for (final member in widget.members)
          FilterRow({'Estado': _memberLevel(member).name}),
      ],
      {'Estado': widget.filter.map((level) => level.name).toSet()},
    )['Estado'];
    final filteredVisible = _order.apply(_filteredMembers);
    final orderIndex = _columns.indexWhere(
      (column) => column.$2 != null && column.$2 == _order.column,
    );
    final totalMembers = filteredVisible.length;
    final totalPages = totalMembers == 0
        ? 1
        : (totalMembers + _membersPerPage - 1) ~/ _membersPerPage;
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final start = safePage * _membersPerPage;
    final calculatedEnd = start + _membersPerPage;
    final end = calculatedEnd > totalMembers ? totalMembers : calculatedEnd;
    final visibleMembers = filteredVisible.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 16,
          children: [
            Text(
              'Integrantes ($totalMembers)',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
            SizedBox(
              width: 250,
              child: FilterDropdown<ComplianceLevel>.multiple(
                selectedValues: widget.filter,
                incompatibleValues: {
                  for (final name
                      in statusOptions?.incompatibleValues ?? const <String>{})
                    ComplianceLevel.values.byName(name),
                },
                hint: 'Estado',
                icon: Icons.traffic_outlined,
                items: [
                  for (final level in ComplianceLevel.values)
                    if (statusOptions?.values.contains(level.name) ?? false)
                      DropdownMenuItem(
                        value: level,
                        child: Text(level.pluralLabel),
                      ),
                ],
                onSelectionChanged: widget.onFilter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleMembers.isEmpty)
          const EmptyDataState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: 'Ningún integrante coincide con el filtro.',
          )
        else ...[
          if (totalPages > 1) ...[
            ResultsPagination(
              currentPage: safePage,
              pageCount: totalPages,
              from: start + 1,
              until: end,
              totalResults: totalMembers,
              resultsLabel: 'integrantes',
              icon: Icons.people_outline,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 1100
                          ? 1100
                          : constraints.maxWidth,
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(
                        context.colorScheme.surfaceContainerLow,
                      ),
                      sortColumnIndex: orderIndex < 0 ? null : orderIndex,
                      sortAscending: _order.ascending,
                      columns: [
                        for (final (title, order) in _columns)
                          DataColumn(
                            label: Text(title),
                            onSort: order == null
                                ? null
                                : (_, _) => setState(() {
                                    _order = _order.toggle(order);
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
      ],
    );
  }

  DataRow _buildRow(EmployeeCompliance member) {
    final employee = member.employee;
    final meets = member.meetsTarget;
    final team = employee.team.trim();

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
        DataCell(
          Text(
            team.isEmpty ? 'Sin equipo asignado' : team,
            style: TextStyle(
              color: team.isEmpty ? context.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
        DataCell(SeniorityChip(seniority: employee.seniority)),
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
              color: meets
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
