import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/pending_reminder_labels.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/providers/pending_reminders_providers.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/widgets/pending_reminders_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emails each employee in the current filters the courses they still have
/// pending, after confirming who gets what.
class NotifyPendingButton extends ConsumerWidget {
  const NotifyPendingButton({super.key});

  Future<void> _notify(
    BuildContext context,
    WidgetRef ref,
    PendingReminderPlan plan,
  ) async {
    if (plan.reminders.isEmpty) {
      showAppSnackBar(
        context,
        plan.skipped.isEmpty
            ? noPendingReminders
            : 'Ningún colaborador con pendientes tiene un mail válido en la '
                  'nómina.',
      );
      return;
    }
    if (!await showPendingRemindersDialog(context, plan)) return;
    if (!context.mounted) return;
    await runWithResultFeedback(
      context,
      action: () =>
          ref.read(pendingRemindersSendProvider.notifier).send(plan.reminders),
      success: pendingReminderSuccess,
      failure: pendingReminderFailure,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(pendingReminderPlanProvider);
    final sending = ref.watch(pendingRemindersSendProvider).isLoading;
    final help = switch (planAsync) {
      AsyncValue(isLoading: true) => 'Cargando datos…',
      AsyncValue(hasError: true) => 'No se pudieron cargar los datos',
      _ =>
        'Envía un mail a cada colaborador de los filtros con sus cursos '
            'pendientes',
    };
    final cs = context.colorScheme;

    return Tooltip(
      message: help,
      child: OutlinedButton.icon(
        // On error it stays enabled to explain why nothing can be sent.
        onPressed: sending || planAsync.isLoading
            ? null
            : () => switch (planAsync) {
                AsyncValue(:final error?) => showAppSnackBar(
                  context,
                  'No se pudieron cargar los datos. '
                  '${loadErrorMessage(error)}',
                ),
                AsyncValue(value: final plan?) => _notify(context, ref, plan),
                _ => showAppSnackBar(context, noPendingReminders),
              },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 30),
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outlineVariant),
          textStyle: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: sending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.forward_to_inbox_outlined, size: 16),
        label: Text(sending ? 'Enviando…' : 'Notificar pendientes por mail'),
      ),
    );
  }
}
