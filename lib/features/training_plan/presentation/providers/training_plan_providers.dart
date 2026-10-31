import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/training_plan/data/in_memory_training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/data/supabase_training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trainingPlanRepositoryProvider = Provider<TrainingPlanRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseTrainingPlanRepository(ref.watch(supabaseClientProvider))
      : InMemoryTrainingPlanRepository(),
);

/// Saving a version invalidates it and every compliance figure recalculates.
final trainingPlanHistoryProvider = FutureProvider<TrainingPlanHistory>(
  (ref) => ref.watch(trainingPlanRepositoryProvider).getPlans(),
);
