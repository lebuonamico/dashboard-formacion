import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/pending_reminder_labels.dart';
import 'package:flutter/material.dart';

const confirmPendingRemindersKey = Key('confirm-pending-reminders');

/// Lists who gets an email and with which courses, and who is left out.
/// Returns whether the user confirmed the send.
Future<bool> showPendingRemindersDialog(
  BuildContext context,
  PendingReminderPlan plan,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Notificar cursos pendientes'),
      content: SizedBox(width: 520, child: _PlanSummary(plan)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: confirmPendingRemindersKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.send_outlined, size: 18),
          label: Text('Enviar ${emailCount(plan.reminders.length)}'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _PlanSummary extends StatelessWidget {
  final PendingReminderPlan plan;

  const _PlanSummary(this.plan);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Se enviará un mail a ${peopleCount(plan.reminders.length)} '
          'con ${courseCount(plan.courseCount)} '
          '${plan.courseCount == 1 ? 'pendiente' : 'pendientes'} en total. '
          'Cada colaborador recibe solo sus cursos.',
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final reminder in plan.reminders) _ReminderTile(reminder),
              ],
            ),
          ),
        ),
        if (plan.skipped.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SkippedNotice(plan.skipped),
        ],
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final PendingReminder reminder;

  const _ReminderTile(this.reminder);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reminder.fullName,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          Text(
            reminder.email,
            style: context.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          for (final course in reminder.courses)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '• ${course.courseName}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.intermediateText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkippedNotice extends StatelessWidget {
  final List<SkippedReminder> skipped;

  const _SkippedNotice(this.skipped);

  @override
  Widget build(BuildContext context) {
    final warning = context.colors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: warning.text),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No se notificará a ${peopleCount(skipped.length)}:',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: warning.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final person in skipped)
            Text(
              '• ${person.fullName.isEmpty ? 'Legajo ${person.employeeId}' : person.fullName}'
              ' (${person.reason.label}, ${courseCount(person.pendingCourses)})',
              style: context.textTheme.bodySmall?.copyWith(color: warning.text),
            ),
        ],
      ),
    );
  }
}
