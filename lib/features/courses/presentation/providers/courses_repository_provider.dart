import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/data/supabase_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  if (!SupabaseConfig.enabled) return InMemoryCoursesRepository();
  // The repository caches the catalog it read: another session reads again.
  ref.watch(sessionDataProvider);
  return SupabaseCoursesRepository(ref.watch(supabaseClientProvider));
});
