import 'dart:async';

import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_repository.dart';
import 'package:app_finnegans/features/assistant/domain/chat_message.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_labels.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_repository_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _dashboard = AssistantDestination(AssistantModule.dashboard);
const _question = '¿Qué significa cumplimiento?';

AuthState _session({
  String email = 'academia@finnegans-demo.com',
  bool isAuthorized = true,
  bool signedIn = true,
}) => AuthState(
  user: signedIn ? AuthUser(id: email, email: email) : null,
  isAuthorized: isAuthorized,
  role: 'academia',
);

class _SwitchableAuth extends AuthNotifier {
  _SwitchableAuth(AuthState super.initial);

  void switchTo(AuthState next) => state = next;
}

class _FakeRepository implements AssistantRepository {
  final messages = <String>[];
  final _answers = <FutureOr<String> Function()>[];

  void answer(String text) => _answers.add(() => text);

  void fail(AssistantException error) => _answers.add(() => throw error);

  Completer<String> hold() {
    final completer = Completer<String>();
    _answers.add(() => completer.future);
    return completer;
  }

  @override
  Future<String> ask(String message, {Future<void>? cancellation}) async {
    messages.add(message);
    return _answers.isEmpty ? 'Respuesta' : _answers.removeAt(0)();
  }
}

class _Chat {
  final repository = _FakeRepository();
  late final _SwitchableAuth auth;
  late final ProviderContainer container;

