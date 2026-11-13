import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada pantalla tiene su etiqueta', () {
    expect(
      {for (final module in AssistantModule.values) module: module.label},
      {
        AssistantModule.dashboard: 'Dashboard',
        AssistantModule.areas: 'Áreas',
        AssistantModule.teams: 'Equipos',
        AssistantModule.teamDetail: 'Detalle de equipo',
        AssistantModule.people: 'Colaboradores',
        AssistantModule.courses: 'Cursos',
        AssistantModule.settings: 'Configuración',
        AssistantModule.others: 'Ayuda general',
      },
    );
  });

  test('el contexto dice si lleva datos', () {
    AssistantContext context({required bool dynamic}) => AssistantContext(
      module: AssistantModule.teams,
      dynamic: dynamic,
      data: const {},
    );

    expect(
      assistantContextLabel(context(dynamic: true)),
      'Equipos · datos del proyecto',
    );
    expect(
      assistantContextLabel(context(dynamic: false)),
      'Equipos · ayuda conceptual',
    );
  });

  test('cada problema de la pregunta tiene su mensaje', () {
    expect(
      {for (final issue in QuestionIssue.values) issue: issue.message},
      {
        QuestionIssue.empty: 'Escribí una pregunta.',
        QuestionIssue.tooLong: 'Usá hasta 1200 caracteres.',
        QuestionIssue.sensitive:
            'Quitá correos, enlaces, claves, tokens o credenciales de la pregunta.',
      },
    );
    expect(
      {
        for (final issue in AssistantQueryIssue.values)
          issue: AssistantQueryException(issue).message,
      },
      {
        AssistantQueryIssue.invalidMonth: 'Indicá un mes válido entre 1 y 12.',
        AssistantQueryIssue.contextTooLarge:
            'La consulta supera el contexto disponible. Pedí menos períodos o precisá el equipo, área o curso.',
      },
    );
  });

  test('cada tipo de error tiene su mensaje', () {
    expect(
      {
        for (final type in AssistantErrorType.values)
          type: AssistantException(type).message,
      },
      {
        AssistantErrorType.temporary:
            'El servicio de IA está experimentando una dificultad temporal. Tu pregunta se conservó y podés volver a intentarlo en unos momentos.',
        AssistantErrorType.limit:
            'El asistente alcanzó temporalmente su límite de consultas. Intentá nuevamente más tarde.',
        AssistantErrorType.connection:
            'No pudimos completar la conexión. Revisá tu conexión a Internet e intentá nuevamente.',
        AssistantErrorType.session:
            'Tu sesión venció. Volvé a iniciar sesión para continuar utilizando el asistente.',
        AssistantErrorType.permission:
            'No tenés permisos para utilizar el asistente. Si creés que es un error, consultá con el administrador.',
        AssistantErrorType.unknown:
            'No pudimos completar tu consulta en este momento. Podés volver a intentarlo.',
      },
    );
  });
}
