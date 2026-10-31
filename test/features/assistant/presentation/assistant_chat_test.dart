import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: AssistantChat()),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Preguntale a la IA'));
  await tester.pumpAndSettle();
}

IconButton _sendButton(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(
    of: find.byIcon(Icons.arrow_upward_rounded),
    matching: find.byType(IconButton),
  ),
);

String _draft(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('asistente_input')))
    .controller!
    .text;

void main() {
  testWidgets('Abre el panel con la bienvenida y el envío deshabilitado', (
    tester,
  ) async {
    final container = await _show(tester);
    expect(container.read(assistantChatProvider).open, isFalse);

    await _open(tester);

    expect(container.read(assistantChatProvider).open, isTrue);
    expect(find.byKey(const Key('asistente_panel')), findsOneWidget);
    expect(find.byKey(const Key('asistente_encabezado')), findsOneWidget);
    expect(find.text('¡Hola! ¿En qué puedo ayudarte?'), findsOneWidget);
    expect(
      find.text('Contexto dinámico · Datos disponibles en la aplicación'),
      findsOneWidget,
    );
    expect(_sendButton(tester).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.copy_outlined),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Una sugerencia llena el borrador y habilita el envío', (
    tester,
  ) async {
    await _show(tester);
    await _open(tester);

    await tester.tap(find.text('¿Qué cursos hay disponibles?'));
    await tester.pump();

    expect(_draft(tester), '¿Qué cursos hay disponibles?');
    expect(_sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('Sin sesión, enviar conserva el borrador y avisa sin reintento', (
    tester,
  ) async {
    final container = await _show(tester);
    await _open(tester);

    await tester.enterText(
      find.byKey(const Key('asistente_input')),
      '¿Qué es una hora válida?',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar pregunta'));
    await tester.pumpAndSettle();

    expect(_draft(tester), '¿Qué es una hora válida?');
    expect(find.text('Tu consulta sigue disponible'), findsOneWidget);
    expect(find.byKey(const Key('asistente_reintentar')), findsNothing);
    expect(container.read(assistantChatProvider).error, isNotNull);
    expect(container.read(assistantChatProvider).messages, isEmpty);
  }, skip: SupabaseConfig.enabled);

  testWidgets('Limpiar pide confirmación y borra el borrador', (tester) async {
    await _show(tester);
    await _open(tester);
    await tester.enterText(
      find.byKey(const Key('asistente_input')),
      'Borrador',
    );

    await tester.tap(find.byTooltip('Limpiar conversación'));
    await tester.pumpAndSettle();
    expect(find.text('¿Limpiar esta conversación?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Limpiar conversación'));
    await tester.pumpAndSettle();

    expect(find.text('¿Limpiar esta conversación?'), findsNothing);
    expect(_draft(tester), isEmpty);
  });

  testWidgets('Minimizar cierra el panel', (tester) async {
    final container = await _show(tester);
    await _open(tester);

    await tester.tap(find.byTooltip('Minimizar asistente'));
    await tester.pumpAndSettle();

    expect(container.read(assistantChatProvider).open, isFalse);
  });
}
