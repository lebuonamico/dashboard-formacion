import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/org_structure/data/in_memory_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/data/supabase_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final orgStructureRepositoryProvider = Provider<OrgStructureRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseOrgStructureRepository(ref.watch(supabaseClientProvider))
      : InMemoryOrgStructureRepository(),
);
