import 'package:app_finnegans/domain/modelos/plan_formacion.dart';

/// Versiones del plan de formación por seniority. Los errores para mostrar se
/// lanzan como [FormatException].
abstract class TrainingPlanRepository {
  Future<TrainingPlanHistory> getPlans();

  /// Guarda el plan que rige desde ese mes. Si ya había una versión para ese
  /// mismo mes, la reemplaza.
  Future<void> saveVersion(TrainingPlanVersion version);
}
