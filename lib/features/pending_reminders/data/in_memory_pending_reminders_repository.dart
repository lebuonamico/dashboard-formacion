import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminders_repository.dart';

/// Local mode sends nothing: it keeps the reminders so the whole flow can be
/// tried without Supabase.
class InMemoryPendingRemindersRepository implements PendingRemindersRepository {
  final List<PendingReminder> sent = [];

  @override
  Future<PendingReminderResult> send(List<PendingReminder> reminders) async {
    sent.addAll(reminders);
    return PendingReminderResult(sent: reminders.length, failed: 0, skipped: 0);
  }
}
