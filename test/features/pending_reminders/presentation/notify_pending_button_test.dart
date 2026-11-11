import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/pending_reminders/data/in_memory_pending_reminders_repository.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminders_repository.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/providers/pending_reminders_providers.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/providers/pending_reminders_repository_provider.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/widgets/notify_pending_button.dart';
import 'package:app_finnegans/features/pending_reminders/presentation/widgets/pending_reminders_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = PendingReminderPlan(
  reminders: [
    PendingReminder(
      employeeId: '1',
      fullName: 'Ana Pérez',
      email: 'ana@finnegans.com',
      courses: [
        PendingCourse(courseId: 'C1', courseName: 'Administración de accesos'),
        PendingCourse(courseId: 'C2', courseName: 'Oratoria'),
      ],
    ),
  ],
  skipped: [
    SkippedReminder(
      employeeId: '7',
      fullName: 'Beto Gómez',
      pendingCourses: 1,
      reason: SkipReason.missingEmail,
    ),
  ],
);

class _FailingRepository implements PendingRemindersRepository {
  @override
  Future<PendingReminderResult> send(List<PendingReminder> reminders) async =>
      throw const PendingReminderException(
        PendingReminderErrorType.unavailable,
        status: 503,
      );
}

Future<void> _showButton(
  WidgetTester tester, {
  required PendingReminderPlan plan,
  required PendingRemindersRepository repository,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pendingReminderPlanProvider.overrideWith((ref) async => plan),
        pendingRemindersRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: NotifyPendingButton())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra a quién se notifica y qué cursos antes de enviar', (
    tester,
  ) async {
    final repository = InMemoryPendingRemindersRepository();
    await _showButton(tester, plan: _plan, repository: repository);

    await tester.tap(find.text('Notificar pendientes por mail'));
    await tester.pumpAndSettle();

    expect(find.text('Notificar cursos pendientes'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@finnegans.com'), findsOneWidget);
    expect(find.text('• Administración de accesos'), findsOneWidget);
    expect(find.text('• Oratoria'), findsOneWidget);
    expect(find.textContaining('Beto Gómez'), findsOneWidget);
    expect(find.textContaining('sin mail en la nómina'), findsOneWidget);
    expect(find.text('Enviar 1 mail'), findsOneWidget);
  });

  testWidgets('Cancelar no envía nada', (tester) async {
    final repository = InMemoryPendingRemindersRepository();
    await _showButton(tester, plan: _plan, repository: repository);

    await tester.tap(find.text('Notificar pendientes por mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Notificar cursos pendientes'), findsNothing);
    expect(repository.sent, isEmpty);
  });

  testWidgets('Confirmar envía los mails y avisa el resultado', (tester) async {
    final repository = InMemoryPendingRemindersRepository();
    await _showButton(tester, plan: _plan, repository: repository);

    await tester.tap(find.text('Notificar pendientes por mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmPendingRemindersKey));
    await tester.pumpAndSettle();

    expect(repository.sent.map((r) => r.employeeId), ['1']);
    expect(find.text('Se envió 1 mail.'), findsOneWidget);
  });

  testWidgets('Un error del servidor se explica en el SnackBar', (
    tester,
  ) async {
    await _showButton(tester, plan: _plan, repository: _FailingRepository());

    await tester.tap(find.text('Notificar pendientes por mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmPendingRemindersKey));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se enviaron los mails. '
        'El envío de mails no está configurado en el servidor.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Sin pendientes avisa y no abre el diálogo', (tester) async {
    final repository = InMemoryPendingRemindersRepository();
    await _showButton(
      tester,
      plan: PendingReminderPlan.empty,
      repository: repository,
    );

    await tester.tap(find.text('Notificar pendientes por mail'));
    await tester.pumpAndSettle();

    expect(find.text('Notificar cursos pendientes'), findsNothing);
    expect(
      find.text('No hay cursos pendientes para notificar con estos filtros.'),
      findsOneWidget,
    );
    expect(repository.sent, isEmpty);
  });
}
