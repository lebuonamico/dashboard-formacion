import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/member_order_provider.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _membersPerPage = 8;
const _minimumTableWidth = 1100.0;
const _columns = <(String, MemberSort?)>[
  ('Legajo', MemberSort.employeeId),
  ('Colaborador', MemberSort.employee),
  ('Equipo', MemberSort.team),
  ('Seniority', MemberSort.seniority),
  ('Horas realizadas / objetivo', MemberSort.hours),
  ('Cumplimiento', MemberSort.compliance),
  ('Por categoría', null),
];

/// Members of the area, paginated, with a selector to filter by progress.
class AreaMembersTable extends ConsumerStatefulWidget {
  final String areaName;

  const AreaMembersTable({super.key, required this.areaName});

  @override
  ConsumerState<AreaMembersTable> createState() => _AreaMembersTableState();
}

class _AreaMembersTableState extends ConsumerState<AreaMembersTable> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final viewProvider = areaMembersViewProvider(widget.areaName);
    ref.listen(viewProvider, (previous, next) {
      if (previous?.value?.members != next.value?.members) {
        setState(() => _currentPage = 0);
      }
    });

    return ref
        .watch(viewProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar los integrantes',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(viewProvider),
          ),
          data: (view) => _MembersPage(
            view: view,
            currentPage: _currentPage,
            onPage: (page) => setState(() => _currentPage = page),
          ),
        );
  }
}

class _MembersPage extends ConsumerWidget {
  final AreaMembersView view;
  final int currentPage;
  final ValueChanged<int> onPage;

  const _MembersPage({
    required this.view,
    required this.currentPage,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(memberOrderProvider(MemberTable.area));
    final members = view.members;
    final totalMembers = members.length;
    final totalPages = totalMembers == 0
        ? 1
        : (totalMembers + _membersPerPage - 1) ~/ _membersPerPage;
    final safePage = currentPage.clamp(0, totalPages - 1);
    final start = safePage * _membersPerPage;
    final end = (start + _membersPerPage).clamp(0, totalMembers);
    final orderIndex = _columns.indexWhere(
      (column) => column.$2 != null && column.$2 == order.column,
    );

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
                selectedValues: ref.watch(areaMemberStatusFilterProvider),
                incompatibleValues: view.incompatibleLevels,
                hint: 'Estado',
                icon: Icons.traffic_outlined,
                items: [
                  for (final level in ComplianceLevel.values)
                    if (view.levelOptions.contains(level))
                      DropdownMenuItem(
                        value: level,
                        child: Text(level.pluralLabel),
                      ),
                ],
                onSelectionChanged: (levels) => ref
                    .read(areaMemberStatusFilterProvider.notifier)
                    .select(levels),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
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
              onPrevious: safePage > 0 ? () => onPage(safePage - 1) : null,
              onNext: safePage < totalPages - 1
                  ? () => onPage(safePage + 1)
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
                      sortColumnIndex: orderIndex < 0 ? null : orderIndex,
                      sortAscending: order.ascending,
                      columns: [
                        for (final (title, column) in _columns)
                          DataColumn(
                            label: Text(title),
                            onSort: column == null
                                ? null
                                : (_, _) => ref
                                      .read(
                                        memberOrderProvider(
                                          MemberTable.area,
                                        ).notifier,
                                      )
                                      .sortBy(column),
                          ),
                      ],
                      rows: members
                          .sublist(start, end)
                          .map((member) => _buildRow(context, member))
                          .toList(),
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

  DataRow _buildRow(BuildContext context, EmployeeCompliance member) {
    final employee = member.employee;
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
              color: member.meetsTarget
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
