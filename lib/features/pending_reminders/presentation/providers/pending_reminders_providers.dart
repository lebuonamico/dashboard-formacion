import 'dart:async';

import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder_service.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/providers/pending_reminders_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingReminderServiceProvider = Provider<PendingReminderService>(
  (ref) => const PendingReminderService(),
);

/// The reminders for what the certification filters show right now.
final pendingReminderPlanProvider = FutureProvider<PendingReminderPlan>((
  ref,
) async {
  final filtered = await ref.watch(filteredCertificationsProvider.future);
  return ref.watch(pendingReminderServiceProvider).plan(filtered);
});

final pendingRemindersSendProvider =
    AsyncNotifierProvider<PendingRemindersNotifier, void>(
      PendingRemindersNotifier.new,
    );

/// Loading while the reminders are sent. A failure is rethrown and the state
/// goes back to idle, so the button can retry.
class PendingRemindersNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Null when a send is already running.
  Future<PendingReminderResult?> send(List<PendingReminder> reminders) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      return await ref.read(pendingRemindersRepositoryProvider).send(reminders);
    } finally {
      if (ref.mounted) state = const AsyncData(null);
    }
  }
}
