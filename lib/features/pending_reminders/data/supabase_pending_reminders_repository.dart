import 'dart:async';

import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminders_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PendingReminderException _fromHttp(int status) =>
    PendingReminderException(switch (status) {
      401 => PendingReminderErrorType.session,
      403 => PendingReminderErrorType.permission,
      429 => PendingReminderErrorType.limit,
      503 => PendingReminderErrorType.unavailable,
      0 || 408 || 504 => PendingReminderErrorType.connection,
      _ => PendingReminderErrorType.unknown,
    }, status: status);

/// Calls the `notificar-pendientes` Edge Function with the shared client, so
/// the Supabase session goes along. Only employee and course IDs travel: the
/// function reads the emails and checks again, with the user's RLS, that
/// each course is still pending and visible. It knows nothing of Resend.
class SupabasePendingRemindersRepository implements PendingRemindersRepository {
  /// The function's own limit per request.
  static const maxRecipients = 500;

  final SupabaseClient _client;
  final Duration timeout;

  SupabasePendingRemindersRepository(
    this._client, {
    this.timeout = const Duration(seconds: 60),
  });

  @override
  Future<PendingReminderResult> send(List<PendingReminder> reminders) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) throw _fromHttp(401);
    var sent = 0, failed = 0, skipped = 0;
    for (var start = 0; start < reminders.length; start += maxRecipients) {
      final end = start + maxRecipients < reminders.length
          ? start + maxRecipients
          : reminders.length;
      final result = await _sendBatch(reminders.sublist(start, end));
      sent += result.sent;
      failed += result.failed;
      skipped += result.skipped;
    }
    return PendingReminderResult(sent: sent, failed: failed, skipped: skipped);
  }

  Future<PendingReminderResult> _sendBatch(
    List<PendingReminder> reminders,
  ) async {
    try {
      final response = await _client.functions
          .invoke(
            'notificar-pendientes',
            body: {
              'destinatarios': [
                for (final reminder in reminders)
                  {
                    'legajo': reminder.employeeId,
                    'cursos': [
                      for (final course in reminder.courses) course.courseId,
                    ],
                  },
              ],
            },
          )
          .timeout(timeout);
      if (response.status < 200 || response.status >= 300) {
        throw _fromHttp(response.status);
      }
      final data = response.data;
      if (data is! Map) {
        throw const PendingReminderException(PendingReminderErrorType.unknown);
      }
      int count(String key) => (data[key] as num?)?.toInt() ?? 0;
      return PendingReminderResult(
        sent: count('enviados'),
        failed: count('fallidos'),
        skipped: count('omitidos'),
      );
    } on FunctionException catch (error) {
      throw _fromHttp(error.status);
    } on TimeoutException {
      throw const PendingReminderException(PendingReminderErrorType.connection);
    } on PendingReminderException {
      rethrow;
    } catch (_) {
      // No internal messages or bodies reach the browser.
      throw const PendingReminderException(PendingReminderErrorType.unknown);
    }
  }
}
