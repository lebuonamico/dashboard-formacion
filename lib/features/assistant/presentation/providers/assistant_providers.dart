import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context_builder.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_data.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_prompt_composer.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiRealContextProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('IA_CONTEXTO_REAL', defaultValue: true),
);

final assistantQueryPlannerProvider = Provider<AssistantQueryPlanner>(
  (ref) => const AssistantQueryPlanner(),
);

final assistantPromptComposerProvider = Provider<AssistantPromptComposer>(
  (ref) => const AssistantPromptComposer(),
);

final assistantContextBuilderProvider = Provider<AssistantContextBuilder>((
  ref,
) {
  final teams = ref.watch(teamsServiceProvider);
  return AssistantContextBuilder(
    planner: ref.watch(assistantQueryPlannerProvider),
    periods: teams.periods,
    teams: teams,
    areas: ref.watch(areasServiceProvider),
    kpis: ref.watch(dashboardKpisServiceProvider),
    trend: ref.watch(dashboardTrendServiceProvider),
    scopes: ref.watch(userScopeServiceProvider),
  );
});

/// The same data as the screens, with the session's scope. The assistant only
/// reads it when a query sends indicators.
final assistantDataProvider = FutureProvider<AssistantData>((ref) async {
  final (
    employees,
    history,
    courses,
    timeEntries,
    certifications,
    scope,
    complianceService,
  ) = await (
    ref.watch(employeesProvider.future),
    ref.watch(employeeHistoryProvider.future),
    ref.watch(coursesProvider.future),
    ref.watch(crmTimeEntriesProvider.future),
    ref.watch(lmsCertificationsProvider.future),
    ref.watch(userScopeProvider.future),
    ref.watch(complianceServiceProvider.future),
  ).wait;
  return AssistantData(
    employees: employees,
    history: history,
    courses: courses,
    timeEntries: timeEntries,
    certifications: certifications,
    scope: scope,
    complianceService: complianceService,
  );
});
