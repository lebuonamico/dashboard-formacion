import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/courses/presentation/providers/course_services_providers.dart';

final complianceServiceProvider = FutureProvider<ComplianceService>((
  ref,
) async {
  final plans = await ref.watch(trainingPlanHistoryProvider.future);
  return ComplianceService(
    plans: plans,
    classification: ref.watch(courseClassificationServiceProvider),
  );
});
