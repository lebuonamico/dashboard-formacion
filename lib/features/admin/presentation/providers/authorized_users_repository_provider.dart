import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/admin/data/in_memory_authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/data/supabase_authorized_users_repository.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authorizedUsersRepositoryProvider = Provider<AuthorizedUsersRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseAuthorizedUsersRepository(ref.watch(supabaseClientProvider))
      : InMemoryAuthorizedUsersRepository(),
);
