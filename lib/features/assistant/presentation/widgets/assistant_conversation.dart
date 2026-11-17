import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_chat_notifier.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_message.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantConversation extends StatelessWidget {
  final ChatState status;
  final bool real;
  final ScrollController controller;
  final ValueChanged<String> onSuggestion;

  const AssistantConversation({
    super.key,
    required this.status,
    required this.real,
    required this.controller,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    key: const Key('asistente_viewport'),
    child: Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        key: const Key('asistente_scroll'),
        controller: controller,
        primary: false,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContextNotice(real: real),
            if (status.messages.isEmpty &&
                !status.sending &&
                status.error == null)
              _Welcome(sending: status.sending, onSuggestion: onSuggestion)
            else ...[
              const SizedBox(height: 20),
              for (final message in status.messages)
                Padding(
                  key: GlobalObjectKey(message),
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AssistantMessage(message: message),
                ),
            ],
            if (status.sending) const _AnalyzingQuery(),
            if (status.error case final error?)
              _ChatError(
                error: error,
                canRetry: status.canRetry,
                sending: status.sending,
              ),
          ],
        ),
      ),
    ),
  );
}

class _ContextNotice extends StatelessWidget {
  final bool real;

  const _ContextNotice({required this.real});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('asistente_aviso'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: context.colors.ai.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.layers_outlined,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            real
                ? 'Contexto dinámico · Datos disponibles en la aplicación'
                : 'Ayuda conceptual · Indicadores deshabilitados',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChatError extends ConsumerWidget {
  final String error;
  final bool canRetry;
  final bool sending;

  const _ChatError({
    required this.error,
    required this.canRetry,
    required this.sending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warning = context.colors.warning;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warning.background,
          border: Border.all(color: warning.text.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: warning.text, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu consulta sigue disponible',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: warning.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    error,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.intermediateText,
                      height: 1.5,
                    ),
                  ),
                  if (canRetry) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('asistente_reintentar'),
                      onPressed: sending
                          ? null
                          : () => ref
                                .read(assistantChatProvider.notifier)
                                .retry(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se conserva la misma pregunta. Tu borrador actual no se modifica.',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  static const _suggestions = [
    (Icons.insights_rounded, '¿Cómo viene el cumplimiento?'),
    (Icons.groups_outlined, '¿Qué equipos necesitan atención?'),
    (Icons.auto_stories_outlined, '¿Qué cursos hay disponibles?'),
    (Icons.upload_file_outlined, '¿Cómo funciona la importación de nómina?'),
  ];

  final bool sending;
  final ValueChanged<String> onSuggestion;

  const _Welcome({required this.sending, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Column(
        children: [
          const AssistantSymbol(size: 68, halo: true),
          const SizedBox(height: 22),
          Text(
            '¡Hola! ¿En qué puedo ayudarte?',
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              height: 1.25,
              letterSpacing: -.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analizá indicadores, explorá capacitaciones y encontrá respuestas sobre tu organización.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 360 &&
                  MediaQuery.textScalerOf(context).scale(14) < 19;
              final width = columns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (icon, question) in _suggestions)
                    SizedBox(
                      width: width,
                      child: _SuggestionButton(
                        icon: icon,
                        question: question,
                        tall: columns,
                        onPressed: sending
                            ? null
                            : () => onSuggestion(question),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  final IconData icon;
  final String question;
  final bool tall;
  final VoidCallback? onPressed;

  const _SuggestionButton({
    required this.icon,
    required this.question,
    required this.tall,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.intermediateText,
        backgroundColor: context.colorScheme.surface,
        padding: const EdgeInsets.all(14),
        minimumSize: Size(0, tall ? 100 : 66),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: colors.ai.text),
          const SizedBox(height: 9),
          Text(
            question,
            style: context.textTheme.bodySmall?.copyWith(
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingQuery extends StatefulWidget {
  const _AnalyzingQuery();

  @override
  State<_AnalyzingQuery> createState() => _AnalyzingQueryState();
}

class _AnalyzingQueryState extends State<_AnalyzingQuery>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (assistantMotion(context, 1) == Duration.zero) {
      _animation.stop();
      _animation.value = .5;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Analizando tu consulta',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            const AssistantSymbol(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analizando tu consulta…',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final wave =
                      (math.sin(_animation.value * math.pi * 2 - i * .9) + 1) /
                      2;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Opacity(
                      opacity: .3 + .7 * wave,
                      child: Transform.translate(
                        offset: Offset(0, -2 * wave),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: context.colors.ai.text,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