  _Chat({AuthState? session, bool dynamicContext = false}) {
    auth = _SwitchableAuth(session ?? _session());
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        assistantRepositoryProvider.overrideWithValue(repository),
        aiRealContextProvider.overrideWithValue(dynamicContext),
        periodFilterProvider.overrideWith(
          () => PeriodFilterNotifier(
            const PeriodFilter(
              scope: PeriodScope.monthly,
              month: 7,
              year: 2026,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(assistantChatProvider, (_, _) {});
  }

  ChatState get state => container.read(assistantChatProvider);

  AssistantChatNotifier get notifier =>
      container.read(assistantChatProvider.notifier);

  Future<void> send(String question) => notifier.send(question, _dashboard);

  Future<void> untilAsked(int count) async {
    for (var i = 0; i < 100 && repository.messages.length < count; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(repository.messages, hasLength(count));
  }
}

String _message(AssistantErrorType type) => AssistantException(type).message;

List<(String, bool, String)> _bubbles(ChatState state) => [
  for (final message in state.messages)
    (message.text, message.isUser, message.context),
];

void main() {
  group('ChatState', () {
    test('copyWith conserva el error salvo que se lo pase', () {
      final state = ChatState(error: 'falló', canRetry: true);

      expect(state.copyWith(open: true).error, 'falló');
      expect(state.copyWith(sending: true).canRetry, isTrue);
      expect(state.copyWith(error: null).error, isNull);
      expect(state.copyWith(error: 'otro').error, 'otro');
    });

    test('los mensajes no se pueden modificar', () {
      final state = ChatState(
        messages: [
          const ChatMessage(text: 'Hola', isUser: true, context: 'Dashboard'),
        ],
      );

      expect(
        () => state.messages.add(
          const ChatMessage(text: 'x', isUser: true, context: ''),
        ),
        throwsUnsupportedError,
      );
      expect(() => state.copyWith().messages.clear(), throwsUnsupportedError);
    });
  });

  group('AssistantChatNotifier', () {
    test('una consulta agrega la pregunta y la respuesta', () async {
      final chat = _Chat();

      await chat.send('  $_question  ');

      expect(_bubbles(chat.state), [
        (_question, true, 'Dashboard'),
        ('Respuesta', false, 'Dashboard · ayuda conceptual'),
      ]);
      expect(chat.state.sending, isFalse);
      expect(chat.state.error, isNull);
      expect(
        chat.repository.messages.single,
        allOf(
          startsWith('Sos el asistente de formación de Finnegans'),
          endsWith('PREGUNTA="$_question"'),
        ),
      );
    });

    test('un error temporal conserva la pregunta y el reintento reenvía el '
        'mismo mensaje', () async {
      final chat = _Chat(dynamicContext: true);
      chat.repository.fail(
        const AssistantException(AssistantErrorType.temporary, status: 503),
      );

      await chat.send('¿Cómo viene el cumplimiento?');

      expect(_bubbles(chat.state), [
        ('¿Cómo viene el cumplimiento?', true, 'Dashboard'),
      ]);
      expect(chat.state.error, _message(AssistantErrorType.temporary));
      expect(chat.state.canRetry, isTrue);

      // Otro período en pantalla no cambia lo que se reintenta.
      chat.container.read(periodFilterProvider.notifier).setMonth(8);
      await chat.notifier.retry();

      expect(chat.repository.messages, hasLength(2));
      expect(chat.repository.messages.last, chat.repository.messages.first);
      expect(_bubbles(chat.state), [
        ('¿Cómo viene el cumplimiento?', true, 'Dashboard'),
        ('Respuesta', false, 'Dashboard · datos del proyecto'),
      ]);
      expect(chat.state.error, isNull);
      expect(chat.state.canRetry, isFalse);
    });

    test('sin sesión o sin permiso no se consulta ni se reintenta', () async {
      for (final (session, type) in [
        (_session(signedIn: false), AssistantErrorType.session),
        (_session(isAuthorized: false), AssistantErrorType.permission),
      ]) {
        final chat = _Chat(session: session);

        await chat.send(_question);

        expect(chat.state.messages, isEmpty, reason: type.name);
        expect(chat.state.error, _message(type), reason: type.name);
        expect(chat.state.canRetry, isFalse, reason: type.name);
        expect(chat.repository.messages, isEmpty, reason: type.name);
      }
    });

    test('una sesión vencida en el servicio no ofrece reintento', () async {
      final chat = _Chat();
      chat.repository.fail(
        const AssistantException(AssistantErrorType.session, status: 401),
      );

      await chat.send(_question);
      await chat.notifier.retry();

      expect(chat.state.error, _message(AssistantErrorType.session));
      expect(chat.state.canRetry, isFalse);
      expect(chat.repository.messages, hasLength(1));
    });

    test('una pregunta inválida no agrega mensajes', () async {
      final chat = _Chat();

      await chat.send('   ');

      expect(chat.state.messages, isEmpty);
      expect(chat.state.error, 'Escribí una pregunta.');
      expect(chat.state.canRetry, isFalse);
    });

    test('un mes inválido pide reformular, sin reintento', () async {
      final chat = _Chat(dynamicContext: true);

      await chat.send('¿Cómo fue el mes 13?');

      expect(_bubbles(chat.state), [
        ('¿Cómo fue el mes 13?', true, 'Dashboard'),
      ]);
      expect(chat.state.error, 'Indicá un mes válido entre 1 y 12.');
      expect(chat.state.canRetry, isFalse);
      expect(chat.repository.messages, isEmpty);
    });

    test('abrir y cerrar conservan el error', () async {
      final chat = _Chat();
      await chat.send('   ');

      chat.notifier.open();
      expect(
        (chat.state.open, chat.state.error),
        (true, 'Escribí una pregunta.'),
      );
      chat.notifier.close();
      expect(
        (chat.state.open, chat.state.error),
        (false, 'Escribí una pregunta.'),
      );
    });

    test('una nueva consulta borra el error anterior', () async {
      final chat = _Chat();
      await chat.send('   ');

      await chat.send(_question);

      expect(chat.state.error, isNull);
    });

    test('guarda hasta 40 mensajes', () async {
      final chat = _Chat();

      for (var i = 1; i <= 25; i++) {
        await chat.send('Pregunta $i');
      }

      expect(chat.state.messages, hasLength(40));
      expect(chat.state.messages.first.text, 'Pregunta 6');
      expect(chat.state.messages.last.text, 'Respuesta');
    });

    test('mientras espera una respuesta ignora otra consulta', () async {
      final chat = _Chat();
      final answer = chat.repository.hold();

      final first = chat.send(_question);
      await chat.untilAsked(1);
      expect(chat.state.sending, isTrue);
      await chat.send('Otra pregunta');
      answer.complete('Listo');
      await first;

      expect(chat.repository.messages, hasLength(1));
      expect(chat.state.messages.map((m) => m.text), [_question, 'Listo']);
    });

    test(
      'al cambiar de usuario se vacía y descarta la respuesta tardía',
      () async {
        final chat = _Chat();
        final answer = chat.repository.hold();

        final pending = chat.send(_question);
        await chat.untilAsked(1);
        chat.auth.switchTo(_session(email: 'otra@finnegans-demo.com'));

        expect(chat.state.messages, isEmpty);
        expect(chat.state.sending, isTrue);
        answer.complete('Tarde');
        await pending;

        expect(chat.state.messages, isEmpty);
        expect(chat.state.sending, isFalse);
        expect(chat.state.error, isNull);
      },
    );

    test('limpiar descarta la respuesta en curso', () async {
      final chat = _Chat();
      final answer = chat.repository.hold();

      final pending = chat.send(_question);
      await chat.untilAsked(1);
      chat.notifier.clear();
      answer.complete('Tarde');
      await pending;

      expect(chat.state.messages, isEmpty);
      expect(chat.state.sending, isFalse);
    });
  }, skip: SupabaseConfig.enabled);
}
