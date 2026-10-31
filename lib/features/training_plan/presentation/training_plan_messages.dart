import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';

/// The error to show under an hours field, or `null` when it is valid.
String? hoursErrorText(
  TrainingPlanService service,
  double? hours,
) => switch (service.hoursIssue(hours)) {
  null => null,
  HoursIssue.notANumber => 'Ingresá un número',
  HoursIssue.negative => 'No puede ser negativo',
  HoursIssue.aboveMax =>
    'Máximo ${TrainingPlanService.maxHoursPerCategory.toStringAsFixed(0)} h',
};
