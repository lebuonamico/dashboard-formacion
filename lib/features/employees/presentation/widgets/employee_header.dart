import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';

/// Who the employee is and, with data in the period, their valid hours. On
/// desktop the hours box sits beside the data; below 840 px it goes under
/// them, across the panel.
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
    final windowSize = context.windowSize;
    if (windowSize == WindowSize.expanded) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: context.panel(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(employee),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: _Name(employee, maxLines: 1)),
                      const SizedBox(width: 12),
                      SeniorityChip(seniority: employee.seniority),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Contact(employee),
                  const SizedBox(height: 16),
                  _TeamAndLeader(employee),
                ],
              ),
            ),
            if (showCompliance) _ComplianceBox(compliance),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(windowSize == WindowSize.compact ? 16 : 24),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(employee, small: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Name(employee, maxLines: 2),
                    const SizedBox(height: 4),
                    SeniorityChip(seniority: employee.seniority),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Contact(employee),
          const SizedBox(height: 12),
          _TeamAndLeader(employee),
          if (showCompliance) ...[
            const SizedBox(height: 16),
            _ComplianceBox(compliance),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Employee employee;
  final bool small;

  const _Avatar(this.employee, {this.small = false});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final firstName = employee.firstName.trim();
    final style = small
        ? context.textTheme.headlineMedium
        : context.textTheme.displaySmall;
    return CircleAvatar(
      radius: small ? 28 : 36,
      backgroundColor: cs.primary,
      child: Text(
        firstName.isEmpty ? '?' : firstName.substring(0, 1).toUpperCase(),
        style: style?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Name extends StatelessWidget {
  final Employee employee;
  final int maxLines;

  const _Name(this.employee, {required this.maxLines});

  @override
  Widget build(BuildContext context) => Text(
    '${employee.firstName} ${employee.lastName}',
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: context.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    ),
  );
}

class _Contact extends StatelessWidget {
  final Employee employee;

  const _Contact(this.employee);

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodyMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Área: ${orDash(employee.area)} · Legajo ${employee.employeeId}',
          style: style,
        ),
        const SizedBox(height: 4),
        Text(orDash(employee.email), style: style),
      ],
    );
  }
}

class _TeamAndLeader extends StatelessWidget {
  final Employee employee;

  const _TeamAndLeader(this.employee);

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _EmployeeData(label: 'Equipo', value: orDash(employee.team)),
      _EmployeeData(label: 'Líder', value: orDash(employee.manager)),
    ],
  );
}

/// Valid hours of the period against the target, green once met.
class _ComplianceBox extends StatelessWidget {
  final EmployeeCompliance compliance;

  const _ComplianceBox(this.compliance);

  @override
  Widget build(BuildContext context) {
    final status = compliance.meetsTarget
        ? context.colors.success
        : context.colors.warning;
    return Container(
      key: const Key('perfil_horas_validas'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '${formatAchievedHours(compliance.totalCreditedHours, target: compliance.totalRequiredHours)} / ${formatHours(compliance.totalRequiredHours)} hs válidas',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: status.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            compliance.meetsTarget ? 'Objetivo cumplido' : 'En progreso',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: status.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CRM declaró ${formatHours(compliance.totalDeclaredHours)} hs',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
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
