import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/assistant/data/offline_assistant_repository.dart';
import 'package:app_finnegans/features/assistant/data/supabase_assistant_repository.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseAssistantRepository(ref.watch(supabaseClientProvider))
      : const OfflineAssistantRepository(),
);
