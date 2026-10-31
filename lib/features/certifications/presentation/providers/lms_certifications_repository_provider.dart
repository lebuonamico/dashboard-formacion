import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/data/supabase_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lmsCertificationsRepositoryProvider =
    Provider<LmsCertificationsRepository>(
      (ref) => SupabaseConfig.enabled
          ? SupabaseLmsCertificationsRepository(
              ref.watch(supabaseClientProvider),
              ref.watch(coursesRepositoryProvider),
            )
          : InMemoryLmsCertificationsRepository(),
    );
