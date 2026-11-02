import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';

/// Starts without versions: the default plan of each seniority applies.
class InMemoryTrainingPlanRepository implements TrainingPlanRepository {
  final TrainingPlanService _service;
  TrainingPlanHistory _plans;

  InMemoryTrainingPlanRepository([
    TrainingPlanHistory plans = const TrainingPlanHistory.empty(),
    this._service = const TrainingPlanService(),
  ]) : _plans = plans;

  @override
  Future<TrainingPlanHistory> getPlans() async => _plans;

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    _plans = _service.withVersion(
      _plans,
      version.copyWith(plan: _service.validate(version.plan)),
    );
  }
}
