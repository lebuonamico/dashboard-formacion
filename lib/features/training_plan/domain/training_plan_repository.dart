import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';

/// Versions of the training plan by seniority. Errors to show are thrown
/// as [FormatException].
abstract class TrainingPlanRepository {
  Future<TrainingPlanHistory> getPlans();

  /// Saves the plan effective from that month. If that month already had a
  /// version, it replaces it.
  Future<void> saveVersion(TrainingPlanVersion version);
}
