import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/data/supabase_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final crmTimeEntriesRepositoryProvider = Provider<CrmTimeEntriesRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseCrmTimeEntriesRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(coursesRepositoryProvider),
        )
      : InMemoryCrmTimeEntriesRepository(),
);
