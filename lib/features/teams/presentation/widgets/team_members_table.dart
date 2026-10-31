import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/member_order_provider.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _membersPerPage = 8;
const _minimumTableWidth = 980.0;
const _columns = <(String, MemberSort?)>[
  ('Legajo', MemberSort.employeeId),
  ('Colaborador', MemberSort.employee),
  ('Seniority', MemberSort.seniority),
  ('Horas realizadas / objetivo', MemberSort.hours),
  ('Cumplimiento', MemberSort.compliance),
  ('Por categoría', null),
];

class TeamMembersTable extends ConsumerStatefulWidget {
  final ({String area, String team}) section;

  const TeamMembersTable({super.key, required this.section});

  @override
  ConsumerState<TeamMembersTable> createState() => _TeamMembersTableState();
}

class _TeamMembersTableState extends ConsumerState<TeamMembersTable> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final membersProvider = sortedTeamMembersProvider(widget.section);
    ref.listen(membersProvider, (previous, next) {
      if (previous?.value != next.value) setState(() => _currentPage = 0);
    });

    return ref
        .watch(membersProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar los integrantes',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(membersProvider),
          ),
          data: (members) => _MembersPage(
            members: members,
            currentPage: _currentPage,
            onPage: (page) => setState(() => _currentPage = page),
          ),
        );
  }
}

class _MembersPage extends ConsumerWidget {
  final List<EmployeeCompliance> members;
  final int currentPage;
  final ValueChanged<int> onPage;

  const _MembersPage({
    required this.members,
    required this.currentPage,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(memberOrderProvider(MemberTable.team));
    final memberCount = members.length;
    final pageCount = memberCount == 0
        ? 1
        : (memberCount + _membersPerPage - 1) ~/ _membersPerPage;
    final safePage = currentPage.clamp(0, pageCount - 1);
    final startIndex = safePage * _membersPerPage;
    final endIndex = (startIndex + _membersPerPage).clamp(0, memberCount);
    final sortColumnIndex = _columns.indexWhere(
      (column) => column.$2 != null && column.$2 == order.column,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrantes ($memberCount)',
          style: context.textTheme.titleMedium?.copyWith(
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
            onPrevious: safePage > 0 ? () => onPage(safePage - 1) : null,
            onNext: safePage < pageCount - 1
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
                    sortColumnIndex: sortColumnIndex < 0
                        ? null
                        : sortColumnIndex,
                    sortAscending: order.ascending,
                    columns: [
                      for (final (title, sortColumn) in _columns)
                        DataColumn(
                          label: Text(title),
                          onSort: sortColumn == null
                              ? null
                              : (_, _) => ref
                                    .read(
                                      memberOrderProvider(
                                        MemberTable.team,
                                      ).notifier,
                                    )
                                    .sortBy(sortColumn),
                        ),
                    ],
                    rows: members
                        .sublist(startIndex, endIndex)
                        .map((member) => _buildRow(context, member))
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(BuildContext context, EmployeeCompliance member) {
    final employee = member.employee;

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
