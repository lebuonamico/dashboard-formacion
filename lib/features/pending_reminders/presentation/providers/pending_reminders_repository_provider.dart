import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/pending_reminders/data/in_memory_pending_reminders_repository.dart';
import 'package:app_finnegans/features/pending_reminders/data/supabase_pending_reminders_repository.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminders_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingRemindersRepositoryProvider = Provider<PendingRemindersRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabasePendingRemindersRepository(ref.watch(supabaseClientProvider))
      : InMemoryPendingRemindersRepository(),
);
