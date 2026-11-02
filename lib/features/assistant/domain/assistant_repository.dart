/// Sends the composed message to the AI service. Never retries; failures are
/// [AssistantException]s.
abstract interface class AssistantRepository {
  Future<String> ask(String message, {Future<void>? cancellation});
}
