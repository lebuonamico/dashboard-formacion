import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_repository.dart';

/// Local mode has no session: the chat is visible but never answers.
class OfflineAssistantRepository implements AssistantRepository {
  const OfflineAssistantRepository();

  @override
  Future<String> ask(String message, {Future<void>? cancellation}) async =>
      throw const AssistantException(AssistantErrorType.session, status: 401);
}
