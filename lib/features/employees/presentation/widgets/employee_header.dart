import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';

class EmployeeHeader extends StatelessWidget {
  final Employee employee;
  final EmployeeCompliance compliance;
  final bool showCompliance;

  const EmployeeHeader({
    super.key,
    required this.employee,
    required this.compliance,
    required this.showCompliance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final complianceStatus = compliance.meetsTarget
        ? context.colors.success
        : context.colors.warning;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primary,
            child: Text(
              employee.firstName.trim().isEmpty
                  ? '?'
                  : employee.firstName.trim().substring(0, 1).toUpperCase(),
              style: context.textTheme.displaySmall?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${employee.firstName} ${employee.lastName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SeniorityChip(seniority: employee.seniority),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área: ${orDash(employee.area)} · Legajo ${employee.employeeId}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orDash(employee.email),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EmployeeData(
                      label: 'Equipo',
                      value: orDash(employee.team),
                    ),
                    _EmployeeData(
                      label: 'Líder',
                      value: orDash(employee.manager),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showCompliance)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: complianceStatus.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${formatAchievedHours(compliance.totalCreditedHours, target: compliance.totalRequiredHours)} / ${formatHours(compliance.totalRequiredHours)} hs válidas',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compliance.meetsTarget
                        ? 'Objetivo cumplido'
                        : 'En progreso',
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: complianceStatus.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CRM declaró ${formatHours(compliance.totalDeclaredHours)} hs',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeData extends StatelessWidget {
  final String label;
  final String value;

  const _EmployeeData({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: context
          .panel(radius: 6)
          .copyWith(color: context.colorScheme.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
