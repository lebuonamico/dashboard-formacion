import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';

/// Starts without versions: the default plan of each seniority applies.
class InMemoryTrainingPlanRepository implements TrainingPlanRepository {
  TrainingPlanHistory _plans;

  InMemoryTrainingPlanRepository([
    TrainingPlanHistory plans = const TrainingPlanHistory.empty(),
  ]) : _plans = plans;

  @override
  Future<TrainingPlanHistory> getPlans() async => _plans;

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    _plans = _plans.withVersion(version);
  }
}
