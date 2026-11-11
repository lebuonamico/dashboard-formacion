import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';

/// Sends the reminders. Failures are [PendingReminderException]s.
abstract interface class PendingRemindersRepository {
  Future<PendingReminderResult> send(List<PendingReminder> reminders);
}

enum PendingReminderErrorType {
  session,
  permission,
  unavailable,
  limit,
  connection,
  unknown,
}

class PendingReminderException implements Exception {
  final PendingReminderErrorType type;
  final int? status;

  const PendingReminderException(this.type, {this.status});
}
