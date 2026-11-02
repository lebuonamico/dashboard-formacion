import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';

class AssistantContext {
  final AssistantModule module;
  final bool dynamic;
  final Map<String, Object?> data;

  AssistantContext({
    required this.module,
    required this.dynamic,
    required Map<String, Object?> data,
  }) : data = Map.unmodifiable(data);
}
