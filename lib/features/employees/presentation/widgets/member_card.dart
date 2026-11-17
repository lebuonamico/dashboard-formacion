import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/percentage_formatter.dart';
import 'package:app_finnegans/core/widgets/color_label.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_colors.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/category_hours_progress.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Below 840 px, a member of an area or a team: what a row of the members
/// table shows. Tapping it opens the profile.
class MemberCard extends StatelessWidget {
  final EmployeeCompliance member;

  /// Menu section the detail was opened from, so the profile highlights it.
  final String origin;

  /// The area lists its members' teams; a team does not repeat its own.
  final bool showTeam;

  const MemberCard({
    super.key,
    required this.member,
    required this.origin,
    this.showTeam = false,
  });

  @override
  Widget build(BuildContext context) {
    final employee = member.employee;
    final team = employee.team.trim();
    final level = const ComplianceLevelService().fromPercentage(
      member.totalPercentage,
    );

    return RecordCard(
      key: ValueKey('member_card_${employee.employeeId}'),
      title: employee.fullName,
      subtitle: 'Legajo ${employee.employeeId}',
      trailing: ColorLabel(
        text: formatPercentage(member.totalPercentage),
        colors: level.colors(context),
      ),
      metrics: [
        if (showTeam)
          RecordMetric('Equipo', team.isEmpty ? 'Sin equipo asignado' : team),
        RecordMetric('Seniority', employee.seniority.label),
        RecordMetric(
          'Horas válidas / objetivo',
          '${formatAchievedHours(member.totalCreditedHours, target: member.totalRequiredHours)} / ${formatHours(member.totalRequiredHours)} hs',
        ),
      ],
      footer: CategoryHoursProgress(
        compliance: member,
        showOnlyApplicableHours: true,
      ),
      onTap: () => context.push(
        '/empleados/${Uri.encodeComponent(employee.employeeId)}?origen=$origin',
      ),
    );
  }
}
