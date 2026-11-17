import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminders_repository.dart';

const noPendingReminders =
    'No hay cursos pendientes para notificar con estos filtros.';

String peopleCount(int count) =>
    count == 1 ? '1 colaborador' : '$count colaboradores';

String courseCount(int count) => count == 1 ? '1 curso' : '$count cursos';

String emailCount(int count) => count == 1 ? '1 mail' : '$count mails';

extension SkipReasonLabel on SkipReason {
  String get label => switch (this) {
    SkipReason.outsidePayroll => 'fuera de la nómina',
    SkipReason.inactive => 'inactivo en la nómina',
    SkipReason.missingEmail => 'sin mail en la nómina',
  };
}

String pendingReminderSuccess(PendingReminderResult result) {
  final sent = result.sent == 1
      ? 'Se envió 1 mail'
      : 'Se enviaron ${result.sent} mails';
  final notes = [
    if (result.failed > 0) '${result.failed} con error',
    if (result.skipped > 0) '${result.skipped} sin enviar',
  ];
  return notes.isEmpty ? '$sent.' : '$sent (${notes.join(', ')}).';
}

String pendingReminderFailure(Object error) {
  final reason = switch (error) {
    PendingReminderException(type: PendingReminderErrorType.session) =>
      'La sesión venció. Volvé a iniciar sesión.',
    PendingReminderException(type: PendingReminderErrorType.permission) =>
      'No tenés permiso para enviar notificaciones.',
    PendingReminderException(type: PendingReminderErrorType.unavailable) =>
      'El envío de mails no está configurado en el servidor.',
    PendingReminderException(type: PendingReminderErrorType.limit) =>
      'Se alcanzó el límite de envíos. Probá más tarde.',
    PendingReminderException(type: PendingReminderErrorType.connection) =>
      'No hubo respuesta del servidor. Revisá la conexión.',
    _ => 'Intentá nuevamente.',
  };
  return 'No se enviaron los mails. $reason';
}
