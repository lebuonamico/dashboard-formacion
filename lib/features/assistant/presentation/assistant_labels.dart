import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';

extension AssistantModuleLabel on AssistantModule {
  String get label => switch (this) {
    AssistantModule.dashboard => 'Dashboard',
    AssistantModule.areas => 'Áreas',
    AssistantModule.teams => 'Equipos',
    AssistantModule.teamDetail => 'Detalle de equipo',
    AssistantModule.people => 'Colaboradores',
    AssistantModule.courses => 'Cursos',
    AssistantModule.settings => 'Configuración',
    AssistantModule.others => 'Ayuda general',
  };
}

String assistantContextLabel(AssistantContext context) =>
    '${context.module.label} · ${context.dynamic ? 'datos del proyecto' : 'ayuda conceptual'}';

extension QuestionIssueMessage on QuestionIssue {
  String get message => switch (this) {
    QuestionIssue.empty => 'Escribí una pregunta.',
    QuestionIssue.tooLong =>
      'Usá hasta ${AssistantQueryPlanner.maxQuestion} caracteres.',
    QuestionIssue.sensitive =>
      'Quitá correos, enlaces, claves, tokens o credenciales de la pregunta.',
  };
}

extension AssistantQueryExceptionMessage on AssistantQueryException {
  String get message => switch (issue) {
    AssistantQueryIssue.invalidMonth => 'Indicá un mes válido entre 1 y 12.',
    AssistantQueryIssue.contextTooLarge =>
      'La consulta supera el contexto disponible. Pedí menos períodos o precisá el equipo, área o curso.',
  };
}

extension AssistantExceptionMessage on AssistantException {
  String get message => switch (type) {
    AssistantErrorType.temporary =>
      'El servicio de IA está experimentando una dificultad temporal. Tu pregunta se conservó y podés volver a intentarlo en unos momentos.',
    AssistantErrorType.limit =>
      'El asistente alcanzó temporalmente su límite de consultas. Intentá nuevamente más tarde.',
    AssistantErrorType.connection =>
      'No pudimos completar la conexión. Revisá tu conexión a Internet e intentá nuevamente.',
    AssistantErrorType.session =>
      'Tu sesión venció. Volvé a iniciar sesión para continuar utilizando el asistente.',
    AssistantErrorType.permission =>
      'No tenés permisos para utilizar el asistente. Si creés que es un error, consultá con el administrador.',
    AssistantErrorType.unknown =>
      'No pudimos completar tu consulta en este momento. Podés volver a intentarlo.',
  };
}
