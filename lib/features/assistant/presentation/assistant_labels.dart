import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';

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
